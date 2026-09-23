@{
    Name        = 'AD Users'
    Description = 'All Active Directory users.'
    RowType     = 'User'
    RowKey      = 'SamAccountName'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        Get-ADUser -Filter * -Properties Enabled, Department, Office, LastLogonDate, LockedOut |
            Select-Object DisplayName, SamAccountName, UserPrincipalName, Enabled, LockedOut, Department, Office, LastLogonDate, DistinguishedName
    }
}
