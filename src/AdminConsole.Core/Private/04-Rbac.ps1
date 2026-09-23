# Console role-based access control.
#
# Roles hold permission names (a role holding '*' has every permission). Windows
# accounts are assigned to roles. Actions and reports declare the permission they
# need, so a new plugin automatically shows up in the role editor.
#
# NOTE: this governs what the console lets you click. It does not grant any rights
# in AD, Entra ID or Exchange - those still come from the operator's own account.

$script:CurrentUserOverride = $null

$script:BuiltInPermissions = [ordered]@{
    RunReport       = 'Run reports'
    ExportReport    = 'Export report results'
    ViewAudit       = 'View the audit log'
    ManageApprovals = 'Approve or reject requests'
    ManageSchedules = 'Create and run scheduled reports'
    ManageAlerts    = 'Create and run alerts and notifications'
    ManageRBAC      = 'Manage console roles and assignments'
    ManageSettings  = 'Edit console settings'
}

function Get-ConsoleUser {
    if ($script:CurrentUserOverride) { return $script:CurrentUserOverride }
    try {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        if ($id -and $id.Name) { return $id.Name }
    }
    catch { }
    [System.Environment]::UserName
}

function Set-ConsoleUser {
    # For tests and for the headless job runner. $null restores the real Windows identity.
    param([string]$Account)
    $script:CurrentUserOverride = $Account
}

function Test-ConsolePermission {
    param([string]$Permission, [string]$Account = (Get-ConsoleUser))
    if ([string]::IsNullOrWhiteSpace($Permission)) { return $true }
    $hit = Invoke-DbScalar "SELECT 1 FROM UserRoles ur JOIN RolePermissions rp ON rp.RoleId = ur.RoleId
                            WHERE ur.Account = @a AND (rp.Permission = @p OR rp.Permission = '*') LIMIT 1" @{ a = $Account; p = $Permission }
    [bool]$hit
}

function Assert-ConsolePermission {
    param([Parameter(Mandatory)][string]$Permission)
    if (-not (Test-ConsolePermission $Permission)) {
        throw [System.UnauthorizedAccessException]::new("Access denied: '$(Get-ConsoleUser)' does not have the '$Permission' permission. Ask a console admin to add it on the Access tab.")
    }
}

function Get-ConsolePermissionCatalog {
    # Built-in permissions plus every permission declared by a loaded plugin.
    $list = New-Object System.Collections.ArrayList
    foreach ($k in $script:BuiltInPermissions.Keys) {
        [void]$list.Add([pscustomobject]@{ Permission = $k; Description = $script:BuiltInPermissions[$k]; Source = 'Built-in' })
    }
    $seen = @{}
    foreach ($k in $script:BuiltInPermissions.Keys) { $seen[$k] = $true }
    foreach ($a in @(Get-ConsoleAction) + @(Get-ConsoleWorkflow) + @(Get-ConsoleReport)) {
        if ($a -and $a.Permission -and -not $seen.ContainsKey($a.Permission)) {
            $seen[$a.Permission] = $true
            [void]$list.Add([pscustomobject]@{ Permission = $a.Permission; Description = "Used by: $($a.Name)"; Source = 'Plugin' })
        }
    }
    $list | Sort-Object Source, Permission
}

function Get-ConsoleRole {
    param([string]$Name)
    $roles = Invoke-DbQuery "SELECT r.Id, r.Name, r.Description, COALESCE(GROUP_CONCAT(rp.Permission, ', '), '') AS Permissions
                             FROM Roles r LEFT JOIN RolePermissions rp ON rp.RoleId = r.Id
                             GROUP BY r.Id ORDER BY r.Name"
    if ($Name) { $roles | Where-Object { $_.Name -eq $Name } } else { $roles }
}

function New-ConsoleRole {
    param([Parameter(Mandatory)][string]$Name, [string]$Description = '', [string[]]$Permissions = @())
    Assert-ConsolePermission 'ManageRBAC'
    $id = Invoke-DbInsert 'INSERT INTO Roles (Name, Description) VALUES (@n, @d)' @{ n = $Name; d = $Description }
    Set-ConsoleRolePermissions -Role $Name -Permissions $Permissions
    Write-ConsoleAudit -Action 'Create Role' -Target $Name -Result 'Success'
    $id
}

