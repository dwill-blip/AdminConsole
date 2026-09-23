# For AD-synced users Exchange Online refuses Set-Mailbox -HiddenFromAddressListsEnabled
# (the source of authority is on-prem), so the AD attribute is set instead.
@{
    Name      = 'Hide from GAL'
    Scope     = 'User'
    Category  = 'Exchange Online'
    Order     = 60
    AppliesTo = { param($User) [bool]$User.UserPrincipalName }
    Check     = {
        param($User)
        $synced = $User.Entra -and $User.Entra.OnPremisesSyncEnabled
        if ($User.AD -and ($synced -or -not (Test-ConsoleSource 'ExchangeOnline'))) {
            Connect-ConsoleActiveDirectory
            $v = (Get-ADUser -Identity $User.AD.DistinguishedName -Properties msExchHideFromAddressLists -ErrorAction Stop).msExchHideFromAddressLists
            return @{ Done = ($v -eq $true); Detail = "msExchHideFromAddressLists (AD): $v" }
        }
        Connect-ConsoleExchange
        $v = (Get-Mailbox -Identity $User.UserPrincipalName -ErrorAction Stop).HiddenFromAddressListsEnabled
        @{ Done = [bool]$v; Detail = "Hidden from address lists: $v" }
    }
    Run       = {
        param($User)
        $synced = $User.Entra -and $User.Entra.OnPremisesSyncEnabled
        if ($User.AD -and ($synced -or -not (Test-ConsoleSource 'ExchangeOnline'))) {
            Connect-ConsoleActiveDirectory
            Set-ADUser -Identity $User.AD.DistinguishedName -Replace @{ msExchHideFromAddressLists = $true } -ErrorAction Stop
            'Set msExchHideFromAddressLists in AD (takes effect after the next Entra Connect sync).'
        }
        else {
            Connect-ConsoleExchange
            Set-Mailbox -Identity $User.UserPrincipalName -HiddenFromAddressListsEnabled $true -ErrorAction Stop
        }
    }
}
