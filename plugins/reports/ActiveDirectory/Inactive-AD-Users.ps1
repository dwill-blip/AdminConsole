@{
    Name        = 'Inactive AD Users'
    Description = 'Enabled users who have not logged on for N days (or never).'
    Parameters  = @(
        @{ Name = 'Days'; Label = 'Inactive for (days)'; Type = 'Number'; Default = 90; Required = $true }
    )
    RowType     = 'User'
    RowKey      = 'SamAccountName'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        $cutoff = (Get-Date).AddDays(-[int]$Params.Days)
        Get-ADUser -Filter 'Enabled -eq $true' -Properties LastLogonDate, WhenCreated, Department |
            Where-Object { -not $_.LastLogonDate -or $_.LastLogonDate -lt $cutoff } |
            Select-Object DisplayName, SamAccountName, UserPrincipalName, Department, LastLogonDate, WhenCreated
    }
}
