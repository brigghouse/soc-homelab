<#
.SYNOPSIS
    Generates harmless, attacker-LIKE activity on WS01 so each custom Wazuh rule can be tested.

.DESCRIPTION
    Every scenario is benign: it runs built-in Windows commands (whoami, net, schtasks...)
    and creates objects that the Cleanup scenario removes. Nothing is downloaded or exploited.
    Each action is written with a UTC timestamp to a CSV so you can line it up with the
    alerts when you write the incident report.

    ONLY run this inside the isolated soc-homelab environment.

.PARAMETER Scenario
    FailedLogons     T1110      - repeated logons with a deliberately wrong password
    NewLocalUser     T1136.001  - creates local user labsim_user
    PrivilegedGroup  T1098      - adds labsim_user to local Administrators
    EncodedPowerShell T1059.001 - runs "whoami; hostname" through -EncodedCommand
    ScheduledTask    T1053.005  - creates a one-off task that runs "whoami"
    RunKey           T1547.001  - adds an HKCU Run value that echoes text
    Discovery        T1069.002  - net group "Domain Admins" /domain, net user /domain
    All              all of the above, in order
    Cleanup          removes everything the scenarios created

.EXAMPLE
    .\Invoke-LabSimulation.ps1 -Scenario All
    .\Invoke-LabSimulation.ps1 -Scenario Cleanup
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
    Justification = 'Deliberately wrong lab-only password used to generate failed-logon events.')]
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('FailedLogons', 'NewLocalUser', 'PrivilegedGroup', 'EncodedPowerShell',
        'ScheduledTask', 'RunKey', 'Discovery', 'All', 'Cleanup')]
    [string]$Scenario,

    [string]$TargetUser = 'LAB\hprice',
    [ValidateRange(1, 30)]
    [int]$Attempts = 10,
    [string]$LogPath = (Join-Path $PSScriptRoot "simulation-log-$(Get-Date -Format yyyyMMdd).csv")
)

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw 'Run this script from an elevated PowerShell (Run as administrator).' }

$SimUser = 'labsim_user'
$SimTask = 'LabSim-Task'
$SimRunValue = 'LabSim'

function Write-SimLog {
    param([string]$Technique, [string]$Action)
    $entry = [pscustomobject]@{
        TimestampUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        Host         = $env:COMPUTERNAME
        User         = "$env:USERDOMAIN\$env:USERNAME"
        Technique    = $Technique
        Action       = $Action
    }
    $entry | Export-Csv -Path $LogPath -Append -NoTypeInformation
    Write-Output ("[{0}] {1,-10} {2}" -f $entry.TimestampUtc, $Technique, $Action)
}

function New-RandomSecureString {
    # Random throwaway password for the simulated account; never displayed or stored.
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!#%+=?'
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] 24
    $rng.GetBytes($bytes)
    $secure = New-Object Security.SecureString
    foreach ($b in $bytes) { $secure.AppendChar($chars[$b % $chars.Length]) }
    # Guarantee complexity: upper, lower, digit, symbol.
    foreach ($c in 'Q', 'q', '7', '!') { $secure.AppendChar($c) }
    $secure.MakeReadOnly()
    $rng.Dispose()
    return $secure
}

