# Resets the on-premises AD password (synced to Entra ID by Entra Connect).
@{
    Name        = 'Reset Password'
    Scope       = 'User'
    Category    = 'Account'
    Order       = 10
    Description = 'Set a new AD password and optionally force a change at next logon.'
    Permission  = 'ResetPassword'
    Inputs      = @(
        @{ Name = 'NewPassword'; Label = 'New password'; Type = 'Password'; Required = $true }
        @{ Name = 'MustChange';  Label = 'User must change password at next logon'; Type = 'Bool'; Default = $true }
    )
    AppliesTo   = { param($User) [bool]$User.AD }
    Check       = { param($User) @{ Done = $null; Detail = "Password last set $($User.AD.PasswordLastSet)" } }
    Run         = {
        param($User, $Inputs)
        Connect-ConsoleActiveDirectory
        $secure = ConvertTo-SecureString $Inputs.NewPassword -AsPlainText -Force
        Set-ADAccountPassword -Identity $User.AD.DistinguishedName -Reset -NewPassword $secure -ErrorAction Stop
        Set-ADUser -Identity $User.AD.DistinguishedName -ChangePasswordAtLogon $Inputs.MustChange -ErrorAction Stop
    }
}
