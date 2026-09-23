@{
    Name        = 'App Secrets and Certificates Expiring'
    Description = 'App registration client secrets and certificates that have expired or expire within N days.'
    Parameters  = @(@{ Name = 'Days'; Label = 'Expiring within (days)'; Type = 'Number'; Default = 30; Required = $true })
    GraphScopes = @('Application.Read.All')
    Run         = {
        param($Params)
        $now = Get-Date
        $cutoff = $now.AddDays([int]$Params.Days)
        foreach ($app in @(Invoke-ConsoleGraph GET 'v1.0/applications?$select=displayName,appId,passwordCredentials,keyCredentials&$top=999' -All)) {
            $creds = @($app.passwordCredentials | ForEach-Object { @{ Kind = 'Secret'; C = $_ } }) + @($app.keyCredentials | ForEach-Object { @{ Kind = 'Certificate'; C = $_ } })
            foreach ($x in $creds) {
                if (-not $x.C) { continue }
                $end = [datetime]$x.C.endDateTime
                if ($end -le $cutoff) {
                    [pscustomobject]@{
                        Application = $app.displayName; AppId = $app.appId; Type = $x.Kind; Name = $x.C.displayName
                        Expires = $end; DaysLeft = [int]($end - $now).TotalDays
                        Status = $(if ($end -lt $now) { 'Error' } else { 'Warning' })
                    }
                }
            }
        }
    }
}
