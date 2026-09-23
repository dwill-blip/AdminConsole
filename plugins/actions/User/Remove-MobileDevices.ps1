@{
    Name      = 'Remove Mobile Devices'
    Scope     = 'User'
    Category  = 'Exchange Online'
    Order     = 20
    AppliesTo = { param($User) $User.UserPrincipalName -and (Test-ConsoleSource 'ExchangeOnline') }
    Check     = {
        param($User)
        Connect-ConsoleExchange
        $n = @(Get-MobileDevice -Mailbox $User.UserPrincipalName -ErrorAction Stop).Count
        @{ Done = ($n -eq 0); Detail = "$n mobile device(s)" }
    }
    Run       = {
        param($User)
        Connect-ConsoleExchange
        $devices = @(Get-MobileDevice -Mailbox $User.UserPrincipalName -ErrorAction Stop)
        $devices | Remove-MobileDevice -Confirm:$false -ErrorAction Stop
        "Removed $($devices.Count) mobile device partnership(s)."
    }
}
