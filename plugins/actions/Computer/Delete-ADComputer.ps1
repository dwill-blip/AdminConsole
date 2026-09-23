# -Recursive also removes child objects (BitLocker recovery info, etc.), which is
# what makes a plain Remove-ADComputer fail on many machines.
@{
    Name             = 'Delete AD Computer'
    Scope            = 'Computer'
    Category         = 'Active Directory'
    Order            = 90
    Danger           = $true
    RequiresApproval = $true
    AppliesTo        = { param($Computer) [bool]$Computer.AD }
    Run              = {
        param($Computer)
        Connect-ConsoleActiveDirectory
        Remove-ADObject -Identity $Computer.AD.DistinguishedName -Recursive -Confirm:$false -ErrorAction Stop
    }
}
