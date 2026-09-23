# Engine tests. They need PSSQLite but NOT Active Directory, Graph or Exchange:
# a throw-away console root is built in $TestDrive with fake plugins.
#
#   Invoke-Pester .\tests
#
# Works with Pester 4.x and 5.x.

Describe 'AdminConsole core' {

    BeforeAll {
        $repo = Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path (Join-Path (Join-Path $repo 'src') 'AdminConsole.Core') 'AdminConsole.Core.psm1') -Force

        $script:root = Join-Path $TestDrive 'console'
        New-Item -ItemType Directory -Path (Join-Path $script:root 'config') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:root 'database') -Force | Out-Null
        Copy-Item -Path (Join-Path (Join-Path $repo 'database') 'migrations') -Destination (Join-Path $script:root 'database') -Recurse
        foreach ($d in 'actions/Test', 'workflows', 'reports/Test') { New-Item -ItemType Directory -Path (Join-Path (Join-Path $script:root 'plugins') $d) -Force | Out-Null }

        '{ "RequireApprovals": true, "AllowSelfApproval": false, "ApprovalExpiryHours": 1,
           "ReportOutputFolder": "out/reports", "Notifications": { "DropFolder": "out/notes", "WebhookUrl": "" },
           "Sources": { "ActiveDirectory": false, "EntraID": false, "ExchangeOnline": false } }' |
            Set-Content (Join-Path (Join-Path $script:root 'config') 'settings.json')

        # Run a block as another operator, always switching back.
        function script:Invoke-As([string]$Account, [scriptblock]$Block) {
            Set-ConsoleUser $Account
            try { & $Block } finally { Set-ConsoleUser 'CONTOSO\alice' }
        }
        # Error message of a block (works the same in Pester 4 and 5).
        function script:Get-ErrorText([scriptblock]$Block) {
            try { & $Block; '' } catch { $_.Exception.Message }
        }

        function script:Write-Plugin([string]$Rel, [string]$Body) {
            Set-Content -Path (Join-Path (Join-Path $script:root 'plugins') $Rel) -Value $Body
        }

        Write-Plugin 'actions/Test/Echo.ps1' @'
@{ Name = 'Echo'; Scope = 'User'; Permission = 'Echo'; Confirm = $false
   Inputs = @(@{ Name = 'Secret'; Type = 'Password'; Required = $true }, @{ Name = 'Note'; Default = 'hi' })
   Run = { param($T, $I) "echo $($T.Identity) $($I.Note)" } }
'@
        Write-Plugin 'actions/Test/Guarded.ps1' @'
@{ Name = 'Guarded Thing'; Scope = 'User'; RequiresApproval = $true; Run = { param($T) 'ran' } }
'@
        Write-Plugin 'actions/Test/Boom.ps1' @'
@{ Name = 'Boom'; Scope = 'User'; Run = { param($T) throw 'kaboom' } }
'@
        Write-Plugin 'actions/Test/SoftError.ps1' @'
@{ Name = 'Soft Error'; Scope = 'User'; Run = { param($T) Write-Error 'non-terminating'; 'should not get here' } }
'@
        Write-Plugin 'actions/Test/OnlyAd.ps1' @'
@{ Name = 'Only AD'; Scope = 'User'; AppliesTo = { param($T) [bool]$T.AD }; Run = { param($T) 'ok' } }
'@
        Write-Plugin 'actions/Test/RowThing.ps1' @'
@{ Name = 'Row Thing'; Scope = 'Row'; TargetName = { param($R) "row-$($R.Id)" }; Run = { param($R) "row $($R.Id)" } }
'@
        Write-Plugin 'actions/Test/Checked.ps1' @'
@{ Name = 'Checked'; Scope = 'User'; Check = { param($T) @{ Done = ($T.DisplayName -eq 'Done Dan'); Detail = "name=$($T.DisplayName)" } }; Run = { param($T) 'ok' } }
'@
        Write-Plugin 'actions/Test/InfoOnly.ps1' @'
@{ Name = 'Info Only'; Scope = 'User'; Check = { param($T) 'just so you know' }; Run = { param($T) 'ok' } }
'@
        Write-Plugin 'actions/Test/BrokenCheck.ps1' @'
