# TEMPLATE - copy, drop the underscore, edit. Steps are action names (same Scope).
@{
    Name        = 'My Workflow'
    Scope       = 'User'                         # User | Computer
    Description = 'What this does.'
    StopOnError = $false                         # $true = stop at the first failed step
    Steps       = @(
        'Revoke Sign-in Sessions'
        'Disable AD Account'
    )
}
