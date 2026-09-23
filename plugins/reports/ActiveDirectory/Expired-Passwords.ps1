@{
    Name        = 'Expired Passwords'
    Description = 'Enabled users whose password has already expired.'
    RowType     = 'User'
    RowKey      = 'SamAccountName'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        Get-ADUser -Filter 'Enabled -eq $true' -Properties PasswordExpired, PasswordLastSet, LastLogonDate |
            Where-Object { $_.PasswordExpired } |
            Select-Object Name, SamAccountName, UserPrincipalName, PasswordLastSet, LastLogonDate
    }
}
