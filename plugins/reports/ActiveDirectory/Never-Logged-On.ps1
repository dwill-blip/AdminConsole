@{
    Name        = 'Users Who Never Logged On'
    Description = 'Enabled accounts older than N days that have never logged on.'
    Parameters  = @(@{ Name = 'Days'; Label = 'Created more than (days) ago'; Type = 'Number'; Default = 30 })
    RowType     = 'User'
    RowKey      = 'SamAccountName'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        $cutoff = (Get-Date).AddDays(-[int]$Params.Days)
        Get-ADUser -Filter 'Enabled -eq $true' -Properties LastLogonDate, whenCreated, Description |
            Where-Object { -not $_.LastLogonDate -and $_.whenCreated -lt $cutoff } |
            Select-Object Name, SamAccountName, UserPrincipalName, whenCreated, Description, DistinguishedName
    }
}
