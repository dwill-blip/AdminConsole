# Removes Entra ID directory roles held directly by the user: active assignments and,
# where PIM is licensed, eligible assignments. Roles held through a role-assignable group
# are removed when the user leaves that group.
@{
    Name        = 'Remove Admin Roles'
    Scope       = 'User'
    Category    = 'Entra ID'
    Order       = 16
    Danger      = $true
    GraphScopes = @('RoleManagement.ReadWrite.Directory')
    AppliesTo   = { param($User) [bool]$User.Entra }
    Check       = {
        param($User)
        $f = [uri]::EscapeDataString("principalId eq '$($User.Entra.Id)'")
        $active = @(Invoke-ConsoleGraph GET "v1.0/roleManagement/directory/roleAssignments?`$filter=$f&`$expand=roleDefinition" -All)
        $eligible = @()
        try { $eligible = @(Invoke-ConsoleGraph GET "v1.0/roleManagement/directory/roleEligibilitySchedules?`$filter=$f&`$expand=roleDefinition" -All) } catch { }
        $names = @($active + $eligible | ForEach-Object { $_.roleDefinition.displayName }) | Sort-Object -Unique
        @{ Done = (($active.Count + $eligible.Count) -eq 0); Detail = "$(if ($names) { 'Roles: ' + ($names -join ', ') } else { 'No admin roles' })" }
    }
    Run         = {
        param($User)
        $id = $User.Entra.Id
        $f = [uri]::EscapeDataString("principalId eq '$id'")
        $done = @(); $notes = @()
        foreach ($a in @(Invoke-ConsoleGraph GET "v1.0/roleManagement/directory/roleAssignments?`$filter=$f&`$expand=roleDefinition" -All)) {
            try { Invoke-ConsoleGraph DELETE "v1.0/roleManagement/directory/roleAssignments/$($a.id)" | Out-Null }
            catch {
                # PIM-activated / time-bound assignments must be ended with a schedule request.
                Invoke-ConsoleGraph POST 'v1.0/roleManagement/directory/roleAssignmentScheduleRequests' -Body @{
                    action = 'adminRemove'; principalId = $id; roleDefinitionId = $a.roleDefinitionId
                    directoryScopeId = $a.directoryScopeId; justification = 'Offboarding'
                } | Out-Null
            }
            $done += $a.roleDefinition.displayName
        }
        try {
            foreach ($e in @(Invoke-ConsoleGraph GET "v1.0/roleManagement/directory/roleEligibilitySchedules?`$filter=$f&`$expand=roleDefinition" -All)) {
                Invoke-ConsoleGraph POST 'v1.0/roleManagement/directory/roleEligibilityScheduleRequests' -Body @{
                    action = 'adminRemove'; principalId = $id; roleDefinitionId = $e.roleDefinitionId
                    directoryScopeId = $e.directoryScopeId; justification = 'Offboarding'
                } | Out-Null
                $done += "$($e.roleDefinition.displayName) (eligible)"
            }
        }
        catch { $notes += "PIM eligible roles not checked: $($_.Exception.Message)" }
        if (-not $done.Count) { return (@('User holds no admin roles.') + $notes) -join ' ' }
        (@("Removed: $($done -join ', ').") + $notes) -join ' '
    }
}
