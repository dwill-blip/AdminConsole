@{
    Name        = 'Users Without MFA'
    Description = 'Enabled members who have not registered any MFA method.'
    GraphScopes = @('AuditLog.Read.All', 'Reports.Read.All')
    RowType     = 'User'
    RowKey      = 'UserPrincipalName'
    Run         = {
        param($Params)
        Invoke-ConsoleGraph GET 'v1.0/reports/authenticationMethods/userRegistrationDetails?$top=999' -All |
            Where-Object { -not $_.isMfaRegistered -and $_.userType -ne 'guest' } |
            ForEach-Object {
                [pscustomobject]@{
                    DisplayName = $_.userDisplayName; UserPrincipalName = $_.userPrincipalName; IsAdmin = $_.isAdmin
                    SsprRegistered = $_.isSsprRegistered; MethodsRegistered = @($_.methodsRegistered) -join ', '
                }
            }
    }
}
