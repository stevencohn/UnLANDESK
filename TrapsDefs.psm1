#*************************************************************************************************
# Definitions for Traps
# Include with:
#   Import-Module (Resolve-Path $PSScriptRoot\TrapsDefs.psm1).Path -Scope Local
#*************************************************************************************************

# Path of Registry key for installation
$script:TrapsKey = 'HKLM:\SOFTWARE\Cyvera\Client'

# Path of installation
$script:InstallPath = (Get-ItemProperty $TrapsKey).'Install Path'

# Ordered list of service names, most annoying first
$script:ServiceNames = @(
	'Traps', # CyveraService.exe
	'Traps Local Analysis Service',	# tlaservice.exe
	'Traps Reporting Service', # cyserver.exe
	'Traps Watchdog Service' # twdservice.exe
)

Export-ModuleMember -Variable *
