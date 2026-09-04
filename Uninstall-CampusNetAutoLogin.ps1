#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$taskName = 'CampusNetAutoLoginAtStartup'
$ncsiPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator'
$ncsiInternetPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet'
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
$baseDirectory = Join-Path $env:ProgramData 'CampusNetAutoLogin'
if (Test-Path -LiteralPath $baseDirectory) {
    Remove-Item -LiteralPath $baseDirectory -Recurse -Force
}

# Restore Windows active network probing.
if (Test-Path -LiteralPath $ncsiPolicyPath) {
    Remove-ItemProperty -Path $ncsiPolicyPath -Name 'NoActiveProbe' -ErrorAction SilentlyContinue
}
if (Test-Path -LiteralPath $ncsiInternetPath) {
    New-ItemProperty -Path $ncsiInternetPath -Name 'EnableActiveProbing' -PropertyType DWord -Value 1 -Force | Out-Null
}

Write-Host 'CampusNet auto-login task, local credential data, and NCSI changes removed.'
