@{
    Name      = 'Remove Inbox Rules'
    Scope     = 'User'
    Category  = 'Exchange Online'
    Order     = 30
    AppliesTo = { param($User) $User.UserPrincipalName -and (Test-ConsoleSource 'ExchangeOnline') }
    Check     = {
        param($User)
        Connect-ConsoleExchange
        $n = @(Get-InboxRule -Mailbox $User.UserPrincipalName -ErrorAction Stop).Count
        @{ Done = ($n -eq 0); Detail = "$n inbox rule(s)" }
    }
    Run       = {
        param($User)
        Connect-ConsoleExchange
        $rules = @(Get-InboxRule -Mailbox $User.UserPrincipalName -ErrorAction Stop)
        $rules | Remove-InboxRule -Confirm:$false -ErrorAction Stop
        "Removed $($rules.Count) inbox rule(s)."
    }
}
