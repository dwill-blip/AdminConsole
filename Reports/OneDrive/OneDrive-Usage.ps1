# ReportName: OneDrive Usage
# Description: OneDrive usage.
Ensure-Graph;$f=Join-Path $env:TEMP od.csv;Get-MgReportOneDriveUsageAccountDetail -Period $ReportFilters.Period -OutFile $f;Import-Csv $f
