@{
    Name        = 'Out of Office Enabled'
    Description = 'User mailboxes with automatic replies on or scheduled. Slow in big tenants.'
    RowType     = 'User'
    RowKey      = 'UserPrincipalName'
    Run         = {
        param($Params)
        Connect-ConsoleExchange
        Write-ConsoleProgress 'Listing mailboxes...'
        $boxes = @(Get-EXOMailbox -RecipientTypeDetails UserMailbox, SharedMailbox -ResultSize Unlimited)
        $i = 0
        foreach ($mb in $boxes) {
            $i++
            Write-ConsoleProgress "Reading automatic replies: $($mb.DisplayName)" $i $boxes.Count
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
