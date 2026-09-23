@{
    Name        = 'License Assignments'
    Description = 'One row per user per license, showing whether it is direct or group-based.'
    RowType     = 'User'
    RowKey      = 'UserPrincipalName'
    RowActions  = @('Remove License Assignment')
    Run         = {
        param($Params)
        Connect-ConsoleGraph
        $skus = @{}
        Get-MgSubscribedSku -All -ErrorAction Stop | ForEach-Object { $skus[[string]$_.SkuId] = $_.SkuPartNumber }
        foreach ($u in Get-MgUser -All -Property 'Id,DisplayName,UserPrincipalName,LicenseAssignmentStates' -ErrorAction Stop) {
            foreach ($l in @($u.LicenseAssignmentStates)) {
                $via = 'Direct'
                if ($l.AssignedByGroup) { $via = "Group $($l.AssignedByGroup)" }
                [pscustomobject]@{
                    DisplayName       = $u.DisplayName
                    UserPrincipalName = $u.UserPrincipalName
                    License           = $skus[[string]$l.SkuId]
                    AssignedVia       = $via
                    State             = $l.State
                    UserId            = $u.Id
                    SkuId             = $l.SkuId
                }
            }
        }
    }
}
