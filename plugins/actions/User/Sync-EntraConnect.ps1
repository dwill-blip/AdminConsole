# Runs a delta sync on the Entra Connect server (Settings: EntraConnect.Server, default sm-adfs01)
# and waits for it to finish (EntraConnect.WaitSeconds, default 300), so the next steps see
# the change in the cloud. Needs WinRM + admin rights on that server.
@{
    Name        = 'Run Entra Connect Sync'
    Scope       = 'User'
    Category    = 'Entra ID'
    Order       = 5
    Permission  = 'RunEntraConnectSync'
    Description = 'Start-ADSyncSyncCycle -PolicyType Delta on the Entra Connect server, then wait for it to finish.'
    Confirm     = $false
    AppliesTo   = { param($User) [bool]$User.AD }
    Run         = { param($User) Invoke-ConsoleEntraConnectSync }
}
