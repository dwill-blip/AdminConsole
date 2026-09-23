# ReportName: AD Computers
# Description: AD computer inventory.
Ensure-AD;Get-ADComputer -Filter * -Properties OperatingSystem,Enabled,LastLogonDate|select Name,OperatingSystem,Enabled,LastLogonDate,DistinguishedName
