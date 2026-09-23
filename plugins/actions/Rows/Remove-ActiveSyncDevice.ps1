# Row action: used by the "ActiveSync Devices" report (RowActions = 'Remove ActiveSync Device').
@{
    Name       = 'Remove ActiveSync Device'
    Scope      = 'Row'
    Category   = 'Exchange Online'
    Danger     = $true
    TargetName = { param($Row) $Row.Identity }
    Run        = {
        param($Row)
        Connect-ConsoleExchange
        Remove-MobileDevice -Identity $Row.Identity -Confirm:$false -ErrorAction Stop
    }
}
