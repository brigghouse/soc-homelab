<#
.SYNOPSIS
    Step 1 on DC01: static IP, DNS pointing to itself, rename to DC01. Reboots.

.NOTES
    Run in an elevated PowerShell inside the DC01 VM.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ComputerName = 'DC01',
    [string]$IPAddress = '10.10.10.10',
    [int]$PrefixLength = 24,
    [string]$Gateway = '10.10.10.1'
)

$ErrorActionPreference = 'Stop'

$adapter = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1
if (-not $adapter) { throw 'No network adapter is up.' }

if ($PSCmdlet.ShouldProcess($adapter.Name, "Set static IP $IPAddress/$PrefixLength")) {
    Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -Dhcp Disabled
    Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Remove-NetIPAddress -Confirm:$false
    Get-NetRoute -InterfaceIndex $adapter.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Remove-NetRoute -Confirm:$false
    New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $Gateway | Out-Null
    # Until AD DS is installed, use a public resolver; Install-ADDSForest switches DNS to itself.
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses '1.1.1.1'
}

# Keep the clock right: Kerberos breaks with > 5 minutes of skew.
Set-TimeZone -Id 'GMT Standard Time' -ErrorAction SilentlyContinue

if ($env:COMPUTERNAME -ne $ComputerName -and $PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Rename to $ComputerName and reboot")) {
    Rename-Computer -NewName $ComputerName -Force
    Restart-Computer -Force
}
else {
    Write-Output "Computer is already named $ComputerName. Network configured."
}
