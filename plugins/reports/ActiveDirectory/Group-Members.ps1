@{
    Name        = 'Group Members'
    Description = 'Members of one AD group (optionally including nested groups).'
    Parameters  = @(
        @{ Name = 'Group'; Label = 'Group name'; Required = $true }
        @{ Name = 'Recursive'; Label = 'Include nested groups'; Type = 'Bool'; Default = $true }
    )
    RowType     = 'User'
    RowKey      = 'SamAccountName'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        $p = @{ Identity = $Params.Group }
        if ($Params.Recursive) { $p.Recursive = $true }
        Get-ADGroupMember @p |
            Select-Object name, SamAccountName, objectClass, distinguishedName
    }
}
