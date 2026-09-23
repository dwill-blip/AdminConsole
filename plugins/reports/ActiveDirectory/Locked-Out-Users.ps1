@{
    Name        = 'Locked Out Users'
    Description = 'Accounts currently locked out. Right-click a row to unlock.'
    RowType     = 'User'
    RowKey      = 'SamAccountName'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        Search-ADAccount -LockedOut -UsersOnly |
            ForEach-Object { Get-ADUser $_.DistinguishedName -Properties LockoutTime, BadLogonCount, LastBadPasswordAttempt } |
            Select-Object Name, SamAccountName, UserPrincipalName,
                @{ n = 'LockedOutAt'; e = { if ($_.LockoutTime) { [datetime]::FromFileTime($_.LockoutTime) } } },
                BadLogonCount, LastBadPasswordAttempt
    }
}
