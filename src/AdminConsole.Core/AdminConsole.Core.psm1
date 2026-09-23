# AdminConsole.Core
# UI-free engine: configuration, database, RBAC, approvals, audit, plugin loading,
# the action runner, reports and background jobs. Used by the GUI, by the headless
# job runner, and by the tests.
#
# Every *.ps1 file in Private\ is dot-sourced here, in name order.

# Module-wide: any error inside the engine, a plugin or an event handler stops that
# operation (and is reported) instead of being silently skipped.
$ErrorActionPreference = 'Stop'

foreach ($file in (Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' | Sort-Object Name)) {
    . $file.FullName
}

Export-ModuleMember -Function * -Variable @()