@{ Name = 'Broken Check'; Scope = 'User'; Check = { param($T) throw 'cannot reach server' }; Run = { param($T) 'ok' } }
'@
        Write-Plugin 'workflows/StatusFlow.ps1' "@{ Name = 'Status Flow'; Scope = 'User'; Steps = @('Checked', 'Info Only', 'Only AD', 'Broken Check', 'Checked') }"
        Write-Plugin 'actions/Test/_Ignored.ps1' '@{ Name = "Ignored"; Scope = "User"; Run = {} }'
        Write-Plugin 'actions/Test/Broken.ps1' '@{ Name = "Broken"; Scope = "Nowhere"; Run = {} }'
        Write-Plugin 'workflows/Flow.ps1' "@{ Name = 'Flow'; Scope = 'User'; Steps = @('Echo', 'Boom', 'Only AD') }"
        Write-Plugin 'workflows/StopFlow.ps1' "@{ Name = 'Stop Flow'; Scope = 'User'; StopOnError = `$true; Steps = @('Boom', 'Only AD') }"
        Write-Plugin 'workflows/BadFlow.ps1' "@{ Name = 'Bad Flow'; Scope = 'User'; Steps = @('Does Not Exist') }"
        Write-Plugin 'reports/Test/Numbers.ps1' @'
@{ Name = 'Numbers'; RowActions = @('Row Thing')
   Parameters = @(@{ Name = 'Rows'; Type = 'Number'; Default = 3 })
   Run = { param($P) 1..$P.Rows | ForEach-Object { [pscustomobject]@{ Id = $_; Name = "item $_"; Tags = @('a', 'b') } } } }
