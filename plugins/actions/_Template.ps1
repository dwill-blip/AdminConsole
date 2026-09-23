# TEMPLATE - copy this file, drop the leading underscore, and edit.
# Files starting with '_' are ignored by the loader.
#
# The file must end with a hashtable. Required keys: Name, Scope, Run.
@{
    Name             = 'My New Action'          # button text; must be unique
    Scope            = 'User'                   # User | Computer | Row
    Category         = 'Account'                # groups buttons on the page (defaults to the folder name)
    Order            = 100                      # sort order inside the category
    Description      = 'Tooltip text.'
    Permission       = 'MyNewAction'            # defaults to Name without spaces; assign it to roles on the Access tab
    RequiresApproval = $false                   # $true = a second person must approve first
    Danger           = $false                   # $true = red button
    Confirm          = $true                    # $false = no "are you sure?", or a string like 'Really do X to {0}?'

    # Optional: prompt the operator for values before running.
    # Types: Text, Password, Multiline, Number, Bool, Choice (with Choices = @(...)), Date
    Inputs           = @(
        @{ Name = 'Reason'; Label = 'Reason'; Type = 'Text'; Required = $true }
    )

    # Optional: grey the button out when it does not make sense for this target.
    AppliesTo        = { param($User) [bool]$User.AD }

    # Row actions only: how the target is named in the audit log / approvals.
    # TargetName     = { param($Row) $Row.UserPrincipalName }

    # $Target is a hybrid user (.AD, .Entra, .UserPrincipalName ...), a hybrid computer
    # (.AD, .Entra[]), or a report row. $Inputs is a hashtable of the values above.
    # Throw to report failure. Anything you output is shown to the operator.
    Run              = {
        param($User, $Inputs)
        Connect-ConsoleActiveDirectory          # or Connect-ConsoleGraph / Connect-ConsoleExchange
        Set-ADUser -Identity $User.AD.DistinguishedName -Description $Inputs.Reason -ErrorAction Stop
        "Description set."
    }
}
