# Approvals tab: pending requests for actions marked RequiresApproval.

function Update-UiApprovals {
    param($Page)
    Set-UiGridData $Page.Grid @(Get-ApprovalRequest -Status ([string]$Page.Filter.SelectedItem))
}

function Set-UiApprovalDecision {
    param($Page, [string]$Decision)
    $req = Get-UiGridSelection $Page.Grid
    if (-not $req) { Show-UiInfo 'Select a request first.'; return }
    if ($req.Status -ne 'Pending') { Show-UiInfo "Request #$($req.Id) is $($req.Status)."; return }
    $notes = Show-UiPrompt -Title "$Decision request #$($req.Id)" -Label "Notes for '$($req.ActionName)' on $($req.Target) (optional):"
    if ($null -eq $notes) { return }
    if ($Decision -eq 'Approve') { Approve-ConsoleRequest -Id $req.Id -Notes $notes } else { Deny-ConsoleRequest -Id $req.Id -Notes $notes }
    Update-UiApprovals $Page
}

# Hidden unless RequireApprovals is on in Settings.
Register-UiPage -Title 'Approvals' -Order 40 -Visible { [bool](Get-ConsoleSetting 'RequireApprovals' $false) } -Build {
    param($Tab)
    $ui = New-UiToolbarGrid -Parent $Tab
    $page = @{ Grid = $ui.Grid }
    $ui.Bar.Controls.Add((New-UiLabel 'Show:'))
    $page.Filter = New-UiComboBox -Items @('Pending', 'Approved', 'Rejected', 'Executed', 'Expired', 'All') -Selected 'Pending' -Width 120
    Register-UiEvent $page.Filter SelectedIndexChanged -State $page -Handler { param($p) Update-UiApprovals $p }
    $ui.Bar.Controls.Add($page.Filter)
    $ui.Bar.Controls.Add((New-UiButton -Text 'Refresh' -State $page -OnClick { param($p) Update-UiApprovals $p }))
    $canApprove = Test-ConsolePermission 'ManageApprovals'
    $approve = New-UiButton -Text 'Approve...' -State $page -OnClick { param($p) Set-UiApprovalDecision $p 'Approve' }
    $reject = New-UiButton -Text 'Reject...' -State $page -OnClick { param($p) Set-UiApprovalDecision $p 'Reject' } -Danger
    $approve.Enabled = $canApprove; $reject.Enabled = $canApprove
    $ui.Bar.Controls.AddRange(@($approve, $reject))
    $note = 'The requester runs the action again after approval. You cannot approve your own requests unless AllowSelfApproval is on.'
    if (-not $canApprove) { $note = 'You can see requests but need the ManageApprovals permission to decide them.' }
    $ui.Bar.Controls.Add((New-UiLabel "   $note"))
    Update-UiApprovals $page
}
