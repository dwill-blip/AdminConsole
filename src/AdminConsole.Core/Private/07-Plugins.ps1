# Plugin discovery.
#
#   plugins\actions\<Category>\*.ps1   -> buttons on the Users / Computers pages, or report row actions
#   plugins\workflows\*.ps1            -> multi-step buttons (e.g. Offboard User)
#   plugins\reports\<Category>\*.ps1   -> entries in the Reports tree
#
# Each file simply returns a hashtable. Files whose name starts with '_' are ignored
# (use them for templates). See docs\EXTENDING.md for the full format.

$script:Actions      = [ordered]@{}
$script:Workflows    = [ordered]@{}
$script:Reports      = [ordered]@{}
$script:PluginErrors = New-Object System.Collections.ArrayList
$script:PluginRoot   = $null

$script:ValidScopes     = 'User', 'Computer', 'Row'
$script:ReservedInputNames = 'Count', 'Keys', 'Values', 'Item', 'IsReadOnly', 'IsFixedSize', 'IsSynchronized', 'SyncRoot', 'Comparer'
$script:ValidInputTypes = 'Text', 'Password', 'Multiline', 'Number', 'Bool', 'Choice', 'Date'

function Get-DefValue {
    param([hashtable]$Def, [string]$Key, $Default = $null)
    if ($Def.ContainsKey($Key) -and $null -ne $Def[$Key]) { return $Def[$Key] }
    $Default
}

function ConvertTo-InputDefinitions {
    param($Inputs, [string]$Owner)
    $list = @()
    foreach ($i in @($Inputs)) {
        if (-not $i) { continue }
        if ($i -isnot [hashtable]) { throw "$Owner : each entry in Inputs/Parameters must be a hashtable." }
        if (-not $i.Name) { throw "$Owner : an input is missing Name." }
        if ($i.Name -in $script:ReservedInputNames) { throw "$Owner : '$($i.Name)' cannot be used as an input name (it clashes with a hashtable property). Pick another name." }
        $type = Get-DefValue $i 'Type' 'Text'
        if ($type -notin $script:ValidInputTypes) { throw "$Owner : input '$($i.Name)' has unknown Type '$type'. Use one of: $($script:ValidInputTypes -join ', ')" }
        $list += [pscustomobject]@{
            Name     = [string]$i.Name
            Label    = [string](Get-DefValue $i 'Label' $i.Name)
            Type     = $type
            Required = [bool](Get-DefValue $i 'Required' $false)
            Default  = Get-DefValue $i 'Default'
            Choices  = @(Get-DefValue $i 'Choices' @())
            Help     = [string](Get-DefValue $i 'Help' '')
        }
    }
    , $list
}

function Get-DefaultPermissionName {
    # 'Convert to Shared Mailbox' -> 'ConvertToSharedMailbox'
    param([string]$Name)
    (($Name -split '[^A-Za-z0-9]+') | Where-Object { $_ } | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }) -join ''
}

function Import-PluginFile {
    param([System.IO.FileInfo]$File)
    $def = & $File.FullName
    if ($def -is [array]) { $def = $def | Where-Object { $_ -is [hashtable] } | Select-Object -Last 1 }
    if ($def -isnot [hashtable]) { throw 'The file must return a hashtable - make sure the last thing in the file is @{ ... }.' }
    $def
}

