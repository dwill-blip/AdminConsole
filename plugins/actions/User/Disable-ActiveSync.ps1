@{
    Name      = 'Disable ActiveSync'
    Scope     = 'User'
    Category  = 'Exchange Online'
    Order     = 10
    AppliesTo = { param($User) $User.UserPrincipalName -and (Test-ConsoleSource 'ExchangeOnline') }
    Check     = {
        param($User)
        Connect-ConsoleExchange
        $on = (Get-CASMailbox -Identity $User.UserPrincipalName -ErrorAction Stop).ActiveSyncEnabled
        @{ Done = -not $on; Detail = "ActiveSync enabled: $on" }
    }
    Run       = {
        param($User)
        Connect-ConsoleExchange
        Set-CASMailbox -Identity $User.UserPrincipalName -ActiveSyncEnabled $false -ErrorAction Stop
    }
}
