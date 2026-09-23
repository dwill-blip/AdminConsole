# Running and exporting reports, plus per-operator favorites.

function Resolve-ConsoleReport {
    param([Parameter(Mandatory)]$Report)
    if ($Report -is [string]) {
        $def = Get-ConsoleReport -Name $Report
        if (-not $def) { throw "No report named '$Report' is loaded." }
        return $def
    }
    $Report
}

function Invoke-ConsoleReport {
    <#
    .SYNOPSIS  Runs a report and returns its rows. Wrap the call in @() to always get an array.
    .PARAMETER AsSystem  Skip the RBAC check (used by scheduled jobs, which an admin configured).
    #>
    param(
        [Parameter(Mandatory)]$Report,
        [hashtable]$Parameters,
        [switch]$AsSystem
    )
    $def = Resolve-ConsoleReport $Report
    if (-not $AsSystem) { Assert-ConsolePermission $def.Permission }
    $params = Complete-ConsoleInputs $def.Parameters $Parameters
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $rows = @(& $def.Run $params | Where-Object { $null -ne $_ })
        Write-ConsoleAudit -Action 'Run Report' -Target $def.Name -Result 'Success' -Details ("{0} rows in {1:n1}s" -f $rows.Count, $sw.Elapsed.TotalSeconds)
        $rows
    }
    catch {
        Write-ConsoleAudit -Action 'Run Report' -Target $def.Name -Result 'Failed' -Details $_.Exception.Message
        throw
    }
}

function Select-ConsoleRows {
    # Case-insensitive "contains" filter across every column.
    param([object[]]$Rows, [string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $Rows }
    $pattern = '*' + [System.Management.Automation.WildcardPattern]::Escape($Text.Trim()) + '*'
    $Rows | Where-Object {
            $row = $_
            $hit = $false
            foreach ($p in $row.PSObject.Properties) {
                if ((Format-ConsoleValue $p.Value) -like $pattern) { $hit = $true; break }
            }
            $hit
        }
}

function Format-ConsoleValue {
    # Display text for a cell: arrays are joined, dates are ISO-ish.
    param($Value)
    if ($null -eq $Value) { return '' }
    if ($Value -is [datetime]) { return $Value.ToString('yyyy-MM-dd HH:mm') }
    if ($Value -is [string]) { return $Value }
    if ($Value -is [System.Collections.IEnumerable]) { return (@($Value) | ForEach-Object { [string]$_ }) -join '; ' }
    [string]$Value
}

function ConvertTo-ConsoleFlatRows {
    # Make rows safe for CSV / grid: every value becomes display text.
    param([object[]]$Rows)
    foreach ($r in @($Rows)) {
        $o = [ordered]@{}
        foreach ($p in $r.PSObject.Properties) { $o[$p.Name] = Format-ConsoleValue $p.Value }
        [pscustomobject]$o
    }
}

function Export-ConsoleRows {
    <#
    .SYNOPSIS  Exports rows to .csv, .json or .html (chosen by the file extension).
    #>
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Rows, [Parameter(Mandatory)][string]$Path, [string]$Title = 'Report', [switch]$AsSystem)
    if (-not $AsSystem) { Assert-ConsolePermission 'ExportReport' }
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $flat = @(ConvertTo-ConsoleFlatRows $Rows)
    switch -Regex ([System.IO.Path]::GetExtension($Path).ToLower()) {
        '\.json' { $flat | ConvertTo-Json -Depth 3 | Set-Content -Path $Path -Encoding UTF8 }
        '\.html?' {
            $head = "<title>$Title</title><style>body{font-family:Segoe UI,Arial;font-size:13px}table{border-collapse:collapse}td,th{border:1px solid #ccc;padding:4px 8px}th{background:#f0f0f0}</style>"
            $flat | ConvertTo-Html -Head $head -PreContent "<h2>$Title</h2><p>Generated $(Get-Date)</p>" | Set-Content -Path $Path -Encoding UTF8
        }
        default { $flat | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8 }
    }
    Write-ConsoleAudit -Action 'Export Report' -Target $Title -Result 'Success' -Details "$($flat.Count) rows -> $Path"
}

function Get-ConsoleFavorite {
    @(Invoke-DbQuery 'SELECT ReportName FROM Favorites WHERE Account = @a ORDER BY ReportName' @{ a = (Get-ConsoleUser) } | ForEach-Object { $_.ReportName })
}

function Add-ConsoleFavorite {
    param([Parameter(Mandatory)][string]$ReportName)
    Invoke-DbNonQuery 'INSERT OR IGNORE INTO Favorites (Account, ReportName, CreatedOn) VALUES (@a, @r, @d)' @{ a = (Get-ConsoleUser); r = $ReportName; d = (Get-ConsoleNow) } | Out-Null
}

function Remove-ConsoleFavorite {
    param([Parameter(Mandatory)][string]$ReportName)
    Invoke-DbNonQuery 'DELETE FROM Favorites WHERE Account = @a AND ReportName = @r' @{ a = (Get-ConsoleUser); r = $ReportName } | Out-Null
}

function Get-ConsoleRowTarget {
    # Turns a report row into a User/Computer target (for reports that declare RowType + RowKey).
    param([Parameter(Mandatory)]$Report, [Parameter(Mandatory)]$Row)
    $def = Resolve-ConsoleReport $Report
    if (-not $def.RowType) { return $Row }
    $key = $Row.($def.RowKey)
    if (-not $key) { throw "This row has no value in column '$($def.RowKey)'." }
    switch ($def.RowType) {
        'User'     { Get-HybridUser -Identity $key }
        'Computer' { Get-HybridComputer -Name $key }
    }
}
