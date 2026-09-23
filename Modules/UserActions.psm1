function Get-HybridUser($id){$r=[ordered]@{AD=$null;Entra=$null};try{Ensure-AD;$r.AD=Get-ADUser $id -Properties * -EA Stop}catch{};try{Ensure-Graph;$u=if($r.AD.UserPrincipalName){$r.AD.UserPrincipalName}else{$id};$r.Entra=Get-MgUser -UserId $u -Property Id,DisplayName,UserPrincipalName,AccountEnabled,AssignedLicenses -EA Stop}catch{};[pscustomobject]$r}
function Reset-OnPremPassword($u,$p,$c){Set-ADAccountPassword $u.DistinguishedName -Reset -NewPassword(ConvertTo-SecureString $p -AsPlainText -Force);Set-ADUser $u.DistinguishedName -ChangePasswordAtLogon $c}
function Disable-OnPremUser($u){Disable-ADAccount $u.DistinguishedName}
function Revoke-CloudSessions($u){Revoke-MgUserSignInSession -UserId $u.Id|Out-Null}
function Remove-AllUserLicenses($u){$x=@((Get-MgUserLicenseDetail -UserId $u.Id).SkuId);if($x){Set-MgUserLicense -UserId $u.Id -AddLicenses @() -RemoveLicenses $x|Out-Null}}
function Set-OffboardProfile($u){Set-ADUser $u.DistinguishedName -Office Disabled -Clear mobile}
function Remove-ADMemberships($u){$u.MemberOf|%{Remove-ADGroupMember $_ $u.DistinguishedName -Confirm:$false}}
function Export-ADMemberships($u,$p){$u.MemberOf|%{Get-ADGroup $_}|select Name,GroupScope,DistinguishedName|Export-Csv $p -NoTypeInformation}
function Move-ToDisabledOU($u,$ou){Move-ADObject $u.DistinguishedName -TargetPath $ou}
Export-ModuleMember -Function *
