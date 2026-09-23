# Configuration: loads config\settings.json, merges it over built-in defaults,
# and exposes values through Get-ConsoleSetting 'Dotted.Path'.

$script:ConsoleRoot  = $null
$script:SettingsPath = $null
$script:Settings     = $null

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

function Initialize-ConsoleConfig {
    param(
        [Parameter(Mandatory)][string]$Root,
        [string]$SettingsPath
    )
    $script:ConsoleRoot = (Resolve-Path $Root).Path
    if (-not $SettingsPath) { $SettingsPath = Join-Path (Join-Path $script:ConsoleRoot 'config') 'settings.json' }
    $script:SettingsPath = $SettingsPath

    $fromFile = @{}
    if (Test-Path $SettingsPath) {
        $raw = Get-Content -Path $SettingsPath -Raw
        if ($raw.Trim()) { $fromFile = ConvertTo-ConsoleHashtable ($raw | ConvertFrom-Json) }
    }
    $script:Settings = Merge-ConsoleHashtable (Get-ConsoleDefaultSettings) $fromFile
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
    if ($script:SettingsPath -and (Test-Path $script:SettingsPath)) { return Get-Content $script:SettingsPath -Raw }
    $script:Settings | ConvertTo-Json -Depth 6
}

function Save-ConsoleSettingsJson {
    param([Parameter(Mandatory)][string]$Json)
    Assert-ConsolePermission 'ManageSettings'
    $null = $Json | ConvertFrom-Json   # throws on invalid JSON before anything is written
    Set-Content -Path $script:SettingsPath -Value $Json -Encoding UTF8
    Initialize-ConsoleConfig -Root $script:ConsoleRoot -SettingsPath $script:SettingsPath
    Write-ConsoleAudit -Action 'Save Settings' -Target 'settings.json' -Result 'Success'
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
