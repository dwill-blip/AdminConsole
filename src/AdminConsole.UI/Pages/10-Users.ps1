# Users and Computers tabs share one generic "target page": look something up,
# show its details, and show a button for every action/workflow with that Scope.
# New action plugins appear here automatically.

$script:UiTargetPages = @{}

function New-UiTargetPage {
    param(
        [Parameter(Mandatory)]$Tab,
        [Parameter(Mandatory)][ValidateSet('User', 'Computer')][string]$Scope,
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][scriptblock]$Lookup
    )
    $page = @{ Scope = $Scope; Lookup = $Lookup; Target = $null; Tab = $Tab; Buttons = New-Object System.Collections.ArrayList }
    $script:UiTargetPages[$Scope] = $page

    $layout = New-UiLayout -Rows 'Auto', 'Fill' -Columns '45%', '55%'

    # --- lookup bar
    $bar = New-UiFlow
    $bar.Controls.Add((New-UiLabel $Prompt))
    $page.Input = New-UiTextBox -Width 320 -Cue 'Press Enter to look up'
    $bar.Controls.Add($page.Input)
    $bar.Controls.Add((New-UiButton -Text 'Look up' -State $page -OnClick { param($p) Invoke-UiTargetLookup $p }))
    $bar.Controls.Add((New-UiButton -Text 'Refresh' -State $page -OnClick { param($p) if ($p.Target) { $p.Input.Text = $p.Target.Identity; Invoke-UiTargetLookup $p } }))
    $bar.Controls.Add((New-UiButton -Text 'Check status...' -ToolTip 'Checks every step (read-only) and shows what is done and what still needs doing.' -State $page -OnClick { param($p) Show-UiTargetStatus $p }))
    $page.Title = New-UiLabel '' -Bold
    $bar.Controls.Add($page.Title)
    Register-UiEvent $page.Input KeyDown -State $page -Handler {
        param($p, $sender, $e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) { $e.SuppressKeyPress = $true; Invoke-UiTargetLookup $p }
    }
    Add-UiCell $layout $bar 0 0 -ColumnSpan 2

    # --- details
    $page.Details = New-UiDetailsGrid
    Add-UiCell $layout $page.Details 0 1

    # --- actions, grouped by category. One wrapping flow panel; flow breaks start each
    #     category header (and the buttons after it) on a new line.
    $actions = New-Object System.Windows.Forms.FlowLayoutPanel
    $actions.Dock = 'Fill'
    $actions.AutoScroll = $true
    $actions.WrapContents = $true
    $groups = [ordered]@{}
    foreach ($wf in @(Get-ConsoleWorkflow -Scope $Scope)) {
        if (-not $groups.Contains('Workflows')) { $groups['Workflows'] = New-Object System.Collections.ArrayList }
        [void]$groups['Workflows'].Add($wf)
    }
    foreach ($a in @(Get-ConsoleAction -Scope $Scope)) {
        if (-not $groups.Contains($a.Category)) { $groups[$a.Category] = New-Object System.Collections.ArrayList }
        [void]$groups[$a.Category].Add($a)
    }
    $last = $null
    foreach ($cat in $groups.Keys) {
        $header = New-UiLabel $cat -Bold
        $header.Margin = New-Object System.Windows.Forms.Padding(3, 12, 3, 2)
        if ($last) { $actions.SetFlowBreak($last, $true) }
        $actions.Controls.Add($header)
        $actions.SetFlowBreak($header, $true)
        foreach ($item in $groups[$cat]) {
            $tip = $item.Description
            if ($item.Kind -eq 'Workflow') { $tip = "$($item.Description)`nSteps: $($item.Steps -join ', ')" }
            elseif ($item.Kind -eq 'Action' -and (Test-ConsoleApprovalRequired $item)) { $tip = "$tip`n(Requires approval)".Trim() }
            $text = $item.Name
            if ($item.Kind -eq 'Action' -and (Test-ConsoleApprovalRequired $item)) { $text += ' *' }
            if ($item.Kind -eq 'Workflow') { $text += '...' }
            $isDanger = ($item.Kind -eq 'Action' -and $item.Danger)
            $btn = New-UiButton -Text $text -Width 180 -ToolTip $tip -Danger:$isDanger -State @{ Page = $page; Item = $item } -OnClick {
                param($s)
                if ($s.Item.Kind -eq 'Workflow') { Invoke-UiWorkflow -Workflow $s.Item -Target $s.Page.Target -Page $s.Page } else { Invoke-UiAction $s.Page $s.Item }
            }
            $btn.Enabled = $false
            [void]$page.Buttons.Add(@{ Button = $btn; Item = $item })
            $actions.Controls.Add($btn)
            $last = $btn
        }
    }
    if ($last) { $actions.SetFlowBreak($last, $true) }
    $hintText = 'Red = destructive.   Greyed out = not applicable, or you lack the permission.'
    if (Get-ConsoleSetting 'RequireApprovals' $false) { $hintText = "* = needs a second person to approve.   $hintText" }
    $hint = New-UiLabel $hintText -Wrap -MaxWidth 560
    $hint.ForeColor = [System.Drawing.Color]::DimGray
    $hint.Margin = New-Object System.Windows.Forms.Padding(3, 16, 3, 3)
    $actions.Controls.Add($hint)
    Add-UiCell $layout $actions 1 1

    $Tab.Controls.Add($layout)
    $page
}

