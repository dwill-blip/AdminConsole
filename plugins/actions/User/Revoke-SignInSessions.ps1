@{
    Name        = 'Revoke Sign-in Sessions'
    Scope       = 'User'
    Category    = 'Entra ID'
    Order       = 10
    Permission  = 'RevokeSignInSessions'
    Description = 'Invalidates refresh tokens so the user is signed out of Microsoft 365 everywhere.'
    AppliesTo   = { param($User) [bool]$User.Entra }
    Check       = { param($User) @{ Done = $null; Detail = "Sessions valid from $($User.Entra.SignInSessionsValidFromDateTime) (UTC)" } }
    Run         = {
        param($User)
        Connect-ConsoleGraph
        Revoke-MgUserSignInSession -UserId $User.Entra.Id -ErrorAction Stop | Out-Null
    }
}
