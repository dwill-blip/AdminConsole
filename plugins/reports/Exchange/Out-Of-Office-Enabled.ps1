@{
    Name        = 'Out of Office Enabled'
    Description = 'User mailboxes with automatic replies on or scheduled. Slow in big tenants.'
    RowType     = 'User'
    RowKey      = 'UserPrincipalName'
    Run         = {
        param($Params)
        Connect-ConsoleExchange
        foreach ($mb in @(Get-EXOMailbox -RecipientTypeDetails UserMailbox, SharedMailbox -ResultSize Unlimited)) {
            $c = Get-MailboxAutoReplyConfiguration -Identity $mb.ExternalDirectoryObjectId -ErrorAction SilentlyContinue
            if ($c -and "$($c.AutoReplyState)" -ne 'Disabled') {
                [pscustomobject]@{
                    DisplayName = $mb.DisplayName; UserPrincipalName = $mb.UserPrincipalName; State = $c.AutoReplyState
                    Start = $(if ("$($c.AutoReplyState)" -eq 'Scheduled') { $c.StartTime }); End = $(if ("$($c.AutoReplyState)" -eq 'Scheduled') { $c.EndTime })
                    ExternalAudience = $c.ExternalAudience
                }
            }
        }
    }
}
