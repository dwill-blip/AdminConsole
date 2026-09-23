# Verifies out-of-office is off, and turns it off if it is not.
@{
    Name        = 'Disable Out of Office'
    Scope       = 'User'
    Category    = 'Exchange Online'
    Order       = 40
    Permission  = 'DisableAutoReply'
    Description = 'Checks the automatic-reply (out of office) setting and turns it off if it is on or scheduled.'
    Confirm     = $false
    AppliesTo   = { param($User) $User.UserPrincipalName -and (Test-ConsoleSource 'ExchangeOnline') }
    Check       = {
        param($User)
        Connect-ConsoleExchange
        $state = (Get-MailboxAutoReplyConfiguration -Identity $User.UserPrincipalName -ErrorAction Stop).AutoReplyState
        @{ Done = ("$state" -eq 'Disabled'); Detail = "Out of office: $state" }
    }
    Run         = {
        param($User)
        Connect-ConsoleExchange
        $before = (Get-MailboxAutoReplyConfiguration -Identity $User.UserPrincipalName -ErrorAction Stop).AutoReplyState
        if ("$before" -eq 'Disabled') { return 'Out of office was already disabled.' }
        Set-MailboxAutoReplyConfiguration -Identity $User.UserPrincipalName -AutoReplyState Disabled -ErrorAction Stop
        $after = (Get-MailboxAutoReplyConfiguration -Identity $User.UserPrincipalName -ErrorAction Stop).AutoReplyState
        if ("$after" -ne 'Disabled') { throw "Out of office is still '$after' after trying to disable it." }
        "Out of office was '$before'; now Disabled (verified)."
    }
}
