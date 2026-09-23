# Microsoft Teams helpers.

function Get-ConsoleUserTeams {
    <# Teams the user is a member and/or owner of: Id, Name, Member, Owner, Dynamic. #>
    param([Parameter(Mandatory)]$User)
    $uid = $User.Entra.Id
    $isTeam = { $_.'@odata.type' -eq '#microsoft.graph.group' -and @($_.resourceProvisioningOptions) -contains 'Team' }
    $byId = [ordered]@{}
    foreach ($g in @(Invoke-ConsoleGraph GET "v1.0/users/$uid/memberOf" -All | Where-Object $isTeam)) {
        $byId[$g.id] = [pscustomobject]@{ Id = $g.id; Name = $g.displayName; Member = $true; Owner = $false; Dynamic = (@($g.groupTypes) -contains 'DynamicMembership') }
    }
    foreach ($g in @(Invoke-ConsoleGraph GET "v1.0/users/$uid/ownedObjects" -All | Where-Object $isTeam)) {
        if ($byId.Contains($g.id)) { $byId[$g.id].Owner = $true }
        else { $byId[$g.id] = [pscustomobject]@{ Id = $g.id; Name = $g.displayName; Member = $false; Owner = $true; Dynamic = (@($g.groupTypes) -contains 'DynamicMembership') } }
    }
    @($byId.Values)
}
