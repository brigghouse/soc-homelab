<#
.SYNOPSIS
    WS01: static IP, DNS -> DC01, rename and join lab.local. Reboots.

.NOTES
    Run in an elevated PowerShell inside WS01. You will be asked for LAB\Administrator credentials.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ComputerName = 'WS01',
    [string]$IPAddress = '10.10.10.30',
    [int]$PrefixLength = 24,
    [string]$Gateway = '10.10.10.1',
    [string]$DnsServer = '10.10.10.10',
    [string]$DomainName = 'lab.local'
)

$ErrorActionPreference = 'Stop'

$adapter = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1
if (-not $adapter) { throw 'No network adapter is up.' }

if ($PSCmdlet.ShouldProcess($adapter.Name, "Set static IP $IPAddress and DNS $DnsServer")) {
    Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -Dhcp Disabled
    Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Remove-NetIPAddress -Confirm:$false
    Get-NetRoute -InterfaceIndex $adapter.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Remove-NetRoute -Confirm:$false
    New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $Gateway | Out-Null
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DnsServer
}

# Fail early with a clear message instead of a cryptic domain-join error.
if (-not (Resolve-DnsName -Name $DomainName -ErrorAction SilentlyContinue)) {
    throw "Cannot resolve $DomainName via $DnsServer. Is DC01 running and reachable (ping $DnsServer)?"
}

$cred = Get-Credential -Message "Domain admin for $DomainName (e.g. LAB\Administrator)"

if ($PSCmdlet.ShouldProcess($DomainName, "Join as $ComputerName and reboot")) {
    if ($env:COMPUTERNAME -ne $ComputerName) {
        Add-Computer -DomainName $DomainName -NewName $ComputerName -Credential $cred -Restart -Force
    }
    else {
        Add-Computer -DomainName $DomainName -Credential $cred -Restart -Force
    }
}
