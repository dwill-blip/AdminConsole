# Manager attribute helpers (used by the Set Manager actions and the manager reports).

function ConvertFrom-ConsoleDn {
    # 'CN=Jane Smith,OU=Staff,DC=contoso,DC=com' -> 'Jane Smith'
    param([string]$DistinguishedName)
    if (-not $DistinguishedName) { return '' }
    (($DistinguishedName -split '(?<!\\),')[0] -replace '^CN=', '') -replace '\\(.)', '$1'
}

function Resolve-ConsoleAdUser {
    <# Finds exactly one AD user by sAMAccountName, UPN, email or display name. #>
    param([Parameter(Mandatory)][string]$Identity)
    Connect-ConsoleActiveDirectory
    $id = $Identity.Trim()
    $f = ConvertTo-FilterLiteral $id
    $hits = @(Get-ADUser -Filter "sAMAccountName -eq '$f' -or UserPrincipalName -eq '$f' -or mail -eq '$f' -or DisplayName -eq '$f'" -Properties DisplayName, mail)
    if ($hits.Count -eq 0) { throw "No AD user matches '$id'. Use their username, UPN, email or exact display name." }
    if ($hits.Count -gt 1) { throw "'$id' matches $($hits.Count) users ($(($hits | ForEach-Object { $_.SamAccountName }) -join ', ')). Use the username instead." }
    $hits[0]
}

function Set-ConsoleUserManager {
    <#
    .SYNOPSIS  Sets (or with a blank -Manager, clears) a user's manager.
               AD users: the AD 'manager' attribute (reaches Entra ID at the next sync).
               Cloud-only users: the Entra ID manager via Graph.
    #>
    param([Parameter(Mandatory)]$User, [string]$Manager)
    $clear = [string]::IsNullOrWhiteSpace($Manager)
    if ($User.AD) {
        Connect-ConsoleActiveDirectory
        if ($clear) {
            Set-ADUser -Identity $User.AD.DistinguishedName -Clear manager
            return 'Manager cleared (AD).'
        }
        $m = Resolve-ConsoleAdUser $Manager
        if ($m.DistinguishedName -eq $User.AD.DistinguishedName) { throw 'A user cannot be their own manager.' }
        Set-ADUser -Identity $User.AD.DistinguishedName -Manager $m.DistinguishedName
        return "Manager set to $($m.DisplayName) ($($m.SamAccountName)). Syncs to Microsoft 365 at the next Entra Connect sync."
    }
    if (-not $User.Entra) { throw 'User has no AD or Entra ID account.' }
    if ($clear) {
        Invoke-ConsoleGraph DELETE "v1.0/users/$($User.Entra.Id)/manager/`$ref" | Out-Null
        return 'Manager cleared (Entra ID).'
    }
    $mgr = Invoke-ConsoleGraph GET "v1.0/users/$([uri]::EscapeDataString($Manager.Trim()))?`$select=id,displayName,userPrincipalName"
    Invoke-ConsoleGraph PUT "v1.0/users/$($User.Entra.Id)/manager/`$ref" -Body @{ '@odata.id' = "https://graph.microsoft.com/v1.0/users/$($mgr.id)" } | Out-Null
    "Manager set to $($mgr.displayName) ($($mgr.userPrincipalName))."
}
