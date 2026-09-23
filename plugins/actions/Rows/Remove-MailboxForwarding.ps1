# Row action: used by the "Mailbox Forwarding" report.
@{
    Name       = 'Remove Mailbox Forwarding'
    Scope      = 'Row'
    Category   = 'Exchange Online'
    TargetName = { param($Row) $Row.UserPrincipalName }
    Run        = {
        param($Row)
        Connect-ConsoleExchange
        Set-Mailbox -Identity $Row.UserPrincipalName -ForwardingAddress $null -ForwardingSmtpAddress $null -DeliverToMailboxAndForward $false -ErrorAction Stop
    }
}
