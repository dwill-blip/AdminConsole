@{
    Name        = 'Distribution Groups'
    Description = 'Distribution lists, owners, and whether outside senders can mail them.'
    Run         = {
        param($Params)
        Connect-ConsoleExchange
        Get-DistributionGroup -ResultSize Unlimited |
            Select-Object DisplayName, PrimarySmtpAddress, RecipientTypeDetails,
                @{ n = 'Owners'; e = { @($_.ManagedBy) -join ', ' } },
                @{ n = 'ExternalSendersAllowed'; e = { -not $_.RequireSenderAuthenticationEnabled } },
                MemberJoinRestriction, @{ n = 'SyncedFromAD'; e = { $_.IsDirSynced } }, HiddenFromAddressListsEnabled
    }
}
