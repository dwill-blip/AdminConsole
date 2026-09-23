# Audit tab.

Register-UiPage -Title 'Audit' -Order 60 -Permission 'ViewAudit' -Build {
    param($Tab)
    $ui = New-UiToolbarGrid -Parent $Tab
    $page = @{ Grid = $ui.Grid }
    $page.Search = New-UiTextBox -Width 280 -Cue 'Searches action, target, operator, result and details'
    $ui.Bar.Controls.Add((New-UiLabel 'Search:'))
    $ui.Bar.Controls.Add($page.Search)
    $run = { param($p) Set-UiGridData $p.Grid @(Get-ConsoleAudit -Search $p.Search.Text.Trim()) }
    $ui.Bar.Controls.Add((New-UiButton -Text 'Search' -State $page -OnClick $run))
    Register-UiEvent $page.Search KeyDown -State $page -Handler {
        param($p, $sender, $e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) { $e.SuppressKeyPress = $true; Set-UiGridData $p.Grid @(Get-ConsoleAudit -Search $p.Search.Text.Trim()) }
    }
    $ui.Bar.Controls.Add((New-UiButton -Text 'Export...' -State $page -OnClick {
                param($p)
                $rows = @($p.Grid.Tag['Rows'])
                if (-not $rows.Count) { return }
                $dlg = New-Object System.Windows.Forms.SaveFileDialog
                $dlg.Filter = 'CSV (*.csv)|*.csv|HTML (*.html)|*.html'
                $dlg.FileName = "audit-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
                if ($dlg.ShowDialog() -eq 'OK') { Export-ConsoleRows -Rows $rows -Path $dlg.FileName -Title 'Audit log' }
                $dlg.Dispose()
            }))
    Register-UiEvent $page.Grid CellDoubleClick -State $page -Handler {
        param($p, $sender, $e)
        if ($e.RowIndex -lt 0) { return }
        $row = Get-UiGridSelection $p.Grid
        if ($row) { Show-UiText -Title "Audit #$($row.Id)" -Text (($row | Format-List | Out-String).Trim()) }
    }
    & $run $page
}
