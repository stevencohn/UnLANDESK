<#
.SYNOPSIS
Show services, processes, firewall rules, scheduled tasks related to the LANDesk application.

.DESCRIPTION
No guarantees, warranties, assurances, promises, support, or licenses are granted
either explicitly or implicitly. Use at your own risk and responsibility.
#>

[CmdletBinding(SupportsShouldProcess = $true)]

param()

Import-Module (Resolve-Path $PSScriptRoot\LANDeskDefs.psm1).Path -Scope Local -Force
Import-Module (Resolve-Path $PSScriptRoot\Helpfuls.psm1).Path -Scope Local -Force

if (!(CheckRequirements 'LANDesk' $LANDeskKey))
{
	return
}

ShowFirewallRules 'LANDesk'
ShowScheduledTask $ScheduledTaskName
ShowServices $ServiceNames
ShowRogueProcesses $InstallPath
ShowInstallationFolder $InstallPath

Write-Host
