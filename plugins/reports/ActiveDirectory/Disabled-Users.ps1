@{
    Name        = 'Disabled Users'
    Description = 'All disabled user accounts, with where they live and when they last changed.'
    RowType     = 'User'
    RowKey      = 'SamAccountName'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        Get-ADUser -Filter 'Enabled -eq $false' -Properties LastLogonDate, whenChanged, Office, MemberOf |
            Select-Object Name, SamAccountName, UserPrincipalName, Office, LastLogonDate, whenChanged,
                @{ n = 'GroupCount'; e = { @($_.MemberOf).Count } }, DistinguishedName
    }
}
