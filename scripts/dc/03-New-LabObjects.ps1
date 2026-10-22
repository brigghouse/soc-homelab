<#
.SYNOPSIS
    Step 3 on DC01 (after the reboot): DNS forwarders, OU structure, groups and users from lab-users.csv.

.DESCRIPTION
    Idempotent: objects that already exist are skipped. Asks once for the initial password
    given to every lab user (they must change it at first logon).

.EXAMPLE
    .\03-New-LabObjects.ps1 -CsvPath .\lab-users.csv
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$CsvPath = (Join-Path $PSScriptRoot 'lab-users.csv'),
    [string[]]$DnsForwarders = @('1.1.1.1', '8.8.8.8')
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$domainDn = (Get-ADDomain).DistinguishedName
$dnsRoot = (Get-ADDomain).DNSRoot
$rootOu = "OU=LAB,$domainDn"

# --- DNS forwarders -------------------------------------------------------
$currentForwarders = @((Get-DnsServerForwarder).IPAddress | ForEach-Object { $_.IPAddressToString })
foreach ($fwd in $DnsForwarders) {
    if ($currentForwarders -notcontains $fwd) {
        if ($PSCmdlet.ShouldProcess($fwd, 'Add DNS forwarder')) {
            Add-DnsServerForwarder -IPAddress $fwd
        }
    }
}

# --- OUs ------------------------------------------------------------------
function New-LabOu {
    param([string]$Name, [string]$Path)
    $dn = "OU=$Name,$Path"
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue)) {
        if ($PSCmdlet.ShouldProcess($dn, 'Create OU')) {
            New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true
        }
    }
    return $dn
}

$null = New-LabOu -Name 'LAB' -Path $domainDn
$usersOu = New-LabOu -Name 'Users' -Path $rootOu
foreach ($ou in 'Workstations', 'Servers', 'Groups', 'Disabled') { $null = New-LabOu -Name $ou -Path $rootOu }
$groupsOu = "OU=Groups,$rootOu"

$users = Import-Csv -Path $CsvPath
foreach ($dept in ($users.Department | Sort-Object -Unique)) { $null = New-LabOu -Name $dept -Path $usersOu }

# --- Groups ---------------------------------------------------------------
$allGroups = $users.Groups -split ';' | Where-Object { $_ } | Sort-Object -Unique
foreach ($g in $allGroups) {
    if (-not (Get-ADGroup -Filter "Name -eq '$g'" -ErrorAction SilentlyContinue)) {
        if ($PSCmdlet.ShouldProcess($g, 'Create global security group')) {
            New-ADGroup -Name $g -GroupScope Global -GroupCategory Security -Path $groupsOu
        }
    }
}

# --- Users ----------------------------------------------------------------
$initialPassword = Read-Host -AsSecureString -Prompt 'Initial password for all lab users (must meet complexity)'

foreach ($u in $users) {
    $sam = $u.SamAccountName
    if (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
        Write-Verbose "User $sam already exists, skipping."
        continue
    }
    $ouPath = "OU=$($u.Department),$usersOu"
    if ($PSCmdlet.ShouldProcess($sam, "Create user in $ouPath")) {
        New-ADUser -Name "$($u.GivenName) $($u.Surname)" `
            -GivenName $u.GivenName -Surname $u.Surname `
            -SamAccountName $sam -UserPrincipalName "$sam@$dnsRoot" `
            -Department $u.Department -Title $u.Title `
            -Path $ouPath -AccountPassword $initialPassword `
            -ChangePasswordAtLogon $true -Enabled $true
        foreach ($g in ($u.Groups -split ';' | Where-Object { $_ })) {
            Add-ADGroupMember -Identity $g -Members $sam
        }
    }
}

# Move computers into the right OUs so GPOs can target them later.
Get-ADComputer -Filter * -SearchBase "CN=Computers,$domainDn" -ErrorAction SilentlyContinue |
    ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_.Name, 'Move to Workstations OU')) {
            Move-ADObject -Identity $_.DistinguishedName -TargetPath "OU=Workstations,$rootOu"
        }
    }

Write-Output "Done. Users:"
Get-ADUser -Filter * -SearchBase $usersOu -Properties Department |
    Select-Object SamAccountName, Department, Enabled | Format-Table -AutoSize
