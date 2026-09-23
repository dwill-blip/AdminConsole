# Saves the user's group list to a CSV first, so it can be restored if needed.
@{
    Name        = 'Remove AD Group Memberships'
    Scope       = 'User'
    Category    = 'Account'
    Order       = 60
    Danger      = $true
    Description = 'Removes the user from every AD group (except the primary group) after backing the list up to CSV.'
    AppliesTo   = { param($User) $User.AD -and @($User.AD.MemberOf).Count -gt 0 }
    Check       = { param($User) $n = @($User.AD.MemberOf).Count; @{ Done = ($n -eq 0); Detail = "Member of $n AD group(s)" } }
    Run         = {
        param($User)
        Connect-ConsoleActiveDirectory
        $folder = Resolve-ConsolePath 'output/memberships'
        if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
        $file = Join-Path $folder ('{0}-{1}.csv' -f $User.SamAccountName, (Get-Date -Format 'yyyyMMdd-HHmmss'))
        $groups = @($User.AD.MemberOf | ForEach-Object { Get-ADGroup -Identity $_ })
        $groups | Select-Object Name, GroupScope, GroupCategory, DistinguishedName | Export-Csv -Path $file -NoTypeInformation
        foreach ($g in $groups) {
            Remove-ADGroupMember -Identity $g.DistinguishedName -Members $User.AD.DistinguishedName -Confirm:$false -ErrorAction Stop
        }
        "Removed from $($groups.Count) group(s). Backup: $file"
    }
}
