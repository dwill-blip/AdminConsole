# Reports tab: tree of report plugins, generated parameter inputs, results grid,
# filter, export, favorites, "schedule this" / "alert on this", and row actions.

$script:WeekDays = 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'

function New-UiReportsPage {
    param([Parameter(Mandatory)]$Tab)
    $page = @{ Report = $null; Rows = @(); Shown = @(); Elapsed = $null; ParamControls = @{} }

    $split = New-Object System.Windows.Forms.SplitContainer
    $split.Size = New-Object System.Drawing.Size(1200, 700)   # real size before SplitterDistance, or it throws
    $split.SplitterDistance = 260
    $split.FixedPanel = 'Panel1'
    $split.Dock = 'Fill'

    # --- left: report tree
    $page.Tree = New-Object System.Windows.Forms.TreeView
    $page.Tree.Dock = 'Fill'
    $page.Tree.Font = $script:UiFont
    $page.Tree.HideSelection = $false
    Register-UiEvent $page.Tree AfterSelect -State $page -Handler {
        param($p, $sender, $e)
        if ($e.Node -and $e.Node.Tag) { Select-UiReport $p ([string]$e.Node.Tag) }
    }
    $split.Panel1.Controls.Add($page.Tree)

    # --- right: header, parameters, toolbar, grid, status
    $right = New-UiLayout -Rows 'Auto', 'Auto', 'Auto', 'Fill', 'Auto'
    $head = New-UiFlow
    $page.Title = New-UiLabel 'Pick a report on the left.' -Bold
    $page.Description = New-UiLabel '' -Wrap -MaxWidth 900
    $head.Controls.Add($page.Title)
    $head.SetFlowBreak($page.Title, $true)
    $head.Controls.Add($page.Description)
    Add-UiCell $right $head 0 0

    $page.Params = New-UiFlow
    Add-UiCell $right $page.Params 0 1

    $bar = New-UiFlow
    $page.RunButton = New-UiButton -Text 'Run' -Width 90 -State $page -OnClick { param($p) Invoke-UiReportRun $p }
    $page.RunButton.Font = $script:UiBoldFont
    $bar.Controls.Add($page.RunButton)
    $bar.Controls.Add((New-UiButton -Text 'Export...' -State $page -OnClick { param($p) Export-UiReport $p }))
    $page.FavButton = New-UiButton -Text 'Add to favorites' -State $page -OnClick { param($p) Switch-UiFavorite $p }
    $bar.Controls.Add($page.FavButton)
    $bar.Controls.Add((New-UiButton -Text 'Schedule...' -State $page -OnClick { param($p) New-UiScheduleFromReport $p }))
    $bar.Controls.Add((New-UiButton -Text 'Alert on this...' -State $page -OnClick { param($p) New-UiAlertFromReport $p }))
    $page.RowButton = New-UiButton -Text 'Row actions...' -State $page -OnClick { param($p) Show-UiRowMenu $p }
    $bar.Controls.Add($page.RowButton)
    $bar.Controls.Add((New-UiLabel '   Filter:'))
    $page.Filter = New-UiTextBox -Width 220 -Cue 'Shows rows containing this text in any column'
    # Live filtering for normal-sized results; for big ones, press Enter.
    Register-UiEvent $page.Filter TextChanged -State $page -Handler { param($p) if (@($p.Rows).Count -le 5000) { Update-UiReportGrid $p } }
    Register-UiEvent $page.Filter KeyDown -State $page -Handler {
        param($p, $sender, $e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) { $e.SuppressKeyPress = $true; Update-UiReportGrid $p }
    }
    $bar.Controls.Add($page.Filter)
    Add-UiCell $right $bar 0 2

    $page.Grid = New-UiGrid
    Register-UiEvent $page.Grid CellMouseDown -State $page -Handler {
        param($p, $sender, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right -and $e.RowIndex -ge 0) {
            Select-UiGridRowAt $p.Grid $e.RowIndex $e.ColumnIndex
            Show-UiRowMenu $p
        }
    }
    Add-UiCell $right $page.Grid 0 3

    $page.Status = New-UiLabel ''
    Add-UiCell $right $page.Status 0 4
    $split.Panel2.Controls.Add($right)

    $Tab.Controls.Add($split)
    Update-UiReportTree $page
    Set-UiReportButtons $page
    $page
}