function Invoke-UiTargetLookup {
    param($Page)
    $id = $Page.Input.Text.Trim()
    if (-not $id) { Show-UiInfo "Type something to look up first."; return }
    $Page.Target = $null
    $Page.Title.Text = ''
    Set-UiDetails $Page.Details $null
    Update-UiTargetButtons $Page
    $Page.Target = & $Page.Lookup $id
    $name = $Page.Target.DisplayName
    if (-not $name) { $name = $Page.Target.Identity }
    $Page.Title.Text = "$name  ($($Page.Target.Identity))"
    Set-UiDetails $Page.Details (Get-ConsoleTargetSummary $Page.Target)
    Update-UiTargetButtons $Page
    Write-ConsoleLog "Loaded $($Page.Scope.ToLower()) $($Page.Target.Identity)"
}

function Update-UiTargetButtons {
    param($Page)
    foreach ($b in $Page.Buttons) {
        $ok = $false
        if ($Page.Target) {
            if ($b.Item.Kind -eq 'Workflow') { $ok = Test-ConsolePermission $b.Item.Permission }
            else { $ok = (Test-ConsolePermission $b.Item.Permission) -and (Test-ConsoleActionApplies $b.Item $Page.Target) }
        }
        $b.Button.Enabled = $ok
    }
}

function Invoke-UiAction {
    param($Page, $Action)
    $r = Invoke-ConsoleAction -Action $Action -Target $Page.Target -GetInputs $script:UiGetInputs -Confirm $script:UiConfirm
    Show-UiActionResult $r
    if ($r.Status -eq 'Success') { Invoke-UiTargetRefresh $Page }
}

function Invoke-UiWorkflow {
    # $Page is optional: when given, the page is refreshed afterwards.
    param([Parameter(Mandatory)]$Workflow, [Parameter(Mandatory)]$Target, $Page = $null)
    $target = $Target
    Set-UiStatus "Checking status of $($Workflow.Steps.Count) steps..."
    $status = @(Get-ConsoleWorkflowStatus -Workflow $Workflow -Target $target)
    $items = @(); $checked = @(); $stepByLabel = @{}
    foreach ($s in $status) {
        $note = $s.Status
        if ($s.Detail) { $note = "$($s.Status): $($s.Detail)" }
        if (-not $s.Permitted) { $note = "no permission - $note" }
        elseif ($s.RequiresApproval -and $s.Status -ne 'Done') { $note = "needs approval - $note" }
        $label = '{0:00}. {1}   [{2}]' -f $s.Step, $s.Action, $note
        $items += $label
        $stepByLabel[$label] = $s.Action
        if ($s.Suggested) { $checked += $label }
    }
    $todo = @($status | Where-Object { $_.Status -eq 'To do' }).Count
    $done = @($status | Where-Object { $_.Status -eq 'Done' }).Count
    $msg = "$($Workflow.Description)`n`nTarget: $($target.Identity)`n$done step(s) already done, $todo still to do. Only steps that still need doing are ticked."
    $chosen = Show-UiChecklist -Title $Workflow.Name -Message $msg -Items $items -Checked $checked -Width 900 -Height 440
    if ($null -eq $chosen -or -not $chosen.Count) { return }
    $steps = @($chosen | ForEach-Object { $stepByLabel[$_] })
    $results = @(Invoke-ConsoleWorkflow -Workflow $Workflow -Target $target -Steps $steps -GetInputs $script:UiGetInputs -Confirm $script:UiConfirm)
    if ($results.Count -eq 1 -and $results[0].Status -in 'Cancelled', 'Denied' -and $results[0].Action -eq $Workflow.Name) {
        if ($results[0].Status -eq 'Denied') { Show-UiActionResult $results[0] }
        return
    }
    Show-UiResultList -Title "$($Workflow.Name) - $($target.Identity)" -Results $results
    if ($Page) { Invoke-UiTargetRefresh $Page }
}

