@{
    Name        = 'Enable AD Account'
    Scope       = 'User'
    Category    = 'Account'
    Order       = 30
    AppliesTo   = { param($User) $User.AD -and -not $User.AD.Enabled }
    Run         = {
        param($User)
        Connect-ConsoleActiveDirectory
        Enable-ADAccount -Identity $User.AD.DistinguishedName -ErrorAction Stop
    }
}
