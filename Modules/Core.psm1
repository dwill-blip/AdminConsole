function Ensure-AD{Import-Module ActiveDirectory -ErrorAction Stop}
function Ensure-Graph{$s=@('User.ReadWrite.All','Device.ReadWrite.All','Directory.ReadWrite.All','UserAuthenticationMethod.ReadWrite.All','Reports.Read.All','AuditLog.Read.All','TeamMember.ReadWrite.All','Mail.Send');Import-Module Microsoft.Graph.Authentication -ErrorAction Stop;if(-not(Get-MgContext)){Connect-MgGraph -Scopes $s -NoWelcome|Out-Null}}
function Ensure-EXO{Import-Module ExchangeOnlineManagement -ErrorAction Stop;if(-not(Get-ConnectionInformation -ErrorAction SilentlyContinue)){Connect-ExchangeOnline -ShowBanner:$false}}
function Confirm-AdminAction($m){Add-Type -AssemblyName System.Windows.Forms;[Windows.Forms.MessageBox]::Show($m,'Confirm','YesNo','Warning','Button2') -eq 'Yes'}
function Show-AdminError($m,$t='Error'){Add-Type -AssemblyName System.Windows.Forms;[Windows.Forms.MessageBox]::Show($m,$t,'OK','Error')|Out-Null}
Export-ModuleMember -Function *
