<#
.SYNOPSIS
Show services, processes, firewall rules, scheduled tasks related to the Traps application.

.DESCRIPTION
No guarantees, warranties, assurances, promises, support, or licenses are granted
either explicitly or implicitly. Use at your own risk and responsibility.
#>

[CmdletBinding(SupportsShouldProcess = $true)]

param()

Import-Module (Resolve-Path $PSScriptRoot\TrapsDefs.psm1).Path -Scope Local -Force
Import-Module (Resolve-Path $PSScriptRoot\Helpfuls.psm1).Path -Scope Local -Force

if (!(CheckRequirements 'Traps' $TrapsKey))
{
	return
}

ShowServices $ServiceNames
ShowRogueProcesses $InstallPath
ShowInstallationFolder $InstallPath

Write-Host
