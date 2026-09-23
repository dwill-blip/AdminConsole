# Clears the mobile number from AD (synced users) or Entra ID (cloud-only users).
# The MFA phone number is separate - see 'Remove MFA Methods'.
@{
    Name        = 'Remove Mobile Number'
    Scope       = 'User'
    Category    = 'Account'
    Order       = 45
    Confirm     = $false
    AppliesTo   = { param($User) $User.AD -or $User.Entra }
    Check       = {
        param($User)
        $num = if ($User.AD) { $User.AD.mobile } else { $User.Entra.MobilePhone }
        @{ Done = [string]::IsNullOrWhiteSpace($num); Detail = "Mobile: $(if ($num) { $num } else { '(empty)' })" }
    }
    Run         = {
        param($User)
        if ($User.AD) {
            Connect-ConsoleActiveDirectory
            Set-ADUser -Identity $User.AD.DistinguishedName -Clear mobile -ErrorAction Stop
            'Cleared the AD mobile attribute (reaches Entra ID at the next sync).'
        }
        else {
            Invoke-ConsoleGraph PATCH "v1.0/users/$($User.Entra.Id)" -Body @{ mobilePhone = $null } | Out-Null
            'Cleared mobilePhone in Entra ID.'
        }
    }
}
