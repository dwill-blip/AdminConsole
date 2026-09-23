# "Disable MFA" for a leaver: removes every registered authentication method except the
# password (phone, Authenticator app, OATH tokens, FIDO2 keys, Windows Hello, email,
# temporary access pass) and turns legacy per-user MFA off.
@{
    Name        = 'Remove MFA Methods'
    Scope       = 'User'
    Category    = 'Entra ID'
    Order       = 15
    Danger      = $true
    Description = 'Deletes all MFA / sign-in methods except the password, and sets per-user MFA to disabled.'
    GraphScopes = @('UserAuthenticationMethod.ReadWrite.All', 'Policy.ReadWrite.AuthenticationMethod')
    AppliesTo   = { param($User) [bool]$User.Entra }
    Check       = {
        param($User)
        $m = @(Invoke-ConsoleGraph GET "v1.0/users/$($User.Entra.Id)/authentication/methods" -All |
            Where-Object { $_.'@odata.type' -ne '#microsoft.graph.passwordAuthenticationMethod' })
        $kinds = ($m | ForEach-Object { ($_.'@odata.type' -replace '#microsoft.graph.', '' -replace 'AuthenticationMethod', '') }) -join ', '
        @{ Done = ($m.Count -eq 0); Detail = "$($m.Count) method(s)$(if ($kinds) { ": $kinds" })" }
    }
    Run         = {
        param($User)
        $id = $User.Entra.Id
        $segment = @{
            '#microsoft.graph.phoneAuthenticationMethod'                   = 'phoneMethods'
            '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod'  = 'microsoftAuthenticatorMethods'
            '#microsoft.graph.softwareOathAuthenticationMethod'            = 'softwareOathMethods'
            '#microsoft.graph.fido2AuthenticationMethod'                   = 'fido2Methods'
            '#microsoft.graph.windowsHelloForBusinessAuthenticationMethod' = 'windowsHelloForBusinessMethods'
            '#microsoft.graph.emailAuthenticationMethod'                   = 'emailMethods'
            '#microsoft.graph.temporaryAccessPassAuthenticationMethod'     = 'temporaryAccessPassMethods'
            '#microsoft.graph.platformCredentialAuthenticationMethod'      = 'platformCredentialMethods'
        }
        $removed = 0; $errors = @{}
        # The default method can only go once the others are gone, so make up to three passes.
        for ($pass = 1; $pass -le 3; $pass++) {
            $left = @(Invoke-ConsoleGraph GET "v1.0/users/$id/authentication/methods" -All |
                Where-Object { $_.'@odata.type' -ne '#microsoft.graph.passwordAuthenticationMethod' })
            if (-not $left.Count) { break }
            foreach ($m in $left) {
                $seg = $segment[$m.'@odata.type']
                if (-not $seg) { $errors[$m.id] = "unsupported type $($m.'@odata.type')"; continue }
                try { Invoke-ConsoleGraph DELETE "v1.0/users/$id/authentication/$seg/$($m.id)" | Out-Null; $removed++; $errors.Remove($m.id) }
                catch { $errors[$m.id] = "$seg : $($_.Exception.Message)" }
            }
        }
        $msg = "Removed $removed method(s)."
        try {
            Invoke-ConsoleGraph PATCH "beta/users/$id/authentication/requirements" -Body @{ perUserMfaState = 'disabled' } | Out-Null
            $msg += ' Per-user MFA set to disabled.'
        }
        catch { $msg += " (Per-user MFA not changed: $($_.Exception.Message))" }
        if ($errors.Count) { throw "$msg Could not remove: $($errors.Values -join '; ')" }
        $msg
    }
}
