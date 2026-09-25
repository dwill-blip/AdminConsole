# The action runner. Every button in the console goes through Invoke-ConsoleAction,
# which applies the same policy in the same order every time:
#
#   1. permission check (RBAC)          -> Denied
#   2. AppliesTo check                  -> NotApplicable
#   3. approval check                   -> ApprovalRequested / PendingApproval
#   4. collect inputs (callback)        -> Cancelled
#   5. confirmation (callback)          -> Cancelled
#   6. run, audit, consume approval     -> Success / Failed
#
# It never throws for expected outcomes; it returns a result object instead, so the
# GUI, the job runner and the tests can all use it the same way.

function Get-ConsoleTargetName {
    param([Parameter(Mandatory)]$Definition, $Target)
    if ($null -eq $Target) { return '' }
    if ($Definition.PSObject.Properties['TargetName'] -and $Definition.TargetName) {
        return [string](& $Definition.TargetName $Target)
    }
    if ($Target -is [string]) { return $Target }
    foreach ($p in 'Identity', 'UserPrincipalName', 'SamAccountName', 'Name', 'DisplayName', 'Id') {
        if ($Target.PSObject.Properties[$p] -and $Target.$p) { return [string]$Target.$p }
    }
    [string]$Target
}

function Resolve-ConsoleAction {
    param([Parameter(Mandatory)]$Action)
    if ($Action -is [string]) {
        $def = Get-ConsoleAction -Name $Action
        if (-not $def) { throw "No action named '$Action' is loaded." }
        return $def
    }
    $Action
}

function Complete-ConsoleInputs {
    # Applies defaults and checks required inputs. Returns a hashtable.
    param([Parameter(Mandatory)]$Definitions, [hashtable]$Values)
    $result = @{}
    if ($Values) { foreach ($k in $Values.Keys) { $result[$k] = $Values[$k] } }
    foreach ($d in @($Definitions)) {
        if (-not $d) { continue }
        if (-not $result.ContainsKey($d.Name) -or $null -eq $result[$d.Name]) { $result[$d.Name] = $d.Default }
        $v = $result[$d.Name]
        if ($d.Required -and ($null -eq $v -or ($v -is [string] -and [string]::IsNullOrWhiteSpace($v)))) {
            throw "'$($d.Label)' is required."
        }
        if ($d.Type -eq 'Choice' -and $v -and @($d.Choices).Count -and $v -notin $d.Choices) {
            throw "'$($d.Label)' must be one of: $($d.Choices -join ', ')"
        }
        if ($d.Type -eq 'Number' -and $null -ne $v -and "$v" -ne '') { $result[$d.Name] = [double]$v }
        if ($d.Type -eq 'Bool') { $result[$d.Name] = [bool]$v }
    }
    $result
}

function Format-InputsForAudit {
    param($Definitions, [hashtable]$Values)
    if (-not $Values -or -not $Values.Count) { return '' }
    $secret = @{}
    foreach ($d in @($Definitions)) { if ($d -and $d.Type -eq 'Password') { $secret[$d.Name] = $true } }
    ($Values.Keys | Sort-Object | ForEach-Object {
        if ($secret.ContainsKey($_)) { "$_=********" } else { "$_=$($Values[$_])" }
    }) -join '; '
}

function New-ActionResult {
    param($Action, $Target, $Status, $Message = '', $Output = $null, $CorrelationId = '')
    [pscustomobject]@{
        PSTypeName    = 'AdminConsole.ActionResult'
        Action        = $Action
        Target        = $Target
        Status        = $Status
        Message       = $Message
        Output        = $Output
        CorrelationId = $CorrelationId
    }
}

function Test-ConsoleApprovalRequired {
    # True only when the action asks for approval AND approvals are switched on in Settings.
    param([Parameter(Mandatory)]$Action)
    $def = Resolve-ConsoleAction $Action
    [bool]($def.RequiresApproval -and (Get-ConsoleSetting 'RequireApprovals' $false))
}

