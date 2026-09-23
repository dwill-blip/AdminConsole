# Reusable modal dialogs. None of them need event handlers: OK/Cancel buttons use
# DialogResult, and values are read after ShowDialog() returns.

function New-UiDialogForm {
    param([string]$Title)
    $f = New-Object System.Windows.Forms.Form
    $f.Text = $Title
    $f.Font = $script:UiFont
    $f.FormBorderStyle = 'FixedDialog'
    $f.MaximizeBox = $false
    $f.MinimizeBox = $false
    $f.ShowInTaskbar = $false
    $f.StartPosition = 'CenterParent'
    $f.AutoSize = $true
    $f.AutoSizeMode = 'GrowAndShrink'
    $f.Padding = New-Object System.Windows.Forms.Padding(10)
    $f
}

function New-UiDialogButtons {
    param($Form, [string]$OkText = 'OK', [switch]$NoCancel)
    $flow = New-Object System.Windows.Forms.FlowLayoutPanel
    $flow.FlowDirection = 'RightToLeft'
    $flow.AutoSize = $true
    $flow.Dock = 'Fill'
    $flow.Margin = New-Object System.Windows.Forms.Padding(0, 10, 0, 0)
    if (-not $NoCancel) {
        $cancel = New-UiButton -Text 'Cancel' -Width 90
        $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $Form.CancelButton = $cancel
    }
    $ok = New-UiButton -Text $OkText -Width 90
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $Form.AcceptButton = $ok
    if ($NoCancel) { $Form.CancelButton = $ok }
    # RightToLeft: first added is right-most.
    if (-not $NoCancel) { $flow.Controls.Add($cancel) }
    $flow.Controls.Add($ok)
    $flow
}

function Show-UiInputDialog {
    <#
    .SYNOPSIS  Prompts for values described by input definitions (see plugin Inputs). Returns a hashtable, or $null if cancelled.
    #>
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)]$Inputs,
        [hashtable]$Values = @{},
        [string]$Message = ''
    )
    $form = New-UiDialogForm $Title
    $table = New-Object System.Windows.Forms.TableLayoutPanel
    $table.AutoSize = $true
    $table.AutoSizeMode = 'GrowAndShrink'
    $table.ColumnCount = 2
    [void]$table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
    [void]$table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $row = 0
    if ($Message) {
        $table.Controls.Add((New-UiLabel $Message -Wrap -MaxWidth 480), 0, $row)
        $table.SetColumnSpan($table.GetControlFromPosition(0, $row), 2)
        $row++
    }
    $controls = @{}
    foreach ($def in @($Inputs)) {
        $value = $null
        if ($Values.ContainsKey($def.Name)) { $value = $Values[$def.Name] }
        $ctl = New-UiInputControl -Definition $def -Value $value
        $controls[$def.Name] = $ctl
        if ($def.Type -eq 'Bool') {
            $table.Controls.Add($ctl, 1, $row)
        }
        else {
            $label = $def.Label
            if ($def.Required) { $label += ' *' }
            $table.Controls.Add((New-UiLabel $label), 0, $row)
            $table.Controls.Add($ctl, 1, $row)
        }
        $row++
    }
    $buttons = New-UiDialogButtons $form
    $table.Controls.Add($buttons, 0, $row)
    $table.SetColumnSpan($buttons, 2)
    $form.Controls.Add($table)

    try {
        while ($true) {
            if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
            $result = @{}
            foreach ($def in @($Inputs)) { $result[$def.Name] = Get-UiInputValue -Definition $def -Control $controls[$def.Name] }
            try {
                return (Complete-ConsoleInputs -Definitions $Inputs -Values $result)
            }
            catch { Show-UiWarning $_.Exception.Message 'Check your input' }
        }
    }
    finally { $form.Dispose() }
}

function Show-UiPrompt {
    # One text value. Returns the string or $null.
    param([string]$Title, [string]$Label, [string]$Default = '', [switch]$Required)
    $def = [pscustomobject]@{ Name = 'Value'; Label = $Label; Type = 'Text'; Required = [bool]$Required; Default = $Default; Choices = @(); Help = '' }
    $r = Show-UiInputDialog -Title $Title -Inputs @($def)
    if ($null -eq $r) { return $null }
    [string]$r.Value
}

