# ReportName: ActiveSync Devices
# Description: Exchange mobile device partnerships.
# ActionType: ActiveSyncDevice
Ensure-EXO;Get-MobileDevice -ResultSize Unlimited|select UserDisplayName,Identity,DeviceType,DeviceModel,DeviceOS,DeviceAccessState,FirstSyncTime
