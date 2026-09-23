#requires -Version 5.1
<#
.SYNOPSIS
    Hybrid Administration Console (v8) - GUI entry point.
.DESCRIPTION
    Loads the engine (src\AdminConsole.Core), the Windows Forms UI (src\AdminConsole.UI)
    and every plugin under plugins\, then opens the main window.
    Start it with Start-AdminConsole.cmd, or:  powershell.exe -STA -File .\AdminConsole.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

# Files extracted from a downloaded zip are marked "from the internet"; Windows then
# refuses to load the bundled SQLite DLL. Clear the mark on our own folder.
if (Get-Command Unblock-File -ErrorAction SilentlyContinue) {
    Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
}

# Windows Forms needs a single-threaded apartment.
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    $exe = (Get-Process -Id $PID).Path
    Start-Process -FilePath $exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$PSCommandPath`"")
    return
}

try {
    Import-Module (Join-Path $Root 'src\AdminConsole.Core\AdminConsole.Core.psm1') -Force
    Register-ConsoleFileLog -Folder (Join-Path $Root 'logs')
    Import-Module (Join-Path $Root 'src\AdminConsole.UI\AdminConsole.UI.psm1') -Force
    Initialize-AdminConsole -Root $Root
    Show-AdminConsoleWindow
}
catch {
    $detail = "$($_.Exception.Message)`n`n$($_.ScriptStackTrace)"
    try {
        $logDir = Join-Path $Root 'logs'
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        Add-Content -Path (Join-Path $logDir 'startup-errors.log') -Value "$(Get-Date -Format s)`n$detail`n"
    }
    catch { }
    Add-Type -AssemblyName System.Windows.Forms
    [void][System.Windows.Forms.MessageBox]::Show("The console could not start:`n`n$detail`n`nRun Install-Prerequisites.ps1 if a module is missing.", 'Hybrid Administration Console', 'OK', 'Error')
    exit 1
}
finally {
    if (Get-Command Close-ConsoleDatabase -ErrorAction SilentlyContinue) { Close-ConsoleDatabase }
}
