@{
    Name      = 'Disable AD Computer'
    Scope     = 'Computer'
    Category  = 'Active Directory'
    Order     = 10
    AppliesTo = { param($Computer) $Computer.AD -and $Computer.AD.Enabled }
    Run       = {
        param($Computer)
        Connect-ConsoleActiveDirectory
        Disable-ADAccount -Identity $Computer.AD.DistinguishedName -ErrorAction Stop
    }
}
