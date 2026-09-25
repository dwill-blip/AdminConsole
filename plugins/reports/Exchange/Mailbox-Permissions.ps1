@{
    Name        = 'Mailbox Permissions'
    Description = 'Full Access and Send As permissions granted to other people. Leave Mailbox blank for all mailboxes: Full Access is read one mailbox at a time, so that takes a while in big tenants (a progress window with Cancel is shown).'
    Parameters  = @(
        @{ Name = 'Mailbox'; Label = 'Mailbox (blank = all)' }
        @{ Name = 'Type'; Label = 'Mailbox type'; Type = 'Choice'; Choices = @('All', 'SharedMailbox', 'UserMailbox', 'RoomMailbox', 'EquipmentMailbox'); Default = 'All' }
        @{ Name = 'Permission'; Label = 'Permission'; Type = 'Choice'; Choices = @('Both', 'Full Access', 'Send As'); Default = 'Both'
            Help = 'Send As alone is quick even for every mailbox.' }
    )
    Run         = {
        param($Params)
        Connect-ConsoleExchange
        $wantFull = $Params.Permission -ne 'Send As'
        $wantSendAs = $Params.Permission -ne 'Full Access'

        Write-ConsoleProgress 'Listing mailboxes...'
        if ($Params.Mailbox) { $boxes = @(Get-EXOMailbox -Identity $Params.Mailbox) }
        else {
            $p = @{ ResultSize = 'Unlimited' }
            if ($Params.Type -and $Params.Type -ne 'All') { $p.RecipientTypeDetails = $Params.Type }
            $boxes = @(Get-EXOMailbox @p)
        }
        if (-not $boxes.Count) { return }

        if ($wantSendAs) {
            if ($boxes.Count -eq 1) {
                $sendAs = @(Get-EXORecipientPermission -Identity $boxes[0].ExternalDirectoryObjectId -ErrorAction SilentlyContinue)
            }
            else {
                # One call for the whole tenant instead of one per mailbox.
                Write-ConsoleProgress 'Reading Send As permissions...'
                $sendAs = @(Get-EXORecipientPermission -ResultSize Unlimited -ErrorAction SilentlyContinue)
            }
            # Send As entries name the mailbox by its Identity / Name.
            $lookup = @{}
            foreach ($mb in $boxes) { foreach ($k in @($mb.Identity, $mb.Name, $mb.Alias, $mb.DisplayName, $mb.PrimarySmtpAddress, $mb.ExternalDirectoryObjectId)) { if ($k) { $lookup["$k"] = $mb } } }
            $showOthers = -not $Params.Mailbox -and (-not $Params.Type -or $Params.Type -eq 'All')
            foreach ($e in $sendAs) {
                if ($e.Trustee -like 'NT AUTHORITY\*' -or $e.Trustee -like 'S-1-5-*' -or $e.AccessControlType -ne 'Allow') { continue }
                $mb = if ($boxes.Count -eq 1) { $boxes[0] } else { $lookup["$($e.Identity)"] }
                if ($mb) {
                    [pscustomobject]@{ Mailbox = $mb.DisplayName; MailboxAddress = $mb.PrimarySmtpAddress; Type = $mb.RecipientTypeDetails; Permission = 'SendAs'; GrantedTo = $e.Trustee }
                }
                elseif ($showOthers) {
                    # Not one of the listed mailboxes - usually a group. Shown so nothing is hidden.
                    [pscustomobject]@{ Mailbox = "$($e.Identity)"; MailboxAddress = $null; Type = 'Other recipient'; Permission = 'SendAs'; GrantedTo = $e.Trustee }
                }
            }
        }

        if ($wantFull) {
            $i = 0
            foreach ($mb in $boxes) {
                $i++
                Write-ConsoleProgress "Reading Full Access: $($mb.DisplayName)" $i $boxes.Count
                Get-EXOMailboxPermission -Identity $mb.ExternalDirectoryObjectId -ErrorAction SilentlyContinue |
                    Where-Object { $_.User -notlike 'NT AUTHORITY\*' -and $_.User -notlike 'S-1-5-*' -and -not $_.IsInherited -and -not $_.Deny } |
                    ForEach-Object {
                        [pscustomobject]@{ Mailbox = $mb.DisplayName; MailboxAddress = $mb.PrimarySmtpAddress; Type = $mb.RecipientTypeDetails; Permission = ($_.AccessRights -join ', '); GrantedTo = $_.User }
                    }
            }
        }
    }
}
