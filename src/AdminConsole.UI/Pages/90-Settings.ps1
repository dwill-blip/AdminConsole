# Settings tab: edit config\settings.json with validation.

Register-UiPage -Title 'Settings' -Order 90 -Permission 'ManageSettings' -Build {
    param($Tab)
    $page = @{}
    $layout = New-UiLayout -Rows 'Auto', 'Fill'
    $bar = New-UiFlow
    $page.Editor = New-UiTextBox -Multiline -Mono -Width 800
    $page.Editor.Dock = 'Fill'
    $page.Editor.Text = (Get-ConsoleSettingsJson) -replace "`r?`n", "`r`n"
    $bar.Controls.Add((New-UiButton -Text 'Save' -State $page -OnClick {
                param($p)
                Save-ConsoleSettingsJson -Json $p.Editor.Text
                Show-UiInfo 'Settings saved and reloaded. Connection settings apply to new connections (restart the console to reconnect).'
                Request-UiPagesRebuild -Select 'Settings'
            }))
    $bar.Controls.Add((New-UiButton -Text 'Revert' -State $page -OnClick { param($p) $p.Editor.Text = (Get-ConsoleSettingsJson) -replace "`r?`n", "`r`n" }))
    $bar.Controls.Add((New-UiLabel '   JSON is validated before saving. See docs\SETTINGS.md for every option.'))
    Add-UiCell $layout $bar 0 0
    Add-UiCell $layout $page.Editor 0 1
    $Tab.Controls.Add($layout)
}
