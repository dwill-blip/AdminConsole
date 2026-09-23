# Sets the Office field to the text in Settings (Offboarding.OfficeText, default 'Disabled').
@{
    Name        = 'Set Office to Disabled'
    Scope       = 'User'
    Category    = 'Account'
    Order       = 46
    Confirm     = $false
    AppliesTo   = { param($User) $User.AD -or $User.Entra }
    Check       = {
        param($User)
        $want = Get-ConsoleSetting 'Offboarding.OfficeText' 'Disabled'
        $now = if ($User.AD) { $User.AD.Office } else { $User.Entra.OfficeLocation }
        @{ Done = ($now -eq $want); Detail = "Office: $(if ($now) { $now } else { '(empty)' })" }
    }
    Run         = {
        param($User)
        $want = Get-ConsoleSetting 'Offboarding.OfficeText' 'Disabled'
        if ($User.AD) {
            Connect-ConsoleActiveDirectory
            Set-ADUser -Identity $User.AD.DistinguishedName -Office $want -ErrorAction Stop
        }
        else {
            Invoke-ConsoleGraph PATCH "v1.0/users/$($User.Entra.Id)" -Body @{ officeLocation = $want } | Out-Null
        }
        "Office set to '$want'."
    }
}
