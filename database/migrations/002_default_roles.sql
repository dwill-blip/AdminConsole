-- Default console roles. Edit them afterwards on the Access tab.
-- Permission names match the Permission field of each plugin (default: the action
-- name without spaces, e.g. "Reset Password" -> ResetPassword).

INSERT OR IGNORE INTO Roles (Name, Description) VALUES
    ('GlobalAdmin',    'Everything, including roles and settings'),
    ('Helpdesk',       'Password resets, unlocks and read-only reports'),
    ('Messaging',      'Exchange Online mailbox administration'),
    ('Security',       'Sessions, licenses, device removal and approvals'),
    ('Infrastructure', 'Computers and devices'),
    ('Auditor',        'Read-only: reports and audit log');

INSERT OR IGNORE INTO RolePermissions (RoleId, Permission)
SELECT r.Id, p.Permission FROM Roles r JOIN (
              SELECT 'GlobalAdmin' AS Role, '*' AS Permission
    UNION ALL SELECT 'Helpdesk', 'RunReport'
    UNION ALL SELECT 'Helpdesk', 'ResetPassword'
    UNION ALL SELECT 'Helpdesk', 'UnlockADAccount'
    UNION ALL SELECT 'Helpdesk', 'EnableADAccount'
    UNION ALL SELECT 'Helpdesk', 'RevokeSignInSessions'
    UNION ALL SELECT 'Messaging', 'RunReport'
    UNION ALL SELECT 'Messaging', 'ExportReport'
    UNION ALL SELECT 'Messaging', 'DisableActiveSync'
    UNION ALL SELECT 'Messaging', 'RemoveMobileDevices'
    UNION ALL SELECT 'Messaging', 'RemoveInboxRules'
    UNION ALL SELECT 'Messaging', 'ConvertToSharedMailbox'
    UNION ALL SELECT 'Messaging', 'HideFromGAL'
    UNION ALL SELECT 'Messaging', 'DisableAutoReply'
    UNION ALL SELECT 'Messaging', 'RemoveActiveSyncDevice'
    UNION ALL SELECT 'Messaging', 'RemoveMailboxForwarding'
    UNION ALL SELECT 'Security', 'RunReport'
    UNION ALL SELECT 'Security', 'ExportReport'
    UNION ALL SELECT 'Security', 'ViewAudit'
    UNION ALL SELECT 'Security', 'ManageApprovals'
    UNION ALL SELECT 'Security', 'ManageAlerts'
    UNION ALL SELECT 'Security', 'RevokeSignInSessions'
    UNION ALL SELECT 'Security', 'RemoveAllLicenses'
    UNION ALL SELECT 'Security', 'RemoveLicenseAssignment'
    UNION ALL SELECT 'Security', 'DeleteEntraDevices'
    UNION ALL SELECT 'Security', 'DisableADAccount'
    UNION ALL SELECT 'Infrastructure', 'RunReport'
    UNION ALL SELECT 'Infrastructure', 'ExportReport'
    UNION ALL SELECT 'Infrastructure', 'DisableADComputer'
    UNION ALL SELECT 'Infrastructure', 'MoveComputerToDisabledOU'
    UNION ALL SELECT 'Infrastructure', 'DeleteADComputer'
    UNION ALL SELECT 'Infrastructure', 'DeleteEntraDevices'
    UNION ALL SELECT 'Infrastructure', 'ManageSchedules'
    UNION ALL SELECT 'Auditor', 'RunReport'
    UNION ALL SELECT 'Auditor', 'ExportReport'
    UNION ALL SELECT 'Auditor', 'ViewAudit'
) p ON p.Role = r.Name;