function Test-ConsoleActionApplies {
    param([Parameter(Mandatory)]$Action, $Target)
    $def = Resolve-ConsoleAction $Action
    if (-not $def.AppliesTo) { return $true }
    try { [bool](& $def.AppliesTo $Target) } catch { $false }
}

function Invoke-ConsoleAction {
    <#
    .SYNOPSIS  Runs one action against one target with RBAC, approvals, confirmation and audit.
    .PARAMETER GetInputs  { param($Action, $Target) ... } returns a hashtable, or $null to cancel.
    .PARAMETER Confirm    { param($Message) ... } returns $true to proceed.
    #>
    param(
        [Parameter(Mandatory)]$Action,
        $Target,
        [hashtable]$Inputs,
        [scriptblock]$GetInputs,
        [scriptblock]$Confirm
    )
    $def = Resolve-ConsoleAction $Action
    $targetName = Get-ConsoleTargetName $def $Target

    # 1. RBAC
    if (-not (Test-ConsolePermission $def.Permission)) {
        Write-ConsoleAudit -Action $def.Name -Target $targetName -Result 'Denied' -Details "Missing permission $($def.Permission)"
        return New-ActionResult $def.Name $targetName 'Denied' "You need the '$($def.Permission)' permission to run '$($def.Name)'."
    }

    # 2. Does it make sense for this target?
    if (-not (Test-ConsoleActionApplies $def $Target)) {
        return New-ActionResult $def.Name $targetName 'NotApplicable' "'$($def.Name)' does not apply to $targetName."
    }

    # 3. Approval
    $approval = $null
    if (Test-ConsoleApprovalRequired $def) {
        $state = Get-ApprovalState -ActionName $def.Name -Target $targetName
        switch ($state.Status) {
            'None' {
                $req = New-ApprovalRequest -ActionName $def.Name -Target $targetName
                return New-ActionResult $def.Name $targetName 'ApprovalRequested' "'$($def.Name)' on $targetName needs approval. Request #$($req.Id) was created - run it again once it is approved." $null $req.CorrelationId
            }
            'Pending' {
                return New-ActionResult $def.Name $targetName 'PendingApproval' "Request #$($state.Request.Id) for '$($def.Name)' on $targetName is still waiting for approval." $null $state.Request.CorrelationId
            }
            'Approved' { $approval = $state.Request }
        }
    }

    # 4. Inputs
    if (-not $Inputs -and @($def.Inputs).Count -and $GetInputs) {
        $Inputs = & $GetInputs $def $Target
        if ($null -eq $Inputs) { return New-ActionResult $def.Name $targetName 'Cancelled' 'Cancelled.' }
    }
    try { $Inputs = Complete-ConsoleInputs $def.Inputs $Inputs }
    catch { return New-ActionResult $def.Name $targetName 'Cancelled' $_.Exception.Message }

    # 5. Confirmation
    if ($Confirm -and $def.Confirm) {
        $msg = if ($def.Confirm -is [string]) { $def.Confirm -f $targetName } else { "Run '$($def.Name)' on $targetName?" }
        if (-not (& $Confirm $msg)) { return New-ActionResult $def.Name $targetName 'Cancelled' 'Cancelled.' }
    }

    # 6. Run
    $correlation = if ($approval) { $approval.CorrelationId } else { [guid]::NewGuid().ToString() }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $output = & $def.Run $Target $Inputs
        if ($approval) { Complete-ApprovalRequest -Id $approval.Id }
        $details = Format-InputsForAudit $def.Inputs $Inputs
        Write-ConsoleAudit -Action $def.Name -Target $targetName -Result 'Success' -Details $details -CorrelationId $correlation
        $text = ''
        if ($null -ne $output) { $text = (@($output) | ForEach-Object { [string]$_ }) -join "`n" }
        New-ActionResult $def.Name $targetName 'Success' ("Done in {0:n1}s. {1}" -f $sw.Elapsed.TotalSeconds, $text).Trim() $output $correlation
    }
    catch {
        $err = $_.Exception.Message
        Write-ConsoleAudit -Action $def.Name -Target $targetName -Result 'Failed' -Details $err -CorrelationId $correlation
        New-ActionResult $def.Name $targetName 'Failed' $err $null $correlation
    }
}

