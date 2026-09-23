@{
    Name        = 'Accounts Expiring Soon'
    Description = 'Accounts with an expiry date in the next N days (contractors, temps).'
    Parameters  = @(@{ Name = 'Days'; Label = 'Expiring within (days)'; Type = 'Number'; Default = 30 })
    RowType     = 'User'
    RowKey      = 'SamAccountName'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        Search-ADAccount -AccountExpiring -UsersOnly -TimeSpan (New-TimeSpan -Days ([int]$Params.Days)) |
            Select-Object Name, SamAccountName, UserPrincipalName, Enabled, AccountExpirationDate |
            Sort-Object AccountExpirationDate
    }
}
