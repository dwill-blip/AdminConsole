@{
    Name        = 'Password Never Expires'
    Description = 'Enabled users whose password is set to never expire.'
    RowType     = 'User'
    RowKey      = 'SamAccountName'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        Get-ADUser -Filter 'Enabled -eq $true -and PasswordNeverExpires -eq $true' -Properties PasswordLastSet, LastLogonDate, Description |
            Select-Object Name, SamAccountName, UserPrincipalName, PasswordLastSet, LastLogonDate, Description, DistinguishedName
    }
}
