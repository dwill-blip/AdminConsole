@{
    Name        = 'Guest Users'
    Description = 'External (guest) accounts with invite state and last sign-in. Sign-in dates need Entra ID P1.'
    GraphScopes = @('User.Read.All', 'AuditLog.Read.All')
    RowType     = 'User'
    RowKey      = 'UserPrincipalName'
    Run         = {
        param($Params)
        Get-ConsoleGraphUsers -Filter "userType eq 'Guest'" -Select id, displayName, mail, userPrincipalName, createdDateTime, externalUserState, accountEnabled -SignInActivity |
            ForEach-Object {
                $last = Get-ConsoleLastSignIn $_
                [pscustomobject]@{
                    DisplayName = $_.displayName; Mail = $_.mail; UserPrincipalName = $_.userPrincipalName
                    InviteState = $_.externalUserState; Enabled = $_.accountEnabled; Created = $_.createdDateTime
                    LastSignIn = $last; DaysSinceSignIn = Get-ConsoleDaysSince $last
                }
            } | Sort-Object LastSignIn
    }
}