function ConvertTo-ActionDefinition {
    param([hashtable]$Def, [System.IO.FileInfo]$File)
    if (-not $Def.Name) { throw 'Missing Name.' }
    if ($Def.Scope -notin $script:ValidScopes) { throw "Scope must be one of: $($script:ValidScopes -join ', ')." }
    if ($Def.Run -isnot [scriptblock]) { throw 'Run must be a script block: Run = { param($Target, $Inputs) ... }' }
    foreach ($k in 'AppliesTo', 'TargetName', 'Check') {
        if ($Def.ContainsKey($k) -and $null -ne $Def[$k] -and $Def[$k] -isnot [scriptblock]) { throw "$k must be a script block." }
    }
    [pscustomobject]@{
        PSTypeName       = 'AdminConsole.Action'
        Kind             = 'Action'
        Name             = [string]$Def.Name
        Scope            = [string]$Def.Scope
        Category         = [string](Get-DefValue $Def 'Category' $File.Directory.Name)
        Description      = [string](Get-DefValue $Def 'Description' '')
        Permission       = [string](Get-DefValue $Def 'Permission' (Get-DefaultPermissionName $Def.Name))
        RequiresApproval = [bool](Get-DefValue $Def 'RequiresApproval' $false)
        Confirm          = (Get-DefValue $Def 'Confirm' $true)
        Danger           = [bool](Get-DefValue $Def 'Danger' $false)
        Order            = [int](Get-DefValue $Def 'Order' 100)
        Inputs           = ConvertTo-InputDefinitions (Get-DefValue $Def 'Inputs' @()) "Action '$($Def.Name)'"
        AppliesTo        = Get-DefValue $Def 'AppliesTo'
        TargetName       = Get-DefValue $Def 'TargetName'
        Check            = Get-DefValue $Def 'Check'
        GraphScopes      = [string[]]@(Get-DefValue $Def 'GraphScopes' @())
        Run              = $Def.Run
        Source           = $File.FullName
    }
}

function ConvertTo-WorkflowDefinition {
    param([hashtable]$Def, [System.IO.FileInfo]$File)
    if (-not $Def.Name) { throw 'Missing Name.' }
    if ($Def.Scope -notin 'User', 'Computer') { throw 'Scope must be User or Computer.' }
    $steps = @($Def.Steps | Where-Object { $_ })
    if (-not $steps.Count) { throw 'Steps must list at least one action name.' }
    [pscustomobject]@{
        PSTypeName   = 'AdminConsole.Workflow'
        Kind         = 'Workflow'
        Name         = [string]$Def.Name
        Scope        = [string]$Def.Scope
        Category     = 'Workflows'
        Description  = [string](Get-DefValue $Def 'Description' '')
        Permission   = [string](Get-DefValue $Def 'Permission' '')
        Steps        = [string[]]$steps
        StopOnError  = [bool](Get-DefValue $Def 'StopOnError' $false)
        Order        = [int](Get-DefValue $Def 'Order' 100)
        Source       = $File.FullName
    }
}

