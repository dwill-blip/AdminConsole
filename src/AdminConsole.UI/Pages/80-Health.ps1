# Health tab: prerequisites, database, plugin load errors; reload plugins without restarting.

function Update-UiHealth {
    param($Page)
    Set-UiGridData $Page.Checks @(Invoke-ConsoleHealthCheck)
    Set-UiGridData $Page.Errors @(Get-ConsolePluginErrors)
}

Register-UiPage -Title 'Health' -Order 80 -Build {
    param($Tab)
    $page = @{}
    $layout = New-UiLayout -Rows '55%', '45%'
    $top = New-Object System.Windows.Forms.Panel; $top.Dock = 'Fill'
    $bottom = New-Object System.Windows.Forms.Panel; $bottom.Dock = 'Fill'
    Add-UiCell $layout $top 0 0
    Add-UiCell $layout $bottom 0 1
    $Tab.Controls.Add($layout)

    $ui = New-UiToolbarGrid -Parent $top -Caption 'Checks'
    $page.Checks = $ui.Grid
    $ui.Bar.Controls.Add((New-UiButton -Text 'Run checks' -State $page -OnClick { param($p) Update-UiHealth $p }))
    $ui.Bar.Controls.Add((New-UiButton -Text 'Reload plugins' -ToolTip 'Picks up new or edited files in the plugins folder without restarting.' -OnClick {
                Import-ConsolePlugins
                Show-UiInfo ("Plugins reloaded: {0} actions, {1} workflows, {2} reports, {3} error(s)." -f @(Get-ConsoleAction).Count, @(Get-ConsoleWorkflow).Count, @(Get-ConsoleReport).Count, @(Get-ConsolePluginErrors).Count)
                # Last line on purpose: the rebuild disposes this button, so nothing may run after it in this handler.
                Request-UiPagesRebuild -Select 'Health'
            }))
    $ui.Bar.Controls.Add((New-UiButton -Text 'Open plugins folder' -OnClick { Start-Process explorer.exe (Join-Path (Get-ConsoleRoot) 'plugins') }))
    $ui.Bar.Controls.Add((New-UiButton -Text 'Connect to Graph' -OnClick { Connect-ConsoleGraph; Show-UiInfo 'Connected to Microsoft Graph.' }))
    $ui.Bar.Controls.Add((New-UiButton -Text 'Connect to Exchange' -OnClick { Connect-ConsoleExchange; Show-UiInfo 'Connected to Exchange Online.' }))

    $ui2 = New-UiToolbarGrid -Parent $bottom -Caption 'Plugin files that failed to load'
    $page.Errors = $ui2.Grid
    $ui2.Bar.Controls.Add((New-UiLabel 'Fix the file, then click Reload plugins. Double-click a row to see the full error.'))
    Register-UiEvent $page.Errors CellDoubleClick -State $page -Handler {
        param($p, $sender, $e)
        if ($e.RowIndex -lt 0) { return }
        $row = Get-UiGridSelection $p.Errors
        if ($row) { Show-UiText -Title $row.File -Text $row.Error }
    }
    Update-UiHealth $page
}
