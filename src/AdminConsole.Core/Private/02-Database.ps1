# SQLite data access.
#
# One connection stays open for the life of the process. (The old version opened a
# new connection per query, which silently broke BEGIN/COMMIT and made the first
# launch crash in the migration step.) The System.Data.SQLite driver comes from the
# PSSQLite module, which ships the right native build for 5.1 / 7, x86 / x64.

# Console folder = three levels above this file (src\AdminConsole.Core\Private).
$script:CoreRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$script:Db = $null
$script:DbPath = $null

function Import-SqliteDriver {
    if ('System.Data.SQLite.SQLiteConnection' -as [type]) { return }
    # Prefer the bundled copy in lib\PSSQLite (MIT licence) so nothing has to be installed;
    # fall back to an installed PSSQLite module.
    $bundled = Join-Path (Join-Path $script:CoreRoot 'lib') (Join-Path 'PSSQLite' 'PSSQLite.psd1')
    if (Test-Path $bundled) { Import-Module $bundled -Force -ErrorAction Stop }
    elseif (Get-Module -ListAvailable -Name PSSQLite) { Import-Module PSSQLite -ErrorAction Stop }
    else { throw "The SQLite driver was not found. Expected the bundled copy at $bundled - extract the complete AdminConsole folder again, or run: Install-Module PSSQLite" }
    if (-not ('System.Data.SQLite.SQLiteConnection' -as [type])) {
        throw 'PSSQLite loaded but System.Data.SQLite is not available. If the folder came from a downloaded zip: right-click the zip > Properties > Unblock, then extract it again.'
    }
}

function Open-ConsoleDatabase {
    param([Parameter(Mandatory)][string]$Path)
    Import-SqliteDriver
    Close-ConsoleDatabase
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $conn = New-Object System.Data.SQLite.SQLiteConnection ("Data Source=$Path;Version=3;Foreign Keys=True;")
    $conn.Open()
    $script:Db = $conn
    $script:DbPath = $Path
    Invoke-DbNonQuery 'PRAGMA busy_timeout = 5000;' | Out-Null
    Invoke-DbNonQuery 'PRAGMA foreign_keys = ON;' | Out-Null
}

function Close-ConsoleDatabase {
    if ($script:Db) {
        try { $script:Db.Close(); $script:Db.Dispose() } catch { }
        $script:Db = $null
    }
}

function Get-ConsoleDatabasePath { $script:DbPath }

function New-DbCommand {
    param([string]$Sql, [hashtable]$Parameters)
    if (-not $script:Db) { throw 'Database is not open. Call Initialize-AdminConsole first.' }
    $cmd = $script:Db.CreateCommand()
    $cmd.CommandText = $Sql
    if ($Parameters) {
        foreach ($key in $Parameters.Keys) {
            $p = $cmd.CreateParameter()
            $p.ParameterName = '@' + $key.TrimStart('@')
            $value = $Parameters[$key]
            if ($null -eq $value) { $value = [DBNull]::Value }
            elseif ($value -is [bool]) { $value = [int]$value }
            elseif ($value -is [datetime]) { $value = $value.ToString('yyyy-MM-ddTHH:mm:ss') }
            $p.Value = $value
            [void]$cmd.Parameters.Add($p)
        }
    }
    $cmd
}

function Invoke-DbQuery {
    <#
    .SYNOPSIS  Runs a SELECT and returns one PSCustomObject per row.
    .EXAMPLE   Invoke-DbQuery 'SELECT * FROM Audit WHERE Operator = @u' @{ u = 'CONTOSO\dan' }
    #>
    param([Parameter(Mandatory)][string]$Sql, [hashtable]$Parameters = @{})
    $cmd = New-DbCommand $Sql $Parameters
    $reader = $cmd.ExecuteReader()
    try {
        while ($reader.Read()) {
            $row = [ordered]@{}
            for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                $v = $reader.GetValue($i)
                if ($v -is [DBNull]) { $v = $null }
                $row[$reader.GetName($i)] = $v
            }
            [pscustomobject]$row
        }
    }
    finally { $reader.Dispose(); $cmd.Dispose() }
}

function Invoke-DbNonQuery {
    param([Parameter(Mandatory)][string]$Sql, [hashtable]$Parameters = @{})
    $cmd = New-DbCommand $Sql $Parameters
    try { $cmd.ExecuteNonQuery() } finally { $cmd.Dispose() }
}

function Invoke-DbScalar {
    param([Parameter(Mandatory)][string]$Sql, [hashtable]$Parameters = @{})
    $cmd = New-DbCommand $Sql $Parameters
    try {
        $v = $cmd.ExecuteScalar()
        if ($v -is [DBNull]) { $null } else { $v }
    }
    finally { $cmd.Dispose() }
}

function Invoke-DbInsert {
    # INSERT and return the new row id.
    param([Parameter(Mandatory)][string]$Sql, [hashtable]$Parameters = @{})
    Invoke-DbNonQuery $Sql $Parameters | Out-Null
    [long](Invoke-DbScalar 'SELECT last_insert_rowid()')
}

function Invoke-DbTransaction {
    param([Parameter(Mandatory)][scriptblock]$ScriptBlock)
    Invoke-DbNonQuery 'BEGIN IMMEDIATE;' | Out-Null
    try {
        & $ScriptBlock
        Invoke-DbNonQuery 'COMMIT;' | Out-Null
    }
    catch {
        try { Invoke-DbNonQuery 'ROLLBACK;' | Out-Null } catch { }
        throw
    }
}

function Update-ConsoleDatabase {
    <#
    .SYNOPSIS  Applies database\migrations\NNN_name.sql files that have not run yet, each in its own transaction.
    #>
    param([Parameter(Mandatory)][string]$MigrationsPath)
    Invoke-DbNonQuery 'CREATE TABLE IF NOT EXISTS SchemaVersion (Version INTEGER PRIMARY KEY, Name TEXT NOT NULL, AppliedOn TEXT NOT NULL);' | Out-Null
    $applied = @{}
    foreach ($r in @(Invoke-DbQuery 'SELECT Version FROM SchemaVersion')) { $applied[[int]$r.Version] = $true }

    foreach ($file in (Get-ChildItem -Path $MigrationsPath -Filter '*.sql' | Sort-Object Name)) {
        if ($file.BaseName -notmatch '^(\d+)_') { Write-ConsoleLog "Skipping migration with no numeric prefix: $($file.Name)" Warning; continue }
        $version = [int]$Matches[1]
        if ($applied.ContainsKey($version)) { continue }
        $sql = Get-Content -Path $file.FullName -Raw
        Invoke-DbTransaction {
            Invoke-DbNonQuery $sql | Out-Null
            Invoke-DbNonQuery 'INSERT INTO SchemaVersion (Version, Name, AppliedOn) VALUES (@v, @n, @d)' @{ v = $version; n = $file.Name; d = (Get-ConsoleNow) } | Out-Null
        }
        Write-ConsoleLog "Applied database migration $($file.Name)"
    }
}

function Get-ConsoleSchemaVersion {
    [int](Invoke-DbScalar 'SELECT COALESCE(MAX(Version), 0) FROM SchemaVersion')
}
