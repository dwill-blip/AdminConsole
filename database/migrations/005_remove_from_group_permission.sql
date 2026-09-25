-- Remove From Group (row action on the User Group Memberships report).
INSERT OR IGNORE INTO RolePermissions (RoleId, Permission)
SELECT Id, 'RemoveFromGroup' FROM Roles WHERE Name IN ('Security', 'Messaging');
