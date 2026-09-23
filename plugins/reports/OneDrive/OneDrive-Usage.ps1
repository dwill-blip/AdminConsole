@{
    Name        = 'OneDrive Usage'
    Description = 'OneDrive storage per account (Microsoft 365 usage report; data lags about 2 days).'
    Parameters  = @(
        @{ Name = 'Period'; Label = 'Period'; Type = 'Choice'; Choices = @('D7', 'D30', 'D90', 'D180'); Default = 'D30'; Required = $true }
    )
    GraphScopes = @('Reports.Read.All')
    Run         = { param($Params) Get-ConsoleGraphUsageReport 'getOneDriveUsageAccountDetail' $Params.Period }
}
