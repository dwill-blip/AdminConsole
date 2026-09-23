@{
    Name        = 'Risky Users'
    Description = 'Users Entra ID Protection currently flags as at risk (needs Entra ID P2).'
    GraphScopes = @('IdentityRiskyUser.Read.All')
    RowType     = 'User'
    RowKey      = 'UserPrincipalName'
    Run         = {
        param($Params)
        $f = [uri]::EscapeDataString("riskState eq 'atRisk'")
        Invoke-ConsoleGraph GET "v1.0/identityProtection/riskyUsers?`$filter=$f" -All |
            ForEach-Object {
                [pscustomobject]@{
                    DisplayName = $_.userDisplayName; UserPrincipalName = $_.userPrincipalName
                    RiskLevel = $_.riskLevel; RiskDetail = $_.riskDetail; LastUpdated = $_.riskLastUpdatedDateTime
                }
            }
    }
}
