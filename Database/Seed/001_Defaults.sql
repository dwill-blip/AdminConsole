INSERT OR IGNORE INTO RoleDefinitions(RoleName,Description,IsSystem) VALUES
('Helpdesk','Password and user support',1),('Messaging','Exchange administration',1),('Security','Security administration',1),('Infrastructure','Device and server administration',1),('GlobalAdmin','Full console access',1);
INSERT OR IGNORE INTO Permissions(PermissionName,Description,Category) VALUES
('RunReport','Run reports','Reporting'),('ExportReport','Export reports','Reporting'),('ResetPassword','Reset passwords','Users'),('DisableUser','Disable users','Users'),('RemoveMFA','Remove MFA methods','Security'),('DeleteDevice','Delete devices','Devices'),('RemoveLicense','Remove licenses','Licensing'),('ManageAlerts','Manage alerts','Alerts'),('ManageSchedules','Manage schedules','Scheduling'),('ManageApprovals','Manage approvals','Approvals'),('ManageRBAC','Manage RBAC','Security'),('ApprovalOverride','Execute approved actions','Approvals');
INSERT OR IGNORE INTO ApprovalRules(ActionName,Enabled,RequiredRole,ExpiresMinutes) VALUES
('Delete Entra Device',1,'Security',1440),('Delete AD Computer',1,'Infrastructure',1440),('Remove License',1,'Security',1440),('Remove MFA',1,'Security',1440),('Convert Mailbox',1,'Messaging',1440);
INSERT OR IGNORE INTO Favorites(DisplayName,ReportPath,Created) VALUES
('Exchange | ActiveSync Devices','Reports\Exchange\ActiveSync-Devices.ps1',datetime('now')),('Exchange | Mailbox Forwarding','Reports\Exchange\Forwarding.ps1',datetime('now')),('Entra | MFA Registration Status','Reports\Entra\MFA-Status.ps1',datetime('now'));
INSERT OR IGNORE INTO Alerts(Name,Enabled,ReportPath,ContainsFilter,Severity) VALUES
('Users Without MFA',1,'Reports\Entra\MFA-Status.ps1','False','Warning'),('Mailbox Forwarding Enabled',1,'Reports\Exchange\Forwarding.ps1','','Critical');
