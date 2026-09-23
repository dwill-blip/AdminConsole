@{
    Name        = 'Shared Mailboxes'
    Description = 'Every shared mailbox, and whether its sign-in is blocked (it should be).'
    Run         = {
        param($Params)
        Connect-ConsoleExchange
        $users = @{}
        Get-User -RecipientTypeDetails SharedMailbox -ResultSize Unlimited | ForEach-Object { $users[$_.UserPrincipalName] = $_ }
        Get-EXOMailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited -Properties GrantSendOnBehalfTo, WhenCreated, HiddenFromAddressListsEnabled |
            ForEach-Object {
                $u = $users[$_.UserPrincipalName]
                [pscustomobject]@{
                    DisplayName = $_.DisplayName; PrimarySmtpAddress = $_.PrimarySmtpAddress
                    SignInBlocked = $(if ($u) { $u.AccountDisabled }); HiddenFromGAL = $_.HiddenFromAddressListsEnabled
                    SendOnBehalf = @($_.GrantSendOnBehalfTo) -join ', '; Created = $_.WhenCreated
                }
            }
    }
}
