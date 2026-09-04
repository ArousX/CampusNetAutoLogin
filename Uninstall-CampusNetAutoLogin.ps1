#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$taskName = 'CampusNetAutoLoginAtStartup'
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
$baseDirectory = Join-Path $env:ProgramData 'CampusNetAutoLogin'
if (Test-Path -LiteralPath $baseDirectory) {
    Remove-Item -LiteralPath $baseDirectory -Recurse -Force
}
Write-Host 'CampusNet auto-login task and local credential data removed.'
