# Reports

Generated from the report plugins. Right-click rows in reports marked **User** or **Computer** to run any user/computer action or workflow on that row.

## ActiveDirectory

| Report | What it shows | Parameters | Rows |
|---|---|---|---|
| Accounts Expiring Soon | Accounts with an expiry date in the next N days (contractors, temps). | Expiring within (days) | User |
| AD Computers | Active Directory computer inventory. |  | Computer |
| AD Users | All Active Directory users. Right-click a row > Change Manager to update the manager. |  | User |
| Disabled Users | All disabled user accounts, with where they live and when they last changed. |  | User |
| Disabled Users Still in Groups | Disabled accounts that still hold group memberships - leftovers from incomplete offboarding. |  | User |
| Domain Controllers | All domain controllers with site, OS, GC/RODC status and FSMO roles. |  |  |
| Empty Groups | AD groups with no members (built-in system groups excluded). |  |  |
| Expired Passwords | Enabled users whose password has already expired. |  | User |
| Group Members | Members of one AD group (optionally including nested groups). | Group name, Include nested groups | User |
| Inactive AD Users | Enabled users who have not logged on for N days (or never). | Inactive for (days) | User |
| Locked Out Users | Accounts currently locked out. Right-click a row to unlock. |  | User |
| Operating System Summary | Count of enabled computers per operating system and version - spot unsupported Windows versions. |  |  |
| Password Never Expires | Enabled users whose password is set to never expire. |  | User |
| Passwords Expiring Soon | Enabled users whose password expires in the next N days (honours fine-grained password policies). | Expiring within (days) | User |
| Privileged Group Members | Everyone in Domain/Enterprise/Schema Admins, Administrators and the operator groups (nested membership expanded). |  | User |
| Recently Created AD Users |  | Created in the last (days) | User |
| Risky Account Settings | Enabled users with settings attackers look for: no password required, Kerberos pre-auth off, reversible encryption, SPNs (Kerberoastable), unconstrained delegation. |  | User |
| Stale Computers | Enabled computer accounts that have not logged on for N days - candidates for Decommission Computer. | No logon for (days) | Computer |
| Users and Managers | Every enabled user with department, title and manager. Right-click a row > Change Manager to update it. | Only users with no manager, Department (blank = all) | User |
| Users Who Never Logged On | Enabled accounts older than N days that have never logged on. | Created more than (days) ago | User |

## EntraID

| Report | What it shows | Parameters | Rows |
|---|---|---|---|
| Directory Sync Status | When Entra Connect last synced, and whether that is overdue (normal cycle is every 30 minutes). |  |  |
| Entra Devices | All Entra ID device objects. |  | Computer |
| Groups and Teams Without Owners | Microsoft 365 groups (including Teams) that have no owner - nobody to manage members or renew them. |  |  |
| Guest Users | External (guest) accounts with invite state and last sign-in. Sign-in dates need Entra ID P1. |  | User |
| Inactive Microsoft 365 Users | Enabled accounts with no sign-in for N days (interactive or not). Needs Entra ID P1 for sign-in data. | No sign-in for (days), Include guests | User |
| MFA Registration Status | Per-user MFA registration (needs Reports.Read.All / AuditLog.Read.All). |  | User |
| Recently Created Microsoft 365 Users |  | Created in the last (days) | User |
| Stale Entra Devices | Entra ID devices with no sign-in for N days. | No sign-in for (days) | Computer |
| User Group Memberships | Every Microsoft 365 / Entra ID group one user belongs to. Filter by where the group lives (synced from AD or cloud only) and by kind (Microsoft 365, distribution, mail-enabled security, security). Right-click a row > Remove From Group, for that group or for all shown rows. | User (UPN, email or sAMAccountName), Source, Group type, Include nested groups |  |

## Exchange

| Report | What it shows | Parameters | Rows |
|---|---|---|---|
| ActiveSync Devices | Exchange Online mobile device partnerships. |  |  |
| Distribution Groups | Distribution lists, owners, and whether outside senders can mail them. |  |  |
| Inactive Mailboxes | Mailboxes kept after the user was deleted (litigation hold / retention). |  |  |
| Mailbox Forwarding | Mailboxes that forward mail - a common sign of compromise. |  | User |
| Mailbox Permissions | Full Access and Send As permissions granted to other people. Leave Mailbox blank for all mailboxes (slow in big tenants). | Mailbox (blank = all) |  |
| Mailbox Sizes | Size and item count of every mailbox, largest first. Can take several minutes in big tenants. | Mailbox type | User |
| Out of Office Enabled | User mailboxes with automatic replies on or scheduled. Slow in big tenants. |  | User |
| Shared Mailboxes | Every shared mailbox, and whether its sign-in is blocked (it should be). |  |  |

## Licensing

| Report | What it shows | Parameters | Rows |
|---|---|---|---|
| Disabled Users With Licenses | Disabled accounts that still use a license. (Shared mailboxes under 50 GB need no license.) |  | User |
| License Assignments | One row per user per license, showing whether it is direct or group-based. |  | User |
| License Summary | Purchased vs assigned for every subscription - spot unused (wasted) and over-assigned licenses. |  |  |

## OneDrive

| Report | What it shows | Parameters | Rows |
|---|---|---|---|
| OneDrive Usage | OneDrive storage per account (Microsoft 365 usage report; data lags about 2 days). | Period |  |

## Security

| Report | What it shows | Parameters | Rows |
|---|---|---|---|
| Admins Without MFA | Accounts with an admin role that have not registered MFA - highest-priority fix. |  | User |
| App Secrets and Certificates Expiring | App registration client secrets and certificates that have expired or expire within N days. | Expiring within (days) |  |
| Conditional Access Policies | Every Conditional Access policy, its state and what it requires. |  |  |
| Entra Admin Role Members | Who holds which Entra ID admin role - active and PIM-eligible (eligible needs Entra ID P2). |  | User |
| Risky Users | Users Entra ID Protection currently flags as at risk (needs Entra ID P2). |  | User |
| Users Without MFA | Enabled members who have not registered any MFA method. |  | User |

## Teams

| Report | What it shows | Parameters | Rows |
|---|---|---|---|
| Teams Inventory | Every Microsoft Team. |  |  |

## Usage

| Report | What it shows | Parameters | Rows |
|---|---|---|---|
| Mailbox Usage | Storage used, item counts and last activity per mailbox. (Microsoft 365 usage report; data lags about 2 days.) | Period |  |
| Microsoft 365 Active Users | Last activity date per user and service. (Microsoft 365 usage report; data lags about 2 days.) | Period |  |
| SharePoint Site Usage | Storage, files and last activity per SharePoint site. (Microsoft 365 usage report; data lags about 2 days.) | Period |  |
| Teams User Activity | Chats, calls and meetings per user. (Microsoft 365 usage report; data lags about 2 days.) | Period |  |

Microsoft 365 reports use Microsoft Graph; the first run asks you to consent to the read permissions they need (see each file's GraphScopes). Sign-in dates need Entra ID P1; PIM-eligible roles and Risky Users need Entra ID P2.
