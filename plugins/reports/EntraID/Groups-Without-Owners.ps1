@{
    Name        = 'Groups and Teams Without Owners'
    Description = 'Microsoft 365 groups (including Teams) that have no owner - nobody to manage members or renew them.'
    GraphScopes = @('Group.Read.All')
    Run         = {
        param($Params)
        $f = [uri]::EscapeDataString("groupTypes/any(c:c eq 'Unified')")
        Invoke-ConsoleGraph GET "v1.0/groups?`$filter=$f&`$select=id,displayName,mail,visibility,createdDateTime,resourceProvisioningOptions&`$expand=owners(`$select=id)&`$top=999" -All |
            Where-Object { -not @($_.owners).Count } |
            ForEach-Object {
                [pscustomobject]@{
                    DisplayName = $_.displayName; Mail = $_.mail; Visibility = $_.visibility
                    IsTeam = (@($_.resourceProvisioningOptions) -contains 'Team'); Created = $_.createdDateTime; Id = $_.id
                }
            }
    }
}
