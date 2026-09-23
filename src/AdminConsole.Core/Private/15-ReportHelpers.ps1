# Helpers shared by report plugins.

function Get-ConsoleGraphUsageReport {
    <#
    .SYNOPSIS  Downloads a Microsoft 365 usage report (Reports API, CSV) and returns its rows.
    .EXAMPLE   Get-ConsoleGraphUsageReport 'getMailboxUsageDetail' 'D30'
    .NOTES     If names show as random IDs, turn off "Display concealed user, group, and site
               names in all reports" in the Microsoft 365 admin center (Settings > Org settings > Reports).
    #>
    param([Parameter(Mandatory)][string]$Name, [ValidateSet('D7', 'D30', 'D90', 'D180')][string]$Period = 'D30')
    Connect-ConsoleGraph
    $file = Join-Path ([System.IO.Path]::GetTempPath()) ("m365-{0}.csv" -f [guid]::NewGuid())
    try {
        Invoke-MgGraphRequest -Method GET -Uri "v1.0/reports/$Name(period='$Period')" -OutputFilePath $file -ErrorAction Stop
        Import-Csv -Path $file
    }
    finally { Remove-Item $file -ErrorAction SilentlyContinue }
}

function Get-ConsoleGraphUsers {
    <#
    .SYNOPSIS  All users matching an optional $filter, with the given $select. -SignInActivity adds last
               sign-in dates (needs Entra ID P1 + AuditLog.Read.All); if unavailable it carries on without.
    #>
    param([string]$Filter, [string[]]$Select = @('id', 'displayName', 'userPrincipalName'), [switch]$SignInActivity)
    $fields = @($Select)
    if ($SignInActivity) { $fields += 'signInActivity' }
    $build = {
        param($f)
        $q = "v1.0/users?`$top=999&`$select=$($f -join ',')"
        if ($Filter) { $q += "&`$filter=$([uri]::EscapeDataString($Filter))" }
        $q
    }
    try { Invoke-ConsoleGraph GET (& $build $fields) -All }
    catch {
        if (-not $SignInActivity) { throw }
        Write-ConsoleLog "Sign-in activity is not available ($($_.Exception.Message)); continuing without it." Warning
        Invoke-ConsoleGraph GET (& $build $Select) -All
    }
}

function Get-ConsoleLastSignIn {
    # Newest of interactive / non-interactive / successful sign-in, or $null.
    param($User)
    $a = $User.signInActivity
    if (-not $a) { return $null }
    $dates = @($a.lastSignInDateTime, $a.lastNonInteractiveSignInDateTime, $a.lastSuccessfulSignInDateTime) |
        Where-Object { $_ } | ForEach-Object { [datetime]$_ }
    if (-not $dates.Count) { return $null }
    ($dates | Sort-Object -Descending)[0]
}

function Get-ConsoleDaysSince {
    param($Date)
    if (-not $Date) { return $null }
    [int]((Get-Date) - [datetime]$Date).TotalDays
}

function ConvertTo-ConsoleBytes {
    # Exchange sizes look like "1.234 GB (1,325,000,000 bytes)".
    param($Size)
    if ($null -eq $Size) { return $null }
    $m = [regex]::Match([string]$Size, '\(([\d,\.]+) bytes\)')
    if ($m.Success) { return [long]($m.Groups[1].Value -replace '[,\.]', '') }
    $null
}