function Update-UiReportTree {
    param($Page)
    $tree = $Page.Tree
    $tree.BeginUpdate()
    $tree.Nodes.Clear()
    $favs = @(Get-ConsoleFavorite)
    if ($favs.Count) {
        $fn = $tree.Nodes.Add('Favorites')
        $fn.NodeFont = $script:UiBoldFont
        foreach ($f in $favs) { if (Get-ConsoleReport -Name $f) { $n = $fn.Nodes.Add($f); $n.Tag = $f } }
    }
    $cats = @{}
    foreach ($r in @(Get-ConsoleReport)) {
        if (-not $cats.ContainsKey($r.Category)) { $cats[$r.Category] = $tree.Nodes.Add($r.Category) }
        $n = $cats[$r.Category].Nodes.Add($r.Name)
        $n.Tag = $r.Name
        $n.ToolTipText = $r.Description
    }
    $tree.ShowNodeToolTips = $true
    $tree.ExpandAll()
    $tree.EndUpdate()
}

function Select-UiReport {
    param($Page, [string]$Name)
    $def = Get-ConsoleReport -Name $Name
    if (-not $def) { return }
    $Page.Report = $def
    $Page.Rows = @()
    $Page.Shown = @()
    $Page.Elapsed = $null
    $Page.Title.Text = $def.Name
    $Page.Description.Text = $def.Description
    $Page.Params.SuspendLayout()
    $Page.Params.Controls.Clear()
    $Page.ParamControls = @{}
    foreach ($p in @($def.Parameters)) {
        if ($p.Type -ne 'Bool') { $Page.Params.Controls.Add((New-UiLabel "$($p.Label):")) }
        $ctl = New-UiInputControl -Definition $p
        $Page.ParamControls[$p.Name] = $ctl
        $Page.Params.Controls.Add($ctl)
    }
    $Page.Params.ResumeLayout()
    Set-UiGridData $Page.Grid @()
    $Page.Status.Text = ''
    Set-UiReportButtons $Page
}

function Set-UiReportButtons {
    param($Page)
    $has = [bool]$Page.Report
    $Page.RunButton.Enabled = $has -and (Test-ConsolePermission $Page.Report.Permission)
    $Page.FavButton.Enabled = $has
    if ($has) {
        $Page.FavButton.Text = if ((Get-ConsoleFavorite) -contains $Page.Report.Name) { 'Remove favorite' } else { 'Add to favorites' }
        $Page.RowButton.Enabled = [bool]($Page.Report.RowType -or @($Page.Report.RowActions).Count)
    }
    else { $Page.RowButton.Enabled = $false }
}

function Get-UiReportParams {
    param($Page)
    $values = @{}
    foreach ($p in @($Page.Report.Parameters)) { $values[$p.Name] = Get-UiInputValue -Definition $p -Control $Page.ParamControls[$p.Name] }
    Complete-ConsoleInputs -Definitions $Page.Report.Parameters -Values $values
}

function Invoke-UiReportRun {
    param($Page)
    if (-not $Page.Report) { return }
    $params = Get-UiReportParams $Page
    $Page.Status.Text = "Running $($Page.Report.Name)..."
    $Page.Status.Refresh()
    Set-UiStatus "Running $($Page.Report.Name)..."
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $Page.Rows = @(Invoke-ConsoleReport -Report $Page.Report -Parameters $params)
    $Page.Elapsed = $sw.Elapsed.TotalSeconds
    Update-UiReportGrid $Page
}

function Update-UiReportGrid {
    param($Page)
    $shown = @(Select-ConsoleRows -Rows $Page.Rows -Text $Page.Filter.Text)
    $Page.Shown = $shown
    Set-UiGridData $Page.Grid $shown
    $text = "{0} row(s)" -f @($Page.Rows).Count
    if ($Page.Filter.Text) { $text = "{0} of {1} row(s) match the filter" -f $shown.Count, @($Page.Rows).Count }
    if ($Page.Elapsed) { $text += (" - ran in {0:n1}s" -f $Page.Elapsed) }
    if ($Page.Report -and ($Page.Report.RowType -or @($Page.Report.RowActions).Count)) { $text += '   (right-click a row for actions)' }
    $Page.Status.Text = $text
}

