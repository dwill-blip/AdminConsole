@{
    Name        = 'Passwords Expiring Soon'
    Description = 'Enabled users whose password expires in the next N days (honours fine-grained password policies).'
    Parameters  = @(@{ Name = 'Days'; Label = 'Expiring within (days)'; Type = 'Number'; Default = 14; Required = $true })
    RowType     = 'User'
    RowKey      = 'SamAccountName'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        $now = Get-Date
        $cutoff = $now.AddDays([int]$Params.Days)
        Get-ADUser -Filter 'Enabled -eq $true -and PasswordNeverExpires -eq $false' -Properties 'msDS-UserPasswordExpiryTimeComputed', PasswordLastSet, mail |
            ForEach-Object {
                $v = $_.'msDS-UserPasswordExpiryTimeComputed'
                if ($v -and $v -gt 0 -and $v -lt 9223372036854775807) {
                    $exp = [datetime]::FromFileTime($v)
                    if ($exp -gt $now -and $exp -le $cutoff) {
                        [pscustomobject]@{
                            Name = $_.Name; SamAccountName = $_.SamAccountName; Email = $_.mail
                            PasswordLastSet = $_.PasswordLastSet; Expires = $exp; DaysLeft = [int]($exp - $now).TotalDays
                        }
                    }
                }
            } | Sort-Object Expires
    }
}
