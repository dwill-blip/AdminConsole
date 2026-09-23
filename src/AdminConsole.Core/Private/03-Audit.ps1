# Audit trail. Every action, approval decision, report run and settings change lands here.

function Write-ConsoleAudit {
    param(
        [Parameter(Mandatory)][string]$Action,
        [string]$Target = '',
        [Parameter(Mandatory)][string]$Result,
        [string]$Details = '',
        [string]$CorrelationId = ''
    )
    try {
        Invoke-DbNonQuery 'INSERT INTO Audit (Timestamp, Operator, Action, Target, Result, Details, CorrelationId) VALUES (@t, @o, @a, @g, @r, @d, @c)' @{
            t = (Get-ConsoleNow); o = (Get-ConsoleUser); a = $Action; g = $Target; r = $Result; d = $Details; c = $CorrelationId
        } | Out-Null
    }
    catch { Write-ConsoleLog "Could not write audit record: $($_.Exception.Message)" Error }
    $level = 'Info'
    if ($Result -in 'Failed', 'Denied') { $level = 'Warning' }
    $msg = "$Action [$Target] $Result"
    if ($Details) { $msg += " - $Details" }
    Write-ConsoleLog $msg $level
}

function Get-ConsoleAudit {
    param([string]$Search = '', [int]$Limit = 2000)
    Invoke-DbQuery "SELECT Id, Timestamp, Operator, Action, Target, Result, Details, CorrelationId FROM Audit
                    WHERE @s = '' OR Action LIKE @like OR Target LIKE @like OR Operator LIKE @like OR Result LIKE @like OR Details LIKE @like
                    ORDER BY Id DESC LIMIT @lim" @{ s = $Search; like = "%$Search%"; lim = $Limit }
}