function Invoke-ConsoleWorkflow {
    <#
    .SYNOPSIS  Runs several actions against one target, with one confirmation up front.
    .OUTPUTS    One result per step. Wrap the call in @().
    .PARAMETER Steps  Optional subset of the workflow's steps (e.g. what the operator ticked).
    #>
    param(
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)]$Target,
        [string[]]$Steps,
        [scriptblock]$GetInputs,
        [scriptblock]$Confirm
    )
    $wf = $Workflow
    if ($Workflow -is [string]) { $wf = Get-ConsoleWorkflow -Name $Workflow; if (-not $wf) { throw "No workflow named '$Workflow'." } }
    if (-not $Steps) { $Steps = $wf.Steps }
    $targetName = Get-ConsoleTargetName ([pscustomobject]@{ TargetName = $null }) $Target

    if ($wf.Permission -and -not (Test-ConsolePermission $wf.Permission)) {
        Write-ConsoleAudit -Action $wf.Name -Target $targetName -Result 'Denied'
        return New-ActionResult $wf.Name $targetName 'Denied' "You need the '$($wf.Permission)' permission."
    }
    if ($Confirm) {
        $list = ($Steps | ForEach-Object { "  - $_" }) -join "`n"
        if (-not (& $Confirm "Run '$($wf.Name)' on $targetName?`n`n$list")) {
            return New-ActionResult $wf.Name $targetName 'Cancelled' 'Cancelled.'
        }
    }

    Write-ConsoleAudit -Action $wf.Name -Target $targetName -Result 'Started' -Details ($Steps -join ', ')
    $results = New-Object System.Collections.ArrayList
    foreach ($step in $Steps) {
        $r = Invoke-ConsoleAction -Action $step -Target $Target -GetInputs $GetInputs
        [void]$results.Add($r)
        if ($r.Status -in 'Failed', 'Denied' -and $wf.StopOnError) { break }
    }
    $summary = ($results | Group-Object Status | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ', '
    Write-ConsoleAudit -Action $wf.Name -Target $targetName -Result 'Completed' -Details $summary
    $results
}

