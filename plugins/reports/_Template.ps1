# TEMPLATE - copy into a category folder (the folder name becomes the category),
# drop the underscore, edit.
@{
    Name        = 'My Report'
    Description = 'Shown under the report tree.'
    Permission  = 'RunReport'                    # default

    # Optional inputs shown above the grid (same types as action Inputs).
    Parameters  = @(
        @{ Name = 'Days'; Label = 'Inactive for (days)'; Type = 'Number'; Default = 90 }
    )

    # Optional: make each row a User or Computer so every User/Computer action and
    # workflow is available from the row's right-click menu.
    RowType     = 'User'                         # User | Computer
    RowKey      = 'UserPrincipalName'            # column used to look the row up

    # Optional: extra Scope = 'Row' actions offered for rows of this report.
    RowActions  = @()

    # Return objects; each property becomes a column.
    Run         = {
        param($Params)
        Connect-ConsoleActiveDirectory
        $cutoff = (Get-Date).AddDays(-[int]$Params.Days)
        Get-ADUser -Filter { LastLogonDate -lt $cutoff } -Properties LastLogonDate |
            Select-Object Name, UserPrincipalName, LastLogonDate
    }
}
