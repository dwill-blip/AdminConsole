# Connections to Active Directory, Microsoft Graph (Entra ID) and Exchange Online,
# plus the "hybrid" lookups that the Users and Computers pages use as targets.
#
# Graph and Exchange use app-only (certificate) auth when ClientId/AppId and a
# CertificateThumbprint are set in settings - required for unattended jobs.
# Otherwise they fall back to an interactive sign-in.

function Connect-ConsoleActiveDirectory {
    if (-not (Test-ConsoleSource 'ActiveDirectory')) { throw 'Active Directory is disabled in settings (Sources.ActiveDirectory).' }
    if (-not (Get-Module ActiveDirectory)) { Import-Module ActiveDirectory -ErrorAction Stop -Verbose:$false }
}

function Get-ConsoleGraphScopes {
    # Scopes from settings plus every GraphScopes declared by a loaded plugin, so a new
    # plugin that needs a new permission asks for it automatically.
    $all = @(Get-ConsoleSetting 'Graph.Scopes' @())
    foreach ($d in @(Get-ConsoleAction) + @(Get-ConsoleReport)) {
        if ($d -and $d.PSObject.Properties['GraphScopes']) { $all += @($d.GraphScopes) }
    }
    @($all | Where-Object { $_ } | Sort-Object -Unique)
}

function Connect-ConsoleGraph {
    if (-not (Test-ConsoleSource 'EntraID')) { throw 'Entra ID is disabled in settings (Sources.EntraID).' }
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop -Verbose:$false
    $clientId = Get-ConsoleSetting 'Graph.ClientId'
    $thumb    = Get-ConsoleSetting 'Graph.CertificateThumbprint'
    $tenant   = Get-ConsoleSetting 'Graph.TenantId'
    $appOnly  = [bool]($clientId -and $thumb -and $tenant)
    $ctx = Get-MgContext
    $scopes = Get-ConsoleGraphScopes
    if ($ctx) {
        if ($appOnly -or "$($ctx.AuthType)" -ne 'Delegated') { return }
        $missing = @($scopes | Where-Object { @($ctx.Scopes) -notcontains $_ })
        if (-not $missing.Count) { return }
        Write-ConsoleLog "Graph needs additional permissions ($($missing -join ', ')) - signing in again."
    }
    if ($appOnly) {
        Connect-MgGraph -ClientId $clientId -CertificateThumbprint $thumb -TenantId $tenant -NoWelcome -ErrorAction Stop | Out-Null
    }
    else {
        $p = @{ Scopes = $scopes; NoWelcome = $true; ErrorAction = 'Stop' }
        if ($tenant) { $p.TenantId = $tenant }
        Connect-MgGraph @p | Out-Null
    }
    Write-ConsoleLog "Connected to Microsoft Graph as $((Get-MgContext).Account)$((Get-MgContext).AppName)"
}

