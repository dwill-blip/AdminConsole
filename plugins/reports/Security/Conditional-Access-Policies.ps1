@{
    Name        = 'Conditional Access Policies'
    Description = 'Every Conditional Access policy, its state and what it requires.'
    GraphScopes = @('Policy.Read.All')
    Run         = {
        param($Params)
        Invoke-ConsoleGraph GET 'v1.0/identity/conditionalAccess/policies' -All |
            ForEach-Object {
                $u = $_.conditions.users
                [pscustomobject]@{
                    Policy        = $_.displayName
                    State         = $_.state
                    IncludeUsers  = (@($u.includeUsers) + @($u.includeGroups | ForEach-Object { "group:$_" }) + @($u.includeRoles | ForEach-Object { "role:$_" })) -join ', '
                    ExcludeUsers  = (@($u.excludeUsers) + @($u.excludeGroups | ForEach-Object { "group:$_" })) -join ', '
                    Apps          = @($_.conditions.applications.includeApplications) -join ', '
                    GrantControls = "$($_.grantControls.operator): $(@($_.grantControls.builtInControls) -join ', ')"
                    Modified      = $_.modifiedDateTime
                }
            }
    }
}
