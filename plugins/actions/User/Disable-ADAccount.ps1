@{
    Name        = 'Disable AD Account'
    Scope       = 'User'
    Category    = 'Account'
    Order       = 40
    Danger      = $true
    AppliesTo   = { param($User) $User.AD -and $User.AD.Enabled }
    Check       = { param($User) @{ Done = -not $User.AD.Enabled; Detail = "AD account enabled: $($User.AD.Enabled)" } }
    Run         = {
        param($User)
        Connect-ConsoleActiveDirectory
        Disable-ADAccount -Identity $User.AD.DistinguishedName -ErrorAction Stop
    }
}
