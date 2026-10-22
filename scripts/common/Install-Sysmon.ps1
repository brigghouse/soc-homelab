<#
.SYNOPSIS
    Run on DC01 and WS01: downloads Sysmon from Microsoft Sysinternals and installs it with this repo's config.

.DESCRIPTION
    If Sysmon is already installed, the configuration is updated instead (sysmon -c).

.EXAMPLE
    .\Install-Sysmon.ps1
    .\Install-Sysmon.ps1 -ConfigPath ..\..\configs\sysmon\sysmon-lab.xml
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\..\configs\sysmon\sysmon-lab.xml'),
    [string]$DownloadUrl = 'https://download.sysinternals.com/files/Sysmon.zip',
    [string]$InstallDir = "$env:ProgramFiles\Sysmon"
)

$ErrorActionPreference = 'Stop'
$ConfigPath = (Resolve-Path $ConfigPath).Path

# Validate the XML before touching the system.
try { [xml](Get-Content -Raw -Path $ConfigPath) | Out-Null }
catch { throw "Sysmon config '$ConfigPath' is not valid XML: $_" }

$exe = Join-Path $InstallDir 'Sysmon64.exe'

if (-not (Test-Path $exe)) {
    if ($PSCmdlet.ShouldProcess($DownloadUrl, 'Download Sysmon')) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        $zip = Join-Path $env:TEMP 'Sysmon.zip'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $InstallDir -Force
        Remove-Item $zip -Force

        # Only run a binary signed by Microsoft.
        $sig = Get-AuthenticodeSignature -FilePath $exe
        if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'Microsoft') {
            throw "Sysmon64.exe signature check failed: $($sig.Status) $($sig.SignerCertificate.Subject)"
        }
    }
}

$service = Get-Service -Name 'Sysmon64' -ErrorAction SilentlyContinue
if ($service) {
    if ($PSCmdlet.ShouldProcess('Sysmon64', "Update configuration from $ConfigPath")) {
        & $exe -c $ConfigPath
    }
}
elseif ($PSCmdlet.ShouldProcess('Sysmon64', "Install with $ConfigPath")) {
    & $exe -accepteula -i $ConfigPath
}

if ($LASTEXITCODE -ne 0) { throw "Sysmon returned exit code $LASTEXITCODE" }

Get-Service Sysmon64 | Select-Object Name, Status, StartType
Write-Output 'Check events: Event Viewer > Applications and Services Logs > Microsoft > Windows > Sysmon > Operational'
