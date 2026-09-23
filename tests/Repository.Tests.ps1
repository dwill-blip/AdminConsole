# Static checks on the whole repository - catch problems before anyone launches the GUI.
#   - every .ps1/.psm1 parses
#   - files are plain ASCII (Windows PowerShell 5.1 misreads UTF-8 without a BOM)
#   - the shipped plugins all load, and workflows / row actions point at real actions
#   - every permission used by default roles exists

Describe 'Repository' {

    BeforeAll {
        $script:repo = Split-Path -Parent $PSScriptRoot
        $script:files = @(Get-ChildItem -Path $script:repo -Recurse -Include '*.ps1', '*.psm1' | Where-Object { $_.FullName -notmatch '[\\/](\.git|lib)[\\/]' })
    }

    It 'has script files' {
        $script:files.Count | Should -BeGreaterThan 20
    }

    It 'parses every script without errors' {
        $bad = foreach ($f in $script:files) {
            $tokens = $null; $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors)
            foreach ($e in @($errors)) { "$($f.Name):$($e.Extent.StartLineNumber) $($e.Message)" }
        }
        @($bad) -join "`n" | Should -BeNullOrEmpty
    }

    It 'uses only ASCII in scripts, SQL and JSON' {
        $all = @($script:files) + @(Get-ChildItem -Path $script:repo -Recurse -Include '*.sql', '*.json', '*.cmd' | Where-Object { $_.FullName -notmatch '[\\/]lib[\\/]' })
        $bad = foreach ($f in $all) {
            $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
            if (@($bytes | Where-Object { $_ -gt 127 }).Count) { $f.Name }
        }
        @($bad) -join ', ' | Should -BeNullOrEmpty
    }

    Context 'Shipped plugins' {
        BeforeAll {
            Import-Module (Join-Path (Join-Path (Join-Path $script:repo 'src') 'AdminConsole.Core') 'AdminConsole.Core.psm1') -Force
            Initialize-ConsoleConfig -Root $script:repo
            Import-ConsolePlugins -Path (Join-Path $script:repo 'plugins')
        }

        It 'load without errors' {
            (@(Get-ConsolePluginErrors) | ForEach-Object { "$($_.File): $($_.Error)" }) -join "`n" | Should -BeNullOrEmpty
        }

        It 'include the expected building blocks' {
            @(Get-ConsoleAction -Scope User).Count | Should -BeGreaterThan 10
            @(Get-ConsoleAction -Scope Computer).Count | Should -BeGreaterThan 2
            Get-ConsoleWorkflow -Name 'Offboard User' | Should -Not -BeNullOrEmpty
            @(Get-ConsoleReport).Count | Should -BeGreaterThan 8
        }

        It 'default roles only reference permissions that exist' {
            $sql = Get-Content (Join-Path (Join-Path (Join-Path $script:repo 'database') 'migrations') '002_default_roles.sql') -Raw
            $used = [regex]::Matches($sql, "SELECT '\w+', '(\w+)'") | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
            $known = @(Get-ConsolePermissionCatalog | ForEach-Object { $_.Permission })
            @($used | Where-Object { $known -notcontains $_ }) -join ', ' | Should -BeNullOrEmpty
        }
    }
}
