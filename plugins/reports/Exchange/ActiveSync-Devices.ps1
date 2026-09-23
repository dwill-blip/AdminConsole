@{
    Name        = 'ActiveSync Devices'
    Description = 'Exchange Online mobile device partnerships.'
    RowActions  = @('Remove ActiveSync Device')
    Run         = {
        param($Params)
        Connect-ConsoleExchange
        Get-MobileDevice -ResultSize Unlimited -ErrorAction Stop |
            Select-Object UserDisplayName, Identity, DeviceType, DeviceModel, DeviceOS, DeviceAccessState, FirstSyncTime
    }
}
