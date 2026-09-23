@{
    Name        = 'Microsoft 365 Active Users'
    Description = 'Last activity date per user and service. (Microsoft 365 usage report; data lags about 2 days.)'
    Parameters  = @(@{ Name = 'Period'; Type = 'Choice'; Choices = @('D7', 'D30', 'D90', 'D180'); Default = 'D30'; Required = $true })
    GraphScopes = @('Reports.Read.All')
    Run         = { param($Params) Get-ConsoleGraphUsageReport 'getOffice365ActiveUserDetail' $Params.Period }
}
