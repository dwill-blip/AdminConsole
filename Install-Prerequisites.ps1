#requires -Version 5.1
<#
.SYNOPSIS
    Installs what the console needs. Run once from an ELEVATED Windows PowerShell.
.DESCRIPTION
    - RSAT Active Directory module (Windows client capability or Windows Server feature)
    - The Microsoft Graph sub-modules the plugins use (not the whole 40-module SDK)
    - ExchangeOnlineManagement
    (The SQLite driver is bundled in lib\PSSQLite, so it is not installed here.)
    Use -Skip to leave out a source you do not use, e.g. -Skip ActiveDirectory for cloud-only tenants.
#>
[CmdletBinding()]
param(
    [ValidateSet('ActiveDirectory', 'Graph', 'Exchange', 'SharePoint')]
    [string[]]$Skip = @()
)
$ErrorActionPreference = 'Stop'

function Install-IfMissing([string]$Name) {
    if (Get-Module -ListAvailable -Name $Name) { Write-Host "  [ok]      $Name" -ForegroundColor DarkGreen; return }
    Write-Host "  [install] $Name" -ForegroundColor Cyan
    Install-Module -Name $Name -Scope AllUsers -Force -AllowClobber -Repository PSGallery
}

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
}
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# The SQLite driver (PSSQLite) is bundled in lib\PSSQLite - nothing to install for it.

if ($Skip -notcontains 'ActiveDirectory') {
    Write-Host 'Active Directory (RSAT)'
    if (Get-Module -ListAvailable ActiveDirectory) { Write-Host '  [ok]      ActiveDirectory' -ForegroundColor DarkGreen }
    elseif ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
        Add-WindowsCapability -Online -Name 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0' | Out-Null
    }
    else {
        Install-WindowsFeature -Name RSAT-AD-PowerShell | Out-Null
    }
}

if ($Skip -notcontains 'Graph') {
    Write-Host 'Microsoft Graph'
    foreach ($m in 'Microsoft.Graph.Authentication', 'Microsoft.Graph.Users', 'Microsoft.Graph.Users.Actions',
        'Microsoft.Graph.Identity.DirectoryManagement', 'Microsoft.Graph.Reports', 'Microsoft.Graph.Teams') {
        Install-IfMissing $m
    }
}

if ($Skip -notcontains 'Exchange') {
    Write-Host 'Exchange Online'
    Install-IfMissing 'ExchangeOnlineManagement'
}

if ($Skip -notcontains 'SharePoint') {
    # Optional: lets 'Archive OneDrive' give you access to a leaver's OneDrive (SharePoint.AdminUrl setting).
    Write-Host 'SharePoint Online (optional)'
    Install-IfMissing 'Microsoft.Online.SharePoint.PowerShell'
}

Write-Host "`nDone. Next: edit config\settings.json, then run Start-AdminConsole.cmd." -ForegroundColor Green
