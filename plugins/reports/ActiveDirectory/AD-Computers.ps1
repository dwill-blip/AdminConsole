@{
    Name        = 'AD Computers'
    Description = 'Active Directory computer inventory.'
    RowType     = 'Computer'
    RowKey      = 'Name'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        Get-ADComputer -Filter * -Properties OperatingSystem, Enabled, LastLogonDate |
            Select-Object Name, OperatingSystem, Enabled, LastLogonDate, DistinguishedName
    }
}