function Remove-ConsoleRole {
    param([Parameter(Mandatory)][string]$Name)
    Assert-ConsolePermission 'ManageRBAC'
    if ($Name -eq 'GlobalAdmin') { throw 'The GlobalAdmin role cannot be deleted.' }
    Invoke-DbNonQuery 'DELETE FROM Roles WHERE Name = @n' @{ n = $Name } | Out-Null
    Write-ConsoleAudit -Action 'Delete Role' -Target $Name -Result 'Success'
}

function Set-ConsoleRolePermissions {
    param([Parameter(Mandatory)][string]$Role, [string[]]$Permissions = @())
    Assert-ConsolePermission 'ManageRBAC'
    $roleId = Invoke-DbScalar 'SELECT Id FROM Roles WHERE Name = @n' @{ n = $Role }
    if (-not $roleId) { throw "Role '$Role' not found." }
    Invoke-DbTransaction {
        Invoke-DbNonQuery 'DELETE FROM RolePermissions WHERE RoleId = @r' @{ r = $roleId } | Out-Null
        foreach ($p in ($Permissions | Where-Object { $_ } | Select-Object -Unique)) {
            Invoke-DbNonQuery 'INSERT INTO RolePermissions (RoleId, Permission) VALUES (@r, @p)' @{ r = $roleId; p = $p } | Out-Null
        }
    }
    Write-ConsoleAudit -Action 'Set Role Permissions' -Target $Role -Result 'Success' -Details ($Permissions -join ', ')
}

function Get-ConsoleRoleAssignment {
    param([string]$Account)
    $rows = Invoke-DbQuery 'SELECT ur.Id, ur.Account, r.Name AS Role, ur.AssignedOn, ur.AssignedBy FROM UserRoles ur JOIN Roles r ON r.Id = ur.RoleId ORDER BY ur.Account, r.Name'
    if ($Account) { $rows | Where-Object { $_.Account -eq $Account } } else { $rows }
}

function Add-ConsoleRoleAssignment {
    param([Parameter(Mandatory)][string]$Account, [Parameter(Mandatory)][string]$Role, [switch]$Bootstrap)
    if (-not $Bootstrap) { Assert-ConsolePermission 'ManageRBAC' }
    $roleId = Invoke-DbScalar 'SELECT Id FROM Roles WHERE Name = @n' @{ n = $Role }
    if (-not $roleId) { throw "Role '$Role' not found." }
    $by = if ($Bootstrap) { 'Bootstrap' } else { Get-ConsoleUser }
    Invoke-DbNonQuery 'INSERT OR IGNORE INTO UserRoles (Account, RoleId, AssignedOn, AssignedBy) VALUES (@a, @r, @d, @b)' @{
        a = $Account.Trim(); r = $roleId; d = (Get-ConsoleNow); b = $by
    } | Out-Null
    Write-ConsoleAudit -Action 'Assign Role' -Target $Account -Result 'Success' -Details $Role
}

function Remove-ConsoleRoleAssignment {
    param([Parameter(Mandatory)][string]$Account, [Parameter(Mandatory)][string]$Role)
    Assert-ConsolePermission 'ManageRBAC'
    if ($Role -eq 'GlobalAdmin') {
        $admins = [int](Invoke-DbScalar "SELECT COUNT(*) FROM UserRoles ur JOIN Roles r ON r.Id = ur.RoleId WHERE r.Name = 'GlobalAdmin'")
        if ($admins -le 1) { throw 'Refusing to remove the last GlobalAdmin - you would lock everyone out of the Access tab.' }
    }
    Invoke-DbNonQuery 'DELETE FROM UserRoles WHERE Account = @a AND RoleId = (SELECT Id FROM Roles WHERE Name = @r)' @{ a = $Account; r = $Role } | Out-Null
    Write-ConsoleAudit -Action 'Unassign Role' -Target $Account -Result 'Success' -Details $Role
}

function Initialize-ConsoleBootstrapAdmin {
    # Only when nobody has any role yet: make the first operator GlobalAdmin.
    # (The old version granted GlobalAdmin to EVERY account that launched the console.)
    $count = [int](Invoke-DbScalar 'SELECT COUNT(*) FROM UserRoles')
    if ($count -eq 0) {
        Add-ConsoleRoleAssignment -Account (Get-ConsoleUser) -Role 'GlobalAdmin' -Bootstrap
        Write-ConsoleLog "First run: '$(Get-ConsoleUser)' was made GlobalAdmin. Add other operators on the Access tab."
    }
}
