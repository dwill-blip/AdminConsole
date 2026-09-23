# ReportName: Entra Devices
# Description: Entra devices.
# ActionType: EntraDevice
Ensure-Graph;Get-MgDevice -All|select @{n='ObjectId';e={$_.Id}},DisplayName,DeviceId,OperatingSystem,TrustType,AccountEnabled
