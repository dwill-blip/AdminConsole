# AdminConsole.UI
# Windows Forms front end. Requires AdminConsole.Core to be imported first.
#
# Load order: Controls.ps1, Dialogs.ps1, every file in Pages\ (each one registers a
# tab with Register-UiPage), then MainWindow.ps1.

# Module-wide: any error inside the engine, a plugin or an event handler stops that
# operation (and is reported) instead of being silently skipped.
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

. (Join-Path $PSScriptRoot 'Controls.ps1')
. (Join-Path $PSScriptRoot 'Dialogs.ps1')
foreach ($file in (Get-ChildItem -Path (Join-Path $PSScriptRoot 'Pages') -Filter '*.ps1' | Sort-Object Name)) {
    . $file.FullName
}
. (Join-Path $PSScriptRoot 'MainWindow.ps1')

Export-ModuleMember -Function *
