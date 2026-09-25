# Configuration: loads config\settings.json, then config\settings.local.json (your
# site's values, not in git), merges both over built-in defaults, and exposes values
# through Get-ConsoleSetting 'Dotted.Path'.

$script:ConsoleRoot       = $null
$script:SettingsPath      = $null
$script:LocalSettingsPath = $null
$script:Settings          = $null

function Get-ConsoleDefaultSettings {
    @{
        ApplicationName     = 'Hybrid Administration Console'
        DatabasePath        = 'data/AdminConsole.db'
        Sources             = @{ ActiveDirectory = $true; EntraID = $true; ExchangeOnline = $true }
        RequireApprovals    = $false
        AllowSelfApproval   = $false
        ApprovalExpiryHours = 24
        DisabledUsersOU     = ''
        DisabledComputersOU = ''
        ReportOutputFolder  = 'output/reports'
        DefaultReportPeriod = 'D30'
        Notifications       = @{ DropFolder = 'output/notifications'; WebhookUrl = '' }
        Graph               = @{ TenantId = ''; ClientId = ''; CertificateThumbprint = ''; Scopes = @('User.ReadWrite.All', 'Device.ReadWrite.All', 'Directory.ReadWrite.All', 'Reports.Read.All') }
        Exchange            = @{ Organization = ''; AppId = ''; CertificateThumbprint = '' }
        EntraConnect        = @{ Server = 'sm-adfs01'; WaitSeconds = 300 }
        OneDriveArchive     = @{ TeamName = ''; ChannelName = 'IT Infrastructure'; Folder = 'OneDrive Archive'; WaitSeconds = 300 }
        SharePoint          = @{ AdminUrl = '' }
        Offboarding         = @{ OfficeText = 'Disabled' }
    }
}

function ConvertTo-ConsoleHashtable {
    # ConvertFrom-Json returns PSCustomObjects on Windows PowerShell 5.1 (no -AsHashtable).
    param($InputObject)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $h = @{}
        foreach ($k in $InputObject.Keys) { $h[$k] = ConvertTo-ConsoleHashtable $InputObject[$k] }
        return $h
    }
    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $h = @{}
        foreach ($p in $InputObject.PSObject.Properties) { $h[$p.Name] = ConvertTo-ConsoleHashtable $p.Value }
        return $h
    }
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        return , @($InputObject | ForEach-Object { ConvertTo-ConsoleHashtable $_ })
    }
    return $InputObject
}

function Merge-ConsoleHashtable {
    param([hashtable]$Base, [hashtable]$Override)
    $result = @{}
    foreach ($k in $Base.Keys) { $result[$k] = $Base[$k] }
    if ($Override) {
        foreach ($k in $Override.Keys) {
            if ($result[$k] -is [hashtable] -and $Override[$k] -is [hashtable]) {
                $result[$k] = Merge-ConsoleHashtable $result[$k] $Override[$k]
            }
            else { $result[$k] = $Override[$k] }
        }
    }
    $result
}

function Read-ConsoleSettingsFile {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { return @{} }
    $raw = Get-Content -Path $Path -Raw
    if (-not $raw -or -not $raw.Trim()) { return @{} }
    ConvertTo-ConsoleHashtable ($raw | ConvertFrom-Json)
}

function Initialize-ConsoleConfig {
    param(
        [Parameter(Mandatory)][string]$Root,
        [string]$SettingsPath
    )
    $script:ConsoleRoot = (Resolve-Path $Root).Path
    if (-not $SettingsPath) { $SettingsPath = Join-Path (Join-Path $script:ConsoleRoot 'config') 'settings.json' }
    $script:SettingsPath = $SettingsPath
    $script:LocalSettingsPath = Join-Path (Split-Path -Parent $SettingsPath) 'settings.local.json'

    # First start after upgrading from v7: pick up the old Config\AppConfig.json once.
    if (-not (Test-Path $script:LocalSettingsPath)) {
        $legacy = foreach ($dir in 'config', 'Config') {
            $candidate = Join-Path (Join-Path $script:ConsoleRoot $dir) 'AppConfig.json'
            if (Test-Path $candidate) { $candidate; break }
        }
        if ($legacy) { $null = Import-ConsoleSettingsFile -Path $legacy -NoReload }
    }

    $merged = Merge-ConsoleHashtable (Get-ConsoleDefaultSettings) (Read-ConsoleSettingsFile $SettingsPath)
    $script:Settings = Merge-ConsoleHashtable $merged (Read-ConsoleSettingsFile $script:LocalSettingsPath)
}

function ConvertFrom-ConsoleV7Settings {
    # Maps a v7 Config\AppConfig.json onto v8 names (see docs\MIGRATION-FROM-V7.md).
    # Anything that is not a v7 file is returned unchanged.
    param([Parameter(Mandatory)][hashtable]$Settings)
    $v7Keys = 'Version', 'SeedDatabase', 'NotificationDropFolder', 'ScheduledReportOutputFolder'
    if (-not @($v7Keys | Where-Object { $Settings.ContainsKey($_) })) { return $Settings }

    $out = @{}
    foreach ($k in $Settings.Keys) { $out[$k] = $Settings[$k] }
    # v8 uses a new database; the v7 one is not reused.
    foreach ($k in 'Version', 'SeedDatabase', 'DatabasePath') { $out.Remove($k) }
    if ($out.ContainsKey('NotificationDropFolder')) {
        $out['Notifications'] = @{ DropFolder = $out['NotificationDropFolder'] }
        $out.Remove('NotificationDropFolder')
    }
    if ($out.ContainsKey('ScheduledReportOutputFolder')) {
        $out['ReportOutputFolder'] = $out['ScheduledReportOutputFolder']
        $out.Remove('ScheduledReportOutputFolder')
    }
    $out
}

