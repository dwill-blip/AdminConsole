# Extending the console

Everything the operator can click comes from **plugin files**: small `.ps1` files
that end with a hashtable. The engine discovers them at start-up (or when you click
**Health > Reload plugins**), and the UI builds the buttons, menus, dialogs and
permission lists from them. You never edit the UI to add an action or a report.

Rules that apply to every plugin folder:

- Any `.ps1` under the folder is loaded, including sub-folders.
- Files whose name starts with `_` are ignored. Use them for templates and drafts.
- A file that fails to load is skipped. The rest of the console keeps working, and
  the error shows up on the **Health** tab.
- Names must be unique within their kind (actions, workflows, reports).

---

## 1. Actions: `plugins/actions/**/*.ps1`

An action is one operation on one target.

```powershell
@{
    # --- required
    Name  = 'Set Description'          # button text, unique
    Scope = 'User'                     # User | Computer | Row
    Run   = { param($Target, $Inputs) ... }

    # --- optional
    Category         = 'Account'       # button group; default = folder name
    Order            = 100             # sort order inside the group
    Description      = 'Tooltip text'
    Permission       = 'SetDescription' # default = Name in PascalCase
    RequiresApproval = $false          # $true = a second person must approve first
    Danger           = $false          # $true = red button
    Confirm          = $true           # $false, or a custom message: 'Really wipe {0}?'
    Inputs           = @( ... )        # see "Inputs" below
    AppliesTo        = { param($Target) [bool]$Target.AD }  # greys the button out when $false
    TargetName       = { param($Row) $Row.UserPrincipalName } # Row scope: name shown in audit/approvals
    Check            = { param($Target) @{ Done = $true; Detail = '...' } }  # read-only "is this already done?"
    GraphScopes      = @('Group.ReadWrite.All')  # extra delegated Graph permissions this action needs
}
```

### What `$Target` is

| Scope | `$Target` | Useful properties |
|---|---|---|
| `User` | hybrid user from `Get-HybridUser` | `.Identity`, `.DisplayName`, `.UserPrincipalName`, `.SamAccountName`, `.Enabled`, `.AD` (ADUser or `$null`), `.Entra` (MgUser or `$null`) |
| `Computer` | hybrid computer from `Get-HybridComputer` | `.Name`, `.AD` (ADComputer or `$null`), `.Entra` (array of MgDevice) |
| `Row` | one row of a report | whatever columns the report returns |

### What `Run` should do

- Connect first: `Connect-ConsoleActiveDirectory`, `Connect-ConsoleGraph` or
  `Connect-ConsoleExchange`. They are cheap when you are already connected, and they
  honour the `Sources` and app-only settings.
- **Throw on failure.** The engine runs plugins with `$ErrorActionPreference = 'Stop'`,
  so any cmdlet error fails the action, gets audited as `Failed`, and is shown to the
  operator. You do not need `try/catch`.
- Anything you output (strings are best) is shown in the success message.
- Settings are available through `Get-ConsoleSetting 'Name'` and paths through
  `Resolve-ConsolePath 'output/x'`.
- **Long loops** (one remote call per mailbox, user, ...) should call
  `Write-ConsoleProgress "Reading $($x.Name)" $i $items.Count` once per item. The GUI
  then shows a progress window with **Cancel** and stays responsive instead of
  "Not Responding". Cancel makes that call throw, which stops the plugin. Headless jobs ignore it.

### What the engine does for you

Every click goes through `Invoke-ConsoleAction`, in this order:

1. **Permission** check (RBAC). Result: `Denied`.
2. **AppliesTo** check. Result: `NotApplicable`.
3. **Approval** check, if `RequiresApproval`. Result: `ApprovalRequested` or `PendingApproval`.
4. **Inputs** dialog. Result: `Cancelled`.
5. **Confirmation**. Result: `Cancelled`.
6. **Run**, then audit it. Result: `Success` or `Failed`.

### Status checks (`Check`)

`Check` is a read-only look at whether the action's work is already done. It powers
**Check status...** on the Users tab and the workflow checklist, where only steps
that still need doing are ticked. Return one of these:

