@{
    Name        = 'Teams Inventory'
    Description = 'Every Microsoft Team.'
    Run         = {
        param($Params)
        Connect-ConsoleGraph
        Get-MgTeam -All -ErrorAction Stop | Select-Object DisplayName, Description, Visibility, IsArchived, Id
    }
}
