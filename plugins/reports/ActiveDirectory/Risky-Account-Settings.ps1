@{
    Name        = 'Risky Account Settings'
    Description = 'Enabled users with settings attackers look for: no password required, Kerberos pre-auth off, reversible encryption, SPNs (Kerberoastable), unconstrained delegation.'
    RowType     = 'User'
    RowKey      = 'SamAccountName'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        Get-ADUser -Filter 'Enabled -eq $true' -Properties PasswordNotRequired, DoesNotRequirePreAuth, AllowReversiblePasswordEncryption, ServicePrincipalName, TrustedForDelegation, PasswordLastSet, AdminCount |
            ForEach-Object {
                $issues = @()
                if ($_.PasswordNotRequired) { $issues += 'Password not required' }
                if ($_.DoesNotRequirePreAuth) { $issues += 'Kerberos pre-auth disabled' }
                if ($_.AllowReversiblePasswordEncryption) { $issues += 'Reversible encryption' }
                if (@($_.ServicePrincipalName).Count) { $issues += 'Has SPN (Kerberoastable)' }
                if ($_.TrustedForDelegation) { $issues += 'Unconstrained delegation' }
                if ($issues.Count) {
                    [pscustomobject]@{
                        Name = $_.Name; SamAccountName = $_.SamAccountName; Issues = $issues -join '; '
                        Privileged = [bool]$_.AdminCount; PasswordLastSet = $_.PasswordLastSet
                        SPNs = (@($_.ServicePrincipalName) -join '; ')
                    }
                }
            }
    }
}
