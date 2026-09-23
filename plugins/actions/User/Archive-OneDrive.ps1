# Copies the user's whole OneDrive into  <IT Infrastructure channel> \ OneDrive Archive \ <Display Name>.
# Run this BEFORE removing licenses. Settings: OneDriveArchive.* and SharePoint.AdminUrl.
@{
    Name        = 'Archive OneDrive'
    Scope       = 'User'
    Category    = 'Microsoft 365'
    Order       = 10
    Description = 'Copies all OneDrive files to the OneDrive Archive folder in the IT Infrastructure channel, in a folder named after the user. Items already there are skipped, so it is safe to run again.'
    GraphScopes = @('Files.ReadWrite.All', 'Sites.ReadWrite.All', 'Team.ReadBasic.All', 'Channel.ReadBasic.All')
    AppliesTo   = { param($User) [bool]$User.Entra }
    Check       = { param($User) Get-ConsoleOneDriveArchiveStatus $User }
    Run         = { param($User) Copy-ConsoleOneDriveToArchive $User }
}
