#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated Windows PowerShell window.'
}

$baseDirectory = Join-Path $env:ProgramData 'CampusNetAutoLogin'
$credentialFile = Join-Path $baseDirectory 'credential.bin'
$loginFile = Join-Path $baseDirectory 'Login-CampusNet.ps1'
$taskName = 'CampusNetAutoLoginAtStartup'

$account = Read-Host 'Campus network account'
if ([string]::IsNullOrWhiteSpace($account)) { throw 'Account cannot be empty.' }
$securePassword = Read-Host 'Campus network password (hidden)' -AsSecureString
$passwordPointer = [IntPtr]::Zero
try {
    $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
} finally {
    if ($passwordPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    }
}
if ([string]::IsNullOrEmpty($password)) { throw 'Password cannot be empty.' }

$loginScript = @'
#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
$credentialFile = Join-Path $env:ProgramData 'CampusNetAutoLogin\credential.bin'

function Exit-WithCode([int]$Code) { exit $Code }
function Test-Gateway([int]$TimeoutMilliseconds) {
    $tcp = [System.Net.Sockets.TcpClient]::new()
    try {
        $pending = $tcp.BeginConnect('172.30.100.2', 80, $null, $null)
        if (-not $pending.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false)) { return $false }
        $tcp.EndConnect($pending)
        return $tcp.Connected
    } catch { return $false } finally { $tcp.Dispose() }
}

try {
    if (-not (Test-Path -LiteralPath $credentialFile -PathType Leaf)) { Exit-WithCode 12 }
    $encrypted = [Convert]::FromBase64String((Get-Content -LiteralPath $credentialFile -Raw).Trim())
    $plaintext = [System.Security.Cryptography.ProtectedData]::Unprotect($encrypted, $null, [System.Security.Cryptography.DataProtectionScope]::LocalMachine)
    try { $credential = [Text.Encoding]::UTF8.GetString($plaintext) | ConvertFrom-Json }
    finally { [Array]::Clear($plaintext, 0, $plaintext.Length) }

    $account = [string]$credential.Account
    $password = [string]$credential.Password
    if ([string]::IsNullOrWhiteSpace($account) -or [string]::IsNullOrEmpty($password)) { Exit-WithCode 12 }

    $available = $false
    foreach ($wait in @(0, 3, 5, 8, 12, 15)) {
        if ($wait -gt 0) { Start-Sleep -Seconds $wait }
        if (Test-Gateway -TimeoutMilliseconds 5000) { $available = $true; break }
    }
    if (-not $available) { Exit-WithCode 10 }

    $parameters = [ordered]@{
        callback = 'dr1003'; DDDDD = $account; upass = $password; OMKKey = '123456'
        R1 = '0'; R2 = ''; R3 = ''; R6 = '0'; para = '00'; v6ip = ''
        terminal_type = '1'; lang = 'zh-cn'; jsVersion = '4.1.3'; v = '9785'
    }
    $query = ($parameters.GetEnumerator() | ForEach-Object {
        '{0}={1}' -f $_.Key, [Uri]::EscapeDataString([string]$_.Value)
    }) -join '&'

    $request = [System.Net.HttpWebRequest]::CreateHttp([Uri]::new("http://172.30.100.2/drcom/login?$query"))
    $request.Method = 'GET'
    $request.Proxy = $null
    $request.AllowAutoRedirect = $false
    $request.UseDefaultCredentials = $false
    $request.Timeout = 12000
    $request.ReadWriteTimeout = 12000
    try {
        $response = $request.GetResponse()
        try {
            if ([int]$response.StatusCode -ne 200) { Exit-WithCode 13 }
            $stream = $response.GetResponseStream()
            try {
                $reader = [System.IO.StreamReader]::new($stream, [Text.Encoding]::UTF8, $true, 4096)
                try { $body = $reader.ReadToEnd() }
                finally { $reader.Dispose() }
            } finally { $stream.Dispose() }
        } finally { $response.Dispose() }
    } catch [System.Net.WebException] { Exit-WithCode 13 }

    if ($body -notmatch '(?s)^\s*dr1003\((\{.*\})\)\s*;?\s*$') { Exit-WithCode 14 }
    $result = $Matches[1] | ConvertFrom-Json
    if ([string]$result.result -eq '1') { Exit-WithCode 0 }
    Exit-WithCode 14
} catch { Exit-WithCode 15 }
finally { $password = $null }
'@

New-Item -ItemType Directory -Path $baseDirectory -Force | Out-Null
Set-Content -LiteralPath $loginFile -Value $loginScript -Encoding ASCII -NoNewline

$secret = [PSCustomObject]@{ Account = $account; Password = $password } | ConvertTo-Json -Compress
$bytes = [Text.Encoding]::UTF8.GetBytes($secret)
try {
    $encrypted = [System.Security.Cryptography.ProtectedData]::Protect($bytes, $null, [System.Security.Cryptography.DataProtectionScope]::LocalMachine)
    [Convert]::ToBase64String($encrypted) | Set-Content -LiteralPath $credentialFile -Encoding ASCII -NoNewline
} finally {
    [Array]::Clear($bytes, 0, $bytes.Length)
    $password = $null
}

$systemSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
$adminsSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
$inheritance = [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit
$allow = [Security.AccessControl.AccessControlType]::Allow
$directoryAcl = [Security.AccessControl.DirectorySecurity]::new()
$directoryAcl.SetAccessRuleProtection($true, $false)
foreach ($sid in @($systemSid, $adminsSid)) {
    $rule = [Security.AccessControl.FileSystemAccessRule]::new($sid, [Security.AccessControl.FileSystemRights]::FullControl, $inheritance, [Security.AccessControl.PropagationFlags]::None, $allow)
    [void]$directoryAcl.AddAccessRule($rule)
}
Set-Acl -LiteralPath $baseDirectory -AclObject $directoryAcl
foreach ($file in @($loginFile, $credentialFile)) {
    $fileAcl = [Security.AccessControl.FileSecurity]::new()
    $fileAcl.SetAccessRuleProtection($true, $false)
    foreach ($sid in @($systemSid, $adminsSid)) {
        $rule = [Security.AccessControl.FileSystemAccessRule]::new($sid, [Security.AccessControl.FileSystemRights]::FullControl, $allow)
        [void]$fileAcl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $file -AclObject $fileAcl
}

$action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File `"$loginFile`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = 'PT5S'
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$taskPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $taskPrincipal -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

Write-Host ''
Write-Host 'Installed successfully.'
Write-Host "Scheduled task: $taskName"
Write-Host 'A test run was started. Check LastTaskResult; 0 means authentication succeeded.'
