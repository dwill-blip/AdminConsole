@{
    Name        = 'Admins Without MFA'
    Description = 'Accounts with an admin role that have not registered MFA - highest-priority fix.'
    GraphScopes = @('AuditLog.Read.All', 'Reports.Read.All')
    RowType     = 'User'
    RowKey      = 'UserPrincipalName'
    Run         = {
        param($Params)
        Invoke-ConsoleGraph GET 'v1.0/reports/authenticationMethods/userRegistrationDetails?$top=999' -All |
            Where-Object { $_.isAdmin -and -not $_.isMfaRegistered } |
            ForEach-Object {
                [pscustomobject]@{
                    DisplayName = $_.userDisplayName; UserPrincipalName = $_.userPrincipalName
                    MfaCapable = $_.isMfaCapable; MethodsRegistered = @($_.methodsRegistered) -join ', '
                }
            }
    }
}
