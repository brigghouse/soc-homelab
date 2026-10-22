<#
.SYNOPSIS
    Run on DC01 AND on WS01: enables the advanced audit subcategories the detections rely on
    and makes the Security log big enough not to roll over in minutes.

.NOTES
    In a real company this would be a GPO. Using auditpol keeps the lab simple and reproducible.
    Check the result with:  auditpol /get /category:*
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [int]$SecurityLogSizeMB = 512
)

$ErrorActionPreference = 'Stop'

# Subcategory GUIDs are language-independent (names change on non-English Windows).
$subcategories = [ordered]@{
    'Credential Validation'        = '{0CCE923F-69AE-11D9-BED3-505054503030}'
    'Kerberos Authentication Svc'  = '{0CCE9242-69AE-11D9-BED3-505054503030}'
    'Logon'                        = '{0CCE9215-69AE-11D9-BED3-505054503030}'
    'Special Logon'                = '{0CCE921B-69AE-11D9-BED3-505054503030}'
    'User Account Management'      = '{0CCE9235-69AE-11D9-BED3-505054503030}'
    'Security Group Management'    = '{0CCE9237-69AE-11D9-BED3-505054503030}'
    'Other Object Access Events'   = '{0CCE9227-69AE-11D9-BED3-505054503030}'  # 4698 scheduled task created
    'Process Creation'             = '{0CCE922B-69AE-11D9-BED3-505054503030}'  # 4688
}

foreach ($name in $subcategories.Keys) {
    if ($PSCmdlet.ShouldProcess($name, 'Enable success and failure auditing')) {
        auditpol.exe /set /subcategory:"$($subcategories[$name])" /success:enable /failure:enable | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Warning "auditpol failed for $name" }
    }
}

# Include the command line in 4688 events (Sysmon also does this, but it's a useful fallback).
$key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
if ($PSCmdlet.ShouldProcess($key, 'Enable ProcessCreationIncludeCmdLine_Enabled')) {
    New-Item -Path $key -Force | Out-Null
    Set-ItemProperty -Path $key -Name 'ProcessCreationIncludeCmdLine_Enabled' -Value 1 -Type DWord
}

if ($PSCmdlet.ShouldProcess('Security log', "Set max size to $SecurityLogSizeMB MB")) {
    wevtutil.exe sl Security /ms:$($SecurityLogSizeMB * 1MB)
}

Write-Output 'Audit policy applied:'
auditpol.exe /get /category:* | Select-String -Pattern 'Success|Failure'
