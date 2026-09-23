@{
    Name        = 'Stale Computers'
    Description = 'Enabled computer accounts that have not logged on for N days - candidates for Decommission Computer.'
    Parameters  = @(@{ Name = 'Days'; Label = 'No logon for (days)'; Type = 'Number'; Default = 90; Required = $true })
    RowType     = 'Computer'
    RowKey      = 'Name'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        $cutoff = (Get-Date).AddDays(-[int]$Params.Days)
        Get-ADComputer -Filter 'Enabled -eq $true' -Properties LastLogonDate, OperatingSystem, whenCreated, Description |
            Where-Object { -not $_.LastLogonDate -or $_.LastLogonDate -lt $cutoff } |
            Sort-Object LastLogonDate |
            Select-Object Name, OperatingSystem, LastLogonDate,
                @{ n = 'DaysInactive'; e = { if ($_.LastLogonDate) { [int]((Get-Date) - $_.LastLogonDate).TotalDays } } },
                whenCreated, Description, DistinguishedName
    }
}
