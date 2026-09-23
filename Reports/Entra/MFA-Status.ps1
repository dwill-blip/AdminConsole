# ReportName: MFA Registration Status
# Description: MFA registration status.
Ensure-Graph;Get-MgReportAuthenticationMethodUserRegistrationDetail -All|select UserDisplayName,UserPrincipalName,IsMfaRegistered,IsMfaCapable,MethodsRegistered
