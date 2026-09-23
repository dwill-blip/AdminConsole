@echo off
rem Starts the console in Windows PowerShell 5.1 (STA, no profile).
rem Run elevated only if your AD delegation requires it.
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0AdminConsole.ps1"
