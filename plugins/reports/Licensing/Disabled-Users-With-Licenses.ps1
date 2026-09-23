@{
    Name        = 'Disabled Users With Licenses'
    Description = 'Disabled accounts that still use a license. (Shared mailboxes under 50 GB need no license.)'
    GraphScopes = @('User.Read.All', 'Organization.Read.All')
    RowType     = 'User'
    RowKey      = 'UserPrincipalName'
    Run         = {
        param($Params)
        $skus = @{}
        Invoke-ConsoleGraph GET 'v1.0/subscribedSkus' -All | ForEach-Object { $skus[[string]$_.skuId] = $_.skuPartNumber }
        Get-ConsoleGraphUsers -Filter 'accountEnabled eq false' -Select displayName, userPrincipalName, assignedLicenses, licenseAssignmentStates, onPremisesSyncEnabled |
            Where-Object { @($_.assignedLicenses).Count -gt 0 } |
            ForEach-Object {
                [pscustomobject]@{
                    DisplayName       = $_.displayName
                    UserPrincipalName = $_.userPrincipalName
                    Licenses          = (@($_.assignedLicenses) | ForEach-Object { $skus[[string]$_.skuId] }) -join ', '
                    ViaGroup          = @($_.licenseAssignmentStates | Where-Object { $_.assignedByGroup }).Count
                    SyncedFromAD      = [bool]$_.onPremisesSyncEnabled
                }
            }
    }
}
