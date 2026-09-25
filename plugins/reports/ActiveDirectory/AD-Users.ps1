@{
    Name        = 'AD Users'
    Description = 'All Active Directory users. Right-click a row > Change Manager to update the manager.'
    RowType     = 'User'
    RowKey      = 'SamAccountName'
    RowActions  = @('Change Manager')
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        Get-ADUser -Filter * -Properties Enabled, Department, Title, Office, LastLogonDate, LockedOut, Manager |
            Select-Object DisplayName, SamAccountName, UserPrincipalName, Enabled, LockedOut, Department, Title, Office,
                @{ n = 'Manager'; e = { ConvertFrom-ConsoleDn $_.Manager } }, LastLogonDate, DistinguishedName
    }
}
