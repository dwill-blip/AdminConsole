# Scheduled reports, alerts and the notification queue.
# Nothing here runs by itself: Invoke-AdminJobs.ps1 (run by Windows Task Scheduler)
# or the buttons on the Automation page call Invoke-ConsoleJobs.

$script:Frequencies = 'Hourly', 'Daily', 'Weekly'
$script:Severities  = 'Info', 'Warning', 'Critical'

function Get-NextRunTime {
    <#
    .SYNOPSIS  Next run strictly after -From. At is 'HH:mm' (ignored for Hourly except minutes).
    #>
    param(
        [Parameter(Mandatory)][ValidateSet('Hourly', 'Daily', 'Weekly')][string]$Frequency,
        [string]$At = '06:00',
        [string]$DayOfWeek = 'Monday',
        [datetime]$From = (Get-Date)
    )
    $parts = $At.Split(':')
    $h = [int]$parts[0]; $m = 0
    if ($parts.Count -gt 1) { $m = [int]$parts[1] }
    switch ($Frequency) {
        'Hourly' {
            $next = $From.Date.AddHours($From.Hour).AddMinutes($m)
            if ($next -le $From) { $next = $next.AddHours(1) }
        }
        'Daily' {
            $next = $From.Date.AddHours($h).AddMinutes($m)
            if ($next -le $From) { $next = $next.AddDays(1) }
        }
        'Weekly' {
            $target = [int][System.DayOfWeek]$DayOfWeek
            $delta = ($target - [int]$From.DayOfWeek + 7) % 7
            $next = $From.Date.AddDays($delta).AddHours($h).AddMinutes($m)
            if ($next -le $From) { $next = $next.AddDays(7) }
        }
    }
    $next
}

# ---------------------------------------------------------------- schedules

function Get-ConsoleSchedule { Invoke-DbQuery 'SELECT * FROM Schedules ORDER BY Name' }

function New-ConsoleSchedule {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Report,
        [hashtable]$Parameters = @{},
        [ValidateSet('Hourly', 'Daily', 'Weekly')][string]$Frequency = 'Daily',
        [string]$At = '06:00',
        [string]$DayOfWeek = 'Monday',
        [ValidateSet('csv', 'html', 'json')][string]$Format = 'csv',
        [string]$OutputFolder = ''
    )
    Assert-ConsolePermission 'ManageSchedules'
    $def = Resolve-ConsoleReport $Report
    $next = Get-NextRunTime -Frequency $Frequency -At $At -DayOfWeek $DayOfWeek
    $id = Invoke-DbInsert 'INSERT INTO Schedules (Name, ReportName, ParametersJson, Frequency, At, DayOfWeek, Format, OutputFolder, Enabled, NextRun, CreatedBy, CreatedOn)
                           VALUES (@n, @r, @p, @f, @a, @w, @fmt, @o, 1, @next, @u, @d)' @{
        n = $Name; r = $def.Name; p = ($Parameters | ConvertTo-Json -Compress -Depth 4); f = $Frequency; a = $At; w = $DayOfWeek
        fmt = $Format; o = $OutputFolder; next = $next; u = (Get-ConsoleUser); d = (Get-ConsoleNow)
    }
    Write-ConsoleAudit -Action 'Create Schedule' -Target $Name -Result 'Success' -Details "$($def.Name), $Frequency $At"
    $id
}

function Remove-ConsoleSchedule {
    param([Parameter(Mandatory)][long]$Id)
    Assert-ConsolePermission 'ManageSchedules'
    Invoke-DbNonQuery 'DELETE FROM Schedules WHERE Id = @i' @{ i = $Id } | Out-Null
    Write-ConsoleAudit -Action 'Delete Schedule' -Target "#$Id" -Result 'Success'
}

function Set-ConsoleScheduleEnabled {
    param([Parameter(Mandatory)][long]$Id, [Parameter(Mandatory)][bool]$Enabled)
    Assert-ConsolePermission 'ManageSchedules'
    Invoke-DbNonQuery 'UPDATE Schedules SET Enabled = @e WHERE Id = @i' @{ e = $Enabled; i = $Id } | Out-Null
}

function ConvertFrom-ParametersJson {
    param([string]$Json)
    if ([string]::IsNullOrWhiteSpace($Json)) { return @{} }
    $h = ConvertTo-ConsoleHashtable ($Json | ConvertFrom-Json)
    if ($h -isnot [hashtable]) { return @{} }
    $h
}

