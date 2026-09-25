# Control factories and the event plumbing.
#
# WHY Register-UiEvent: PowerShell event handlers do not see the local variables of
# the function that created them, and GetNewClosure() freezes variables at the moment
# the button is created (that is what broke every user button in the old version:
# they all captured "no user loaded"). Instead, each handler is
# stored in the control's Tag together with a $State object, and one shared
# dispatcher calls it as:  & $Handler $State $Sender $EventArgs
# Errors are caught and shown in a message box, and the cursor shows "busy".

$script:UiFont      = New-Object System.Drawing.Font('Segoe UI', 9)
$script:UiMonoFont  = New-Object System.Drawing.Font('Consolas', 9)
$script:UiBoldFont  = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$script:UiStatus    = $null   # ToolStripStatusLabel, set by MainWindow
$script:UiToolTip   = New-Object System.Windows.Forms.ToolTip

function Invoke-UiEvent {
    param($Sender, [string]$EventName, $EventArgs)
    $entry = $null
    if ($Sender.Tag -is [hashtable]) { $entry = $Sender.Tag[$EventName] }
    if (-not $entry) { return }
    $ErrorActionPreference = 'Stop'
    # No Application.DoEvents() here: it would let a second click re-enter this handler
    # and would swallow SuppressKeyPress for Enter. Just repaint the status bar.
    Set-UiStatus 'Working...'
    [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::WaitCursor
    try {
        & $entry.Handler $entry.State $Sender $EventArgs
    }
    catch {
        if ($_.Exception.Message -eq 'Cancelled by the operator.') { Write-ConsoleLog 'Cancelled.' Warning }
        else {
            Write-ConsoleLog $_.Exception.Message Error
            Show-UiError $_.Exception.Message
        }
    }
    finally {
        Close-UiProgress
        [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::Default
        Set-UiStatus 'Ready'
    }
}

# Progress window for long operations (fed by Write-ConsoleProgress). While it is up the
# main window is disabled, so pumping messages here cannot re-enter a click handler;
# only its Cancel button can be used. Cancel makes the next progress update throw.
$script:UiProgress = $null

function Update-UiProgress {
    param([string]$Activity, [int]$Done, [int]$Total)
    if (-not $script:UiForm -or $script:UiForm.IsDisposed -or -not $script:UiForm.Visible) { return }
    if (-not $script:UiProgress) {
        $dlg = New-Object System.Windows.Forms.Form
        $dlg.Text = 'Working...'
        $dlg.Font = $script:UiFont
        $dlg.FormBorderStyle = 'FixedDialog'
        $dlg.ControlBox = $false
        $dlg.ShowInTaskbar = $false
        $dlg.StartPosition = 'CenterParent'
        $dlg.AutoSize = $true
        $dlg.AutoSizeMode = 'GrowAndShrink'
        $dlg.Padding = New-Object System.Windows.Forms.Padding(12)
        $table = New-Object System.Windows.Forms.TableLayoutPanel
        $table.AutoSize = $true
        $table.ColumnCount = 1
        $label = New-UiLabel ''
        $label.AutoSize = $false
        $label.Width = 420
        $label.Height = 40
        $bar = New-Object System.Windows.Forms.ProgressBar
        $bar.Width = 420
        $cancel = New-Object System.Windows.Forms.Button
        $cancel.Text = 'Cancel'
        $cancel.AutoSize = $true
        $cancel.Anchor = 'Right'
        $cancel.Add_Click({ if ($script:UiProgress) { $script:UiProgress.Cancelled = $true; $script:UiProgress.Label.Text = 'Cancelling...' } })
        $table.Controls.Add($label)
        $table.Controls.Add($bar)
        $table.Controls.Add($cancel)
        $dlg.Controls.Add($table)
        $script:UiProgress = @{ Form = $dlg; Label = $label; Bar = $bar; Cancelled = $false }
        $script:UiForm.Enabled = $false
        $dlg.Show($script:UiForm)
    }
    $p = $script:UiProgress
    if (-not $p.Cancelled) {
        if ($Total -gt 0) {
            $p.Bar.Style = 'Continuous'
            $p.Bar.Maximum = $Total
            $p.Bar.Value = [math]::Max(0, [math]::Min($Done, $Total))
            $p.Label.Text = "$Activity`n$Done of $Total"
        }
        else {
            $p.Bar.Style = 'Marquee'
            $p.Label.Text = $Activity
        }
    }
    [System.Windows.Forms.Application]::DoEvents()
    if ($p.Cancelled) { throw 'Cancelled by the operator.' }
}

function Close-UiProgress {
    if (-not $script:UiProgress) { return }
    $p = $script:UiProgress
    $script:UiProgress = $null
    if ($script:UiForm -and -not $script:UiForm.IsDisposed) { $script:UiForm.Enabled = $true }
    if (-not $p.Form.IsDisposed) { $p.Form.Close(); $p.Form.Dispose() }
    if ($script:UiForm -and -not $script:UiForm.IsDisposed) { [void]$script:UiForm.Activate() }
}

function Set-UiStatus {
    param([string]$Text)
    if (-not $script:UiStatus) { return }
    $script:UiStatus.Text = $Text
    $strip = $script:UiStatus.GetCurrentParent()
    if ($strip -and -not $strip.IsDisposed) { $strip.Refresh() }
}

function Register-UiEvent {
    <#
    .SYNOPSIS  Attach a handler: Register-UiEvent $button Click { param($State, $Sender, $e) ... } $state
    #>
    param(
        [Parameter(Mandatory)]$Control,
        [Parameter(Mandatory)][ValidateSet('Click', 'DoubleClick', 'AfterSelect', 'SelectedIndexChanged', 'TextChanged', 'KeyDown', 'CellMouseDown', 'CellDoubleClick', 'NodeMouseDoubleClick')][string]$EventName,
        [Parameter(Mandatory)][scriptblock]$Handler,
        $State = $null
    )
    if ($Control.Tag -isnot [hashtable]) { $Control.Tag = @{} }
    $first = -not $Control.Tag.ContainsKey($EventName)
    $Control.Tag[$EventName] = @{ Handler = $Handler; State = $State }
    if (-not $first) { return }   # dispatcher already wired; we only swapped the handler
    switch ($EventName) {
        'Click'                { $Control.Add_Click({ Invoke-UiEvent $this 'Click' $_ }) }
        'DoubleClick'          { $Control.Add_DoubleClick({ Invoke-UiEvent $this 'DoubleClick' $_ }) }
        'AfterSelect'          { $Control.Add_AfterSelect({ Invoke-UiEvent $this 'AfterSelect' $_ }) }
        'SelectedIndexChanged' { $Control.Add_SelectedIndexChanged({ Invoke-UiEvent $this 'SelectedIndexChanged' $_ }) }
        'TextChanged'          { $Control.Add_TextChanged({ Invoke-UiEvent $this 'TextChanged' $_ }) }
        'KeyDown'              { $Control.Add_KeyDown({ Invoke-UiEvent $this 'KeyDown' $_ }) }
        'CellMouseDown'        { $Control.Add_CellMouseDown({ Invoke-UiEvent $this 'CellMouseDown' $_ }) }
        'CellDoubleClick'      { $Control.Add_CellDoubleClick({ Invoke-UiEvent $this 'CellDoubleClick' $_ }) }
        'NodeMouseDoubleClick' { $Control.Add_NodeMouseDoubleClick({ Invoke-UiEvent $this 'NodeMouseDoubleClick' $_ }) }
    }
}

# ------------------------------------------------------------------ page registry

$script:PageRegistry = New-Object System.Collections.ArrayList

function Register-UiPage {
    <#
    .SYNOPSIS  Adds a tab. Build receives the TabPage and fills it.
    .EXAMPLE   Register-UiPage -Title 'My Page' -Order 55 -Permission 'RunReport' -Build { param($Tab) ... }
    #>
    param(
        [Parameter(Mandatory)][string]$Title,
        [int]$Order = 100,
        [string]$Permission = '',
        [scriptblock]$Visible,
        [Parameter(Mandatory)][scriptblock]$Build
    )
    [void]$script:PageRegistry.Add([pscustomobject]@{ Title = $Title; Order = $Order; Permission = $Permission; Visible = $Visible; Build = $Build })
}

# ------------------------------------------------------------------ message boxes

function Show-UiError { param([string]$Message, [string]$Title = 'Error')
    [void][System.Windows.Forms.MessageBox]::Show($Message, $Title, 'OK', 'Error')
}
function Show-UiInfo { param([string]$Message, [string]$Title = 'Information')
    [void][System.Windows.Forms.MessageBox]::Show($Message, $Title, 'OK', 'Information')
}
function Show-UiWarning { param([string]$Message, [string]$Title = 'Warning')
    [void][System.Windows.Forms.MessageBox]::Show($Message, $Title, 'OK', 'Warning')
}
function Show-UiConfirm { param([string]$Message, [string]$Title = 'Confirm')
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, 'YesNo', 'Warning', 'Button2') -eq [System.Windows.Forms.DialogResult]::Yes
}

# ------------------------------------------------------------------ basic controls

function New-UiButton {
    param(
        [Parameter(Mandatory)][string]$Text,
        [scriptblock]$OnClick,
        $State,
        [int]$Width = 0,
        [string]$ToolTip,
        [switch]$Danger
    )
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Font = $script:UiFont
    $b.AutoSize = $true
    $b.AutoSizeMode = 'GrowAndShrink'
    $b.Padding = New-Object System.Windows.Forms.Padding(6, 2, 6, 2)
    $b.Margin = New-Object System.Windows.Forms.Padding(3)
    if ($Width -gt 0) { $b.AutoSize = $false; $b.Width = $Width; $b.Height = 30 }
    if ($Danger) { $b.ForeColor = [System.Drawing.Color]::Firebrick }
    if ($ToolTip) { $script:UiToolTip.SetToolTip($b, $ToolTip) }
    if ($OnClick) { Register-UiEvent $b Click $OnClick $State }
    $b
}

function New-UiLabel {
    param([string]$Text = '', [switch]$Bold, [switch]$Wrap, [int]$MaxWidth = 900)
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.AutoSize = $true
    $l.Font = if ($Bold) { $script:UiBoldFont } else { $script:UiFont }
    $l.Margin = New-Object System.Windows.Forms.Padding(3, 8, 3, 3)
    if ($Wrap) { $l.MaximumSize = New-Object System.Drawing.Size($MaxWidth, 0) }
    $l
}

function New-UiTextBox {
    param([int]$Width = 250, [string]$Text = '', [switch]$Password, [switch]$Multiline, [switch]$ReadOnly, [switch]$Mono, [string]$Cue)
    $t = New-Object System.Windows.Forms.TextBox
    $t.Width = $Width
    $t.Text = $Text
    $t.Font = if ($Mono) { $script:UiMonoFont } else { $script:UiFont }
    $t.Margin = New-Object System.Windows.Forms.Padding(3, 5, 3, 3)
    if ($Password) { $t.UseSystemPasswordChar = $true }
    if ($Multiline) { $t.Multiline = $true; $t.ScrollBars = 'Both'; $t.WordWrap = $false; $t.AcceptsReturn = $true; $t.AcceptsTab = $true }
    if ($ReadOnly) { $t.ReadOnly = $true }
    if ($Cue) { $script:UiToolTip.SetToolTip($t, $Cue) }
    $t
}

function New-UiComboBox {
    param([object[]]$Items = @(), $Selected, [int]$Width = 160)
    $c = New-Object System.Windows.Forms.ComboBox
    $c.DropDownStyle = 'DropDownList'
    $c.Width = $Width
    $c.Font = $script:UiFont
    $c.Margin = New-Object System.Windows.Forms.Padding(3, 5, 3, 3)
    foreach ($i in $Items) { [void]$c.Items.Add($i) }
    if ($null -ne $Selected -and $c.Items.Contains($Selected)) { $c.SelectedItem = $Selected }
    elseif ($c.Items.Count) { $c.SelectedIndex = 0 }
    $c
}

function New-UiFlow {
    # A row of controls that wraps; use for toolbars.
    param([switch]$Vertical)
    $f = New-Object System.Windows.Forms.FlowLayoutPanel
    $f.AutoSize = $true
    $f.AutoSizeMode = 'GrowAndShrink'
    $f.Dock = 'Fill'
    $f.WrapContents = -not $Vertical
    if ($Vertical) { $f.FlowDirection = 'TopDown'; $f.AutoScroll = $true; $f.AutoSize = $false }
    $f.Padding = New-Object System.Windows.Forms.Padding(2)
    $f
}

function New-UiLayout {
    <#
    .SYNOPSIS  A TableLayoutPanel that fills its parent. -Rows / -Columns take 'Auto', 'Fill' or a pixel/percent value like '300' / '40%'.
    .EXAMPLE   $grid = New-UiLayout -Rows 'Auto','Fill'
    #>
    param([string[]]$Rows = @('Fill'), [string[]]$Columns = @('Fill'))
    $t = New-Object System.Windows.Forms.TableLayoutPanel
    $t.Dock = 'Fill'
    $t.RowCount = $Rows.Count
    $t.ColumnCount = $Columns.Count
    foreach ($r in $Rows) { [void]$t.RowStyles.Add((ConvertTo-UiSizeStyle $r 'Row')) }
    foreach ($c in $Columns) { [void]$t.ColumnStyles.Add((ConvertTo-UiSizeStyle $c 'Column')) }
    $t
}

function ConvertTo-UiSizeStyle {
    param([string]$Spec, [string]$Kind)
    $type = if ($Kind -eq 'Row') { [System.Windows.Forms.RowStyle] } else { [System.Windows.Forms.ColumnStyle] }
    if ($Spec -eq 'Auto') { return $type::new([System.Windows.Forms.SizeType]::AutoSize) }
    if ($Spec -eq 'Fill') { return $type::new([System.Windows.Forms.SizeType]::Percent, 100) }
    if ($Spec -like '*%') { return $type::new([System.Windows.Forms.SizeType]::Percent, [single]$Spec.TrimEnd('%')) }
    $type::new([System.Windows.Forms.SizeType]::Absolute, [single]$Spec)
}

function Add-UiCell {
    # Put a control in a TableLayoutPanel cell.
    param($Layout, $Control, [int]$Column = 0, [int]$Row = 0, [int]$ColumnSpan = 1)
    $Layout.Controls.Add($Control, $Column, $Row)
    if ($ColumnSpan -gt 1) { $Layout.SetColumnSpan($Control, $ColumnSpan) }
}

# ------------------------------------------------------------------ grids

function New-UiGrid {
    $g = New-Object System.Windows.Forms.DataGridView
    $g.Dock = 'Fill'
    $g.ReadOnly = $true
    $g.AllowUserToAddRows = $false
    $g.AllowUserToDeleteRows = $false
    $g.AllowUserToResizeRows = $false
    $g.SelectionMode = 'FullRowSelect'
    $g.MultiSelect = $false
    $g.RowHeadersVisible = $false
    $g.AutoSizeColumnsMode = 'DisplayedCells'
    $g.BackgroundColor = [System.Drawing.SystemColors]::Window
    $g.BorderStyle = 'FixedSingle'
    $g.Font = $script:UiFont
    $g.Tag = @{ Rows = @() }
    # Hide the row-index column whenever data is (re)bound, and colour rows by their
    # Status / Result column (green = done, yellow = to do / pending, red = failed).
    $g.Add_DataBindingComplete({
            if ($this.Columns.Contains('__row')) { $this.Columns['__row'].Visible = $false }
            $col = $null
            foreach ($name in 'Status', 'Result') { if ($this.Columns.Contains($name)) { $col = $name; break } }
            if (-not $col) { return }
            $green = [System.Drawing.Color]::FromArgb(226, 243, 226)
            $yellow = [System.Drawing.Color]::FromArgb(255, 246, 214)
            $red = [System.Drawing.Color]::FromArgb(250, 222, 222)
            foreach ($row in $this.Rows) {
                $v = [string]$row.Cells[$col].Value
                $c = $null
                if ($v -in 'Done', 'Success', 'Healthy', 'Sent', 'Approved', 'Executed', 'Completed') { $c = $green }
                elseif ($v -in 'To do', 'Pending', 'PendingApproval', 'ApprovalRequested', 'Queued', 'Retry', 'Warning') { $c = $yellow }
                elseif ($v -in 'Error', 'Failed', 'Missing', 'Rejected', 'Denied') { $c = $red }
                if ($c) { $row.DefaultCellStyle.BackColor = $c }
            }
        })
    $g
}

function ConvertTo-UiDataTable {
    param([object[]]$Rows)
    $table = New-Object System.Data.DataTable
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($r in @($Rows | Select-Object -First 200)) {
        if ($null -eq $r) { continue }
        foreach ($p in $r.PSObject.Properties) { if (-not $names.Contains($p.Name)) { $names.Add($p.Name) } }
    }
    foreach ($n in $names) { [void]$table.Columns.Add($n, [string]) }
    [void]$table.Columns.Add('__row', [int])
    $i = 0
    foreach ($r in @($Rows)) {
        if ($null -eq $r) { $i++; continue }
        $dr = $table.NewRow()
        foreach ($n in $names) {
            $p = $r.PSObject.Properties[$n]
            if ($p) { $dr[$n] = Format-ConsoleValue $p.Value }
        }
        $dr['__row'] = $i
        $table.Rows.Add($dr)
        $i++
    }
    , $table
}

function Set-UiGridData {
    <#
    .SYNOPSIS  Shows objects in a grid and remembers them so Get-UiGridSelection returns the originals.
    #>
    param([Parameter(Mandatory)]$Grid, [object[]]$Rows)
    $Rows = @($Rows)
    $Grid.Tag['Rows'] = $Rows
    $Grid.DataSource = $null
    $Grid.DataSource = ConvertTo-UiDataTable $Rows
}

function Get-UiGridSelection {
    param([Parameter(Mandatory)]$Grid)
    if (-not $Grid.CurrentRow) { return $null }
    $idx = $Grid.CurrentRow.Cells['__row'].Value
    if ($null -eq $idx -or $idx -is [DBNull]) { return $null }
    @($Grid.Tag['Rows'])[[int]$idx]
}

function Select-UiGridRowAt {
    # Right-click support: make the clicked row current.
    param($Grid, [int]$RowIndex, [int]$ColumnIndex)
    if ($RowIndex -lt 0 -or $RowIndex -ge $Grid.Rows.Count) { return }
    $col = $ColumnIndex
    if ($col -lt 0 -or -not $Grid.Columns[$col].Visible) {
        $first = @($Grid.Columns | Where-Object { $_.Visible } | Select-Object -First 1)
        if (-not $first.Count) { return }
        $col = $first[0].Index
    }
    $Grid.CurrentCell = $Grid.Rows[$RowIndex].Cells[$col]
}

function New-UiDetailsGrid {
    # Two-column Property / Value grid for showing one object.
    $g = New-UiGrid
    $g.AutoSizeColumnsMode = 'Fill'
    $g.ColumnHeadersVisible = $false
    $g
}

function Set-UiDetails {
    param([Parameter(Mandatory)]$Grid, [System.Collections.IDictionary]$Values)
    $rows = @()
    if ($Values) { foreach ($k in $Values.Keys) { $rows += [pscustomobject]@{ Property = $k; Value = (Format-ConsoleValue $Values[$k]) } } }
    Set-UiGridData $Grid $rows
    if ($Grid.Columns.Contains('Property')) { $Grid.Columns['Property'].FillWeight = 30 }
}

# ------------------------------------------------------------------ inputs (shared by dialogs and report parameters)

function New-UiInputControl {
    param([Parameter(Mandatory)]$Definition, $Value)
    if ($null -eq $Value) { $Value = $Definition.Default }
    switch ($Definition.Type) {
        'Password'  { $c = New-UiTextBox -Width 280 -Password }
        'Multiline' { $c = New-UiTextBox -Width 380 -Multiline; $c.Height = 90; if ($null -ne $Value) { $c.Text = [string]$Value } }
        'Number' {
            $c = New-Object System.Windows.Forms.NumericUpDown
            $c.Minimum = -1000000; $c.Maximum = 100000000; $c.Width = 120; $c.Font = $script:UiFont
            $c.Margin = New-Object System.Windows.Forms.Padding(3, 5, 3, 3)
            if ($null -ne $Value -and "$Value" -ne '') { $c.Value = [decimal][Math]::Min([Math]::Max([double]$Value, -1000000), 100000000) }
        }
        'Bool' {
            $c = New-Object System.Windows.Forms.CheckBox
            $c.Text = $Definition.Label; $c.AutoSize = $true; $c.Font = $script:UiFont; $c.Checked = [bool]$Value
            $c.Margin = New-Object System.Windows.Forms.Padding(3, 6, 3, 3)
        }
        'Choice' { $c = New-UiComboBox -Items $Definition.Choices -Selected $Value -Width 200 }
        'Date' {
            $c = New-Object System.Windows.Forms.DateTimePicker
            $c.Format = 'Short'; $c.Width = 140; $c.Font = $script:UiFont
            if ($Value) { try { $c.Value = [datetime]$Value } catch { } }
        }
        default { $c = New-UiTextBox -Width 280; if ($null -ne $Value) { $c.Text = [string]$Value } }
    }
    if ($Definition.Help) { $script:UiToolTip.SetToolTip($c, $Definition.Help) }
    $c
}

function Get-UiInputValue {
    param([Parameter(Mandatory)]$Definition, [Parameter(Mandatory)]$Control)
    switch ($Definition.Type) {
        'Number' { return [double]$Control.Value }
        'Bool'   { return [bool]$Control.Checked }
        'Choice' { return [string]$Control.SelectedItem }
        'Date'   { return $Control.Value.Date }
        default  { return $Control.Text }
    }
}

function New-UiToolbarGrid {
    # The common "toolbar above a grid" layout. Returns @{ Bar; Grid; Layout }.
    param([Parameter(Mandatory)]$Parent, [string]$Caption)
    $rows = @('Auto', 'Fill')
    if ($Caption) { $rows = @('Auto', 'Auto', 'Fill') }
    $layout = New-UiLayout -Rows $rows
    $r = 0
    if ($Caption) { Add-UiCell $layout (New-UiLabel $Caption -Bold) 0 $r; $r++ }
    $bar = New-UiFlow
    Add-UiCell $layout $bar 0 $r
    $grid = New-UiGrid
    Add-UiCell $layout $grid 0 ($r + 1)
    $Parent.Controls.Add($layout)
    @{ Bar = $bar; Grid = $grid; Layout = $layout }
}
