# Health checks and the single job entry point.

function Invoke-ConsoleHealthCheck {
    $checks = New-Object System.Collections.ArrayList
    function Add-Check($Component, $Status, $Message) {
        [void]$checks.Add([pscustomobject]@{ Component = $Component; Status = $Status; Message = $Message })
    }

    $modules = @(
        @{ Name = 'ActiveDirectory';                Source = 'ActiveDirectory'; Hint = 'Install RSAT: Active Directory tools' },
        @{ Name = 'Microsoft.Graph.Authentication'; Source = 'EntraID';         Hint = 'Install-Module Microsoft.Graph' },
        @{ Name = 'ExchangeOnlineManagement';       Source = 'ExchangeOnline';  Hint = 'Install-Module ExchangeOnlineManagement' }
    )
    foreach ($m in $modules) {
        if (-not (Test-ConsoleSource $m.Source)) { Add-Check $m.Name 'Disabled' "Sources.$($m.Source) is off in settings"; continue }
        $found = Get-Module -ListAvailable -Name $m.Name | Sort-Object Version -Descending | Select-Object -First 1
        if ($found) { Add-Check $m.Name 'Healthy' "v$($found.Version)" } else { Add-Check $m.Name 'Missing' $m.Hint }
    }

    if ((Test-ConsoleSource 'ActiveDirectory') -and (Get-Module -ListAvailable -Name ActiveDirectory)) {
        foreach ($k in 'DisabledUsersOU', 'DisabledComputersOU') {
            $ou = Get-ConsoleSetting $k ''
            if (-not $ou) { Add-Check $k 'Warning' 'Not set in Settings'; continue }
            try {
                Connect-ConsoleActiveDirectory
                Get-ADOrganizationalUnit -Identity $ou -ErrorAction Stop | Out-Null
                Add-Check $k 'Healthy' $ou
            }
            catch { Add-Check $k 'Error' "Not found in AD: $ou - fix it on the Settings tab" }
        }
        $sync = Get-ConsoleSetting 'EntraConnect.Server' ''
        if ($sync -and (Get-Command Test-WSMan -ErrorAction SilentlyContinue)) {
            try { Test-WSMan -ComputerName $sync -ErrorAction Stop | Out-Null; Add-Check 'Entra Connect server' 'Healthy' "$sync reachable over WinRM" }
            catch { Add-Check 'Entra Connect server' 'Warning' "$sync not reachable over WinRM: $($_.Exception.Message)" }
        }
    }

    try { Add-Check 'Database' 'Healthy' ("Schema v{0} at {1}" -f (Get-ConsoleSchemaVersion), (Get-ConsoleDatabasePath)) }
    catch { Add-Check 'Database' 'Error' $_.Exception.Message }

    $errs = @(Get-ConsolePluginErrors)
    if ($errs.Count) { Add-Check 'Plugins' 'Warning' "$($errs.Count) plugin file(s) failed to load - see the list below" }
    else { Add-Check 'Plugins' 'Healthy' ("{0} actions, {1} workflows, {2} reports" -f @(Get-ConsoleAction).Count, @(Get-ConsoleWorkflow).Count, @(Get-ConsoleReport).Count) }

    if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) {
        $ctx = Get-MgContext
        if ($ctx) { Add-Check 'Graph session' 'Healthy' "Connected ($($ctx.Account)$($ctx.AppName))" } else { Add-Check 'Graph session' 'Info' 'Not connected yet (connects on first use)' }
    }

    $pending = [int](Invoke-DbScalar "SELECT COUNT(*) FROM ApprovalRequests WHERE Status = 'Pending'")
    Add-Check 'Approvals' 'Info' "$pending pending"
    $failed = [int](Invoke-DbScalar "SELECT COUNT(*) FROM Notifications WHERE Status = 'Failed'")
    if ($failed) { Add-Check 'Notifications' 'Warning' "$failed notification(s) failed permanently" } else { Add-Check 'Notifications' 'Healthy' 'No failed notifications' }

    $now = Get-ConsoleNow
    foreach ($c in $checks) {
        Invoke-DbNonQuery 'INSERT INTO HealthChecks (CheckedOn, Component, Status, Message) VALUES (@d, @c, @s, @m)' @{ d = $now; c = $c.Component; s = $c.Status; m = $c.Message } | Out-Null
    }
    Invoke-DbNonQuery "DELETE FROM HealthChecks WHERE CheckedOn < @cut" @{ cut = (Get-Date).AddDays(-30).ToString('yyyy-MM-ddTHH:mm:ss') } | Out-Null
    $checks
}

function Invoke-ConsoleJobs {
    <#
    .SYNOPSIS  Runs background work. Called by Invoke-AdminJobs.ps1 and by the Automation page.
    #>
    param([ValidateSet('All', 'Schedules', 'Alerts', 'Notifications', 'Health')][string[]]$Job = 'All')
    $all = $Job -contains 'All'
    if ($all -or $Job -contains 'Schedules')     { $n = Invoke-DueSchedules;      Write-ConsoleLog "Schedules: ran $n due report(s)" }
    if ($all -or $Job -contains 'Alerts')        { $n = Invoke-ConsoleAlerts;     Write-ConsoleLog "Alerts: evaluated $n alert(s)" }
    if ($all -or $Job -contains 'Notifications') { $n = Send-ConsoleNotifications; Write-ConsoleLog "Notifications: sent $n" }
    if ($all -or $Job -contains 'Health')        { $r = Invoke-ConsoleHealthCheck; Write-ConsoleLog "Health: $(@($r | Where-Object { $_.Status -in 'Missing','Error','Warning' }).Count) issue(s)" }
}