| Return | Shown as |
|---|---|
| `$true` or `@{ Done = $true; Detail = '...' }` | **Done** (unticked in workflows) |
| `$false` or `@{ Done = $false; Detail = '...' }` | **To do** |
| `@{ Done = $null; Detail = '...' }` or a string | **Info** (for reference; still ticked) |
| throws | **Error** (still ticked, so a broken check never hides work) |

An action without a `Check` is shown as *No check* and always runs.

```powershell
Check = {
    param($User)
    Connect-ConsoleExchange
    $n = @(Get-InboxRule -Mailbox $User.UserPrincipalName).Count
    @{ Done = ($n -eq 0); Detail = "$n inbox rule(s)" }
}
```

### Calling Microsoft Graph

Use `Invoke-ConsoleGraph` instead of the `Get-Mg*` cmdlets. It only needs
`Microsoft.Graph.Authentication`, handles paging (`-All`), and can return `$null` on
404 (`-AllowNotFound`):

```powershell
$methods = Invoke-ConsoleGraph GET "v1.0/users/$($User.Entra.Id)/authentication/methods" -All
Invoke-ConsoleGraph DELETE "v1.0/groups/$groupId/members/$($User.Entra.Id)/`$ref"
Invoke-ConsoleGraph PATCH "v1.0/users/$($User.Entra.Id)" -Body @{ officeLocation = 'Disabled' }
```

List any extra delegated permissions the action needs in `GraphScopes`. The console
adds them to the sign-in automatically, and the first use prompts for consent.

### Inputs

```powershell
Inputs = @(
    @{ Name = 'NewPassword'; Label = 'New password'; Type = 'Password'; Required = $true }
    @{ Name = 'MustChange';  Label = 'Must change at next logon'; Type = 'Bool'; Default = $true }
    @{ Name = 'Reason';      Type = 'Multiline'; Help = 'Shown as a tooltip' }
    @{ Name = 'Days';        Type = 'Number'; Default = 30 }
    @{ Name = 'Mode';        Type = 'Choice'; Choices = @('Soft', 'Hard'); Default = 'Soft' }
    @{ Name = 'When';        Type = 'Date' }
)
```

- Types: `Text` (the default), `Password`, `Multiline`, `Number`, `Bool`, `Choice`, `Date`.
- `Password` values are masked in the audit log.
- Avoid the input names `Count`, `Keys`, `Values` and `Item`. They clash with
  hashtable members, so the loader rejects them.

### Row actions

A `Row` action works on report rows. A report offers it by listing its name in
`RowActions`:

```powershell
# plugins/actions/Rows/Remove-MailboxForwarding.ps1
@{
    Name       = 'Remove Mailbox Forwarding'
    Scope      = 'Row'
    TargetName = { param($Row) $Row.UserPrincipalName }
    Run        = { param($Row) Connect-ConsoleExchange; Set-Mailbox $Row.UserPrincipalName -ForwardingSmtpAddress $null }
}
```

Add `Bulk = $true` to also offer *<action> - all N shown rows...* in the right-click
menu. It runs the action on every row currently shown (after the text filter) that
`AppliesTo` accepts, with one confirmation and one set of inputs, and each row is
audited on its own. *Remove From Group* on the User Group Memberships report works this way.

### Adding a new directory service

For example, Intune or a ticketing API: write the `Connect-*` function inside the
action itself, or add a new file to `src/AdminConsole.Core/Private/`. Every function
in that folder is exported automatically.

---

## 2. Workflows: `plugins/workflows/*.ps1`

A workflow is an ordered list of existing actions with the same scope. The same
action can appear more than once. *Offboard User* runs **Run Entra Connect Sync**
twice, for example.

```powershell
@{
    Name        = 'Offboard User'
    Scope       = 'User'                  # User | Computer
    Description = 'Standard leaver process'
    StopOnError = $false                  # $true = stop at the first failed step
    Permission  = ''                      # optional extra gate; each step still checks its own
    Steps       = @('Reset Password', 'Revoke Sign-in Sessions', 'Disable AD Account')
}
```

Before running, every step's `Check` runs and the operator sees a checklist with
each step's status. Steps that are already done, that do not apply, or that the
operator lacks permission for start unticked. Steps that need approval create a request and
are reported as such, so the operator can run the workflow again once they are
approved. There is one confirmation for the whole run, and each step is audited on
its own.

---

## 3. Reports: `plugins/reports/<Category>/*.ps1`

```powershell
@{
    Name        = 'Inactive AD Users'
    Description = 'Enabled users who have not logged on for N days'
    Category    = 'Active Directory'      # default = folder name
    Permission  = 'RunReport'             # default
    Parameters  = @( @{ Name = 'Days'; Type = 'Number'; Default = 90 } )   # same format as Inputs
    RowType     = 'User'                  # optional: User | Computer
    RowKey      = 'SamAccountName'        # required with RowType: the column used to look the row up
    RowActions  = @('Some Row Action')    # optional Row-scope actions
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        $cutoff = (Get-Date).AddDays(-[int]$Params.Days)
        Get-ADUser -Filter 'Enabled -eq $true' -Properties LastLogonDate |
            Where-Object { $_.LastLogonDate -lt $cutoff } |
            Select-Object Name, SamAccountName, UserPrincipalName, LastLogonDate
    }
}
```

- Return objects; each property becomes a column. Arrays are shown joined with `; `.
- With `RowType`, right-clicking a row offers *Open on the Users tab*, every workflow,
  and every action for that type. The row is looked up via `RowKey` first.
- Every report can be exported, filtered, favorited, scheduled and alerted on with no
  extra code. Scheduled runs call the same `Run` block, so use app-only auth for
  unattended Graph and Exchange access (see SETTINGS.md).

---

## 4. Pages (tabs): `src/AdminConsole.UI/Pages/*.ps1`

Only needed for something that is not an action or a report, such as a dashboard.
Add a new file:

```powershell
# src/AdminConsole.UI/Pages/55-Licenses.ps1
Register-UiPage -Title 'Licenses' -Order 55 -Permission 'RunReport' -Build {
    param($Tab)
    $ui = New-UiToolbarGrid -Parent $Tab
    $page = @{ Grid = $ui.Grid }
    $ui.Bar.Controls.Add((New-UiButton -Text 'Refresh' -State $page -OnClick {
        param($p)
        Connect-ConsoleGraph
        Set-UiGridData $p.Grid @(Get-MgSubscribedSku | Select-Object SkuPartNumber, ConsumedUnits)
    }))
}
```

Rules for UI code, which exist because of PowerShell event scoping:

- Hook events only through `New-UiButton -OnClick` or `Register-UiEvent`, and pass
  everything the handler needs in `-State`. The handler gets `param($State, $Sender, $EventArgs)`.
- Do not use `.GetNewClosure()` (it freezes variables at creation time), and do not
  rely on local variables from the surrounding function.
- Errors thrown in a handler are caught, logged and shown in a message box.
- Useful helpers: `New-UiLayout`, `New-UiFlow`, `New-UiGrid`, `Set-UiGridData`,
  `Get-UiGridSelection`, `Show-UiInputDialog`, `Show-UiChecklist`, `Show-UiConfirm`,
  `Show-UiText`.

---

## 5. Database changes: `database/migrations/NNN_name.sql`

- Add a new file with the next number, for example `003_ticket_links.sql`.
- Each migration runs once, inside a transaction. The version is recorded in
  `SchemaVersion`.
- **Never edit a migration that has already run anywhere.** Add a new one instead.
- Query from PowerShell with `Invoke-DbQuery`, `Invoke-DbNonQuery`, `Invoke-DbScalar`,
  `Invoke-DbInsert` and `Invoke-DbTransaction`. Always use parameters:
  `Invoke-DbQuery 'SELECT * FROM T WHERE Id = @id' @{ id = 5 }`.

---

## 6. Permissions

- Each action has a permission, which defaults to its name in PascalCase. It appears
  on **Access > Edit permissions...** as soon as the plugin loads.
- To grant it to a built-in role for new installs, add it to a new migration:
  ```sql
  INSERT OR IGNORE INTO RolePermissions (RoleId, Permission)
  SELECT Id, 'SetDescription' FROM Roles WHERE Name = 'Helpdesk';
  ```

---

## 7. Test your change

```powershell
Invoke-Pester .\tests
```

`Repository.Tests.ps1` loads every shipped plugin and fails if any file is broken,
a workflow step or row action points at a missing action, or a script contains
non-ASCII characters. Windows PowerShell 5.1 misreads UTF-8 files that have no BOM,
so a stray smart quote from Word or Teams can break a plugin.
