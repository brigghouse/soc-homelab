<#
.SYNOPSIS
    Run on DC01 and WS01: installs the Wazuh agent, enrols it with WAZUH01 and adds the
    Sysmon / PowerShell / Task Scheduler log sources.

.PARAMETER Version
    Agent version. It must be the SAME as (or older than) the manager version.
    Check the manager with:  sudo /var/ossec/bin/wazuh-control info

.EXAMPLE
    .\Install-WazuhAgent.ps1 -Version 4.x.y          # replace with your manager's version
    .\Install-WazuhAgent.ps1 -MsiUrl https://packages.wazuh.com/4.x/windows/wazuh-agent-4.x.y-1.msi
#>
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Version')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Version')]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [Parameter(Mandatory, ParameterSetName = 'Url')]
    [string]$MsiUrl,

    [string]$Manager = '10.10.10.20',
    [string]$AgentGroup = 'default',
    [string]$LocalfileSnippet = (Join-Path $PSScriptRoot '..\..\configs\wazuh\agent-localfile.xml')
)

$ErrorActionPreference = 'Stop'

if ($PSCmdlet.ParameterSetName -eq 'Version') {
    $major = $Version.Split('.')[0]
    $MsiUrl = "https://packages.wazuh.com/$major.x/windows/wazuh-agent-$Version-1.msi"
}

$agentDir = "${env:ProgramFiles(x86)}\ossec-agent"
$ossecConf = Join-Path $agentDir 'ossec.conf'

# Check the manager is reachable before installing anything.
foreach ($port in 1514, 1515) {
    if (-not (Test-NetConnection -ComputerName $Manager -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue)) {
        throw "Cannot reach $Manager on TCP $port. Is WAZUH01 running and its firewall open?"
    }
}

if (-not (Test-Path $ossecConf)) {
    if ($PSCmdlet.ShouldProcess($MsiUrl, 'Download and install Wazuh agent')) {
        $msi = Join-Path $env:TEMP 'wazuh-agent.msi'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $MsiUrl -OutFile $msi -UseBasicParsing
        $msiArgs = @('/i', "`"$msi`"", '/q',
            "WAZUH_MANAGER=$Manager",
            "WAZUH_AGENT_NAME=$env:COMPUTERNAME",
            "WAZUH_AGENT_GROUP=$AgentGroup")
        $p = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru
        if ($p.ExitCode -ne 0) { throw "msiexec failed with exit code $($p.ExitCode)" }
        Remove-Item $msi -Force
    }
}
else {
    Write-Verbose 'Wazuh agent already installed.'
}

# Add extra event channels once (idempotent).
$conf = Get-Content -Raw -Path $ossecConf
if ($conf -notmatch 'Microsoft-Windows-Sysmon/Operational') {
    if ($PSCmdlet.ShouldProcess($ossecConf, 'Add Sysmon/PowerShell/TaskScheduler log sources')) {
        Copy-Item $ossecConf "$ossecConf.bak" -Force
        $snippet = Get-Content -Raw -Path $LocalfileSnippet
        $snippet = [regex]::Replace($snippet, '(?s)<!--.*?-->', '').Trim()
        $idx = $conf.LastIndexOf('</ossec_config>')
        if ($idx -lt 0) { throw "Unexpected ossec.conf format: no </ossec_config> found." }
        $conf = $conf.Substring(0, $idx) + "`r`n  <!-- soc-homelab -->`r`n" + $snippet + "`r`n" + $conf.Substring($idx)
        # ossec.conf must stay ASCII/UTF-8 without BOM.
        [IO.File]::WriteAllText($ossecConf, $conf, (New-Object Text.UTF8Encoding($false)))
    }
}

if ($PSCmdlet.ShouldProcess('WazuhSvc', 'Restart service')) {
    Restart-Service -Name WazuhSvc
}

Get-Service WazuhSvc | Select-Object Name, Status
Write-Output "Agent log: $agentDir\ossec.log  (look for 'Connected to the server')"
