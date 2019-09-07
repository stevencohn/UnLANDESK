<#
.SYNOPSIS
Enable Traps

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

$script:shouldProcess = $PSCmdLet.ShouldProcess('Testing...', '', '')

$script:changes = 0

$changes += UnhideInstallationFolder $InstallPath $shouldProcess
$changes += EnableServices $ServiceNames $shouldProcess

if ($changes -gt 0)
{
	Write-Host
	Write-Host '*** Traps is enabled' -ForegroundColor Green
}

Write-Host
