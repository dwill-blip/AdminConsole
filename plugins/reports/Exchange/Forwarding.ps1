@{
    Name        = 'Mailbox Forwarding'
    Description = 'Mailboxes that forward mail - a common sign of compromise.'
    RowType     = 'User'
    RowKey      = 'UserPrincipalName'
    RowActions  = @('Remove Mailbox Forwarding')
    Run         = {
        param($Params)
        Connect-ConsoleExchange
        Get-Mailbox -ResultSize Unlimited -ErrorAction Stop |
            Where-Object { $_.ForwardingAddress -or $_.ForwardingSmtpAddress } |
            Select-Object DisplayName, UserPrincipalName, ForwardingAddress, ForwardingSmtpAddress, DeliverToMailboxAndForward
    }
}
