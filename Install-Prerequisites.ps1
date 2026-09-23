# Run from elevated Windows PowerShell 5.1
$ErrorActionPreference='Stop'
$rsat='Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'
if((Get-WindowsCapability -Online -Name $rsat).State -ne 'Installed'){Add-WindowsCapability -Online -Name $rsat}
foreach($m in 'Microsoft.Graph','ExchangeOnlineManagement','PSSQLite'){
 if(-not(Get-Module -ListAvailable $m)){Install-Module $m -Scope CurrentUser -Force -AllowClobber}
}
Write-Host 'Prerequisites installed.' -ForegroundColor Green
