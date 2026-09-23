# Hybrid Administration Console V7.2.1

Corrective release retaining the V7.2 administrative console and implementing the previously identified gaps.

## Fixed
- Transactional migration history with checksum protection
- Seed history so seeds run once
- Report catalog synchronization
- RBAC checks before reports, exports, destructive actions, scheduling, alerts, approvals, and RBAC management
- Approval requests and approval enforcement for protected actions
- Manual scheduled-report processor
- Manual alert evaluator
- File-based notification queue processor
- Expanded audit coverage
- System health checks
- Foreign keys and useful indexes

## Bootstrap
The Windows account that first initializes the database is assigned the seeded GlobalAdmin console role. This is application RBAC only and does not grant AD, Entra, or Exchange permissions.

## Notification limitation
The included provider delivers queued notifications as JSON files into the configured Notifications folder. Email and Teams delivery require organization-specific sender/webhook configuration and are not silently assumed.

## Run
1. Run `Install-Prerequisites.ps1` elevated.
2. Update `Config/AppConfig.json`.
3. Run `Run-AdminConsole.cmd` elevated.
4. Test against non-production objects.
