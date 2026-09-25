#requires -Version 5.1
<#
.SYNOPSIS
    Copies your site's values from an earlier settings file into config\settings.local.json.
.DESCRIPTION
    Accepts a v8 config\settings.json (from an earlier install or zip) or a v7
    Config\AppConfig.json; v7 names are mapped to v8 ones (see docs\MIGRATION-FROM-V7.md).
    Values in config\settings.local.json override config\settings.json. That file is not
    in git and is not in release zips, so updates no longer overwrite your AD settings.
    Run it again to import another file; later imports win.
.EXAMPLE
    .\Import-Settings.ps1 -Path 'C:\AdminConsole-v8.3\config\settings.json'
.EXAMPLE
    .\Import-Settings.ps1 -Path 'C:\HybridAdmin\Config\AppConfig.json'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

Import-Module (Join-Path $Root 'src\AdminConsole.Core\AdminConsole.Core.psm1') -Force
Initialize-ConsoleConfig -Root $Root
$names = Import-ConsoleSettingsFile -Path $Path
Write-Host "Imported $(@($names).Count) setting(s) into config\settings.local.json:" -ForegroundColor Green
Write-Host "  $($names -join ', ')"
Write-Host 'config\settings.local.json now contains:'
Get-Content (Join-Path (Join-Path $Root 'config') 'settings.local.json')
