# Row action for the 'User Group Memberships' report: right-click a row > Remove From Group,
# or > Remove From Group - all shown rows. Filter the report first (Source, Group type, the
# text filter) to choose which groups "all" means.
#   Synced from AD groups           -> removed in Active Directory (shows in 365 after the next sync)
#   Cloud Microsoft 365 / Security  -> removed through Microsoft Graph
#   Cloud Distribution / Mail-enabled security -> removed through Exchange Online
@{
    Name        = 'Remove From Group'
    Scope       = 'Row'
    Category    = 'Microsoft 365'
    Danger      = $true
    Bulk        = $true
    Description = 'Removes the user from the group on this row. Nested and dynamic memberships cannot be removed here.'
    GraphScopes = @('GroupMember.ReadWrite.All')
    TargetName  = { param($Row) "$($Row.User): $($Row.Group)" }
    AppliesTo   = { param($Row) $Row.Membership -eq 'Direct' -and -not $Row.Dynamic -and $Row.Id }
    Run         = {
        param($Row)
        if ($Row.Source -eq 'Synced from AD') {
            if (-not $Row.GroupSamAccountName -or -not $Row.UserSamAccountName) {
                throw "'$($Row.Group)' is synced from AD but its AD name is unknown. Remove the user in Active Directory."
            }
            Connect-ConsoleActiveDirectory
            Remove-ADGroupMember -Identity $Row.GroupSamAccountName -Members $Row.UserSamAccountName -Confirm:$false -ErrorAction Stop
            return "Removed from '$($Row.Group)' in Active Directory. Microsoft 365 shows it after the next Entra Connect sync."
        }
        if ($Row.Type -in 'Distribution', 'Mail-enabled security') {
            Connect-ConsoleExchange
            Remove-DistributionGroupMember -Identity $Row.Mail -Member $Row.User -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction Stop
            return "Removed from '$($Row.Group)' in Exchange Online."
        }
        Invoke-ConsoleGraph DELETE "v1.0/groups/$($Row.Id)/members/$($Row.UserId)/`$ref" | Out-Null
        "Removed from '$($Row.Group)'."
    }
}
