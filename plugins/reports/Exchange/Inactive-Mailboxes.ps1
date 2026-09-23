@{
    Name        = 'Inactive Mailboxes'
    Description = 'Mailboxes kept after the user was deleted (litigation hold / retention).'
    Run         = {
        param($Params)
        Connect-ConsoleExchange
        Get-EXOMailbox -InactiveMailboxOnly -ResultSize Unlimited -Properties WhenSoftDeleted, LitigationHoldEnabled, InPlaceHolds |
            Select-Object DisplayName, PrimarySmtpAddress, WhenSoftDeleted, LitigationHoldEnabled, @{ n = 'Holds'; e = { @($_.InPlaceHolds).Count } }
    }
}
