@{
    Name        = 'Mailbox Sizes'
    Description = 'Size and item count of every mailbox, largest first. Can take several minutes in big tenants.'
    Parameters  = @(@{ Name = 'Type'; Label = 'Mailbox type'; Type = 'Choice'; Choices = @('All', 'UserMailbox', 'SharedMailbox', 'RoomMailbox', 'EquipmentMailbox'); Default = 'All' })
    RowType     = 'User'
    RowKey      = 'UserPrincipalName'
    Run         = {
        param($Params)
        Connect-ConsoleExchange
        $p = @{ ResultSize = 'Unlimited'; Properties = 'ProhibitSendQuota' }
        if ($Params.Type -ne 'All') { $p.RecipientTypeDetails = $Params.Type }
        foreach ($mb in @(Get-EXOMailbox @p)) {
            $s = Get-EXOMailboxStatistics -Identity $mb.ExternalDirectoryObjectId -ErrorAction SilentlyContinue
            $bytes = ConvertTo-ConsoleBytes $s.TotalItemSize
            $quota = ConvertTo-ConsoleBytes $mb.ProhibitSendQuota
            [pscustomobject]@{
                DisplayName = $mb.DisplayName; UserPrincipalName = $mb.UserPrincipalName; Type = $mb.RecipientTypeDetails
                SizeGB = $(if ($null -ne $bytes) { [math]::Round($bytes / 1GB, 2) }); Items = $s.ItemCount
                QuotaGB = $(if ($quota) { [math]::Round($quota / 1GB, 1) })
                PercentOfQuota = $(if ($quota -and $null -ne $bytes) { [math]::Round(100 * $bytes / $quota) })
            }
        }
    }
}
