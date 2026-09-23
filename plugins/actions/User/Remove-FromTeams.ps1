# Removes the user from every Microsoft Team, as a member and as an owner.
@{
    Name        = 'Remove from Teams'
    Scope       = 'User'
    Category    = 'Microsoft 365'
    Order       = 20
    Danger      = $true
    GraphScopes = @('GroupMember.ReadWrite.All', 'Group.ReadWrite.All')
    AppliesTo   = { param($User) [bool]$User.Entra }
    Check       = {
        param($User)
        $t = @(Get-ConsoleUserTeams $User)
        @{ Done = ($t.Count -eq 0); Detail = "$(if ($t.Count) { "In $($t.Count) team(s): " + (($t | ForEach-Object { $_.Name }) -join ', ') } else { 'Not in any team' })" }
    }
    Run         = {
        param($User)
        $uid = $User.Entra.Id
        $removed = @(); $problems = @()
        foreach ($t in @(Get-ConsoleUserTeams $User)) {
            if ($t.Dynamic) { $problems += "$($t.Name): dynamic membership (change the rule instead)"; continue }
            if ($t.Owner) {
                try { Invoke-ConsoleGraph DELETE "v1.0/groups/$($t.Id)/owners/$uid/`$ref" | Out-Null }
                catch { $problems += "$($t.Name): could not remove as owner ($($_.Exception.Message))" }
            }
            if ($t.Member) {
                try { Invoke-ConsoleGraph DELETE "v1.0/groups/$($t.Id)/members/$uid/`$ref" | Out-Null }
                catch { $problems += "$($t.Name): could not remove as member ($($_.Exception.Message))"; continue }
            }
            $removed += $t.Name
        }
        $msg = "Removed from $($removed.Count) team(s)$(if ($removed.Count) { ': ' + ($removed -join ', ') })."
        if ($problems.Count) { throw "$msg Problems: $($problems -join '; ')" }
        $msg
    }
}