function Invoke-ConsoleBulkAction {
    <#
    .SYNOPSIS  Runs one Row action against many report rows, with one confirmation and
               one set of inputs up front. Rows the action does not apply to are skipped.
    .OUTPUTS    One result per applicable row. Wrap the call in @().
    #>
    param(
        [Parameter(Mandatory)]$Action,
        [Parameter(Mandatory)][object[]]$Targets,
        [scriptblock]$GetInputs,
        [scriptblock]$Confirm
    )
    $def = Resolve-ConsoleAction $Action
    if (-not $def.Bulk) { throw "'$($def.Name)' cannot run on several rows at once." }
    if (-not (Test-ConsolePermission $def.Permission)) {
        Write-ConsoleAudit -Action $def.Name -Target "$(@($Targets).Count) row(s)" -Result 'Denied' -Details "Missing permission $($def.Permission)"
        return New-ActionResult $def.Name "$(@($Targets).Count) row(s)" 'Denied' "You need the '$($def.Permission)' permission to run '$($def.Name)'."
    }
    $todo = @($Targets | Where-Object { $null -ne $_ -and (Test-ConsoleActionApplies $def $_) })
    $label = "$($todo.Count) row(s)"
    if (-not $todo.Count) { return New-ActionResult $def.Name $label 'NotApplicable' "'$($def.Name)' does not apply to any of the rows." }

    $inputs = $null
    if (@($def.Inputs).Count -and $GetInputs) {
        $inputs = & $GetInputs $def $todo[0]
        if ($null -eq $inputs) { return New-ActionResult $def.Name $label 'Cancelled' 'Cancelled.' }
    }
    if ($Confirm) {
        $names = @($todo | ForEach-Object { Get-ConsoleTargetName $def $_ })
        $list = ($names | Select-Object -First 25 | ForEach-Object { "  - $_" }) -join "`n"
        if ($names.Count -gt 25) { $list += "`n  ... and $($names.Count - 25) more" }
        if (-not (& $Confirm "Run '$($def.Name)' on $($todo.Count) row(s)?`n`n$list")) {
            return New-ActionResult $def.Name $label 'Cancelled' 'Cancelled.'
        }
    }

    Write-ConsoleAudit -Action $def.Name -Target $label -Result 'Started' -Details 'Bulk run from a report'
    $results = foreach ($t in $todo) { Invoke-ConsoleAction -Action $def -Target $t -Inputs $inputs }
    $summary = (@($results) | Group-Object Status | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ', '
    Write-ConsoleAudit -Action $def.Name -Target $label -Result 'Completed' -Details $summary
    $results
}

# ---------------------------------------------------------------- status checks
#
# An action may declare  Check = { param($Target) ... }  that looks (read-only) at
# whether its work is already done. It returns one of:
#     $true / $false                         -> Done / To do
#     @{ Done = $true|$false; Detail = '...' }
#     @{ Done = $null; Detail = '...' }       -> Info (cannot tell; shown, still runs)
# Get-ConsoleActionStatus turns that into one row the UI can show.

function New-ActionStatus {
    param($Action, [string]$Status, [string]$Detail = '')
    [pscustomobject]@{ Action = $Action; Status = $Status; Detail = $Detail }
}

function Get-ConsoleActionStatus {
    <#
    .SYNOPSIS  Status of one action for one target: Done, To do, Info, N/A, No check or Error.
    #>
    param([Parameter(Mandatory)]$Action, $Target)
    $def = Resolve-ConsoleAction $Action
    $applies = Test-ConsoleActionApplies $def $Target
    if (-not $def.Check) {
        if ($applies) { return New-ActionStatus $def.Name 'No check' 'Always runs' }
        return New-ActionStatus $def.Name 'N/A' 'Does not apply to this target'
    }
    try {
        $r = & $def.Check $Target
        $done = $r; $detail = ''
        if ($r -is [System.Collections.IDictionary]) { $done = $r['Done']; $detail = [string]$r['Detail'] }
        elseif ($r -is [pscustomobject] -and $r.PSObject.Properties['Done']) { $done = $r.Done; $detail = [string]$r.Detail }
        elseif ($r -is [string]) { $done = $null; $detail = $r }
        if ($null -eq $done) { return New-ActionStatus $def.Name 'Info' $detail }
        if ([bool]$done) { return New-ActionStatus $def.Name 'Done' $detail }
        if (-not $applies) { return New-ActionStatus $def.Name 'N/A' $detail }
        New-ActionStatus $def.Name 'To do' $detail
    }
    catch {
        if (-not $applies) { return New-ActionStatus $def.Name 'N/A' $_.Exception.Message }
        New-ActionStatus $def.Name 'Error' $_.Exception.Message
    }
}

function Get-ConsoleWorkflowStatus {
    <#
    .SYNOPSIS  One status row per workflow step (Step, Action, Status, Detail, Permitted, Suggested).
               Suggested = should be ticked by default (not Done / N/A, and permitted).
    #>
    param([Parameter(Mandatory)]$Workflow, [Parameter(Mandatory)]$Target)
    $wf = $Workflow
    if ($Workflow -is [string]) { $wf = Get-ConsoleWorkflow -Name $Workflow; if (-not $wf) { throw "No workflow named '$Workflow'." } }
    $cache = @{}
    $i = 0
    foreach ($step in $wf.Steps) {
        $i++
        $a = Get-ConsoleAction -Name $step
        if (-not $cache.ContainsKey($step)) { $cache[$step] = Get-ConsoleActionStatus -Action $a -Target $Target }
        $s = $cache[$step]
        $permitted = Test-ConsolePermission $a.Permission
        [pscustomobject]@{
            Step             = $i
            Action           = $step
            Status           = $s.Status
            Detail           = $s.Detail
            Permitted        = $permitted
            RequiresApproval = (Test-ConsoleApprovalRequired $a)
            Suggested        = $permitted -and $s.Status -notin 'Done', 'N/A'
        }
    }
}
