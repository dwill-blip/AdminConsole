@{
    Name        = 'Domain Controllers'
    Description = 'All domain controllers with site, OS, GC/RODC status and FSMO roles.'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        Get-ADDomainController -Filter * |
            Select-Object Name, Site, IPv4Address, OperatingSystem, IsGlobalCatalog, IsReadOnly,
                @{ n = 'FSMORoles'; e = { @($_.OperationMasterRoles) -join ', ' } }, Domain
    }
}
