@{
    Name       = 'Move Computer to Disabled OU'
    Scope      = 'Computer'
    Category   = 'Active Directory'
    Order      = 20
    Permission = 'MoveComputerToDisabledOU'
    AppliesTo  = { param($Computer) [bool]$Computer.AD }
    Run        = {
        param($Computer)
        $ou = Get-ConsoleSetting 'DisabledComputersOU'
        if (-not $ou) { throw 'DisabledComputersOU is not set in Settings.' }
        Connect-ConsoleActiveDirectory
        Move-ADObject -Identity $Computer.AD.DistinguishedName -TargetPath $ou -ErrorAction Stop
        "Moved to $ou"
    }
}
