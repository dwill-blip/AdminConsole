#requires -Version 5.1
<#
.SYNOPSIS
    Headless runner for scheduled reports, alerts, notifications and health checks.
.DESCRIPTION
    Meant to be run by Windows Task Scheduler every 15 minutes. Register it with:
        .\Invoke-AdminJobs.ps1 -Register            (from an elevated PowerShell)
    For unattended Graph / Exchange access, configure certificate (app-only) auth in
    config\settings.json (Graph.ClientId / CertificateThumbprint / TenantId and
    Exchange.AppId / CertificateThumbprint / Organization).
.EXAMPLE
    .\Invoke-AdminJobs.ps1                  # everything that is due
.EXAMPLE
    .\Invoke-AdminJobs.ps1 -Job Alerts, Notifications
#>
[CmdletBinding()]
param(
    [ValidateSet('All', 'Schedules', 'Alerts', 'Notifications', 'Health')]
    [string[]]$Job = 'All',
    [switch]$Register,
    [int]$IntervalMinutes = 15,
    [string]$TaskName = 'AdminConsole Jobs'
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

if ($Register) {
    $cred = Get-Credential -Message "Account that '$TaskName' should run as. It needs the AD rights your reports use and access to the Graph/Exchange certificate."
    if (-not $cred) { Write-Warning 'Cancelled.'; return }
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -WorkingDirectory $Root
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1) -StartWhenAvailable
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -User $cred.UserName -Password $cred.GetNetworkCredential().Password -RunLevel Highest -Force | Out-Null
    Write-Host "Registered scheduled task '$TaskName' (every $IntervalMinutes minutes as $($cred.UserName))." -ForegroundColor Green
    return
}

# Files extracted from a downloaded zip are marked "from the internet"; Windows then
# refuses to load the bundled SQLite DLL. Clear the mark on our own folder.
if (Get-Command Unblock-File -ErrorAction SilentlyContinue) {
    Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
}

try {
    Import-Module (Join-Path $Root 'src\AdminConsole.Core\AdminConsole.Core.psm1') -Force
    Register-ConsoleLogSink { param($Line, $Level) Write-Host $Line }
    Register-ConsoleFileLog -Folder (Join-Path $Root 'logs')
    Initialize-AdminConsole -Root $Root
    Invoke-ConsoleJobs -Job $Job
}
catch {
    Write-Error "AdminConsole jobs failed: $($_.Exception.Message)`n$($_.ScriptStackTrace)" -ErrorAction Continue
    exit 1
}
finally {
    if (Get-Command Close-ConsoleDatabase -ErrorAction SilentlyContinue) { Close-ConsoleDatabase }
}
