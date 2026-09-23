@{
    Name             = 'Delete Entra Devices'
    Scope            = 'Computer'
    Category         = 'Entra ID'
    Order            = 90
    Danger           = $true
    RequiresApproval = $true
    Description      = 'Deletes every Entra ID device object with this display name.'
    AppliesTo        = { param($Computer) @($Computer.Entra).Count -gt 0 }
    Run              = {
        param($Computer)
        Connect-ConsoleGraph
        foreach ($d in @($Computer.Entra)) { Remove-MgDevice -DeviceId $d.Id -ErrorAction Stop }
        "Deleted $(@($Computer.Entra).Count) Entra device object(s)."
    }
}
