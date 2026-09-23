@{
    Name        = 'Operating System Summary'
    Description = 'Count of enabled computers per operating system and version - spot unsupported Windows versions.'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        Get-ADComputer -Filter 'Enabled -eq $true' -Properties OperatingSystem, OperatingSystemVersion, LastLogonDate |
            Group-Object OperatingSystem, OperatingSystemVersion |
            ForEach-Object {
                [pscustomobject]@{
                    OperatingSystem = $_.Group[0].OperatingSystem
                    Version         = $_.Group[0].OperatingSystemVersion
                    Computers       = $_.Count
                    ActiveLast30Days = @($_.Group | Where-Object { $_.LastLogonDate -gt (Get-Date).AddDays(-30) }).Count
                }
            } | Sort-Object Computers -Descending
    }
}
