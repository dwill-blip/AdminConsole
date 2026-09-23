@{
    Name        = 'Recently Created AD Users'
    Parameters  = @(@{ Name = 'Days'; Label = 'Created in the last (days)'; Type = 'Number'; Default = 30 })
    RowType     = 'User'
    RowKey      = 'SamAccountName'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        $since = (Get-Date).AddDays(-[int]$Params.Days)
        Get-ADUser -LDAPFilter "(whenCreated>=$($since.ToUniversalTime().ToString('yyyyMMddHHmmss')).0Z)" -Properties whenCreated, Enabled, Department, Title, Manager |
            Sort-Object whenCreated -Descending |
            Select-Object Name, SamAccountName, UserPrincipalName, Enabled, Department, Title, whenCreated,
                @{ n = 'Manager'; e = { if ($_.Manager) { ($_.Manager -split ',')[0] -replace '^CN=' } } }
    }
}
