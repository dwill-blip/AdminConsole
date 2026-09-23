@{
    Name        = 'Mailbox Permissions'
    Description = 'Full Access and Send As permissions granted to other people. Leave Mailbox blank for all mailboxes (slow in big tenants).'
    Parameters  = @(@{ Name = 'Mailbox'; Label = 'Mailbox (blank = all)' })
    Run         = {
        param($Params)
        Connect-ConsoleExchange
        if ($Params.Mailbox) { $boxes = @(Get-EXOMailbox -Identity $Params.Mailbox) }
        else { $boxes = @(Get-EXOMailbox -ResultSize Unlimited) }
        foreach ($mb in $boxes) {
            Get-EXOMailboxPermission -Identity $mb.ExternalDirectoryObjectId -ErrorAction SilentlyContinue |
                Where-Object { $_.User -notlike 'NT AUTHORITY\*' -and $_.User -notlike 'S-1-5-*' -and -not $_.IsInherited -and -not $_.Deny } |
                ForEach-Object {
                    [pscustomobject]@{ Mailbox = $mb.DisplayName; MailboxAddress = $mb.PrimarySmtpAddress; Type = $mb.RecipientTypeDetails; Permission = ($_.AccessRights -join ', '); GrantedTo = $_.User }
                }
            Get-EXORecipientPermission -Identity $mb.ExternalDirectoryObjectId -ErrorAction SilentlyContinue |
                Where-Object { $_.Trustee -notlike 'NT AUTHORITY\*' -and $_.AccessControlType -eq 'Allow' } |
                ForEach-Object {
                    [pscustomobject]@{ Mailbox = $mb.DisplayName; MailboxAddress = $mb.PrimarySmtpAddress; Type = $mb.RecipientTypeDetails; Permission = 'SendAs'; GrantedTo = $_.Trustee }
                }
        }
    }
}
