# ReportName: AD Users
# Description: All AD users.
# ActionType: ADUser
Ensure-AD;Get-ADUser -Filter * -Properties Enabled,Department,Office,LastLogonDate|select DisplayName,SamAccountName,UserPrincipalName,Enabled,Department,Office,LastLogonDate,DistinguishedName
