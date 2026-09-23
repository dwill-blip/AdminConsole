@{
    Name        = 'Move to Disabled OU'
    Scope       = 'User'
    Category    = 'Account'
    Order       = 50
    Description = 'Moves the AD account to the OU set in settings (DisabledUsersOU).'
    AppliesTo   = { param($User) [bool]$User.AD }
    Check       = {
        param($User)
        $ou = Get-ConsoleSetting 'DisabledUsersOU'
        @{ Done = [bool]($ou -and $User.AD.DistinguishedName -like "*,$ou"); Detail = "In: $(($User.AD.DistinguishedName -split ',', 2)[1])" }
    }
    Run         = {
        param($User)
        $ou = Get-ConsoleSetting 'DisabledUsersOU'
        if (-not $ou) { throw 'DisabledUsersOU is not set in Settings.' }
        Connect-ConsoleActiveDirectory
        try { Get-ADOrganizationalUnit -Identity $ou -ErrorAction Stop | Out-Null }
        catch { throw "The DisabledUsersOU in Settings ('$ou') does not exist in AD. Put the real OU's distinguished name on the Settings tab." }
        if ($User.AD.DistinguishedName -like "*,$ou") { return "Already in $ou" }
        Move-ADObject -Identity $User.AD.DistinguishedName -TargetPath $ou -ErrorAction Stop
        "Moved to $ou"
    }
}
