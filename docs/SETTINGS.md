# config/settings.json and settings.local.json

`config\settings.json` holds the shipped defaults and is replaced by each update.
Put your site's values in `config\settings.local.json` instead: anything in it
overrides `settings.json`, and it is not in git or the release zips, so pulling a new
version never overwrites it. It only needs the settings you change, for example:

```json
{
  "DisabledUsersOU": "OU=Disabled Users,DC=corp,DC=contoso,DC=com",
  "DisabledComputersOU": "OU=Disabled Computers,DC=corp,DC=contoso,DC=com",
  "Graph": { "TenantId": "contoso.onmicrosoft.com" }
}
```

Edit the file directly, or use the **Settings** tab (needs the `ManageSettings`
permission), which saves to `settings.local.json`. The JSON is validated before it is
saved. Any setting you leave out falls back to its default. Relative paths are
resolved from the console folder.

## Importing an earlier settings file

To bring over the values from an earlier install, either click **Import...** on the
Settings tab, or run:

```powershell
.\Import-Settings.ps1 -Path 'C:\Old\AdminConsole\config\settings.json'
```

It accepts a v8 `settings.json` or a v7 `AppConfig.json` (v7 names are mapped; see
[MIGRATION-FROM-V7.md](MIGRATION-FROM-V7.md)). Only values that differ from the shipped
`settings.json` are copied, so later updates to the defaults still apply. Importing
again merges into `settings.local.json`; the newer file wins.

If a v7 `AppConfig.json` is in the `config` folder and there is no
`settings.local.json` yet, it is imported automatically the first time the console starts.

## Settings

| Setting | Default | Meaning |
|---|---|---|
| `ApplicationName` | Hybrid Administration Console | Window title |
| `DatabasePath` | `data/AdminConsole.db` | SQLite file that holds roles, audit, approvals, schedules and alerts |
| `Sources.ActiveDirectory` / `EntraID` / `ExchangeOnline` | `true` | Set one to `false` if you do not have that source (for example a cloud-only tenant). Lookups skip it and its actions grey out. |
| `RequireApprovals` | `false` | Turn on two-person approval for actions marked `RequiresApproval` (and show the Approvals tab). Off by default for single-admin shops. |
| `AllowSelfApproval` | `false` | Let people approve their own requests (not recommended) |
| `ApprovalExpiryHours` | `24` | Pending requests expire after this long, and approved requests must be used within it |
| `DisabledUsersOU` | | Target of *Move to Disabled OU* |
| `DisabledComputersOU` | | Target of *Move Computer to Disabled OU* |
| `ReportOutputFolder` | `output/reports` | Default folder for scheduled report files |
| `DefaultReportPeriod` | `D30` | Available to reports through `Get-ConsoleSetting` |
| `Notifications.DropFolder` | `output/notifications` | Every notification is written here as JSON |
| `Notifications.WebhookUrl` | | If set, notifications are also POSTed as `{ "text": "..." }`. This works with a Teams *Workflows* webhook, a Slack incoming webhook or a Power Automate HTTP trigger. |
| `Graph.TenantId` | | Your tenant ID or domain |
| `Graph.ClientId` + `Graph.CertificateThumbprint` | | App-only sign-in. Required for unattended jobs that touch Graph. |
| `Graph.Scopes` | (list) | Delegated scopes requested for interactive sign-in |
| `Exchange.Organization` + `Exchange.AppId` + `Exchange.CertificateThumbprint` | | App-only sign-in for Exchange Online (`contoso.onmicrosoft.com`) |
| `EntraConnect.Server` | `sm-adfs01` | Server where **Run Entra Connect Sync** runs `Start-ADSyncSyncCycle -PolicyType Delta`, over PowerShell remoting. The operator needs WinRM access and admin rights (or the ADSyncOperators group) on it. |
| `EntraConnect.WaitSeconds` | `300` | How long to wait for the sync cycle to finish before moving on |
| `OneDriveArchive.TeamName` | *(blank)* | Team that holds the archive channel. Leave it blank to search every team for the channel below. A team with the same name as the channel is checked first, and if it has no channel by that name its General channel is used. |
| `OneDriveArchive.ChannelName` | `IT Infrastructure` | Channel whose Files hold the archive |
| `OneDriveArchive.Folder` | `OneDrive Archive` | Folder in that channel. Each leaver gets a sub-folder named after them. |
| `OneDriveArchive.WaitSeconds` | `300` | How long **Archive OneDrive** waits for copies to finish. Large copies carry on in the background, and **Check status** shows when they are complete. |
| `SharePoint.AdminUrl` | *(blank)* | For example `https://contoso-admin.sharepoint.com`. When set, and the `Microsoft.Online.SharePoint.PowerShell` module is installed, **Archive OneDrive** makes you site admin of the leaver's OneDrive if you can't already read it. |
| `Offboarding.OfficeText` | `Disabled` | Value that **Set Office to Disabled** writes to the Office field |

## Offboarding permissions

The offboarding actions call Microsoft Graph with these delegated permissions. The
first time you run them you are asked to consent, which needs a Global Admin or
Privileged Role Admin:

- `UserAuthenticationMethod.ReadWrite.All` and `Policy.ReadWrite.AuthenticationMethod`: **Remove MFA Methods**
- `RoleManagement.ReadWrite.Directory`: **Remove Admin Roles**
- `GroupMember.ReadWrite.All` and `Group.ReadWrite.All`: **Remove from Teams**
- `Files.ReadWrite.All`, `Sites.ReadWrite.All`, `Team.ReadBasic.All` and `Channel.ReadBasic.All`: **Archive OneDrive**

You also need access to the leaver's OneDrive before you can archive it. Either set
`SharePoint.AdminUrl` so the console can grant it, or use app-only sign-in.

## Interactive vs app-only sign-in

When the `ClientId`/`AppId` and thumbprint settings are **blank**, the console opens
the normal Microsoft sign-in window the first time it needs Graph or Exchange. That
is fine for people using the GUI.

Scheduled jobs (`Invoke-AdminJobs.ps1`) run with no one there to sign in, so any job
that touches Graph or Exchange needs **app-only** authentication:

1. Create an app registration in Entra ID. Upload a certificate, and install the same
   certificate in the job account's certificate store.
2. Grant **application** permissions: Graph `User.Read.All`, `Device.Read.All`,
   `Reports.Read.All`, `AuditLog.Read.All` and `Organization.Read.All`, plus whatever
   your reports need. Grant admin consent.
3. For Exchange, grant `Exchange.ManageAsApp` and give the app's service principal an
   Exchange role such as *View-Only Recipients*. For write actions it needs
   *Recipient Management*.
4. Fill in the `Graph.*` and `Exchange.*` settings above.

Once these are set, the GUI uses app-only sign-in as well. Every change is still
audited under the operator's Windows account. In Entra's own logs, though, changes
appear as the app, not the operator. If you want Entra's logs to show each person,
keep the GUI on interactive sign-in and give the job runner its own copy of the
console with app-only settings.
