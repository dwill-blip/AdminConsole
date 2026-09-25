# Moving from v7.2.1 to v8

## Why v7.2.1 did not work

These are the defects found in the v7.2.1 code, most severe first. Most of them
stop the console before the window opens, or make every button do nothing.

| # | Where | Problem | Effect |
|---|---|---|---|
| 1 | `Database.psm1` | Every query opened and closed its own connection, so `BEGIN IMMEDIATE` and `COMMIT` ran on different connections. | The first `COMMIT` throws *no transaction is active*, so the **first launch crashes**. Each relaunch gets one migration further. |
| 2 | `AdminConsole.ps1` | `Get-DashboardMetrics` is called, but it is not defined anywhere. | Crash at start-up (`$ErrorActionPreference = 'Stop'`). |
| 3 | `AdminConsole.ps1` | Button handlers used `.GetNewClosure()`, which copies `$HU` (the loaded user) when the button is **created**, before any user is loaded. | Every Offboarding / User Administration button acts on `$null`, whoever you loaded. |
| 4 | `DT` helper | It returned a `DataTable` from a function without the unary comma, so PowerShell unrolled it into rows. | Grids come out empty or garbled. |
| 5 | Reports tab | `Add-Favorite` is called, but it is not defined. | The Favorite button throws. |
| 6 | `Initialize-PlatformDatabase` | It added **every** Windows account that launched the console to GlobalAdmin. | RBAC did nothing: everyone was an admin. |
| 7 | Seed | `RolePermissions` was never seeded, and there was no UI to assign roles. | Nobody except GlobalAdmin could do anything. |
| 8 | Jobs / seed | Alerts and favorites stored **relative** report paths, but jobs ran `& $path` from whatever folder they started in. | Alerts failed unless started from the console folder. |
| 9 | `Get-HybridUser` | `Get-ADUser -Identity user@domain` does not accept a UPN. | Looking up a user by UPN never found the AD account. |
| 10 | Computers tab | *Delete Both* logged the wrong action name. `$db` (the database path) was overwritten by a button. | Approval rules could be bypassed, and the audit trail was misleading. |
| 11 | Row actions | The `MailboxForwarding` action type was declared, but nothing handled it. | The Row Action button did nothing on that report. |
| 12 | Migrations | They were checksummed against the file bytes, so a git line-ending change aborted start-up. | *Migration changed after application* on another PC. |
| 13 | Scheduling | It was a table with no UI for creating schedules or alerts, and nothing ran it automatically. | The feature was not usable. |
| 14 | Remove license | It tried to remove group-assigned licenses. | `Set-MgUserLicense` failed for group-licensed users. |
| 15 | Hide from GAL | It used `Set-Mailbox` on AD-synced users. | Exchange Online refuses this for synced objects. |

Beyond these bugs, the whole UI was about 30 very long lines. Absolute pixel
positions, one-letter function names and shared global variables made any change
risky.

## What changed in v8

- **Two modules instead of one script.** `AdminConsole.Core` contains no UI and is
  unit-tested. `AdminConsole.UI` is split into one file per tab.
- **Plugins.** Actions, workflows and reports are data files, and the UI is generated
  from them. See [EXTENDING.md](EXTENDING.md).
- **One action runner.** Permission checks, approvals, inputs, confirmation, audit
  and error handling are the same for every button, workflow step, row action and job.
- **Real approvals.** The requester cannot self-approve. An approval is tied to the
  requester and used once, and requests expire.
- **Real scheduling.** Schedules and alerts are created from the Reports tab. Jobs
  run from Task Scheduler (`Invoke-AdminJobs.ps1 -Register`), and notifications can
  go to a file drop and/or a webhook.
- **Layout managers** instead of pixel coordinates, so the window resizes and scales.
- **Tests:** 40+ Pester tests, including static checks on every plugin.

## Upgrading

v8 uses a new database schema at `data/AdminConsole.db`. It does not reuse
`Data/HybridAdmin.db`. The old database never got past its first migrations in
practice. If yours holds audit history you need to keep, export it first:

```powershell
Import-Module PSSQLite
Invoke-SqliteQuery -DataSource .\Data\HybridAdmin.db -Query 'SELECT * FROM Audit' |
    Export-Csv .\audit-v7.csv -NoTypeInformation
```

Your v7 settings do not need to be copied by hand. Either run
`.\Import-Settings.ps1 -Path <path to your v7 Config\AppConfig.json>`, or copy that file
into `config\` and start the console; it is imported into
`config\settings.local.json` once (see [SETTINGS.md](SETTINGS.md)). The names map as follows:

| v7 `Config/AppConfig.json` | v8 `config/settings.json` |
|---|---|
| `DisabledUsersOU`, `DisabledComputersOU`, `RequireApprovals`, `DefaultReportPeriod` | same names |
| `DatabasePath` | `DatabasePath` (new default `data/AdminConsole.db`) |
| `NotificationDropFolder` | `Notifications.DropFolder` |
| `ScheduledReportOutputFolder` | `ReportOutputFolder` |
| `SeedDatabase` | removed; default roles are a normal migration |
