@{
    Name        = 'Unlock AD Account'
    Scope       = 'User'
    Category    = 'Account'
    Order       = 20
    Description = 'Clear an AD account lockout.'
    Confirm     = $false
    AppliesTo   = { param($User) [bool]$User.AD }
    Check       = { param($User) @{ Done = -not $User.AD.LockedOut; Detail = "Locked out: $($User.AD.LockedOut)" } }
    Run         = {
        param($User)
        Connect-ConsoleActiveDirectory
        Unlock-ADAccount -Identity $User.AD.DistinguishedName -ErrorAction Stop
    }
}
