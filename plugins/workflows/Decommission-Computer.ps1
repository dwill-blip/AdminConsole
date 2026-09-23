@{
    Name        = 'Decommission Computer'
    Scope       = 'Computer'
    Order       = 10
    Description = 'Delete the device from Entra ID and Active Directory.'
    Steps       = @(
        'Delete Entra Devices'
        'Delete AD Computer'
    )
}