function Invoke-ConsoleGraph {
    <#
    .SYNOPSIS  Calls the Graph REST API directly (no extra Graph sub-modules needed).
    .EXAMPLE   Invoke-ConsoleGraph GET "v1.0/users/$id/authentication/methods" -All
    .EXAMPLE   Invoke-ConsoleGraph DELETE "v1.0/groups/$g/members/$u/`$ref"
    .NOTES     -All follows @odata.nextLink and returns the items of 'value'.
               404 returns $null when -AllowNotFound is set.
    #>
    param(
        [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'PATCH', 'PUT', 'DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        $Body,
        [switch]$All,
        [switch]$AllowNotFound,
        [hashtable]$Headers
    )
    Connect-ConsoleGraph
    $p = @{ Method = $Method; Uri = $Uri; OutputType = 'PSObject'; ErrorAction = 'Stop' }
    if ($null -ne $Body) { $p.Body = ($Body | ConvertTo-Json -Depth 10); $p.ContentType = 'application/json' }
    if ($Headers) { $p.Headers = $Headers }
    try {
        $r = Invoke-MgGraphRequest @p
    }
    catch {
        if ($AllowNotFound -and "$($_.Exception.Message)$($_.ErrorDetails)" -match 'NotFound|404|ResourceNotFound|itemNotFound') { return $null }
        throw
    }
    if (-not $All) { return $r }
    while ($true) {
        foreach ($item in @($r.value)) { if ($null -ne $item) { $item } }
        $next = $r.'@odata.nextLink'
        if (-not $next) { break }
        $r = Invoke-MgGraphRequest -Method GET -Uri $next -OutputType PSObject -ErrorAction Stop
    }
}

function Connect-ConsoleExchange {
    if (-not (Test-ConsoleSource 'ExchangeOnline')) { throw 'Exchange Online is disabled in settings (Sources.ExchangeOnline).' }
    Import-Module ExchangeOnlineManagement -ErrorAction Stop -Verbose:$false
    $existing = @(Get-ConnectionInformation -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Connected' })
    if ($existing.Count) { return }
    $appId = Get-ConsoleSetting 'Exchange.AppId'
    $thumb = Get-ConsoleSetting 'Exchange.CertificateThumbprint'
    $org   = Get-ConsoleSetting 'Exchange.Organization'
    if ($appId -and $thumb -and $org) {
        Connect-ExchangeOnline -AppId $appId -CertificateThumbprint $thumb -Organization $org -ShowBanner:$false -ErrorAction Stop
    }
    else {
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
    }
    Write-ConsoleLog 'Connected to Exchange Online'
}

function ConvertTo-FilterLiteral { param([string]$Value) $Value.Replace("'", "''") }

function Get-HybridUser {
    <#
    .SYNOPSIS  Looks a user up in AD and Entra ID. Accepts sAMAccountName, UPN or email.
    .OUTPUTS   Identity, DisplayName, SamAccountName, UserPrincipalName, Enabled, AD, Entra, Warnings
    #>
    param([Parameter(Mandatory)][string]$Identity)
    $Identity = $Identity.Trim()
    $warnings = New-Object System.Collections.ArrayList
    $ad = $null; $entra = $null

    if (Test-ConsoleSource 'ActiveDirectory') {
        try {
            Connect-ConsoleActiveDirectory
            $props = 'DisplayName', 'UserPrincipalName', 'Enabled', 'LockedOut', 'MemberOf', 'Department', 'Title', 'Office', 'LastLogonDate', 'PasswordLastSet', 'mail', 'mobile', 'Manager'
            if ($Identity -like '*@*') {
                $f = ConvertTo-FilterLiteral $Identity
                $ad = Get-ADUser -Filter "UserPrincipalName -eq '$f' -or mail -eq '$f'" -Properties $props -ErrorAction Stop | Select-Object -First 1
            }
            else {
                $ad = Get-ADUser -Identity $Identity -Properties $props -ErrorAction Stop
            }
            if (-not $ad) { [void]$warnings.Add('AD: no matching user') }
        }
        catch { [void]$warnings.Add("AD: $($_.Exception.Message)") }
    }

    if (Test-ConsoleSource 'EntraID') {
        try {
            Connect-ConsoleGraph
            $upn = $Identity
            if ($ad -and $ad.UserPrincipalName) { $upn = $ad.UserPrincipalName }
            $entra = Get-MgUser -UserId $upn -Property 'Id,DisplayName,UserPrincipalName,AccountEnabled,AssignedLicenses,Mail,OnPremisesSyncEnabled,JobTitle,Department,MobilePhone,OfficeLocation,SignInSessionsValidFromDateTime' -ErrorAction Stop
        }
        catch { [void]$warnings.Add("Entra ID: $($_.Exception.Message)") }
    }

    if (-not $ad -and -not $entra) { throw "User '$Identity' was not found.`n$($warnings -join "`n")" }

    $upnOut = $null; $display = $null; $enabled = $null
    if ($ad) { $upnOut = $ad.UserPrincipalName; $display = $ad.DisplayName; $enabled = $ad.Enabled }
    if ($entra) {
        if (-not $upnOut) { $upnOut = $entra.UserPrincipalName }
        if (-not $display) { $display = $entra.DisplayName }
        if ($null -eq $enabled) { $enabled = $entra.AccountEnabled }
    }
    $sam = $null
    if ($ad) { $sam = $ad.SamAccountName }
    $key = $upnOut
    if (-not $key) { $key = $sam }

    [pscustomobject]@{
        PSTypeName        = 'AdminConsole.HybridUser'
        Identity          = $key
        DisplayName       = $display
        SamAccountName    = $sam
        UserPrincipalName = $upnOut
        Enabled           = $enabled
        AD                = $ad
        Entra             = $entra
        Warnings          = @($warnings)
    }
}

function Get-HybridComputer {
    <#
    .SYNOPSIS  Looks a computer up in AD and Entra ID by name. Entra can hold several devices with one name.
    #>
    param([Parameter(Mandatory)][string]$Name)
    $Name = $Name.Trim()
    $warnings = New-Object System.Collections.ArrayList
    $ad = $null; $entra = @()

    if (Test-ConsoleSource 'ActiveDirectory') {
        try {
            Connect-ConsoleActiveDirectory
            $ad = Get-ADComputer -Identity $Name -Properties OperatingSystem, OperatingSystemVersion, Enabled, LastLogonDate, Description, IPv4Address -ErrorAction Stop
        }
        catch { [void]$warnings.Add("AD: $($_.Exception.Message)") }
    }
    if (Test-ConsoleSource 'EntraID') {
        try {
            Connect-ConsoleGraph
            $entra = @(Get-MgDevice -Filter "displayName eq '$(ConvertTo-FilterLiteral $Name)'" -All -ErrorAction Stop)
            if (-not $entra.Count) { [void]$warnings.Add('Entra ID: no device with that name') }
        }
        catch { [void]$warnings.Add("Entra ID: $($_.Exception.Message)") }
    }
    if (-not $ad -and -not $entra.Count) { throw "Computer '$Name' was not found.`n$($warnings -join "`n")" }

    [pscustomobject]@{
        PSTypeName = 'AdminConsole.HybridComputer'
        Identity   = $Name
        Name       = $Name
        AD         = $ad
        Entra      = $entra
        Warnings   = @($warnings)
    }
}

function Get-ConsoleTargetSummary {
    # Flat name/value pairs describing a target, for the details panel.
    param([Parameter(Mandatory)]$Target)
    $out = [ordered]@{}
    if ($Target.PSObject.TypeNames -contains 'AdminConsole.HybridUser') {
        $out['Display name'] = $Target.DisplayName
        $out['UPN'] = $Target.UserPrincipalName
        $out['sAMAccountName'] = $Target.SamAccountName
        $out['Enabled'] = $Target.Enabled
        $out['In AD'] = [bool]$Target.AD
        $out['In Entra ID'] = [bool]$Target.Entra
        if ($Target.AD) {
            $out['Locked out'] = $Target.AD.LockedOut
            $out['Department'] = $Target.AD.Department
            $out['Title'] = $Target.AD.Title
            $out['Manager'] = ConvertFrom-ConsoleDn $Target.AD.Manager
            $out['Office'] = $Target.AD.Office
            $out['Mobile'] = $Target.AD.mobile
            $out['Last logon'] = $Target.AD.LastLogonDate
            $out['Password last set'] = $Target.AD.PasswordLastSet
            $out['Group count'] = @($Target.AD.MemberOf).Count
            $out['DN'] = $Target.AD.DistinguishedName
        }
        if ($Target.Entra) {
            $out['Entra object id'] = $Target.Entra.Id
            $out['Licenses'] = @($Target.Entra.AssignedLicenses).Count
            $out['Synced from AD'] = $Target.Entra.OnPremisesSyncEnabled
        }
    }
    elseif ($Target.PSObject.TypeNames -contains 'AdminConsole.HybridComputer') {
        $out['Name'] = $Target.Name
        $out['In AD'] = [bool]$Target.AD
        $out['Entra devices'] = @($Target.Entra).Count
        if ($Target.AD) {
            $out['Enabled'] = $Target.AD.Enabled
            $out['OS'] = "$($Target.AD.OperatingSystem) $($Target.AD.OperatingSystemVersion)"
            $out['Last logon'] = $Target.AD.LastLogonDate
            $out['IPv4'] = $Target.AD.IPv4Address
            $out['DN'] = $Target.AD.DistinguishedName
        }
        $i = 0
        foreach ($d in @($Target.Entra)) {
            $i++
            $out["Entra device $i"] = "$($d.OperatingSystem) | trust: $($d.TrustType) | enabled: $($d.AccountEnabled) | id: $($d.Id)"
        }
    }
    else {
        foreach ($p in $Target.PSObject.Properties) { $out[$p.Name] = $p.Value }
    }
    $warn = @($Target.Warnings | Where-Object { $_ })
    if ($warn.Count) { $out['Warnings'] = $warn -join ' | ' }
    $out
}
