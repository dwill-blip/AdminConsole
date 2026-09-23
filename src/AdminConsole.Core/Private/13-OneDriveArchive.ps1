# Copying a leaver's OneDrive into a Teams channel's files ("OneDrive Archive\<user>").
#
# Settings:  OneDriveArchive.TeamName     team that owns the channel (blank = search all teams)
#            OneDriveArchive.ChannelName  default 'IT Infrastructure'
#            OneDriveArchive.Folder       folder inside the channel, default 'OneDrive Archive'
#            OneDriveArchive.WaitSeconds  how long to wait for copies to finish, default 300
#            SharePoint.AdminUrl          optional, e.g. https://contoso-admin.sharepoint.com - lets
#                                         the console grant you access to the user's OneDrive

$script:ArchiveRootCache = $null

function ConvertTo-SafeFolderName {
    param([string]$Name)
    $clean = ($Name -replace '["*:<>?/\\|#%]', ' ').Trim().TrimEnd('.')
    if (-not $clean) { $clean = 'Unnamed user' }
    $clean
}

function ConvertTo-GraphFilterUri {
    param([string]$Base, [string]$Filter)
    "$($Base)?`$filter=$([uri]::EscapeDataString($Filter))"
}

function Get-ConsoleDriveChild {
    <# Folder/file named $Name directly under $ParentId, or $null. -Create makes a folder if missing. #>
    param([Parameter(Mandatory)][string]$DriveId, [Parameter(Mandatory)][string]$ParentId, [Parameter(Mandatory)][string]$Name, [switch]$Create)
    $enc = [uri]::EscapeDataString($Name)
    $item = Invoke-ConsoleGraph GET "v1.0/drives/$DriveId/items/$($ParentId):/$($enc):" -AllowNotFound
    if (-not $item -and $Create) {
        $item = Invoke-ConsoleGraph POST "v1.0/drives/$DriveId/items/$ParentId/children" -Body @{
            name = $Name; folder = @{}; '@microsoft.graph.conflictBehavior' = 'fail'
        }
    }
    $item
}

function Get-ConsoleArchiveRoot {
    <#
    .SYNOPSIS  Finds (and with -Create, makes) the archive folder in the Teams channel. Returns DriveId, ItemId, Path.
    #>
    param([switch]$Create)
    $teamName = Get-ConsoleSetting 'OneDriveArchive.TeamName' ''
    $channelName = Get-ConsoleSetting 'OneDriveArchive.ChannelName' 'IT Infrastructure'
    $folderName = Get-ConsoleSetting 'OneDriveArchive.Folder' 'OneDrive Archive'
    $key = "$teamName|$channelName|$folderName"
    if ($script:ArchiveRootCache -and $script:ArchiveRootCache.Key -eq $key) { return $script:ArchiveRootCache }

    if ($teamName) { $teams = @(Invoke-ConsoleGraph GET (ConvertTo-GraphFilterUri 'v1.0/teams' "displayName eq '$(ConvertTo-FilterLiteral $teamName)'") -All) }
    else { $teams = @(Invoke-ConsoleGraph GET 'v1.0/teams' -All) }
    if (-not $teams.Count) {
        if ($teamName) { throw "No team named '$teamName' was found (Settings: OneDriveArchive.TeamName)." }
        throw 'No Teams were found. Check the Team.ReadBasic.All permission.'
    }
    # A team named like the channel goes first (e.g. team 'IT Infrastructure').
    $teams = @($teams | Sort-Object { if ($_.displayName -eq $channelName) { 0 } else { 1 } })

    $team = $null; $channel = $null
    foreach ($t in $teams) {
        $hit = @(Invoke-ConsoleGraph GET (ConvertTo-GraphFilterUri "v1.0/teams/$($t.id)/channels" "displayName eq '$(ConvertTo-FilterLiteral $channelName)'") -All)
        if ($hit.Count) { $team = $t; $channel = $hit[0]; break }
    }
    if (-not $channel) {
        $named = @($teams | Where-Object { $_.displayName -eq $channelName }) | Select-Object -First 1
        if ($named) {
            $team = $named
            $channel = @(Invoke-ConsoleGraph GET (ConvertTo-GraphFilterUri "v1.0/teams/$($named.id)/channels" "displayName eq 'General'") -All) | Select-Object -First 1
        }
    }
    if (-not $channel) { throw "No channel named '$channelName' was found$(if ($teamName) { " in team '$teamName'" } else { ' in any team you can see' }). Set OneDriveArchive.TeamName / ChannelName in Settings." }

    $files = Invoke-ConsoleGraph GET "v1.0/teams/$($team.id)/channels/$($channel.id)/filesFolder"
    $driveId = $files.parentReference.driveId
    $folder = Get-ConsoleDriveChild -DriveId $driveId -ParentId $files.id -Name $folderName -Create:$Create
    if (-not $folder) { return $null }
    $script:ArchiveRootCache = [pscustomobject]@{
        Key = $key; DriveId = $driveId; ItemId = $folder.id
        Path = "$($team.displayName) > $($channel.displayName) > $folderName"; WebUrl = $folder.webUrl
    }
    $script:ArchiveRootCache
}

