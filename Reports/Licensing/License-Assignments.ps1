# ReportName: License Assignments
# Description: Direct license assignments.
# ActionType: LicenseAssignment
Ensure-Graph;$m=@{};Get-MgSubscribedSku -All|%{$m[$_.SkuId.Guid]=$_.SkuPartNumber};foreach($u in Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AssignedLicenses){foreach($l in $u.AssignedLicenses){[pscustomobject]@{DisplayName=$u.DisplayName;UserPrincipalName=$u.UserPrincipalName;License=$m[$l.SkuId.Guid];UserId=$u.Id;SkuId=$l.SkuId}}}
