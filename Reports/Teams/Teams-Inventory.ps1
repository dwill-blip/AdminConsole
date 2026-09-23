# ReportName: Teams Inventory
# Description: Teams inventory.
Ensure-Graph;Get-MgTeam -All|select DisplayName,Description,Visibility,Id
