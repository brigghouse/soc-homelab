<#
.SYNOPSIS
    Creates the VirtualBox NAT Network used by the SOC lab and the port forward for the Wazuh dashboard.

.DESCRIPTION
    Run on the Windows HOST (not inside a VM). Idempotent: if the network already exists it is left as is.

.EXAMPLE
    .\New-LabNetwork.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$NetworkName = 'LabNet',
    [string]$Cidr = '10.10.10.0/24',
    [string]$WazuhIp = '10.10.10.20',
    [int]$DashboardHostPort = 8443,
    [string]$VBoxManage = "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"
)

if (-not (Test-Path $VBoxManage)) {
    throw "VBoxManage not found at '$VBoxManage'. Is VirtualBox installed?"
}

$existing = & $VBoxManage natnetwork list 2>$null | Select-String -Pattern "Name:\s+$NetworkName$"
if ($existing) {
    Write-Verbose "NAT network '$NetworkName' already exists."
}
elseif ($PSCmdlet.ShouldProcess($NetworkName, 'Create NAT network')) {
    & $VBoxManage natnetwork add --netname $NetworkName --network $Cidr --enable --dhcp off
    if ($LASTEXITCODE -ne 0) { throw "Could not create NAT network '$NetworkName'." }
}

# Forward https://localhost:8443 on the host to the Wazuh dashboard (443) inside the lab.
$rule = "wazuh-dashboard:tcp:[127.0.0.1]:${DashboardHostPort}:[${WazuhIp}]:443"
if ($PSCmdlet.ShouldProcess($NetworkName, "Add port forward $rule")) {
    & $VBoxManage natnetwork modify --netname $NetworkName --port-forward-4 $rule 2>$null
}

& $VBoxManage natnetwork list
Write-Output "Done. Attach each VM's adapter 1 to 'NAT Network' -> '$NetworkName'."
Write-Output "Wazuh dashboard (once installed): https://localhost:$DashboardHostPort"