function Get-ConsoleUserDrive {
    <# The user's OneDrive, $null if they have none. Throws a helpful error on access denied. #>
    param([Parameter(Mandatory)]$User)
    try {
        Invoke-ConsoleGraph GET "v1.0/users/$($User.Entra.Id)/drive" -AllowNotFound
    }
    catch {
        if ("$($_.Exception.Message)$($_.ErrorDetails)" -match 'accessDenied|Forbidden|403') {
            throw [System.UnauthorizedAccessException]::new("You don't have access to $($User.UserPrincipalName)'s OneDrive. Set SharePoint.AdminUrl in Settings so the console can grant it, or in the Microsoft 365 admin center open the user > OneDrive > 'Create link to files', then retry.")
        }
        throw
    }
}

function Grant-ConsoleOneDriveAccess {
    <# Makes the signed-in operator a site admin of the user's OneDrive (needs SharePoint.AdminUrl + SPO module). #>
    param([Parameter(Mandatory)]$User)
    $adminUrl = Get-ConsoleSetting 'SharePoint.AdminUrl' ''
    if (-not $adminUrl) { return $false }
    Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking -ErrorAction Stop -Verbose:$false
    try { Get-SPOTenant -ErrorAction Stop | Out-Null } catch { Connect-SPOService -Url $adminUrl -ErrorAction Stop }
    $upn = $User.UserPrincipalName
    $site = Get-SPOSite -IncludePersonalSite $true -Limit All -Filter "Owner -eq '$upn'" -ErrorAction Stop |
        Where-Object { $_.Url -like '*/personal/*' } | Select-Object -First 1
    if (-not $site) { throw "No OneDrive site found for $upn." }
    $me = (Get-MgContext).Account
    if (-not $me) { throw 'Cannot tell which account to grant (Graph is signed in app-only).' }
    Set-SPOUser -Site $site.Url -LoginName $me -IsSiteCollectionAdmin $true -ErrorAction Stop | Out-Null
    Write-ConsoleAudit -Action 'Grant OneDrive Access' -Target $upn -Result 'Success' -Details "$me is now site admin of $($site.Url)"
    $true
}

function Get-ConsoleOneDriveArchiveStatus {
    <# Compares the user's OneDrive top level with their archive folder. #>
    param([Parameter(Mandatory)]$User)
    $drive = Get-ConsoleUserDrive $User
    if (-not $drive) { return @{ Done = $true; Detail = 'User has no OneDrive' } }
    $src = @(Invoke-ConsoleGraph GET "v1.0/drives/$($drive.id)/root/children?`$select=id,name,size" -All)
    if (-not $src.Count) { return @{ Done = $true; Detail = 'OneDrive is empty' } }
    $root = Get-ConsoleArchiveRoot
    $folder = $null
    if ($root) { $folder = Get-ConsoleDriveChild -DriveId $root.DriveId -ParentId $root.ItemId -Name (ConvertTo-SafeFolderName $User.DisplayName) }
    if (-not $folder) { return @{ Done = $false; Detail = "Not archived yet ($($src.Count) top-level items, $([math]::Round(($drive.quota.used) / 1MB)) MB)" } }
    $dst = @(Invoke-ConsoleGraph GET "v1.0/drives/$($root.DriveId)/items/$($folder.id)/children?`$select=name" -All)
    $names = @($dst | ForEach-Object { $_.name })
    $missing = @($src | Where-Object { $names -notcontains $_.name })
    if ($missing.Count) { return @{ Done = $false; Detail = "$($missing.Count) of $($src.Count) top-level items not in the archive yet" } }
    @{ Done = $true; Detail = "All $($src.Count) top-level items are in $($root.Path)" }
}