function Invoke-ConsoleSchedule {
    param([Parameter(Mandatory)]$Schedule)
    $s = $Schedule
    $status = 'Success'; $detail = ''
    try {
        $rows = @(Invoke-ConsoleReport -Report $s.ReportName -Parameters (ConvertFrom-ParametersJson $s.ParametersJson) -AsSystem)
        $folder = $s.OutputFolder
        if (-not $folder) { $folder = Get-ConsoleSetting 'ReportOutputFolder' 'output/reports' }
        $folder = Resolve-ConsolePath $folder
        $safe = ($s.Name -replace '[^\w\-]', '_')
        $file = Join-Path $folder ('{0}-{1}.{2}' -f $safe, (Get-Date -Format 'yyyyMMdd-HHmmss'), $s.Format)
        Export-ConsoleRows -Rows $rows -Path $file -Title $s.Name -AsSystem
        $detail = "$($rows.Count) rows -> $file"
    }
    catch { $status = 'Failed'; $detail = $_.Exception.Message }
    $next = Get-NextRunTime -Frequency $s.Frequency -At $s.At -DayOfWeek $s.DayOfWeek
    Invoke-DbNonQuery 'UPDATE Schedules SET LastRun = @l, NextRun = @n, LastResult = @r WHERE Id = @i' @{
        l = (Get-ConsoleNow); n = $next; r = "$status - $detail"; i = $s.Id
    } | Out-Null
    Write-ConsoleAudit -Action 'Scheduled Report' -Target $s.Name -Result $status -Details $detail
    if ($status -eq 'Failed') { Add-ConsoleNotification -Subject "Scheduled report failed: $($s.Name)" -Body $detail -Severity 'Warning' }
}

function Invoke-DueSchedules {
    param([datetime]$Now = (Get-Date), [switch]$All)
    $sql = 'SELECT * FROM Schedules WHERE Enabled = 1'
    if (-not $All) { $sql += ' AND (NextRun IS NULL OR NextRun <= @n)' }
    $due = @(Invoke-DbQuery $sql @{ n = $Now.ToString('yyyy-MM-ddTHH:mm:ss') })
    foreach ($s in $due) { Invoke-ConsoleSchedule $s }
    $due.Count
}

# ---------------------------------------------------------------- alerts

function Get-ConsoleAlert { Invoke-DbQuery 'SELECT * FROM Alerts ORDER BY Name' }

function Get-ConsoleAlertHistory { Invoke-DbQuery 'SELECT h.Id, a.Name AS Alert, h.TriggeredOn, h.Severity, h.MatchCount, h.Summary FROM AlertHistory h JOIN Alerts a ON a.Id = h.AlertId ORDER BY h.Id DESC LIMIT 500' }

function New-ConsoleAlert {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Report,
        [hashtable]$Parameters = @{},
        [string]$MatchText = '',
        [int]$MinRows = 1,
        [ValidateSet('Info', 'Warning', 'Critical')][string]$Severity = 'Warning'
    )
    Assert-ConsolePermission 'ManageAlerts'
    $def = Resolve-ConsoleReport $Report
    $id = Invoke-DbInsert 'INSERT INTO Alerts (Name, ReportName, ParametersJson, MatchText, MinRows, Severity, Enabled, CreatedBy, CreatedOn)
                           VALUES (@n, @r, @p, @m, @min, @s, 1, @u, @d)' @{
        n = $Name; r = $def.Name; p = ($Parameters | ConvertTo-Json -Compress -Depth 4); m = $MatchText; min = $MinRows; s = $Severity
        u = (Get-ConsoleUser); d = (Get-ConsoleNow)
    }
    Write-ConsoleAudit -Action 'Create Alert' -Target $Name -Result 'Success' -Details "$($def.Name) contains '$MatchText' >= $MinRows"
    $id
}

function Remove-ConsoleAlert {
    param([Parameter(Mandatory)][long]$Id)
    Assert-ConsolePermission 'ManageAlerts'
    Invoke-DbNonQuery 'DELETE FROM Alerts WHERE Id = @i' @{ i = $Id } | Out-Null
    Write-ConsoleAudit -Action 'Delete Alert' -Target "#$Id" -Result 'Success'
}

function Set-ConsoleAlertEnabled {
    param([Parameter(Mandatory)][long]$Id, [Parameter(Mandatory)][bool]$Enabled)
    Assert-ConsolePermission 'ManageAlerts'
    Invoke-DbNonQuery 'UPDATE Alerts SET Enabled = @e WHERE Id = @i' @{ e = $Enabled; i = $Id } | Out-Null
}

