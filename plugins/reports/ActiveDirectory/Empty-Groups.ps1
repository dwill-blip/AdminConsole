@{
    Name        = 'Empty Groups'
    Description = 'AD groups with no members (built-in system groups excluded).'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        Get-ADGroup -Filter * -Properties Members, whenCreated, whenChanged, Description, isCriticalSystemObject, ManagedBy |
            Where-Object { -not $_.isCriticalSystemObject -and @($_.Members).Count -eq 0 } |
            Select-Object Name, GroupCategory, GroupScope, Description, whenCreated, whenChanged,
                @{ n = 'ManagedBy'; e = { if ($_.ManagedBy) { ($_.ManagedBy -split ',')[0] -replace '^CN=' } } }, DistinguishedName
    }
}