function Copy-ConsoleOneDriveToArchive {
    param([Parameter(Mandatory)]$User)
    try { $drive = Get-ConsoleUserDrive $User }
    catch [System.UnauthorizedAccessException] {
        if (-not (Grant-ConsoleOneDriveAccess $User)) { throw }
        $drive = $null
        for ($i = 0; $i -lt 6 -and -not $drive; $i++) {
            Start-Sleep -Seconds 10   # permission change takes a moment to reach Graph
            try { $drive = Get-ConsoleUserDrive $User } catch [System.UnauthorizedAccessException] { }
        }
        if (-not $drive) { throw 'Access to the OneDrive was granted but Graph has not picked it up yet. Try again in a minute.' }
    }
    if (-not $drive) { return 'User has no OneDrive - nothing to archive.' }

    $src = @(Invoke-ConsoleGraph GET "v1.0/drives/$($drive.id)/root/children?`$select=id,name,size,folder,file" -All)
    if (-not $src.Count) { return 'OneDrive is empty - nothing to archive.' }

    $root = Get-ConsoleArchiveRoot -Create
    $folderName = ConvertTo-SafeFolderName $User.DisplayName
    $dest = Get-ConsoleDriveChild -DriveId $root.DriveId -ParentId $root.ItemId -Name $folderName -Create
    $already = @(Invoke-ConsoleGraph GET "v1.0/drives/$($root.DriveId)/items/$($dest.id)/children?`$select=name" -All | ForEach-Object { $_.name })

    $monitors = New-Object System.Collections.ArrayList
    $skipped = 0; $bytes = 0
    foreach ($item in $src) {
        if ($already -contains $item.name) { $skipped++; continue }
        $body = @{ parentReference = @{ driveId = $root.DriveId; id = $dest.id }; name = $item.name } | ConvertTo-Json -Depth 5
        $resp = Invoke-MgGraphRequest -Method POST -Uri "v1.0/drives/$($drive.id)/items/$($item.id)/copy" -Body $body -ContentType 'application/json' -OutputType HttpResponseMessage -ErrorAction Stop
        if (-not $resp.IsSuccessStatusCode) { throw "Copy of '$($item.name)' was refused: $([int]$resp.StatusCode) $($resp.ReasonPhrase)" }
        [void]$monitors.Add([pscustomobject]@{ Name = $item.name; Url = $resp.Headers.Location.AbsoluteUri; Status = 'inProgress' })
        $bytes += [long]$item.size
    }

    $deadline = (Get-Date).AddSeconds([int](Get-ConsoleSetting 'OneDriveArchive.WaitSeconds' 300))
    while (@($monitors | Where-Object { $_.Status -notin 'completed', 'failed' }).Count -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 5
        foreach ($m in @($monitors | Where-Object { $_.Status -notin 'completed', 'failed' })) {
            if (-not $m.Url) { $m.Status = 'unknown'; continue }
            try { $m.Status = [string](Invoke-RestMethod -Uri $m.Url -Method Get -ErrorAction Stop).status } catch { }
        }
    }
    $failed = @($monitors | Where-Object { $_.Status -eq 'failed' })
    $running = @($monitors | Where-Object { $_.Status -notin 'completed', 'failed' })
    $msg = "Copied $($monitors.Count - $failed.Count - $running.Count) of $($monitors.Count) item(s) ($([math]::Round($bytes / 1MB)) MB) to $($root.Path) > $folderName."
    if ($skipped) { $msg += " $skipped already there." }
    if ($running.Count) { $msg += " $($running.Count) still copying in the background - use Check status later." }
    if ($failed.Count) { throw "$msg FAILED: $(($failed | ForEach-Object { $_.Name }) -join ', ')" }
    $msg
}