function ConvertTo-ReportDefinition {
    param([hashtable]$Def, [System.IO.FileInfo]$File, [string]$ReportsRoot)
    if (-not $Def.Name) { throw 'Missing Name.' }
    if ($Def.Run -isnot [scriptblock]) { throw 'Run must be a script block: Run = { param($Params) ... }' }
    $rowType = Get-DefValue $Def 'RowType'
    if ($rowType -and $rowType -notin 'User', 'Computer') { throw 'RowType must be User or Computer (or left out).' }
    if ($rowType -and -not $Def.RowKey) { throw 'RowKey (the column that identifies the user/computer) is required when RowType is set.' }
    $rel = $File.FullName.Substring($ReportsRoot.Length).TrimStart('\', '/')
    $id = ($rel -replace '\.ps1$', '') -replace '\\', '/'
    [pscustomobject]@{
        PSTypeName  = 'AdminConsole.Report'
        Kind        = 'Report'
        Id          = $id
        Name        = [string]$Def.Name
        Category    = [string](Get-DefValue $Def 'Category' $File.Directory.Name)
        Description = [string](Get-DefValue $Def 'Description' '')
        Permission  = [string](Get-DefValue $Def 'Permission' 'RunReport')
        Parameters  = ConvertTo-InputDefinitions (Get-DefValue $Def 'Parameters' @()) "Report '$($Def.Name)'"
        RowType     = $rowType
        RowKey      = [string](Get-DefValue $Def 'RowKey' '')
        RowActions  = [string[]]@(Get-DefValue $Def 'RowActions' @())
        GraphScopes = [string[]]@(Get-DefValue $Def 'GraphScopes' @())
        Run         = $Def.Run
        Source      = $File.FullName
    }
}

function Import-ConsolePlugins {
    <#
    .SYNOPSIS  (Re)loads every plugin. Broken files are skipped and listed by Get-ConsolePluginErrors.
    #>
    param([string]$Path = (Join-Path (Get-ConsoleRoot) 'plugins'))
    $script:PluginRoot = $Path
    $script:Actions.Clear(); $script:Workflows.Clear(); $script:Reports.Clear(); $script:PluginErrors.Clear()

    $sets = @(
        @{ Folder = 'actions';   Store = $script:Actions;   Kind = 'Action' },
        @{ Folder = 'workflows'; Store = $script:Workflows; Kind = 'Workflow' },
        @{ Folder = 'reports';   Store = $script:Reports;   Kind = 'Report' }
    )
    foreach ($set in $sets) {
        $dir = Join-Path $Path $set.Folder
        if (-not (Test-Path $dir)) { continue }
        $dirFull = (Resolve-Path $dir).Path
        foreach ($file in (Get-ChildItem -Path $dir -Filter '*.ps1' -Recurse | Where-Object { $_.Name -notlike '_*' } | Sort-Object FullName)) {
            try {
                $raw = Import-PluginFile $file
                switch ($set.Kind) {
                    'Action'   { $def = ConvertTo-ActionDefinition $raw $file }
                    'Workflow' { $def = ConvertTo-WorkflowDefinition $raw $file }
                    'Report'   { $def = ConvertTo-ReportDefinition $raw $file $dirFull }
                }
                $key = $def.Name
                if ($set.Store.Contains($key)) { throw "Another $($set.Kind.ToLower()) is already named '$key' ($($set.Store[$key].Source))." }
                $set.Store[$key] = $def
            }
            catch {
                [void]$script:PluginErrors.Add([pscustomobject]@{ Kind = $set.Kind; File = $file.FullName; Error = $_.Exception.Message })
                Write-ConsoleLog "Plugin skipped: $($file.Name) - $($_.Exception.Message)" Warning
            }
        }
    }

    # Cross-checks that need everything loaded.
    foreach ($wf in @($script:Workflows.Values)) {
        $bad = @($wf.Steps | Where-Object { -not $script:Actions.Contains($_) -or $script:Actions[$_].Scope -ne $wf.Scope })
        if ($bad.Count) {
            [void]$script:PluginErrors.Add([pscustomobject]@{ Kind = 'Workflow'; File = $wf.Source; Error = "Unknown step(s) or wrong scope: $($bad -join ', ')" })
            $script:Workflows.Remove($wf.Name)
        }
    }
    foreach ($r in @($script:Reports.Values)) {
        $bad = @($r.RowActions | Where-Object { -not $script:Actions.Contains($_) -or $script:Actions[$_].Scope -ne 'Row' })
        if ($bad.Count) {
            [void]$script:PluginErrors.Add([pscustomobject]@{ Kind = 'Report'; File = $r.Source; Error = "RowActions not found (or not Scope = 'Row'): $($bad -join ', ')" })
        }
    }
    Write-ConsoleLog ("Loaded {0} actions, {1} workflows, {2} reports ({3} plugin errors)" -f $script:Actions.Count, $script:Workflows.Count, $script:Reports.Count, $script:PluginErrors.Count)
}

function Get-ConsoleAction {
    param([string]$Name, [string]$Scope)
    if ($Name) { if ($script:Actions.Contains($Name)) { return $script:Actions[$Name] } else { return $null } }
    $all = @($script:Actions.Values)
    if ($Scope) { $all = @($all | Where-Object { $_.Scope -eq $Scope }) }
    $all | Sort-Object Category, Order, Name
}

function Get-ConsoleWorkflow {
    param([string]$Name, [string]$Scope)
    if ($Name) { if ($script:Workflows.Contains($Name)) { return $script:Workflows[$Name] } else { return $null } }
    $all = @($script:Workflows.Values)
    if ($Scope) { $all = @($all | Where-Object { $_.Scope -eq $Scope }) }
    $all | Sort-Object Order, Name
}

function Get-ConsoleReport {
    <# Accepts a report Name or Id (e.g. 'Exchange/ActiveSync-Devices'). #>
    param([string]$Name)
    if ($Name) {
        if ($script:Reports.Contains($Name)) { return $script:Reports[$Name] }
        return @($script:Reports.Values | Where-Object { $_.Id -eq $Name }) | Select-Object -First 1
    }
    @($script:Reports.Values) | Sort-Object Category, Name
}

function Get-ConsolePluginErrors { @($script:PluginErrors) }