function Get-ConsoleSettingsDifference {
    # The parts of $Settings whose values differ from $Baseline (nested hashtables are
    # compared key by key; other values by their JSON form).
    param([hashtable]$Settings, [hashtable]$Baseline)
    $diff = @{}
    foreach ($k in $Settings.Keys) {
        $value = $Settings[$k]
        $base = if ($Baseline -and $Baseline.ContainsKey($k)) { $Baseline[$k] } else { $null }
        if ($value -is [hashtable] -and $base -is [hashtable]) {
            $sub = Get-ConsoleSettingsDifference $value $base
            if ($sub.Count) { $diff[$k] = $sub }
        }
        elseif ($null -eq $base -or (ConvertTo-Json @(, $value) -Depth 6 -Compress) -ne (ConvertTo-Json @(, $base) -Depth 6 -Compress)) {
            $diff[$k] = $value
        }
    }
    $diff
}

function Import-ConsoleSettingsFile {
    <#
    .SYNOPSIS  Copies your values from an earlier settings file (a v8 settings.json or a
               v7 AppConfig.json) into config\settings.local.json. Values that match
               the shipped config\settings.json are skipped, so later updates to it
               still apply.
    .OUTPUTS   The names of the settings that were imported.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$NoReload
    )
    if (-not $script:LocalSettingsPath) { throw 'Call Initialize-ConsoleConfig first.' }
    if (-not (Test-Path $Path)) { throw "Settings file not found: $Path" }
    $source = (Resolve-Path $Path).Path
    if ($source -eq (Resolve-Path $script:LocalSettingsPath -ErrorAction SilentlyContinue).Path) {
        throw 'That is already the local settings file.'
    }

    $shipped = Merge-ConsoleHashtable (Get-ConsoleDefaultSettings) (Read-ConsoleSettingsFile $script:SettingsPath)
    $imported = Get-ConsoleSettingsDifference (ConvertFrom-ConsoleV7Settings (Read-ConsoleSettingsFile $source)) $shipped
    $local = Merge-ConsoleHashtable (Read-ConsoleSettingsFile $script:LocalSettingsPath) $imported
    $local | ConvertTo-Json -Depth 6 | Set-Content -Path $script:LocalSettingsPath -Encoding UTF8
    if (-not $NoReload) { Initialize-ConsoleConfig -Root $script:ConsoleRoot -SettingsPath $script:SettingsPath }
    Write-ConsoleLog -Message "Imported settings from $source into $($script:LocalSettingsPath)"
    @($imported.Keys | Sort-Object)
}

function Get-ConsoleRoot { $script:ConsoleRoot }

function Get-ConsoleSetting {
    <#
    .SYNOPSIS  Reads a setting. Nested values use dots: Get-ConsoleSetting 'Graph.ClientId'
    #>
    param([Parameter(Mandatory)][string]$Name, $Default = $null)
    $node = $script:Settings
    foreach ($part in $Name.Split('.')) {
        if ($node -is [hashtable] -and $node.ContainsKey($part)) { $node = $node[$part] }
        else { return $Default }
    }
    if ($null -eq $node -or ($node -is [string] -and $node -eq '')) {
        if ($null -ne $Default) { return $Default }
    }
    $node
}

function Set-ConsoleSetting {
    # In-memory only (used by tests and by callers that want a temporary override).
    param([Parameter(Mandatory)][string]$Name, $Value)
    $parts = $Name.Split('.')
    $node = $script:Settings
    for ($i = 0; $i -lt $parts.Count - 1; $i++) {
        if (-not ($node[$parts[$i]] -is [hashtable])) { $node[$parts[$i]] = @{} }
        $node = $node[$parts[$i]]
    }
    $node[$parts[-1]] = $Value
}

function Get-ConsoleSettingsJson {
    # The Settings tab edits settings.local.json, so your values survive updates to
    # settings.json. Until that file exists it starts from settings.json.
    foreach ($path in $script:LocalSettingsPath, $script:SettingsPath) {
        if ($path -and (Test-Path $path)) { return Get-Content $path -Raw }
    }
    $script:Settings | ConvertTo-Json -Depth 6
}

function Save-ConsoleSettingsJson {
    param([Parameter(Mandatory)][string]$Json)
    Assert-ConsolePermission 'ManageSettings'
    $null = $Json | ConvertFrom-Json   # throws on invalid JSON before anything is written
    Set-Content -Path $script:LocalSettingsPath -Value $Json -Encoding UTF8
    Initialize-ConsoleConfig -Root $script:ConsoleRoot -SettingsPath $script:SettingsPath
    Write-ConsoleAudit -Action 'Save Settings' -Target 'settings.local.json' -Result 'Success'
}

function Resolve-ConsolePath {
    # Relative paths in settings are relative to the console root folder.
    param([Parameter(Mandatory)][string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    [System.IO.Path]::GetFullPath((Join-Path $script:ConsoleRoot $Path))
}

function Test-ConsoleSource {
    # Is a directory source (ActiveDirectory / EntraID / ExchangeOnline) enabled in settings?
    param([Parameter(Mandatory)][ValidateSet('ActiveDirectory', 'EntraID', 'ExchangeOnline')][string]$Source)
    [bool](Get-ConsoleSetting "Sources.$Source" $true)
}
