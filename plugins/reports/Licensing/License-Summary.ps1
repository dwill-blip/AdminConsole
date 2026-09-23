@{
    Name        = 'License Summary'
    Description = 'Purchased vs assigned for every subscription - spot unused (wasted) and over-assigned licenses.'
    GraphScopes = @('Organization.Read.All')
    Run         = {
        param($Params)
        Invoke-ConsoleGraph GET 'v1.0/subscribedSkus' -All |
            ForEach-Object {
                $total = [int]$_.prepaidUnits.enabled
                [pscustomobject]@{
                    License   = $_.skuPartNumber
                    Purchased = $total
                    Assigned  = [int]$_.consumedUnits
                    Available = $total - [int]$_.consumedUnits
                    Suspended = [int]$_.prepaidUnits.suspended
                    Warning   = [int]$_.prepaidUnits.warning
                    Status    = $_.capabilityStatus
                }
            } | Sort-Object Purchased -Descending
    }
}
