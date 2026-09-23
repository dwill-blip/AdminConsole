@{
    Name        = 'Stale Entra Devices'
    Description = 'Entra ID devices with no sign-in for N days.'
    Parameters  = @(@{ Name = 'Days'; Label = 'No sign-in for (days)'; Type = 'Number'; Default = 90; Required = $true })
    GraphScopes = @('Device.Read.All')
    RowType     = 'Computer'
    RowKey      = 'DisplayName'
    Run         = {
        param($Params)
        $cutoff = (Get-Date).AddDays(-[int]$Params.Days)
        Invoke-ConsoleGraph GET 'v1.0/devices?$top=999&$select=displayName,operatingSystem,operatingSystemVersion,trustType,accountEnabled,approximateLastSignInDateTime,registrationDateTime,isManaged,isCompliant' -All |
            Where-Object { -not $_.approximateLastSignInDateTime -or [datetime]$_.approximateLastSignInDateTime -lt $cutoff } |
            ForEach-Object {
                [pscustomobject]@{
                    DisplayName = $_.displayName; OS = "$($_.operatingSystem) $($_.operatingSystemVersion)"; TrustType = $_.trustType
                    Enabled = $_.accountEnabled; Managed = $_.isManaged; Compliant = $_.isCompliant
                    LastSignIn = $_.approximateLastSignInDateTime; DaysInactive = Get-ConsoleDaysSince $_.approximateLastSignInDateTime
                    Registered = $_.registrationDateTime
                }
            } | Sort-Object LastSignIn
    }
}
