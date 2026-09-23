@{
    Name        = 'Entra Admin Role Members'
    Description = 'Who holds which Entra ID admin role - active and PIM-eligible (eligible needs Entra ID P2).'
    GraphScopes = @('RoleManagement.Read.Directory', 'Directory.Read.All')
    RowType     = 'User'
    RowKey      = 'UserPrincipalName'
    Run         = {
        param($Params)
        $rows = foreach ($a in @(Invoke-ConsoleGraph GET 'v1.0/roleManagement/directory/roleAssignments?$expand=principal,roleDefinition' -All)) {
            [pscustomobject]@{
                Role = $a.roleDefinition.displayName; Principal = $a.principal.displayName
                UserPrincipalName = $a.principal.userPrincipalName
                PrincipalType = ($a.principal.'@odata.type' -replace '#microsoft.graph.', ''); Assignment = 'Active'
            }
        }
        $rows
        try {
            foreach ($e in @(Invoke-ConsoleGraph GET 'v1.0/roleManagement/directory/roleEligibilitySchedules?$expand=principal,roleDefinition' -All)) {
                [pscustomobject]@{
                    Role = $e.roleDefinition.displayName; Principal = $e.principal.displayName
                    UserPrincipalName = $e.principal.userPrincipalName
                    PrincipalType = ($e.principal.'@odata.type' -replace '#microsoft.graph.', ''); Assignment = 'Eligible'
                }
            }
        }
        catch { Write-ConsoleLog "PIM eligible roles skipped: $($_.Exception.Message)" Warning }
    }
}
