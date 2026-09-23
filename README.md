# Hybrid Administration Console v8

A Windows desktop console for day-to-day hybrid identity admin: Active Directory,
Entra ID (Microsoft Graph) and Exchange Online, with role-based access, two-person
approvals, a full audit trail, reports, scheduled reports and alerts.

v8 is a ground-up rebuild of v7.2.1. The old version did not start (see
[docs/MIGRATION-FROM-V7.md](docs/MIGRATION-FROM-V7.md) for what was broken). The
main goal of the rebuild is that **adding a feature means adding one small file**.

## Why it is still PowerShell

The work this tool does lives in the `ActiveDirectory` and `ExchangeOnlineManagement`
PowerShell modules. Cmdlets like `Set-CASMailbox`, `Get-MobileDevice` and
`Remove-ADObject -Recursive` have no real equivalent in C#, Python or Node, so a
rewrite in another language would still shell out to PowerShell for every button.
The old code's problem was its structure (one minified 30-line file, scoping bugs),
not the language. v8 keeps PowerShell and fixes the structure.

## Quick start

1. From an **elevated** Windows PowerShell: `.\Install-Prerequisites.ps1`
   (use `-Skip ActiveDirectory` on cloud-only tenants).
2. Edit `config\settings.json` - at least `DisabledUsersOU` / `DisabledComputersOU`,
   and set `Sources` to match what you have. See [docs/SETTINGS.md](docs/SETTINGS.md).
3. Double-click `Start-AdminConsole.cmd`.
   The first person to open it becomes **GlobalAdmin**; add everyone else on the
   **Access** tab.
4. Optional: on the **Automation** tab, click *Install Windows scheduled task* so
   scheduled reports and alerts run every 15 minutes.

Test against non-production objects first.

## What is in the window

| Tab | What it does |
|---|---|
| Users | Look up a user (sAMAccountName, UPN or email) in AD and Entra ID; one button per user action; **Offboard User** workflow with tick-boxes per step |
| Computers | Same for computers; **Decommission Computer** workflow |
| Reports | 50 reports across AD, Entra ID, Exchange, licensing, security and usage (list: docs/REPORTS.md); parameters, filter, export (CSV/HTML/JSON), favorites, *Schedule...*, *Alert on this...*, right-click row actions |
| Approvals | Approve / reject requests for protected actions |
| Automation | Scheduled reports, alerts, notification queue |
| Audit | Searchable log of every action, approval, report run and change |
| Access | Console roles, their permissions, and who holds them |
| Health | Prerequisites, database, plugin load errors, *Reload plugins* |
| Settings | Edit `settings.json` with validation |

Buttons grey out when an action does not apply (e.g. *Enable AD Account* on an
enabled account) or you lack the permission. `*` marks actions that need approval.

## Folder layout

```
AdminConsole.ps1             GUI entry point  (Start-AdminConsole.cmd runs it)
Invoke-AdminJobs.ps1         Headless jobs for Task Scheduler (-Register to install)
Install-Prerequisites.ps1
config/settings.json
database/migrations/         NNN_name.sql, applied once each, in order
plugins/
  actions/<folder>/*.ps1     one file = one button
  workflows/*.ps1            one file = one multi-step button
  reports/<Category>/*.ps1   one file = one report
src/
  AdminConsole.Core/         engine: config, SQLite, RBAC, approvals, audit, plugin loader,
                             action runner, reports, scheduling, alerts, health  (no UI)
  AdminConsole.UI/           Windows Forms front end; Pages/ = one file per tab
tests/                       Pester tests (Invoke-Pester .\tests)
docs/                        EXTENDING.md, SETTINGS.md, REPORTS.md, MIGRATION-FROM-V7.md
data/  logs/  output/        created at runtime
```

## Adding features

Short version - copy a template, drop the leading underscore, edit, then click
**Health > Reload plugins** (no restart):

| To add... | Copy | Result |
|---|---|---|
| A button on Users/Computers | `plugins/actions/_Template.ps1` | Button appears, with RBAC, approval, confirmation and audit handled for you |
| A multi-step process | `plugins/workflows/_Template.ps1` | Workflow button with per-step tick boxes |
| A report | `plugins/reports/_Template.ps1` | Appears in the Reports tree; can be exported, scheduled and alerted on |
| A whole new tab | any file in `src/AdminConsole.UI/Pages/` | `Register-UiPage` in a new file |
| A database table | a new `database/migrations/003_*.sql` | Applied on next start |

Full guide with examples: **[docs/EXTENDING.md](docs/EXTENDING.md)**.

A minimal action:

```powershell
# plugins/actions/User/Set-Description.ps1
@{
    Name   = 'Set Description'
    Scope  = 'User'
    Inputs = @( @{ Name = 'Text'; Label = 'Description'; Required = $true } )
    AppliesTo = { param($User) [bool]$User.AD }
    Run    = {
        param($User, $Inputs)
        Connect-ConsoleActiveDirectory
        Set-ADUser -Identity $User.AD.DistinguishedName -Description $Inputs.Text
    }
}
```

## Tests

```powershell
Install-Module Pester -Scope CurrentUser
Invoke-Pester .\tests
```

The tests need no AD, Graph or Exchange: they build a throw-away console with fake
plugins and exercise the database, RBAC, approvals, the action runner, workflows,
reports, exports, scheduling, alerts and notifications, plus static checks
(every script parses, files are ASCII for PowerShell 5.1, shipped plugins load,
default roles reference real permissions).

## Security notes

- Console RBAC controls what the console lets you click. It does not grant rights in
  AD, Entra ID or Exchange - those come from the operator's own account.
- The SQLite file holds roles and the audit log. Put the console on a share or
  server where only admins can write to `data\`, or anyone with write access can
  edit their own role.
- Passwords typed into actions are never written to the audit log.
