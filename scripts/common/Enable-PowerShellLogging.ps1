<#
.SYNOPSIS
    Run on DC01 and WS01: turns on PowerShell Script Block Logging (event 4104) and Module Logging.

.DESCRIPTION
    Script block logging records the code PowerShell actually executes, including the decoded
    content of -EncodedCommand. That is what lets an analyst see through obfuscation.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$base = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell'

$settings = @(
    @{ Path = "$base\ScriptBlockLogging"; Name = 'EnableScriptBlockLogging'; Value = 1 },
    @{ Path = "$base\ModuleLogging"; Name = 'EnableModuleLogging'; Value = 1 }
)

foreach ($s in $settings) {
    if ($PSCmdlet.ShouldProcess("$($s.Path)\$($s.Name)", 'Set to 1')) {
        New-Item -Path $s.Path -Force | Out-Null
        Set-ItemProperty -Path $s.Path -Name $s.Name -Value $s.Value -Type DWord
    }
}

# Module logging needs to know which modules to log; '*' = all.
$names = "$base\ModuleLogging\ModuleNames"
if ($PSCmdlet.ShouldProcess($names, "Log all modules ('*')")) {
    New-Item -Path $names -Force | Out-Null
    Set-ItemProperty -Path $names -Name '*' -Value '*' -Type String
}

# Bigger log so events survive long enough to be shipped and investigated.
if ($PSCmdlet.ShouldProcess('Microsoft-Windows-PowerShell/Operational', 'Set max size to 256 MB')) {
    wevtutil.exe sl 'Microsoft-Windows-PowerShell/Operational' /ms:268435456
}

Write-Output 'PowerShell logging enabled. New sessions will log to Microsoft-Windows-PowerShell/Operational (4103/4104).'
