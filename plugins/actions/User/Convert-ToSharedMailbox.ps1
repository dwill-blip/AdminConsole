@{
    Name             = 'Convert to Shared Mailbox'
    Scope            = 'User'
    Category         = 'Exchange Online'
    Order            = 50
    Danger           = $true
    RequiresApproval = $true
    AppliesTo        = { param($User) $User.UserPrincipalName -and (Test-ConsoleSource 'ExchangeOnline') }
    Check            = {
        param($User)
        Connect-ConsoleExchange
        $t = (Get-Mailbox -Identity $User.UserPrincipalName -ErrorAction Stop).RecipientTypeDetails
        @{ Done = ("$t" -eq 'SharedMailbox'); Detail = "Mailbox type: $t" }
    }
    Run              = {
        param($User)
        Connect-ConsoleExchange
        Set-Mailbox -Identity $User.UserPrincipalName -Type Shared -ErrorAction Stop
    }
}