'@

        Set-ConsoleUser 'CONTOSO\alice'
        Initialize-AdminConsole -Root $script:root
        $script:user = [pscustomobject]@{ PSTypeName = 'AdminConsole.HybridUser'; Identity = 'bob@contoso.com'; DisplayName = 'Bob'; AD = $null; Entra = $null }
    }

    AfterAll {
        Close-ConsoleDatabase
        Set-ConsoleUser $null
    }

    Context 'Plugins' {
        It 'loads valid plugins and skips templates' {
            (Get-ConsoleAction).Count | Should -Be 9
            Get-ConsoleAction -Name 'Ignored' | Should -BeNullOrEmpty
        }
        It 'reports broken plugins instead of crashing' {
            $errs = @(Get-ConsolePluginErrors)
            @($errs | Where-Object { $_.File -like '*Broken.ps1' }).Count | Should -Be 1
            @($errs | Where-Object { $_.Error -like '*Does Not Exist*' }).Count | Should -Be 1
            Get-ConsoleWorkflow -Name 'Bad Flow' | Should -BeNullOrEmpty
        }
        It 'derives defaults' {
            $a = Get-ConsoleAction -Name 'Guarded Thing'
            $a.Permission | Should -Be 'GuardedThing'
            $a.Category | Should -Be 'Test'
            (Get-ConsoleReport -Name 'Test/Numbers').Name | Should -Be 'Numbers'
        }
        It 'rejects input names that clash with hashtable members' {
            { ConvertTo-InputDefinitions @(@{ Name = 'Count' }) 'X' } | Should -Throw
        }
        It 'turns names into PascalCase permissions' {
            Get-DefaultPermissionName 'Convert to Shared Mailbox' | Should -Be 'ConvertToSharedMailbox'
            Get-DefaultPermissionName 'Revoke Sign-in Sessions' | Should -Be 'RevokeSignInSessions'
        }
    }

    Context 'Database and bootstrap' {
        It 'applies migrations once' {
            $n = @(Get-ChildItem (Join-Path (Join-Path $script:root 'database') 'migrations') -Filter '*.sql').Count
            Get-ConsoleSchemaVersion | Should -Be $n
            Update-ConsoleDatabase -MigrationsPath (Join-Path (Join-Path $script:root 'database') 'migrations')
            [int](Invoke-DbScalar 'SELECT COUNT(*) FROM SchemaVersion') | Should -Be $n
        }
        It 'makes only the first operator GlobalAdmin' {
            Invoke-As 'CONTOSO\mallory' {
                Initialize-ConsoleBootstrapAdmin
                Test-ConsolePermission 'Echo' | Should -Be $false
            }
            Test-ConsolePermission 'Echo' | Should -Be $true
            Test-ConsolePermission 'Echo' -Account 'contoso\ALICE' | Should -Be $true   # case-insensitive
        }
        It 'rolls back a failed transaction' {
            { Invoke-DbTransaction { Invoke-DbNonQuery "INSERT INTO Roles (Name) VALUES ('Temp')" | Out-Null; throw 'nope' } } | Should -Throw
            Invoke-DbScalar "SELECT COUNT(*) FROM Roles WHERE Name = 'Temp'" | Should -Be 0
        }
    }

    Context 'Action runner' {
        It 'denies operators without the permission and audits it' {
            $r = Invoke-As 'CONTOSO\mallory' { Invoke-ConsoleAction -Action 'Echo' -Target $script:user -Inputs @{ Secret = 'x' } }
            $r.Status | Should -Be 'Denied'
            (Get-ConsoleAudit -Search 'mallory' | Select-Object -First 1).Result | Should -Be 'Denied'
        }
        It 'runs, applies input defaults and masks passwords in the audit log' {
            $r = Invoke-ConsoleAction -Action 'Echo' -Target $script:user -Inputs @{ Secret = 'hunter2' }
            $r.Status | Should -Be 'Success'
            $r.Output | Should -Be 'echo bob@contoso.com hi'
            $audit = Get-ConsoleAudit -Search 'Echo' | Select-Object -First 1
            $audit.Details | Should -Match 'Secret=\*+'
            $audit.Details | Should -Not -Match 'hunter2'
        }
        It 'asks for inputs through the callback and cancels on $null' {
            (Invoke-ConsoleAction -Action 'Echo' -Target $script:user -GetInputs { param($a, $t) $null }).Status | Should -Be 'Cancelled'
            (Invoke-ConsoleAction -Action 'Echo' -Target $script:user -GetInputs { param($a, $t) @{ Secret = 's'; Note = 'yo' } }).Output | Should -Be 'echo bob@contoso.com yo'
        }
        It 'cancels when a required input is missing' {
            (Invoke-ConsoleAction -Action 'Echo' -Target $script:user -Inputs @{ Note = 'x' }).Status | Should -Be 'Cancelled'
        }
        It 'honours the confirmation callback' {
            (Invoke-ConsoleAction -Action 'Boom' -Target $script:user -Confirm { param($m) $false }).Status | Should -Be 'Cancelled'
        }
        It 'reports thrown errors as Failed' {
            $r = Invoke-ConsoleAction -Action 'Boom' -Target $script:user
            $r.Status | Should -Be 'Failed'
            $r.Message | Should -Be 'kaboom'
        }
        It 'treats non-terminating errors in plugins as failures' {
            (Invoke-ConsoleAction -Action 'Soft Error' -Target $script:user).Status | Should -Be 'Failed'
        }
        It 'respects AppliesTo' {
            (Invoke-ConsoleAction -Action 'Only AD' -Target $script:user).Status | Should -Be 'NotApplicable'
            Test-ConsoleActionApplies 'Only AD' $script:user | Should -Be $false
        }
        It 'names row targets with TargetName' {
            (Invoke-ConsoleAction -Action 'Row Thing' -Target ([pscustomobject]@{ Id = 7 })).Target | Should -Be 'row-7'
        }
    }

    Context 'Approvals' {
        It 'requires a second person and can only be used once' {
            (Invoke-ConsoleAction -Action 'Guarded Thing' -Target $script:user).Status | Should -Be 'ApprovalRequested'
            (Invoke-ConsoleAction -Action 'Guarded Thing' -Target $script:user).Status | Should -Be 'PendingApproval'
            $req = Get-ApprovalRequest -Status Pending | Select-Object -First 1
            $req.RequestedBy | Should -Be 'CONTOSO\alice'

            Get-ErrorText { Approve-ConsoleRequest -Id $req.Id } | Should -Match 'own request'

            Add-ConsoleRoleAssignment -Account 'CONTOSO\carol' -Role 'Security'
            Invoke-As 'CONTOSO\carol' { Approve-ConsoleRequest -Id $req.Id -Notes 'ok' }

            $r = Invoke-ConsoleAction -Action 'Guarded Thing' -Target $script:user
            $r.Status | Should -Be 'Success'
            $r.CorrelationId | Should -Be $req.CorrelationId
            (Get-ApprovalRequest -Id $req.Id).Status | Should -Be 'Executed'
            (Invoke-ConsoleAction -Action 'Guarded Thing' -Target $script:user).Status | Should -Be 'ApprovalRequested'
        }
        It 'refuses approvals from people without ManageApprovals' {
            $req = Get-ApprovalRequest -Status Pending | Select-Object -First 1
            Invoke-As 'CONTOSO\mallory' { Get-ErrorText { Approve-ConsoleRequest -Id $req.Id } } | Should -Match 'ManageApprovals'
        }
        It 'skips approval when RequireApprovals is off' {
            Set-ConsoleSetting 'RequireApprovals' $false
            (Invoke-ConsoleAction -Action 'Guarded Thing' -Target 'someone').Status | Should -Be 'Success'
            Set-ConsoleSetting 'RequireApprovals' $true
        }
    }

    Context 'Workflows' {
        It 'runs every step and reports each result' {
            $results = @(Invoke-ConsoleWorkflow -Workflow 'Flow' -Target $script:user -GetInputs { param($a, $t) @{ Secret = 's' } })
            ($results | ForEach-Object { $_.Status }) -join ',' | Should -Be 'Success,Failed,NotApplicable'
        }
        It 'stops at the first failure when StopOnError is set' {
            @(Invoke-ConsoleWorkflow -Workflow 'Stop Flow' -Target $script:user).Count | Should -Be 1
        }
        It 'can run a subset of steps' {
            $results = Invoke-ConsoleWorkflow -Workflow 'Flow' -Target $script:user -Steps 'Only AD'
            @($results).Count | Should -Be 1
        }
    }

    Context 'Status checks' {
        It 'normalizes Check results' {
            (Get-ConsoleActionStatus -Action 'Checked' -Target $script:user).Status | Should -Be 'To do'
            $done = [pscustomobject]@{ Identity = 'x'; DisplayName = 'Done Dan'; AD = $null }
            $s = Get-ConsoleActionStatus -Action 'Checked' -Target $done
            $s.Status | Should -Be 'Done'
            $s.Detail | Should -Be 'name=Done Dan'
            (Get-ConsoleActionStatus -Action 'Info Only' -Target $script:user).Status | Should -Be 'Info'
            (Get-ConsoleActionStatus -Action 'Broken Check' -Target $script:user).Status | Should -Be 'Error'
            (Get-ConsoleActionStatus -Action 'Echo' -Target $script:user).Status | Should -Be 'No check'
            (Get-ConsoleActionStatus -Action 'Only AD' -Target $script:user).Status | Should -Be 'N/A'
        }
        It 'builds workflow status with suggestions, including repeated steps' {
            $rows = @(Get-ConsoleWorkflowStatus -Workflow 'Status Flow' -Target $script:user)
            $rows.Count | Should -Be 5
            ($rows | ForEach-Object { $_.Status }) -join ',' | Should -Be 'To do,Info,N/A,Error,To do'
            ($rows | ForEach-Object { $_.Suggested }) -join ',' | Should -Be 'True,True,False,True,True'
            $rows[4].Step | Should -Be 5
        }
        It 'runs a repeated step twice' {
            $r = @(Invoke-ConsoleWorkflow -Workflow 'Status Flow' -Target $script:user -Steps 'Checked', 'Info Only', 'Checked')
            ($r | ForEach-Object { $_.Action }) -join ',' | Should -Be 'Checked,Info Only,Checked'
        }
    }

    Context 'Reports and exports' {
        It 'runs with parameter defaults and overrides' {
            @(Invoke-ConsoleReport -Report 'Numbers').Count | Should -Be 3
            @(Invoke-ConsoleReport -Report 'Numbers' -Parameters @{ Rows = 5 }).Count | Should -Be 5
        }
        It 'filters across columns, including arrays, and escapes wildcards' {
            $rows = @(Invoke-ConsoleReport -Report 'Numbers' -Parameters @{ Rows = 12 })
            @(Select-ConsoleRows -Rows $rows -Text 'item 1').Count | Should -Be 4    # 1, 10, 11, 12
            @(Select-ConsoleRows -Rows $rows -Text 'a; b').Count | Should -Be 12
            @(Select-ConsoleRows -Rows $rows -Text '[x').Count | Should -Be 0
        }
        It 'exports csv, json and html' {
            $rows = @(Invoke-ConsoleReport -Report 'Numbers')
            foreach ($ext in 'csv', 'json', 'html') {
                $f = Join-Path $TestDrive "export.$ext"
                Export-ConsoleRows -Rows $rows -Path $f -Title 'Numbers'
                Test-Path $f | Should -Be $true
            }
            @(Import-Csv (Join-Path $TestDrive 'export.csv')).Count | Should -Be 3
            (Import-Csv (Join-Path $TestDrive 'export.csv'))[0].Tags | Should -Be 'a; b'
        }
        It 'keeps favorites per operator' {
            Add-ConsoleFavorite 'Numbers'
            Get-ConsoleFavorite | Should -Be 'Numbers'
            Invoke-As 'CONTOSO\carol' { @(Get-ConsoleFavorite).Count } | Should -Be 0
            Remove-ConsoleFavorite 'Numbers'
            @(Get-ConsoleFavorite).Count | Should -Be 0
        }
    }

    Context 'Scheduling, alerts and notifications' {
        It 'computes next run times' {
            $from = [datetime]'2026-03-04T10:30:00'   # a Wednesday
            Get-NextRunTime -Frequency Daily -At '06:00' -From $from | Should -Be ([datetime]'2026-03-05T06:00:00')
            Get-NextRunTime -Frequency Daily -At '11:00' -From $from | Should -Be ([datetime]'2026-03-04T11:00:00')
            Get-NextRunTime -Frequency Hourly -At '00:15' -From $from | Should -Be ([datetime]'2026-03-04T11:15:00')
            Get-NextRunTime -Frequency Weekly -At '06:00' -DayOfWeek Monday -From $from | Should -Be ([datetime]'2026-03-09T06:00:00')
            Get-NextRunTime -Frequency Weekly -At '12:00' -DayOfWeek Wednesday -From $from | Should -Be ([datetime]'2026-03-04T12:00:00')
        }
        It 'runs due schedules, writes the file and moves NextRun forward' {
            $id = New-ConsoleSchedule -Name 'nums' -Report 'Numbers' -Parameters @{ Rows = 2 } -Frequency Daily -At '06:00'
            Invoke-DbNonQuery 'UPDATE Schedules SET NextRun = @n WHERE Id = @i' @{ n = '2000-01-01T00:00:00'; i = $id } | Out-Null
            Invoke-DueSchedules | Should -Be 1
            Invoke-DueSchedules | Should -Be 0
            $s = Get-ConsoleSchedule | Where-Object { $_.Id -eq $id }
            $s.LastResult | Should -Match '^Success - 2 rows'
            [datetime]$s.NextRun | Should -BeGreaterThan (Get-Date)
            @(Get-ChildItem (Join-Path (Join-Path $script:root 'out') 'reports') -Filter 'nums-*.csv').Count | Should -Be 1
        }
        It 'triggers alerts and delivers notifications to the drop folder' {
            [void](New-ConsoleAlert -Name 'has item 2' -Report 'Numbers' -MatchText 'item 2' -MinRows 1 -Severity Critical)
            [void](New-ConsoleAlert -Name 'never' -Report 'Numbers' -MatchText 'zzz' -MinRows 1)
            Invoke-ConsoleAlerts | Should -Be 2
            @(Get-ConsoleAlertHistory).Count | Should -Be 1
            (Get-ConsoleAlert | Where-Object { $_.Name -eq 'has item 2' }).LastMatches | Should -Be 1
            Send-ConsoleNotifications | Should -Be 1
            @(Get-ChildItem (Join-Path (Join-Path $script:root 'out') 'notes') -Filter '*.json').Count | Should -Be 1
            (Get-ConsoleNotification | Select-Object -First 1).Status | Should -Be 'Sent'
        }
        It 'runs everything through Invoke-ConsoleJobs' {
            { Invoke-ConsoleJobs -Job All } | Should -Not -Throw
        }
    }

    Context 'Settings and health' {
        It 'reads nested settings with defaults' {
            Get-ConsoleSetting 'Notifications.DropFolder' | Should -Be 'out/notes'
            Get-ConsoleSetting 'Graph.ClientId' 'fallback' | Should -Be 'fallback'
            Get-ConsoleSetting 'Missing.Key' 42 | Should -Be 42
            Test-ConsoleSource 'ActiveDirectory' | Should -Be $false
        }
        It 'refuses invalid JSON and keeps the old file' {
            { Save-ConsoleSettingsJson -Json '{ not json' } | Should -Throw
            Get-ConsoleSetting 'ApprovalExpiryHours' | Should -Be 1
        }
        It 'produces health rows' {
            $rows = Invoke-ConsoleHealthCheck
            ($rows | Where-Object { $_.Component -eq 'Database' }).Status | Should -Be 'Healthy'
            ($rows | Where-Object { $_.Component -eq 'Plugins' }).Status | Should -Be 'Warning'
        }
        It 'protects the last GlobalAdmin' {
            Get-ErrorText { Remove-ConsoleRoleAssignment -Account 'CONTOSO\alice' -Role 'GlobalAdmin' } | Should -Match 'last GlobalAdmin'
        }
    }
}
