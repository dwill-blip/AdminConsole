# Settings tab: edit config\settings.local.json with validation, or import an earlier
# settings file (v8 settings.json or v7 AppConfig.json).

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
    $bar.Controls.Add((New-UiButton -Text 'Import...' -ToolTip 'Copy the values from an earlier settings.json or v7 AppConfig.json' -State $page -OnClick {
                param($p)
                Assert-ConsolePermission 'ManageSettings'
                $dialog = New-Object System.Windows.Forms.OpenFileDialog
                $dialog.Title = 'Import an earlier settings file'
                $dialog.Filter = 'Settings files (*.json)|*.json|All files (*.*)|*.*'
                if ($dialog.ShowDialog() -ne 'OK') { return }
                $names = Import-ConsoleSettingsFile -Path $dialog.FileName
                Write-ConsoleAudit -Action 'Import Settings' -Target $dialog.FileName -Result 'Success'
                Show-UiInfo "Imported $(@($names).Count) setting(s) into settings.local.json:`n`n$($names -join ', ')`n`nConnection settings apply to new connections (restart the console to reconnect)."
                Request-UiPagesRebuild -Select 'Settings'
            }))
    $bar.Controls.Add((New-UiLabel '   Saved to config\settings.local.json (not overwritten by updates). See docs\SETTINGS.md for every option.'))
    Add-UiCell $layout $bar 0 0
    Add-UiCell $layout $page.Editor 0 1
    $Tab.Controls.Add($layout)
}
