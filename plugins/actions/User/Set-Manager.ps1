# Button on the Users tab. For changing managers from a report, see Rows/Change-Manager.ps1.
@{
    Name        = 'Set Manager'
    Scope       = 'User'
    Category    = 'Account'
    Order       = 70
    Description = "Set or clear the user's manager (AD for synced users, Entra ID for cloud-only)."
    Confirm     = $false
    Inputs      = @(
        @{ Name = 'Manager'; Label = 'New manager (username, UPN, email or name; blank = clear)'; Help = 'Leave blank to remove the manager.' }
    )
    GraphScopes = @('User.ReadWrite.All')
    AppliesTo   = { param($User) $User.AD -or $User.Entra }
    Run         = { param($User, $Inputs) Set-ConsoleUserManager -User $User -Manager $Inputs.Manager }
}
