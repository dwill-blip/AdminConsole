# Row action: used by the "License Assignments" report.
@{
    Name             = 'Remove License Assignment'
    Scope            = 'Row'
    Category         = 'Licensing'
    Danger           = $true
    RequiresApproval = $true
    TargetName       = { param($Row) "$($Row.UserPrincipalName): $($Row.License)" }
    AppliesTo        = { param($Row) $Row.AssignedVia -eq 'Direct' }
    Run              = {
        param($Row)
        Connect-ConsoleGraph
        Set-MgUserLicense -UserId $Row.UserId -AddLicenses @() -RemoveLicenses @($Row.SkuId) -ErrorAction Stop | Out-Null
    }
}
