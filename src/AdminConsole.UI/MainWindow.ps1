# Main window: one tab per registered page, a log panel and a status bar.

$script:UiForm = $null
$script:UiTabs = $null
$script:UiLogBox = $null

function Initialize-UiPages {
    <#
    .SYNOPSIS  (Re)builds every tab from the page registry. Tabs the operator lacks permission for are hidden.
    #>
    param([string]$Select)
    $tabs = $script:UiTabs
    $tabs.SuspendLayout()
    foreach ($old in @($tabs.TabPages)) { $tabs.TabPages.Remove($old); $old.Dispose() }
    $script:UiTargetPages = @{}
    foreach ($page in ($script:PageRegistry | Sort-Object Order, Title)) {
        if ($page.Permission -and -not (Test-ConsolePermission $page.Permission)) { continue }
        if ($page.Visible -and -not (& $page.Visible)) { continue }
        $tab = New-Object System.Windows.Forms.TabPage $page.Title
        $tab.Padding = New-Object System.Windows.Forms.Padding(6)
        $tab.UseVisualStyleBackColor = $true
        $tabs.TabPages.Add($tab)
        try { & $page.Build $tab }
        catch {
            $tab.Controls.Clear()
            $msg = New-UiLabel "This page failed to load:`n`n$($_.Exception.Message)" -Wrap
            $msg.ForeColor = [System.Drawing.Color]::Firebrick
            $tab.Controls.Add($msg)
            Write-ConsoleLog "Page '$($page.Title)' failed to load: $($_.Exception.Message)" Error
        }
        if ($Select -and $page.Title -eq $Select) { $tabs.SelectedTab = $tab }
    }
    $tabs.ResumeLayout()
}

function Request-UiPagesRebuild {
    # Rebuild after the current event finishes (never dispose the button that is being clicked).
    param([string]$Select)
    $script:UiRebuildSelect = $Select
    [void]$script:UiForm.BeginInvoke([System.Action] {
            try { Initialize-UiPages -Select $script:UiRebuildSelect }
            catch { Show-UiError "Could not rebuild the pages: $($_.Exception.Message)" }
        })
}

function Show-AdminConsoleWindow {
    $user = Get-ConsoleUser
    $roles = (@(Get-ConsoleRoleAssignment -Account $user) | ForEach-Object { $_.Role }) -join ', '
    if (-not $roles) { $roles = 'no roles - ask a console admin to add you on the Access tab' }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = Get-ConsoleSetting 'ApplicationName' 'Hybrid Administration Console'
    $form.Font = $script:UiFont
    $form.Size = New-Object System.Drawing.Size(1400, 900)
    $form.MinimumSize = New-Object System.Drawing.Size(1000, 650)
    $form.StartPosition = 'CenterScreen'
    $form.AutoScaleMode = 'Dpi'
    $script:UiForm = $form

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = 'Fill'
    $script:UiTabs = $tabs

    $log = New-Object System.Windows.Forms.TextBox
    $log.Multiline = $true
    $log.ReadOnly = $true
    $log.ScrollBars = 'Vertical'
    $log.Dock = 'Bottom'
    $log.Height = 110
    $log.Font = $script:UiMonoFont
    $log.BackColor = [System.Drawing.SystemColors]::Window
    $script:UiLogBox = $log

    $splitter = New-Object System.Windows.Forms.Splitter
    $splitter.Dock = 'Bottom'

    $strip = New-Object System.Windows.Forms.StatusStrip
    $statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel 'Ready'
    $statusLabel.Spring = $true
    $statusLabel.TextAlign = 'MiddleLeft'
    $who = New-Object System.Windows.Forms.ToolStripStatusLabel "Signed in as $user  |  Roles: $roles  |  DB: $(Get-ConsoleDatabasePath)"
    [void]$strip.Items.Add($statusLabel)
    [void]$strip.Items.Add($who)
    $script:UiStatus = $statusLabel

    # Fill first, then the edges (WinForms docks in reverse order of adding).
    $form.Controls.Add($tabs)
    $form.Controls.Add($splitter)
    $form.Controls.Add($log)
    $form.Controls.Add($strip)

    Register-ConsoleLogSink {
        param($Line, $Level)
        if ($script:UiLogBox -and -not $script:UiLogBox.IsDisposed) { $script:UiLogBox.AppendText($Line + "`r`n") }
    }

    Initialize-UiPages
    Write-ConsoleLog "Ready. Signed in as $user ($roles)."
    foreach ($e in @(Get-ConsolePluginErrors)) { Write-ConsoleLog "Plugin error in $($e.File): $($e.Error)" Warning }

    [void]$form.ShowDialog()
    Clear-ConsoleLogSinks
    $form.Dispose()
}
