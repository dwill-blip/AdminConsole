# Access tab: console roles, their permissions, and who holds them.

function Update-UiAccess {
    param($Page)
    Set-UiGridData $Page.Roles @(Get-ConsoleRole)
    Set-UiGridData $Page.Assignments @(Get-ConsoleRoleAssignment)
}

function Edit-UiRolePermissions {
    param($Page)
    $role = Get-UiGridSelection $Page.Roles
    if (-not $role) { Show-UiInfo 'Select a role first.'; return }
    $catalog = @(Get-ConsolePermissionCatalog)
    $items = @('*   (everything)') + @($catalog | ForEach-Object { '{0}   - {1}' -f $_.Permission, $_.Description })
    $current = @($role.Permissions -split ',\s*' | Where-Object { $_ })
    $checked = @($items | Where-Object { $current -contains (($_ -split '\s{3}')[0]) })
    $chosen = Show-UiChecklist -Title "Permissions for $($role.Name)" -Message 'Tick what this role may do. Permissions from new plugins appear here automatically.' -Items $items -Checked $checked -Height 420
    if ($null -eq $chosen) { return }
    Set-ConsoleRolePermissions -Role $role.Name -Permissions @($chosen | ForEach-Object { ($_ -split '\s{3}')[0] })
    Update-UiAccess $Page
}

Register-UiPage -Title 'Access' -Order 70 -Permission 'ManageRBAC' -Build {
    param($Tab)
    $page = @{}
    $layout = New-UiLayout -Columns '45%', '55%'
    $left = New-Object System.Windows.Forms.Panel; $left.Dock = 'Fill'
    $right = New-Object System.Windows.Forms.Panel; $right.Dock = 'Fill'
    Add-UiCell $layout $left 0 0
    Add-UiCell $layout $right 1 0
    $Tab.Controls.Add($layout)

    $ui = New-UiToolbarGrid -Parent $left -Caption 'Roles'
    $page.Roles = $ui.Grid
    $ui.Bar.Controls.Add((New-UiButton -Text 'New role...' -State $page -OnClick {
                param($p)
                $v = Show-UiInputDialog -Title 'New role' -Inputs (ConvertTo-InputDefinitions @(
                        @{ Name = 'Name'; Required = $true }
                        @{ Name = 'Description' }
                    ) 'Role')
                if ($v) { [void](New-ConsoleRole -Name $v.Name -Description $v.Description); Update-UiAccess $p }
            }))
    $ui.Bar.Controls.Add((New-UiButton -Text 'Edit permissions...' -State $page -OnClick { param($p) Edit-UiRolePermissions $p }))
    $ui.Bar.Controls.Add((New-UiButton -Text 'Delete role' -Danger -State $page -OnClick {
                param($p)
                $role = Get-UiGridSelection $p.Roles
                if ($role -and (Show-UiConfirm "Delete role '$($role.Name)'? Its assignments are removed too.")) { Remove-ConsoleRole -Name $role.Name; Update-UiAccess $p }
            }))
    Register-UiEvent $page.Roles CellDoubleClick -State $page -Handler { param($p, $sender, $e) if ($e.RowIndex -ge 0) { Edit-UiRolePermissions $p } }

    $ui = New-UiToolbarGrid -Parent $right -Caption 'Who has which role'
    $page.Assignments = $ui.Grid
    $ui.Bar.Controls.Add((New-UiButton -Text 'Assign...' -State $page -OnClick {
                param($p)
                $roles = @(Get-ConsoleRole | ForEach-Object { $_.Name })
                $v = Show-UiInputDialog -Title 'Assign role' -Inputs (ConvertTo-InputDefinitions @(
                        @{ Name = 'Account'; Label = 'Windows account (DOMAIN\user)'; Required = $true; Help = 'Exactly as shown in the status bar when that person runs the console.' }
                        @{ Name = 'Role'; Type = 'Choice'; Choices = $roles; Required = $true }
                    ) 'Assign')
                if ($v) { Add-ConsoleRoleAssignment -Account $v.Account -Role $v.Role; Update-UiAccess $p }
            }))
    $ui.Bar.Controls.Add((New-UiButton -Text 'Remove' -Danger -State $page -OnClick {
                param($p)
                $a = Get-UiGridSelection $p.Assignments
                if ($a -and (Show-UiConfirm "Remove role '$($a.Role)' from $($a.Account)?")) { Remove-ConsoleRoleAssignment -Account $a.Account -Role $a.Role; Update-UiAccess $p }
            }))
    Update-UiAccess $page
}
