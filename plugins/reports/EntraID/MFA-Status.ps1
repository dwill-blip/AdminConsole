@{
    Name        = 'MFA Registration Status'
    Description = 'Per-user MFA registration (needs Reports.Read.All / AuditLog.Read.All).'
    RowType     = 'User'
    RowKey      = 'UserPrincipalName'
    Run         = {
        param($Params)
        Connect-ConsoleGraph
        Get-MgReportAuthenticationMethodUserRegistrationDetail -All -ErrorAction Stop |
            Select-Object UserDisplayName, UserPrincipalName, IsMfaRegistered, IsMfaCapable, IsAdmin, MethodsRegistered
    }
}
