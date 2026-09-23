# Two-person approval for actions that declare RequiresApproval = $true.
#
# Flow: operator clicks the action -> a Pending request is created -> someone with
# ManageApprovals approves it (not the requester, unless AllowSelfApproval) -> the
# operator clicks the action again and it runs -> the request is marked Executed and
# cannot be reused.

function Update-ExpiredApprovals {
    Invoke-DbNonQuery "UPDATE ApprovalRequests SET Status = 'Expired'
                       WHERE Status IN ('Pending', 'Approved') AND ExpiresOn IS NOT NULL AND ExpiresOn <= @n" @{ n = (Get-ConsoleNow) } | Out-Null
}

function Get-ApprovalState {
    <#
    .SYNOPSIS  Returns 'None', 'Pending' or 'Approved' plus the request row, for the current operator.
    #>
    param([Parameter(Mandatory)][string]$ActionName, [Parameter(Mandatory)][string]$Target)
    Update-ExpiredApprovals
    $row = Invoke-DbQuery "SELECT * FROM ApprovalRequests
                           WHERE ActionName = @a AND Target = @t AND RequestedBy = @u AND Status IN ('Pending', 'Approved')
                           ORDER BY CASE Status WHEN 'Approved' THEN 0 ELSE 1 END, Id DESC LIMIT 1" @{
        a = $ActionName; t = $Target; u = (Get-ConsoleUser)
    }
    if (-not $row) { return [pscustomobject]@{ Status = 'None'; Request = $null } }
    [pscustomobject]@{ Status = $row.Status; Request = $row }
}

function New-ApprovalRequest {
    param([Parameter(Mandatory)][string]$ActionName, [Parameter(Mandatory)][string]$Target, [string]$Details = '')
    $correlation = [guid]::NewGuid().ToString()
    $hours = [int](Get-ConsoleSetting 'ApprovalExpiryHours' 24)
    $id = Invoke-DbInsert 'INSERT INTO ApprovalRequests (CorrelationId, ActionName, Target, Details, RequestedBy, RequestedOn, ExpiresOn, Status)
                           VALUES (@c, @a, @t, @d, @u, @n, @e, ''Pending'')' @{
        c = $correlation; a = $ActionName; t = $Target; d = $Details; u = (Get-ConsoleUser)
        n = (Get-ConsoleNow); e = (Get-Date).AddHours($hours).ToString('yyyy-MM-ddTHH:mm:ss')
    }
    Write-ConsoleAudit -Action $ActionName -Target $Target -Result 'ApprovalRequested' -Details "Request #$id" -CorrelationId $correlation
    [pscustomobject]@{ Id = $id; CorrelationId = $correlation }
}

function Get-ApprovalRequest {
    param([ValidateSet('Pending', 'Approved', 'Rejected', 'Executed', 'Expired', 'All')][string]$Status = 'All', [int]$Id)
    Update-ExpiredApprovals
    if ($Id) { return Invoke-DbQuery 'SELECT * FROM ApprovalRequests WHERE Id = @i' @{ i = $Id } }
    if ($Status -eq 'All') { return Invoke-DbQuery 'SELECT * FROM ApprovalRequests ORDER BY Id DESC LIMIT 1000' }
    Invoke-DbQuery 'SELECT * FROM ApprovalRequests WHERE Status = @s ORDER BY Id DESC' @{ s = $Status }
}

function Set-ApprovalDecision {
    param(
        [Parameter(Mandatory)][long]$Id,
        [Parameter(Mandatory)][ValidateSet('Approved', 'Rejected')][string]$Decision,
        [string]$Notes = ''
    )
    Assert-ConsolePermission 'ManageApprovals'
    $req = Get-ApprovalRequest -Id $Id
    if (-not $req) { throw "Approval request #$Id not found." }
    if ($req.Status -ne 'Pending') { throw "Request #$Id is '$($req.Status)', not Pending." }
    $me = Get-ConsoleUser
    if ($Decision -eq 'Approved' -and $req.RequestedBy -eq $me -and -not (Get-ConsoleSetting 'AllowSelfApproval' $false)) {
        throw 'You cannot approve your own request. Another approver must do it (or set AllowSelfApproval in Settings).'
    }
    $expires = $req.ExpiresOn
    if ($Decision -eq 'Approved') {
        # Give the requester a fresh window to actually run the action.
        $expires = (Get-Date).AddHours([int](Get-ConsoleSetting 'ApprovalExpiryHours' 24)).ToString('yyyy-MM-ddTHH:mm:ss')
    }
    Invoke-DbNonQuery 'UPDATE ApprovalRequests SET Status = @s, DecidedBy = @u, DecidedOn = @n, Notes = @x, ExpiresOn = @e WHERE Id = @i' @{
        s = $Decision; u = $me; n = (Get-ConsoleNow); x = $Notes; e = $expires; i = $Id
    } | Out-Null
    Write-ConsoleAudit -Action "Approval $Decision" -Target "$($req.ActionName) -> $($req.Target)" -Result 'Success' -Details $Notes -CorrelationId $req.CorrelationId
}

function Approve-ConsoleRequest { param([Parameter(Mandatory)][long]$Id, [string]$Notes = '') Set-ApprovalDecision -Id $Id -Decision Approved -Notes $Notes }
function Deny-ConsoleRequest    { param([Parameter(Mandatory)][long]$Id, [string]$Notes = '') Set-ApprovalDecision -Id $Id -Decision Rejected -Notes $Notes }

function Complete-ApprovalRequest {
    param([Parameter(Mandatory)][long]$Id)
    Invoke-DbNonQuery "UPDATE ApprovalRequests SET Status = 'Executed', ExecutedOn = @n WHERE Id = @i" @{ n = (Get-ConsoleNow); i = $Id } | Out-Null
}