function Show-UiTargetStatus {
    # Read-only status of every workflow step and every other checkable action.
    param($Page)
    if (-not $Page.Target) { Show-UiInfo 'Look something up first.'; return }
    $t = $Page.Target
    Set-UiStatus 'Checking status...'
    $rows = New-Object System.Collections.ArrayList
    $seen = @{}
    foreach ($wf in @(Get-ConsoleWorkflow -Scope $Page.Scope)) {
        foreach ($s in @(Get-ConsoleWorkflowStatus -Workflow $wf -Target $t)) {
            [void]$rows.Add([pscustomobject]@{ Workflow = $wf.Name; Step = $s.Step; Action = $s.Action; Status = $s.Status; Detail = $s.Detail })
            $seen[$s.Action] = $true
        }
    }
    foreach ($a in @(Get-ConsoleAction -Scope $Page.Scope | Where-Object { $_.Check -and -not $seen.ContainsKey($_.Name) })) {
        $s = Get-ConsoleActionStatus -Action $a -Target $t
        [void]$rows.Add([pscustomobject]@{ Workflow = '(other)'; Step = ''; Action = $a.Name; Status = $s.Status; Detail = $s.Detail })
    }
    $todo = @($rows | Where-Object { $_.Status -eq 'To do' }).Count
    Write-ConsoleAudit -Action 'Check Status' -Target $t.Identity -Result 'Success' -Details "$todo to do"
    Show-UiGridDialog -Title "Status - $($t.Identity)" -Rows $rows -Message "$todo item(s) still to do. 'Info' = shown for reference, 'No check' = always runs, 'N/A' = does not apply."
}

function Open-UiTarget {
    # Jump to the Users/Computers tab and load an identity there (used by report rows).
    param([Parameter(Mandatory)][ValidateSet('User', 'Computer')][string]$Scope, [Parameter(Mandatory)][string]$Identity)
    $page = $script:UiTargetPages[$Scope]
    if (-not $page) { return }
    if ($script:UiTabs) { $script:UiTabs.SelectedTab = $page.Tab }
    $page.Input.Text = $Identity
    Invoke-UiTargetLookup $page
}

function Invoke-UiTargetRefresh {
    param($Page)
    if (-not $Page.Target) { return }
    try {
        $Page.Input.Text = $Page.Target.Identity
        Invoke-UiTargetLookup $Page
    }
    catch { Write-ConsoleLog "Refresh failed: $($_.Exception.Message)" Warning }
}

Register-UiPage -Title 'Users' -Order 10 -Build {
    param($Tab)
    [void](New-UiTargetPage -Tab $Tab -Scope User -Prompt 'User (sAMAccountName, UPN or email):' -Lookup { param($id) Get-HybridUser -Identity $id })
}

Register-UiPage -Title 'Computers' -Order 20 -Build {
    param($Tab)
    [void](New-UiTargetPage -Tab $Tab -Scope Computer -Prompt 'Computer name:' -Lookup { param($id) Get-HybridComputer -Name $id })
}
