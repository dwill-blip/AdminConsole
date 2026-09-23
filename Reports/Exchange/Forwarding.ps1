# ReportName: Mailbox Forwarding
# Description: Mailboxes with forwarding.
# ActionType: MailboxForwarding
Ensure-EXO;Get-Mailbox -ResultSize Unlimited|?{$_.ForwardingAddress -or $_.ForwardingSmtpAddress}|select DisplayName,UserPrincipalName,ForwardingAddress,ForwardingSmtpAddress
