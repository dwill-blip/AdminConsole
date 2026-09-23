@{
    Name        = 'Recently Created Microsoft 365 Users'
    Parameters  = @(@{ Name = 'Days'; Label = 'Created in the last (days)'; Type = 'Number'; Default = 30 })
    GraphScopes = @('User.Read.All')
    RowType     = 'User'
    RowKey      = 'UserPrincipalName'
    Run         = {
        param($Params)
        $since = (Get-Date).AddDays(-[int]$Params.Days).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        Get-ConsoleGraphUsers -Filter "createdDateTime ge $since" -Select displayName, userPrincipalName, userType, createdDateTime, accountEnabled, onPremisesSyncEnabled, department |
            Sort-Object createdDateTime -Descending |
            Select-Object @{ n = 'DisplayName'; e = { $_.displayName } }, @{ n = 'UserPrincipalName'; e = { $_.userPrincipalName } },
                @{ n = 'Type'; e = { $_.userType } }, @{ n = 'Enabled'; e = { $_.accountEnabled } },
                @{ n = 'SyncedFromAD'; e = { [bool]$_.onPremisesSyncEnabled } }, @{ n = 'Department'; e = { $_.department } },
                @{ n = 'Created'; e = { $_.createdDateTime } }
    }
}
