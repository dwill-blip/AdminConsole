# Uses well-known SIDs so it works whatever the groups are called (and in any language).
@{
    Name        = 'Privileged Group Members'
    Description = 'Everyone in Domain/Enterprise/Schema Admins, Administrators and the operator groups (nested membership expanded).'
    RowType     = 'User'
    RowKey      = 'SamAccountName'
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        $domainSid = (Get-ADDomain).DomainSID.Value
        $rootSid = (Get-ADDomain (Get-ADForest).RootDomain).DomainSID.Value
        $sids = [ordered]@{
            'Domain Admins'                  = "$domainSid-512"
            'Enterprise Admins'              = "$rootSid-519"
            'Schema Admins'                  = "$rootSid-518"
            'Administrators'                 = 'S-1-5-32-544'
            'Account Operators'              = 'S-1-5-32-548'
            'Server Operators'               = 'S-1-5-32-549'
            'Backup Operators'               = 'S-1-5-32-551'
            'Print Operators'                = 'S-1-5-32-550'
            'Group Policy Creator Owners'    = "$domainSid-520"
            'Key Admins'                     = "$domainSid-526"
            'Enterprise Key Admins'          = "$rootSid-527"
        }
        foreach ($label in $sids.Keys) {
            try { $g = Get-ADGroup -Identity $sids[$label] -ErrorAction Stop } catch { continue }
            foreach ($m in @(Get-ADGroupMember -Identity $g -Recursive -ErrorAction Stop)) {
                $enabled = $null; $last = $null
                if ($m.objectClass -eq 'user') {
                    $u = Get-ADUser $m.distinguishedName -Properties Enabled, LastLogonDate, PasswordLastSet
                    $enabled = $u.Enabled; $last = $u.LastLogonDate
                }
                [pscustomobject]@{
                    Group = $g.Name; Member = $m.name; SamAccountName = $m.SamAccountName
                    Type = $m.objectClass; Enabled = $enabled; LastLogonDate = $last
                }
            }
        }
    }
}