function Export-UiReport {
    param($Page)
    $rows = @($Page.Shown | Where-Object { $null -ne $_ })
    if (-not $rows.Count) { Show-UiInfo 'Run the report first - there is nothing to export.'; return }
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter = 'CSV (*.csv)|*.csv|HTML (*.html)|*.html|JSON (*.json)|*.json'
    $dlg.FileName = ('{0}-{1}.csv' -f ($Page.Report.Name -replace '[^\w\-]', '_'), (Get-Date -Format 'yyyyMMdd-HHmm'))
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Export-ConsoleRows -Rows $rows -Path $dlg.FileName -Title $Page.Report.Name
        Show-UiInfo "Saved $($rows.Count) row(s) to`n$($dlg.FileName)" 'Export'
    }
    $dlg.Dispose()
}

function Switch-UiFavorite {
    param($Page)
    if (-not $Page.Report) { return }
    $name = $Page.Report.Name
    if ((Get-ConsoleFavorite) -contains $name) { Remove-ConsoleFavorite $name } else { Add-ConsoleFavorite $name }
    Update-UiReportTree $Page
    Set-UiReportButtons $Page
}

function New-UiScheduleFromReport {
    param($Page)
    if (-not $Page.Report) { Show-UiInfo 'Pick a report first.'; return }
    Assert-ConsolePermission 'ManageSchedules'
    $params = Get-UiReportParams $Page
    $inputs = ConvertTo-InputDefinitions @(
        @{ Name = 'Name'; Label = 'Schedule name'; Required = $true; Default = "$($Page.Report.Name) (daily)" }
        @{ Name = 'Frequency'; Type = 'Choice'; Choices = @('Hourly', 'Daily', 'Weekly'); Default = 'Daily' }
        @{ Name = 'At'; Label = 'Time (HH:mm, 24h)'; Default = '06:00'; Required = $true; Help = 'For Hourly only the minutes are used.' }
        @{ Name = 'DayOfWeek'; Label = 'Day (weekly only)'; Type = 'Choice'; Choices = $script:WeekDays; Default = 'Monday' }
        @{ Name = 'Format'; Type = 'Choice'; Choices = @('csv', 'html', 'json'); Default = 'csv' }
        @{ Name = 'OutputFolder'; Label = 'Output folder (blank = default)'; Help = "Default: $(Get-ConsoleSetting 'ReportOutputFolder')" }
    ) 'Schedule'
    $v = Show-UiInputDialog -Title "Schedule: $($Page.Report.Name)" -Inputs $inputs -Message 'The current parameter values are saved with the schedule. Schedules run when Invoke-AdminJobs.ps1 runs (see Automation tab).'
    if ($null -eq $v) { return }
    if ($v.At -notmatch '^\d{1,2}:\d{2}$') { throw "Time must look like 06:00 (got '$($v.At)')." }
    [void](New-ConsoleSchedule -Name $v.Name -Report $Page.Report.Name -Parameters $params -Frequency $v.Frequency -At $v.At -DayOfWeek $v.DayOfWeek -Format $v.Format -OutputFolder $v.OutputFolder)
    Show-UiInfo "Schedule '$($v.Name)' created." 'Schedule'
}

function New-UiAlertFromReport {
    param($Page)
    if (-not $Page.Report) { Show-UiInfo 'Pick a report first.'; return }
    Assert-ConsolePermission 'ManageAlerts'
    $params = Get-UiReportParams $Page
    $inputs = ConvertTo-InputDefinitions @(
        @{ Name = 'Name'; Label = 'Alert name'; Required = $true; Default = "$($Page.Report.Name) alert" }
        @{ Name = 'MatchText'; Label = 'Only count rows containing'; Help = 'Leave blank to count every row.'; Default = $Page.Filter.Text }
        @{ Name = 'MinRows'; Label = 'Trigger when at least N rows'; Type = 'Number'; Default = 1 }
        @{ Name = 'Severity'; Type = 'Choice'; Choices = @('Info', 'Warning', 'Critical'); Default = 'Warning' }
    ) 'Alert'
    $v = Show-UiInputDialog -Title "Alert: $($Page.Report.Name)" -Inputs $inputs -Message 'Alerts are evaluated when Invoke-AdminJobs.ps1 runs, and queue a notification when triggered.'
    if ($null -eq $v) { return }
    [void](New-ConsoleAlert -Name $v.Name -Report $Page.Report.Name -Parameters $params -MatchText $v.MatchText -MinRows ([int]$v.MinRows) -Severity $v.Severity)
    Show-UiInfo "Alert '$($v.Name)' created." 'Alert'
}

