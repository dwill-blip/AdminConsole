# Row action for the 'Users and Managers' (and 'AD Users') reports: right-click a row > Change Manager.
@{
    Name        = 'Change Manager'
    Scope       = 'Row'
    Category    = 'Account'
    Permission  = 'SetManager'
    Confirm     = $false
    Inputs      = @(
        @{ Name = 'Manager'; Label = 'New manager (username, UPN, email or name; blank = clear)' }
    )
    TargetName  = { param($Row) $Row.SamAccountName }
    AppliesTo   = { param($Row) [bool]$Row.SamAccountName }
    Run         = {
        param($Row, $Inputs)
        $u = Get-HybridUser -Identity $Row.SamAccountName
        $msg = Set-ConsoleUserManager -User $u -Manager $Inputs.Manager
        "$msg Re-run the report to see the change."
    }
}
