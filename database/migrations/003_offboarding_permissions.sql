-- Permissions for the offboarding actions added in v8.1.

INSERT OR IGNORE INTO RolePermissions (RoleId, Permission)
SELECT r.Id, p.Permission FROM Roles r JOIN (
              SELECT 'Helpdesk' AS Role, 'RemoveMobileNumber' AS Permission
    UNION ALL SELECT 'Helpdesk', 'SetOfficeToDisabled'
    UNION ALL SELECT 'Helpdesk', 'RunEntraConnectSync'
    UNION ALL SELECT 'Security', 'RunEntraConnectSync'
    UNION ALL SELECT 'Security', 'RemoveMfaMethods'
    UNION ALL SELECT 'Security', 'RemoveAdminRoles'
    UNION ALL SELECT 'Security', 'RemoveFromTeams'
    UNION ALL SELECT 'Security', 'ArchiveOneDrive'
    UNION ALL SELECT 'Security', 'RemoveMobileNumber'
    UNION ALL SELECT 'Security', 'SetOfficeToDisabled'
    UNION ALL SELECT 'Security', 'MoveToDisabledOU'
    UNION ALL SELECT 'Security', 'RemoveADGroupMemberships'
    UNION ALL SELECT 'Messaging', 'RemoveFromTeams'
) p ON p.Role = r.Name;