# ------------------------------------------------------------------ row actions

function New-UiMenuItem {
    param([string]$Text, $State, [switch]$Disabled, [switch]$Danger)
    $item = New-Object System.Windows.Forms.ToolStripMenuItem
    $item.Text = $Text
    if ($Disabled) { $item.Enabled = $false }
    if ($Danger) { $item.ForeColor = [System.Drawing.Color]::Firebrick }
    if ($null -ne $State) { Register-UiEvent $item Click -State $State -Handler { param($s) Invoke-UiRowItem $s } }
    $item
}

function Show-UiRowMenu {
    param($Page)
    $def = $Page.Report
    if (-not $def) { return }
    $row = Get-UiGridSelection $Page.Grid
    if (-not $row) { Show-UiInfo 'Select a row first.'; return }

    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    $menu.Font = $script:UiFont
    foreach ($name in @($def.RowActions)) {
        $a = Get-ConsoleAction -Name $name
        if (-not $a) { continue }
        $ok = (Test-ConsolePermission $a.Permission) -and (Test-ConsoleActionApplies $a $row)
        $label = $a.Name
        if (Test-ConsoleApprovalRequired $a) { $label += ' *' }
        [void]$menu.Items.Add((New-UiMenuItem -Text $label -Danger:$a.Danger -Disabled:(-not $ok) -State @{ Page = $Page; Kind = 'Row'; Item = $a; Row = $row }))
    }
    if ($def.RowType) {
        $key = [string]$row.($def.RowKey)
        if ($menu.Items.Count) { [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) }
        $tabName = if ($def.RowType -eq 'User') { 'Users' } else { 'Computers' }
        [void]$menu.Items.Add((New-UiMenuItem -Text "Open '$key' on the $tabName tab" -State @{ Page = $Page; Kind = 'Open'; Row = $row; Key = $key }))
        foreach ($wf in @(Get-ConsoleWorkflow -Scope $def.RowType)) {
            [void]$menu.Items.Add((New-UiMenuItem -Text "$($wf.Name)..." -State @{ Page = $Page; Kind = 'Workflow'; Item = $wf; Row = $row }))
        }
        $sub = New-Object System.Windows.Forms.ToolStripMenuItem
        $sub.Text = "$($def.RowType) actions"
        foreach ($a in @(Get-ConsoleAction -Scope $def.RowType)) {
            $label = $a.Name
            if (Test-ConsoleApprovalRequired $a) { $label += ' *' }
            [void]$sub.DropDownItems.Add((New-UiMenuItem -Text $label -Danger:$a.Danger -Disabled:(-not (Test-ConsolePermission $a.Permission)) -State @{ Page = $Page; Kind = 'Resolved'; Item = $a; Row = $row }))
        }
        if ($sub.DropDownItems.Count) { [void]$menu.Items.Add($sub) }
    }
    if (-not $menu.Items.Count) { $menu.Dispose(); Show-UiInfo 'This report has no row actions.'; return }
    # One menu at a time: dispose the previous one (never the one being shown).
    if ($Page.Menu -and -not $Page.Menu.IsDisposed) { $Page.Menu.Dispose() }
    $Page.Menu = $menu
    $menu.Show([System.Windows.Forms.Cursor]::Position)
}

function Invoke-UiRowItem {
    param($State)
    $def = $State.Page.Report
    switch ($State.Kind) {
        'Open' { Open-UiTarget -Scope $def.RowType -Identity $State.Key }
        'Row' {
            $r = Invoke-ConsoleAction -Action $State.Item -Target $State.Row -GetInputs $script:UiGetInputs -Confirm $script:UiConfirm
            Show-UiActionResult $r
        }
        'Resolved' {
            $target = Get-ConsoleRowTarget -Report $def -Row $State.Row
            $r = Invoke-ConsoleAction -Action $State.Item -Target $target -GetInputs $script:UiGetInputs -Confirm $script:UiConfirm
            Show-UiActionResult $r
        }
        'Workflow' {
            $target = Get-ConsoleRowTarget -Report $def -Row $State.Row
            Invoke-UiWorkflow -Workflow $State.Item -Target $target
        }
    }
}

Register-UiPage -Title 'Reports' -Order 30 -Permission 'RunReport' -Build {
    param($Tab)
    [void](New-UiReportsPage -Tab $Tab)
}