function Invoke-FailedLogons {
    if (-not $PSCmdlet.ShouldProcess($TargetUser, "$Attempts logons with a wrong password")) { return }
    Write-SimLog 'T1110' "Starting $Attempts failed logons as $TargetUser"
    $wrong = ConvertTo-SecureString 'Definitely-Not-The-Password-1!' -AsPlainText -Force
    $cred = New-Object Management.Automation.PSCredential($TargetUser, $wrong)
    for ($i = 1; $i -le $Attempts; $i++) {
        try {
            Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList '/c', 'exit' `
                -Credential $cred -WindowStyle Hidden -ErrorAction Stop | Out-Null
        }
        catch { Write-Verbose "Attempt $i failed as expected." }
        Start-Sleep -Milliseconds 700
    }
    Write-SimLog 'T1110' 'Finished failed logons'
}

function Invoke-NewLocalUser {
    if (Get-LocalUser -Name $SimUser -ErrorAction SilentlyContinue) {
        Write-Warning "$SimUser already exists. Run -Scenario Cleanup first to re-test."
        return
    }
    if ($PSCmdlet.ShouldProcess($SimUser, 'Create local user')) {
        New-LocalUser -Name $SimUser -Password (New-RandomSecureString) -Description 'soc-homelab simulation account' | Out-Null
        Write-SimLog 'T1136.001' "Created local user $SimUser"
    }
}

function Invoke-PrivilegedGroup {
    if (-not (Get-LocalUser -Name $SimUser -ErrorAction SilentlyContinue)) { Invoke-NewLocalUser }
    # Look the group up by its well-known SID so it works on any Windows language.
    $admins = Get-LocalGroup -SID 'S-1-5-32-544'
    if ($PSCmdlet.ShouldProcess($admins.Name, "Add $SimUser")) {
        Add-LocalGroupMember -Group $admins -Member $SimUser -ErrorAction SilentlyContinue
        Write-SimLog 'T1098' "Added $SimUser to $($admins.Name)"
    }
}

function Invoke-EncodedPowerShell {
    $command = 'whoami; hostname'
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    if ($PSCmdlet.ShouldProcess('powershell.exe', "-EncodedCommand ($command)")) {
        & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -EncodedCommand $encoded | Out-Null
        Write-SimLog 'T1059.001' "Ran powershell -EncodedCommand (decodes to: $command)"
    }
}

function Invoke-ScheduledTask {
    if ($PSCmdlet.ShouldProcess($SimTask, 'Create scheduled task with schtasks.exe')) {
        & schtasks.exe /create /tn $SimTask /tr 'cmd.exe /c whoami' /sc once /st 23:59 /f | Out-Null
        Write-SimLog 'T1053.005' "Created scheduled task $SimTask (runs 'cmd.exe /c whoami')"
    }
}

function Invoke-RunKey {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    if ($PSCmdlet.ShouldProcess("$key\$SimRunValue", 'Set Run value')) {
        Set-ItemProperty -Path $key -Name $SimRunValue -Value 'cmd.exe /c echo soc-homelab-simulation'
        Write-SimLog 'T1547.001' "Set $key\$SimRunValue"
    }
}

function Invoke-Discovery {
    if ($PSCmdlet.ShouldProcess('domain', 'Run discovery commands')) {
        & net.exe group 'Domain Admins' /domain 2>&1 | Out-Null
        Write-SimLog 'T1069.002' 'net group "Domain Admins" /domain'
        & net.exe user /domain 2>&1 | Out-Null
        Write-SimLog 'T1087.002' 'net user /domain'
        & whoami.exe /groups | Out-Null
        Write-SimLog 'T1033' 'whoami /groups'
    }
}

function Invoke-Cleanup {
    if (-not $PSCmdlet.ShouldProcess('simulation artefacts', 'Remove')) { return }
    if (Get-LocalUser -Name $SimUser -ErrorAction SilentlyContinue) {
        Remove-LocalUser -Name $SimUser
        Write-SimLog 'cleanup' "Removed local user $SimUser"
    }
    & schtasks.exe /query /tn $SimTask 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        & schtasks.exe /delete /tn $SimTask /f | Out-Null
        Write-SimLog 'cleanup' "Removed scheduled task $SimTask"
    }
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    if (Get-ItemProperty -Path $key -Name $SimRunValue -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $key -Name $SimRunValue
        Write-SimLog 'cleanup' "Removed $key\$SimRunValue"
    }
}

switch ($Scenario) {
    'FailedLogons' { Invoke-FailedLogons }
    'NewLocalUser' { Invoke-NewLocalUser }
    'PrivilegedGroup' { Invoke-PrivilegedGroup }
    'EncodedPowerShell' { Invoke-EncodedPowerShell }
    'ScheduledTask' { Invoke-ScheduledTask }
    'RunKey' { Invoke-RunKey }
    'Discovery' { Invoke-Discovery }
    'Cleanup' { Invoke-Cleanup }
    'All' {
        Invoke-Discovery
        Invoke-FailedLogons
        Invoke-NewLocalUser
        Invoke-PrivilegedGroup
        Invoke-EncodedPowerShell
        Invoke-ScheduledTask
        Invoke-RunKey
        Write-Output "Done. Now check the Wazuh dashboard, then run: .\Invoke-LabSimulation.ps1 -Scenario Cleanup"
    }
}

Write-Output "Action log: $LogPath"
