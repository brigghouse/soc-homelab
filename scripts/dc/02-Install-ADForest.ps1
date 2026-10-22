<#
.SYNOPSIS
    Step 2 on DC01: installs AD DS + DNS and creates the forest lab.local. Reboots.

.DESCRIPTION
    Asks for the Directory Services Restore Mode (DSRM) password interactively,
    so no password is ever stored in this repository.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$DomainName = 'lab.local',
    [string]$NetbiosName = 'LAB'
)

$ErrorActionPreference = 'Stop'

if ((Get-CimInstance Win32_ComputerSystem).PartOfDomain) {
    Write-Output 'This server is already part of a domain. Nothing to do.'
    return
}

if ($PSCmdlet.ShouldProcess('AD-Domain-Services', 'Install Windows feature')) {
    Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools | Out-Null
}

$dsrm = Read-Host -AsSecureString -Prompt 'DSRM (safe mode) password'

if ($PSCmdlet.ShouldProcess($DomainName, 'Create new AD forest')) {
    Import-Module ADDSDeployment
    Install-ADDSForest `
        -DomainName $DomainName `
        -DomainNetbiosName $NetbiosName `
        -InstallDns `
        -SafeModeAdministratorPassword $dsrm `
        -NoRebootOnCompletion:$true `
        -Force

    Write-Output 'Forest created. Rebooting in 10 seconds...'
    Start-Sleep -Seconds 10
    Restart-Computer -Force
}
