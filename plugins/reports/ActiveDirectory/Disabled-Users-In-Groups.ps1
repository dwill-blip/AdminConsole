@{
    Name        = 'Disabled Users Still in Groups'
    Description = 'Disabled accounts that still hold group memberships - leftovers from incomplete offboarding.'
    RowType     = 'User'
    RowKey      = 'SamAccountName'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        Get-ADUser -Filter 'Enabled -eq $false' -Properties MemberOf, whenChanged |
            Where-Object { @($_.MemberOf).Count -gt 0 } |
            Select-Object Name, SamAccountName, whenChanged,
                @{ n = 'GroupCount'; e = { @($_.MemberOf).Count } },
                @{ n = 'Groups'; e = { ($_.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=' }) -join '; ' } }
    }
}
