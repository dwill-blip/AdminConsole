@{
    Name        = 'Inactive Microsoft 365 Users'
    Description = 'Enabled accounts with no sign-in for N days (interactive or not). Needs Entra ID P1 for sign-in data.'
    Parameters  = @(
        @{ Name = 'Days'; Label = 'No sign-in for (days)'; Type = 'Number'; Default = 90; Required = $true }
        @{ Name = 'IncludeGuests'; Label = 'Include guests'; Type = 'Bool'; Default = $false }
    )
    GraphScopes = @('User.Read.All', 'AuditLog.Read.All')
    RowType     = 'User'
    RowKey      = 'UserPrincipalName'
    Run         = {
        param($Params)
        $filter = 'accountEnabled eq true'
        if (-not $Params.IncludeGuests) { $filter += " and userType eq 'Member'" }
        $cutoff = (Get-Date).AddDays(-[int]$Params.Days)
        Get-ConsoleGraphUsers -Filter $filter -Select id, displayName, userPrincipalName, userType, createdDateTime, assignedLicenses, onPremisesSyncEnabled -SignInActivity |
            ForEach-Object {
                $last = Get-ConsoleLastSignIn $_
                if ((-not $last -and [datetime]$_.createdDateTime -lt $cutoff) -or ($last -and $last -lt $cutoff)) {
                    [pscustomobject]@{
                        DisplayName = $_.displayName; UserPrincipalName = $_.userPrincipalName; Type = $_.userType
                        Licensed = (@($_.assignedLicenses).Count -gt 0); SyncedFromAD = [bool]$_.onPremisesSyncEnabled
                        Created = $_.createdDateTime; LastSignIn = $last; DaysSinceSignIn = Get-ConsoleDaysSince $last
                    }
                }
            } | Sort-Object LastSignIn
    }
}
