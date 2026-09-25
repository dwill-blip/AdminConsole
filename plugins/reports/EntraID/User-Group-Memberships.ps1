@{
    Name        = 'User Group Memberships'
    Description = 'Every Microsoft 365 / Entra ID group one user belongs to. Filter by where the group lives (synced from AD or cloud only) and by kind (Microsoft 365, distribution, mail-enabled security, security).'
    GraphScopes = @('User.Read.All', 'GroupMember.Read.All')
    Parameters  = @(
        @{ Name = 'User'; Label = 'User (UPN, email or sAMAccountName)'; Required = $true }
        @{ Name = 'Source'; Label = 'Source'; Type = 'Choice'; Choices = @('All', 'Synced from AD', 'Cloud only'); Default = 'All'; Required = $true
            Help = 'Synced from AD = hybrid groups managed in Active Directory. Cloud only = groups created in Microsoft 365 / Entra ID.' }
        @{ Name = 'GroupType'; Label = 'Group type'; Type = 'Choice'; Choices = @('All', 'Microsoft 365', 'Distribution', 'Mail-enabled security', 'Security'); Default = 'All'; Required = $true
            Help = 'Distribution and Mail-enabled security groups have an email address. Security groups do not.' }
        @{ Name = 'IncludeNested'; Label = 'Include nested groups'; Type = 'Bool'; Default = $false }
    )
    Run         = {
        param($Params)
        $who = "$($Params.User)".Trim()
        $user = $null
        if ($who -match '@|^[0-9a-fA-F-]{36}$') {
            $user = Invoke-ConsoleGraph GET "v1.0/users/$([uri]::EscapeDataString($who))?`$select=id,userPrincipalName" -AllowNotFound
        }
        if (-not $user) {
            # Not a UPN or object ID: try the email address, then the on-premises logon name.
            $q = $who.Replace("'", "''")
            $f = [uri]::EscapeDataString("mail eq '$q' or proxyAddresses/any(p:p eq 'smtp:$q') or onPremisesSamAccountName eq '$q'")
            $user = @(Invoke-ConsoleGraph GET "v1.0/users?`$filter=$f&`$select=id,userPrincipalName&`$count=true" -All -Headers @{ ConsistencyLevel = 'eventual' }) | Select-Object -First 1
        }
        if (-not $user) { throw "No Microsoft 365 user found for '$who'." }

        $select = 'id,displayName,mail,description,groupTypes,mailEnabled,securityEnabled,onPremisesSyncEnabled,onPremisesLastSyncDateTime,membershipRule,resourceProvisioningOptions'
        $direct = @(Invoke-ConsoleGraph GET "v1.0/users/$($user.id)/memberOf/microsoft.graph.group?`$select=$select&`$top=999" -All)
        $groups = $direct
        if ($Params.IncludeNested) {
            $groups = @(Invoke-ConsoleGraph GET "v1.0/users/$($user.id)/transitiveMemberOf/microsoft.graph.group?`$select=$select&`$top=999" -All)
        }
        $directIds = @{}
        foreach ($g in $direct) { $directIds[$g.id] = $true }

        $rows = foreach ($g in $groups) {
            $type = if (@($g.groupTypes) -contains 'Unified') { 'Microsoft 365' }
            elseif ($g.mailEnabled -and $g.securityEnabled) { 'Mail-enabled security' }
            elseif ($g.mailEnabled) { 'Distribution' }
            elseif ($g.securityEnabled) { 'Security' }
            else { 'Other' }
            $source = if ($g.onPremisesSyncEnabled) { 'Synced from AD' } else { 'Cloud only' }

            if ($Params.Source -and $Params.Source -ne 'All' -and $source -ne $Params.Source) { continue }
            if ($Params.GroupType -and $Params.GroupType -ne 'All' -and $type -ne $Params.GroupType) { continue }

            [pscustomobject]@{
                Group       = $g.displayName
                Type        = $type
                Source      = $source
                Mail        = $g.mail
                Membership  = $(if ($directIds.ContainsKey($g.id)) { 'Direct' } else { 'Nested' })
                Dynamic     = [bool]$g.membershipRule
                IsTeam      = (@($g.resourceProvisioningOptions) -contains 'Team')
                LastSynced  = $g.onPremisesLastSyncDateTime
                Description = $g.description
                User        = $user.userPrincipalName
                Id          = $g.id
            }
        }
        $rows | Sort-Object Source, Type, Group
    }
}
