@{
    Name        = 'Entra Devices'
    Description = 'All Entra ID device objects.'
    RowType     = 'Computer'
    RowKey      = 'DisplayName'
    Run         = {
        param($Params)
        Connect-ConsoleGraph
        Get-MgDevice -All -ErrorAction Stop |
            Select-Object DisplayName, OperatingSystem, OperatingSystemVersion, TrustType, AccountEnabled, ApproximateLastSignInDateTime, @{ n = 'ObjectId'; e = { $_.Id } }, DeviceId
    }
}
