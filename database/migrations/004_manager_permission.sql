-- Set Manager / Change Manager.
INSERT OR IGNORE INTO RolePermissions (RoleId, Permission)
SELECT Id, 'SetManager' FROM Roles WHERE Name IN ('Helpdesk', 'Security');
