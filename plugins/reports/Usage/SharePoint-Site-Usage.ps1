@{
    Name        = 'SharePoint Site Usage'
    Description = 'Storage, files and last activity per SharePoint site. (Microsoft 365 usage report; data lags about 2 days.)'
    Parameters  = @(@{ Name = 'Period'; Type = 'Choice'; Choices = @('D7', 'D30', 'D90', 'D180'); Default = 'D30'; Required = $true })
    GraphScopes = @('Reports.Read.All')
    Run         = { param($Params) Get-ConsoleGraphUsageReport 'getSharePointSiteUsageDetail' $Params.Period }
}
