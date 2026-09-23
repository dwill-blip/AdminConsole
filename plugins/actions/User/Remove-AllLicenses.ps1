# Only removes DIRECTLY assigned licenses. Group-based licenses must be removed by
# taking the user out of the licensing group.
@{
    Name             = 'Remove All Licenses'
    Scope            = 'User'
    Category         = 'Entra ID'
    Order            = 20
    Danger           = $true
    RequiresApproval = $true
    AppliesTo        = { param($User) $User.Entra -and @($User.Entra.AssignedLicenses).Count -gt 0 }
    Check            = {
        param($User)
        $u = Invoke-ConsoleGraph GET "v1.0/users/$($User.Entra.Id)?`$select=licenseAssignmentStates"
        $direct = @($u.licenseAssignmentStates | Where-Object { -not $_.assignedByGroup }).Count
        $group = @($u.licenseAssignmentStates | Where-Object { $_.assignedByGroup }).Count
        @{ Done = ($direct -eq 0); Detail = "$direct direct, $group via groups" }
    }
    Run              = {
        param($User)
        Connect-ConsoleGraph
        $u = Get-MgUser -UserId $User.Entra.Id -Property 'LicenseAssignmentStates' -ErrorAction Stop
        $direct = @($u.LicenseAssignmentStates | Where-Object { -not $_.AssignedByGroup } | ForEach-Object { $_.SkuId } | Select-Object -Unique)
        $viaGroup = @($u.LicenseAssignmentStates | Where-Object { $_.AssignedByGroup }).Count
        if ($direct.Count) {
            Set-MgUserLicense -UserId $User.Entra.Id -AddLicenses @() -RemoveLicenses $direct -ErrorAction Stop | Out-Null
        }
        $msg = "Removed $($direct.Count) direct license(s)."
        if ($viaGroup) { $msg += " $viaGroup license(s) come from groups and were left in place." }
        $msg
    }
}
