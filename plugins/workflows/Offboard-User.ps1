# Standard leaver process. Before it runs, every step is checked and only the steps
# that still need doing are ticked. Steps that need approval create a request and are
# skipped; run the workflow again once they are approved.
#
# Order matters:
#  - Entra Connect sync runs right after the password reset (so the new password and
#    session revocation take effect in the cloud) and again after the AD account is disabled.
#  - OneDrive is archived and the mailbox converted BEFORE licenses are removed.
#  - Move to Disabled OU runs last, after the second sync. If that OU is outside your
#    sync scope, the next sync will delete the cloud user - which is why it comes last.
@{
    Name        = 'Offboard User'
    Scope       = 'User'
    Order       = 10
    Description = 'Standard leaver process: lock the account, cut access, preserve data.'
    Steps       = @(
        'Reset Password'
        'Run Entra Connect Sync'
        'Revoke Sign-in Sessions'
        'Remove MFA Methods'
        'Remove Admin Roles'
        'Disable ActiveSync'
        'Remove Mobile Devices'
        'Remove Inbox Rules'
        'Disable Out of Office'
        'Archive OneDrive'
        'Remove from Teams'
        'Convert to Shared Mailbox'
        'Hide from GAL'
        'Remove Mobile Number'
        'Set Office to Disabled'
        'Remove AD Group Memberships'
        'Remove All Licenses'
        'Disable AD Account'
        'Run Entra Connect Sync'
        'Move to Disabled OU'
    )
}