function Invoke-ConsoleAlert {
    param([Parameter(Mandatory)]$Alert)
    $a = $Alert
    try {
        $rows = @(Invoke-ConsoleReport -Report $a.ReportName -Parameters (ConvertFrom-ParametersJson $a.ParametersJson) -AsSystem)
        $hits = @(Select-ConsoleRows -Rows $rows -Text $a.MatchText)
        Invoke-DbNonQuery 'UPDATE Alerts SET LastRun = @l, LastMatches = @m, LastResult = @r WHERE Id = @i' @{ l = (Get-ConsoleNow); m = $hits.Count; r = 'OK'; i = $a.Id } | Out-Null
        if ($hits.Count -ge [int]$a.MinRows -and $hits.Count -gt 0) {
            $preview = (@(ConvertTo-ConsoleFlatRows @($hits | Select-Object -First 20)) | Format-Table -AutoSize | Out-String -Width 250).Trim()
            $summary = "$($hits.Count) matching row(s) in '$($a.ReportName)'."
            Invoke-DbNonQuery 'INSERT INTO AlertHistory (AlertId, TriggeredOn, Severity, MatchCount, Summary) VALUES (@a, @t, @s, @m, @x)' @{
                a = $a.Id; t = (Get-ConsoleNow); s = $a.Severity; m = $hits.Count; x = $summary
            } | Out-Null
            Add-ConsoleNotification -Subject "[$($a.Severity)] $($a.Name)" -Body "$summary`n`n$preview" -Severity $a.Severity
            Write-ConsoleAudit -Action 'Alert Triggered' -Target $a.Name -Result 'Success' -Details $summary
        }
    }
    catch {
        Invoke-DbNonQuery 'UPDATE Alerts SET LastRun = @l, LastResult = @r WHERE Id = @i' @{ l = (Get-ConsoleNow); r = "Failed - $($_.Exception.Message)"; i = $a.Id } | Out-Null
        Write-ConsoleAudit -Action 'Alert' -Target $a.Name -Result 'Failed' -Details $_.Exception.Message
    }
}

function Invoke-ConsoleAlerts {
    $alerts = @(Invoke-DbQuery 'SELECT * FROM Alerts WHERE Enabled = 1')
    foreach ($a in $alerts) { Invoke-ConsoleAlert $a }
    $alerts.Count
}

# ---------------------------------------------------------------- notifications

function Add-ConsoleNotification {
    param([Parameter(Mandatory)][string]$Subject, [string]$Body = '', [string]$Severity = 'Info')
    Invoke-DbNonQuery "INSERT INTO Notifications (Subject, Body, Severity, Status, Attempts, CreatedOn) VALUES (@s, @b, @v, 'Queued', 0, @d)" @{
        s = $Subject; b = $Body; v = $Severity; d = (Get-ConsoleNow)
    } | Out-Null
}

function Get-ConsoleNotification { Invoke-DbQuery 'SELECT * FROM Notifications ORDER BY Id DESC LIMIT 500' }

function Send-ConsoleNotifications {
    <#
    .SYNOPSIS  Delivers queued notifications: always as a JSON file in Notifications.DropFolder,
               and also to Notifications.WebhookUrl (Teams / Slack / Power Automate) when set.
    #>
    param([int]$MaxAttempts = 5)
    $drop = Resolve-ConsolePath (Get-ConsoleSetting 'Notifications.DropFolder' 'output/notifications')
    if (-not (Test-Path $drop)) { New-Item -ItemType Directory -Path $drop -Force | Out-Null }
    $webhook = Get-ConsoleSetting 'Notifications.WebhookUrl' ''
    $queued = @(Invoke-DbQuery "SELECT * FROM Notifications WHERE Status IN ('Queued', 'Retry') AND Attempts < @m ORDER BY Id" @{ m = $MaxAttempts })
    $sent = 0
    foreach ($n in $queued) {
        try {
            $payload = [ordered]@{ Id = $n.Id; Subject = $n.Subject; Severity = $n.Severity; Body = $n.Body; CreatedOn = $n.CreatedOn; Console = (Get-ConsoleSetting 'ApplicationName') }
            $file = Join-Path $drop ('notification-{0}-{1}.json' -f $n.Id, (Get-Date -Format 'yyyyMMddHHmmss'))
            $payload | ConvertTo-Json | Set-Content -Path $file -Encoding UTF8
            if ($webhook) {
                $text = "**$($n.Subject)**`n`n$($n.Body)"
                $body = @{ text = $text } | ConvertTo-Json
                Invoke-RestMethod -Method Post -Uri $webhook -Body $body -ContentType 'application/json' -ErrorAction Stop | Out-Null
            }
            Invoke-DbNonQuery "UPDATE Notifications SET Status = 'Sent', SentOn = @d, Attempts = Attempts + 1, LastError = NULL WHERE Id = @i" @{ d = (Get-ConsoleNow); i = $n.Id } | Out-Null
            $sent++
        }
        catch {
            $newStatus = if ([int]$n.Attempts + 1 -ge $MaxAttempts) { 'Failed' } else { 'Retry' }
            Invoke-DbNonQuery 'UPDATE Notifications SET Status = @s, Attempts = Attempts + 1, LastError = @e WHERE Id = @i' @{ s = $newStatus; e = $_.Exception.Message; i = $n.Id } | Out-Null
            Write-ConsoleLog "Notification #$($n.Id) failed: $($_.Exception.Message)" Warning
        }
    }
    $sent
}