function Show-UiChecklist {
    <#
    .SYNOPSIS  Tick-box list. Returns the checked items (string[]) or $null if cancelled.
    #>
    param(
        [Parameter(Mandatory)][string]$Title,
        [string]$Message = '',
        [Parameter(Mandatory)][string[]]$Items,
        [string[]]$Checked = @(),
        [int]$Height = 320,
        [int]$Width = 440
    )
    $form = New-UiDialogForm $Title
    $table = New-Object System.Windows.Forms.TableLayoutPanel
    $table.AutoSize = $true
    $table.ColumnCount = 1
    if ($Message) { $table.Controls.Add((New-UiLabel $Message -Wrap -MaxWidth $Width)) }
    $list = New-Object System.Windows.Forms.CheckedListBox
    $list.CheckOnClick = $true
    $list.HorizontalScrollbar = $true
    $list.Width = $Width
    $list.Height = $Height
    $list.Font = $script:UiFont
    foreach ($i in $Items) { [void]$list.Items.Add($i, ($Checked -contains $i)) }
    $table.Controls.Add($list)

    $tools = New-Object System.Windows.Forms.FlowLayoutPanel
    $tools.AutoSize = $true
    $all = New-UiButton -Text 'Select all' -OnClick { param($l) for ($i = 0; $i -lt $l.Items.Count; $i++) { $l.SetItemChecked($i, $true) } } -State $list
    $none = New-UiButton -Text 'Select none' -OnClick { param($l) for ($i = 0; $i -lt $l.Items.Count; $i++) { $l.SetItemChecked($i, $false) } } -State $list
    $tools.Controls.AddRange(@($all, $none))
    $table.Controls.Add($tools)
    $table.Controls.Add((New-UiDialogButtons $form))
    $form.Controls.Add($table)
    try {
        if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
        , [string[]]@($list.CheckedItems | ForEach-Object { [string]$_ })
    }
    finally { $form.Dispose() }
}

function Show-UiText {
    # Read-only text viewer (results, JSON, logs).
    param([string]$Title, [string]$Text, [int]$Width = 760, [int]$Height = 420)
    $form = New-UiDialogForm $Title
    $table = New-Object System.Windows.Forms.TableLayoutPanel
    $table.AutoSize = $true
    $table.ColumnCount = 1
    $box = New-UiTextBox -Multiline -ReadOnly -Mono -Width $Width
    $box.Height = $Height
    $box.Text = ($Text -replace "`r?`n", "`r`n")
    $table.Controls.Add($box)
    $table.Controls.Add((New-UiDialogButtons $form -OkText 'Close' -NoCancel))
    $form.Controls.Add($table)
    try { [void]$form.ShowDialog() } finally { $form.Dispose() }
}

function Show-UiGridDialog {
    # Read-only grid of objects in a resizable dialog (status lists, results).
    param([string]$Title, [object[]]$Rows, [string]$Message = '', [int]$Width = 1000, [int]$Height = 520)
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Font = $script:UiFont
    $form.StartPosition = 'CenterParent'
    $form.ShowInTaskbar = $false
    $form.MinimizeBox = $false
    $form.Size = New-Object System.Drawing.Size($Width, $Height)
    $layout = New-UiLayout -Rows 'Auto', 'Fill', 'Auto'
    $layout.Padding = New-Object System.Windows.Forms.Padding(8)
    Add-UiCell $layout (New-UiLabel $Message -Wrap -MaxWidth ($Width - 40)) 0 0
    $grid = New-UiGrid
    $grid.AutoSizeColumnsMode = 'AllCells'
    Add-UiCell $layout $grid 0 1
    Add-UiCell $layout (New-UiDialogButtons $form -OkText 'Close' -NoCancel) 0 2
    $form.Controls.Add($layout)
    Set-UiGridData $grid $Rows
    try { [void]$form.ShowDialog() } finally { $form.Dispose() }
}

function Show-UiActionResult {
    # Presents an AdminConsole.ActionResult to the operator.
    param([Parameter(Mandatory)]$Result)
    $title = "$($Result.Action) - $($Result.Target)"
    switch ($Result.Status) {
        'Success'           { Show-UiInfo $Result.Message $title }
        'ApprovalRequested' { Show-UiInfo $Result.Message 'Approval required' }
        'PendingApproval'   { Show-UiInfo $Result.Message 'Waiting for approval' }
        'NotApplicable'     { Show-UiInfo $Result.Message $title }
        'Denied'            { Show-UiWarning $Result.Message 'Access denied' }
        'Failed'            { Show-UiError $Result.Message "$title failed" }
        default             { }   # Cancelled: say nothing
    }
}

function Show-UiResultList {
    # Summary of several results (workflows).
    param([string]$Title, [object[]]$Results)
    $lines = foreach ($r in @($Results)) { '{0,-18} {1,-30} {2}' -f $r.Status, $r.Action, ($r.Message -replace "`r?`n", ' ') }
    Show-UiText -Title $Title -Text ($lines -join "`n")
}

# Callbacks handed to the core runner.
$script:UiGetInputs = { param($Action, $Target) Show-UiInputDialog -Title $Action.Name -Inputs $Action.Inputs -Message $Action.Description }
$script:UiConfirm   = { param($Message) Show-UiConfirm $Message }
