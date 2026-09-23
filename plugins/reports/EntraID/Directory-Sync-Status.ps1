@{
    Name        = 'Directory Sync Status'
    Description = 'When Entra Connect last synced, and whether that is overdue (normal cycle is every 30 minutes).'
    GraphScopes = @('Organization.Read.All')
    Run         = {
        param($Params)
        $org = @(Invoke-ConsoleGraph GET 'v1.0/organization?$select=displayName,onPremisesSyncEnabled,onPremisesLastSyncDateTime,onPremisesLastPasswordSyncDateTime' -All)[0]
        $last = $org.onPremisesLastSyncDateTime
        $mins = $null
        if ($last) { $mins = [int]((Get-Date).ToUniversalTime() - ([datetime]$last).ToUniversalTime()).TotalMinutes }
        [pscustomobject]@{
            Tenant             = $org.displayName
            SyncEnabled        = $org.onPremisesSyncEnabled
            LastSync           = $last
            MinutesAgo         = $mins
            LastPasswordSync   = $org.onPremisesLastPasswordSyncDateTime
            Status             = $(if ($null -eq $mins) { 'Unknown' } elseif ($mins -le 45) { 'Healthy' } elseif ($mins -le 180) { 'Warning' } else { 'Error' })
        }
    }
}
