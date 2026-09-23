# Automation tab: scheduled reports, alerts and the notification queue.
# Everything here also runs unattended via Invoke-AdminJobs.ps1.

function Update-UiAutomation {
    param($Page)
    Set-UiGridData $Page.Schedules @(Get-ConsoleSchedule)
    Set-UiGridData $Page.Alerts @(Get-ConsoleAlert)
    Set-UiGridData $Page.Notifications @(Get-ConsoleNotification)
}

function Invoke-UiAutomationRow {
    param($Page, [string]$Kind, [string]$Verb)
    $grid = if ($Kind -eq 'Schedule') { $Page.Schedules } else { $Page.Alerts }
    $row = Get-UiGridSelection $grid
    if (-not $row) { Show-UiInfo "Select a $($Kind.ToLower()) first."; return }
    switch ("$Kind/$Verb") {
        'Schedule/Run'    { Assert-ConsolePermission 'ManageSchedules'; Invoke-ConsoleSchedule $row }
        'Schedule/Toggle' { Set-ConsoleScheduleEnabled -Id $row.Id -Enabled (-not [bool]$row.Enabled) }
        'Schedule/Delete' { if (Show-UiConfirm "Delete schedule '$($row.Name)'?") { Remove-ConsoleSchedule -Id $row.Id } }
        'Alert/Run'       { Assert-ConsolePermission 'ManageAlerts'; Invoke-ConsoleAlert $row }
        'Alert/Toggle'    { Set-ConsoleAlertEnabled -Id $row.Id -Enabled (-not [bool]$row.Enabled) }
        'Alert/Delete'    { if (Show-UiConfirm "Delete alert '$($row.Name)'?") { Remove-ConsoleAlert -Id $row.Id } }
    }
    Update-UiAutomation $Page
}

Register-UiPage -Title 'Automation' -Order 50 -Build {
    param($Tab)
    $page = @{}
    $inner = New-Object System.Windows.Forms.TabControl
    $inner.Dock = 'Fill'
    $Tab.Controls.Add($inner)

    # Schedules
    $t1 = New-Object System.Windows.Forms.TabPage 'Scheduled reports'
    $inner.TabPages.Add($t1)
    $ui = New-UiToolbarGrid -Parent $t1
    $page.Schedules = $ui.Grid
    $ui.Bar.Controls.Add((New-UiButton -Text 'Refresh' -State $page -OnClick { param($p) Update-UiAutomation $p }))
    $ui.Bar.Controls.Add((New-UiButton -Text 'Run selected now' -State $page -OnClick { param($p) Invoke-UiAutomationRow $p 'Schedule' 'Run' }))
    $ui.Bar.Controls.Add((New-UiButton -Text 'Enable / disable' -State $page -OnClick { param($p) Invoke-UiAutomationRow $p 'Schedule' 'Toggle' }))
    $ui.Bar.Controls.Add((New-UiButton -Text 'Delete' -Danger -State $page -OnClick { param($p) Invoke-UiAutomationRow $p 'Schedule' 'Delete' }))
    $ui.Bar.Controls.Add((New-UiButton -Text 'Run all due jobs now' -State $page -OnClick {
                param($p)
                Assert-ConsolePermission 'ManageSchedules'
                Invoke-ConsoleJobs -Job Schedules, Alerts, Notifications
                Update-UiAutomation $p
            }))
    $ui.Bar.Controls.Add((New-UiButton -Text 'Install Windows scheduled task...' -State $page -OnClick {
                param($p)
                $script = Join-Path (Get-ConsoleRoot) 'Invoke-AdminJobs.ps1'
                if (Show-UiConfirm "This opens an elevated PowerShell window that registers a Windows scheduled task running`n$script`nevery 15 minutes. You will be asked for the account it should run as.`n`nContinue?") {
                    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-File', "`"$script`"", '-Register')
                }
            }))
    $ui.Bar.Controls.Add((New-UiLabel '   New schedules are created from the Reports tab (Schedule...).'))

    # Alerts
    $t2 = New-Object System.Windows.Forms.TabPage 'Alerts'
    $inner.TabPages.Add($t2)
    $ui = New-UiToolbarGrid -Parent $t2
    $page.Alerts = $ui.Grid
    $ui.Bar.Controls.Add((New-UiButton -Text 'Refresh' -State $page -OnClick { param($p) Update-UiAutomation $p }))
    $ui.Bar.Controls.Add((New-UiButton -Text 'Evaluate selected now' -State $page -OnClick { param($p) Invoke-UiAutomationRow $p 'Alert' 'Run' }))
    $ui.Bar.Controls.Add((New-UiButton -Text 'Enable / disable' -State $page -OnClick { param($p) Invoke-UiAutomationRow $p 'Alert' 'Toggle' }))
    $ui.Bar.Controls.Add((New-UiButton -Text 'Delete' -Danger -State $page -OnClick { param($p) Invoke-UiAutomationRow $p 'Alert' 'Delete' }))
    $ui.Bar.Controls.Add((New-UiButton -Text 'History...' -OnClick {
                $rows = @(Get-ConsoleAlertHistory)
                $text = (@(ConvertTo-ConsoleFlatRows $rows) | Format-Table -AutoSize | Out-String -Width 300)
                if (-not $rows.Count) { $text = 'No alert has triggered yet.' }
                Show-UiText -Title 'Alert history' -Text $text
            }))
    $ui.Bar.Controls.Add((New-UiLabel '   New alerts are created from the Reports tab (Alert on this...).'))

    # Notifications
    $t3 = New-Object System.Windows.Forms.TabPage 'Notifications'
    $inner.TabPages.Add($t3)
    $ui = New-UiToolbarGrid -Parent $t3
    $page.Notifications = $ui.Grid
    $ui.Bar.Controls.Add((New-UiButton -Text 'Refresh' -State $page -OnClick { param($p) Update-UiAutomation $p }))
    $ui.Bar.Controls.Add((New-UiButton -Text 'Send queued now' -State $page -OnClick {
                param($p)
                Assert-ConsolePermission 'ManageAlerts'
                $n = Send-ConsoleNotifications
                Update-UiAutomation $p
                Show-UiInfo "Sent $n notification(s)."
            }))
    $ui.Bar.Controls.Add((New-UiButton -Text 'Open drop folder' -OnClick {
                $dir = Resolve-ConsolePath (Get-ConsoleSetting 'Notifications.DropFolder' 'output/notifications')
                if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                Start-Process explorer.exe $dir
            }))
    $ui.Bar.Controls.Add((New-UiLabel '   Set Notifications.WebhookUrl in Settings to also post to Teams / Slack / Power Automate.'))

    Update-UiAutomation $page
}
