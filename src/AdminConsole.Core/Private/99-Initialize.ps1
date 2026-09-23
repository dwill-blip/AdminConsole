# One call to get the engine ready: config -> database -> migrations -> first admin -> plugins.

function Initialize-AdminConsole {
    param(
        [Parameter(Mandatory)][string]$Root,
        [string]$SettingsPath,
        [string]$DatabasePath
    )
    Initialize-ConsoleConfig -Root $Root -SettingsPath $SettingsPath
    if (-not $DatabasePath) { $DatabasePath = Resolve-ConsolePath (Get-ConsoleSetting 'DatabasePath') }
    Open-ConsoleDatabase -Path $DatabasePath
    Update-ConsoleDatabase -MigrationsPath (Join-Path (Join-Path $script:ConsoleRoot 'database') 'migrations')
    Initialize-ConsoleBootstrapAdmin
    Import-ConsolePlugins -Path (Join-Path $script:ConsoleRoot 'plugins')
}
