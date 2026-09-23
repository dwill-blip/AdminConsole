# Entra Connect (Azure AD Connect) sync, run on the sync server over PowerShell remoting.

function Invoke-ConsoleEntraConnectSync {
    <#
    .SYNOPSIS  Starts a sync cycle on the Entra Connect server and (optionally) waits for it to finish.
    .NOTES     Needs WinRM access and local admin (or ADSyncOperators) on the server.
               If a cycle is already running it waits for that one first.
    #>
    param(
        [string]$Server = (Get-ConsoleSetting 'EntraConnect.Server' 'sm-adfs01'),
        [ValidateSet('Delta', 'Initial')][string]$PolicyType = 'Delta',
        [int]$TimeoutSeconds = [int](Get-ConsoleSetting 'EntraConnect.WaitSeconds' 300)
    )
    if (-not $Server) { throw 'EntraConnect.Server is not set in Settings.' }
    $work = {
        param($Policy, $Timeout)
        $ErrorActionPreference = 'Stop'
        Import-Module ADSync
        $deadline = (Get-Date).AddSeconds($Timeout)
        while ((Get-ADSyncScheduler).SyncCycleInProgress -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 5 }
        $result = $null
        for ($try = 1; $try -le 6 -and -not $result; $try++) {
            try { $result = Start-ADSyncSyncCycle -PolicyType $Policy }
            catch {
                if ($_.Exception.Message -match 'busy|in progress' -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 10 } else { throw }
            }
        }
        $started = Get-Date
        if ($Timeout -gt 0) {
            Start-Sleep -Seconds 5
            while ((Get-ADSyncScheduler).SyncCycleInProgress -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 5 }
        }
        [pscustomobject]@{
            Result       = [string]$result.Result
            StillRunning = [bool](Get-ADSyncScheduler).SyncCycleInProgress
            Seconds      = [int]((Get-Date) - $started).TotalSeconds
        }
    }
    $short = $Server.Split('.')[0]
    if ($short -eq $env:COMPUTERNAME) { $r = & $work $PolicyType $TimeoutSeconds }
    else { $r = Invoke-Command -ComputerName $Server -ScriptBlock $work -ArgumentList $PolicyType, $TimeoutSeconds -ErrorAction Stop }
    if ($r.Result -and $r.Result -ne 'Success') { throw "Start-ADSyncSyncCycle on $Server returned '$($r.Result)'." }
    if ($r.StillRunning) { return "$PolicyType sync started on $Server; still running after $TimeoutSeconds s (it will finish on its own)." }
    "$PolicyType sync on $Server completed in $($r.Seconds) s."
}
