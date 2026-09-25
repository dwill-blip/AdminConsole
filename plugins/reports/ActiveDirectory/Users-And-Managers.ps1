@{
    Name        = 'Users and Managers'
    Description = 'Every enabled user with department, title and manager. Right-click a row > Change Manager to update it.'
    Parameters  = @(
        @{ Name = 'MissingOnly'; Label = 'Only users with no manager'; Type = 'Bool'; Default = $false }
        @{ Name = 'Department'; Label = 'Department (blank = all)' }
    )
    RowType     = 'User'
    RowKey      = 'SamAccountName'
    RowActions  = @('Change Manager')
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        $mgrs = @{}
        Get-ADUser -Filter 'Enabled -eq $true' -Properties DisplayName, Department, Title, Office, Manager, mail |
            Where-Object { (-not $Params.MissingOnly -or -not $_.Manager) -and (-not $Params.Department -or $_.Department -like "*$($Params.Department)*") } |
            ForEach-Object {
                $mUpn = ''
                if ($_.Manager) {
                    if (-not $mgrs.ContainsKey($_.Manager)) {
                        try { $mgrs[$_.Manager] = Get-ADUser -Identity $_.Manager -Properties UserPrincipalName, Enabled } catch { $mgrs[$_.Manager] = $null }
                    }
                    $m = $mgrs[$_.Manager]
                    if ($m) { $mUpn = $m.UserPrincipalName; if (-not $m.Enabled) { $mUpn += ' (disabled)' } }
                }
                [pscustomobject]@{
                    DisplayName    = $_.DisplayName
                    SamAccountName = $_.SamAccountName
                    Email          = $_.mail
                    Department     = $_.Department
                    Title          = $_.Title
                    Office         = $_.Office
                    Manager        = ConvertFrom-ConsoleDn $_.Manager
                    ManagerUPN     = $mUpn
                }
            } | Sort-Object Department, DisplayName
    }
}
