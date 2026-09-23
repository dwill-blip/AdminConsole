# Lightweight log fan-out. The GUI registers a sink that appends to its log box;
# the job runner registers one that writes to the console / transcript.

$script:LogSinks = New-Object System.Collections.ArrayList

function Register-ConsoleLogSink {
    param([Parameter(Mandatory)][scriptblock]$Sink)
    [void]$script:LogSinks.Add($Sink)
}

function Clear-ConsoleLogSinks { $script:LogSinks.Clear() }

function Write-ConsoleLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')][string]$Level = 'Info'
    )
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level.ToUpper(), $Message
    Write-Verbose $line
    foreach ($sink in @($script:LogSinks)) {
        try { & $sink $line $Level } catch { Write-Verbose "Log sink failed: $_" }
    }
}

function Get-ConsoleNow { (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss') }

function Register-ConsoleFileLog {
    # Daily log file under logs\ - handy when something fails and the window is gone.
    param([Parameter(Mandatory)][string]$Folder)
    if (-not (Test-Path $Folder)) { New-Item -ItemType Directory -Path $Folder -Force | Out-Null }
    $script:LogFolder = $Folder
    Register-ConsoleLogSink {
        param($Line, $Level)
        $file = Join-Path $script:LogFolder ('console-{0}.log' -f (Get-Date -Format 'yyyyMMdd'))
        Add-Content -Path $file -Value $Line -Encoding UTF8
    }
}
