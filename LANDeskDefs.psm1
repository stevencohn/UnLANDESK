#*************************************************************************************************
# Definitions for LANDesk
# Include with:
#   Import-Module (Resolve-Path $PSScriptRoot\LANDeskDefs.psm1).Path -Scope Local
#*************************************************************************************************

# Path of Registry key for installation
$script:LANDeskKey = 'HKLM:\SOFTWARE\WOW6432Node\landesk'

# Path of installation
$script:InstallPath = [IO.Path]::GetDirectoryName((Get-ItemProperty "$LANDeskKey`\managementsuite\WinClient").'Path')

# Name of Windows Task Scheduler task
#   Do we really need to enable the Agent Health task?
#   I think all it does is repair modified configurations
$script:ScheduledTaskName = 'LANDESK Agent Health Bootstrap Task' # runs vulscan.exe

# Ordered list of service names, most annoying first
$script:ServiceNames = @(
	'Intel Local Scheduler Service', # LocalSch.exe, "Intel Local Scheduler Service"
	'ISSUSER', # issuser.exe, "LANDESK Remote Control Service"; parent of rcgui.exe
	'LANDesk Targeted Multicast', # tmvsvc.exe, "LANDesk Targeted Multicast"; parent of SelfElectController.exe
	'CBA8', # residentAgent.exe, "LANDesk(R) Management Agent"; parent of collector.exe, LDRegWatch.exe
	'Softmon', # SoftMon.exe, "LANDesk(R) Software Monitoring Service"
	'LDXDD' # xddclient.exe, "LanDesk(R) Extended device discovery service (Startup:Manual)"

	# These appear to be old and no longer used?
	#   tracksvc    - LANDesk(R) Power Management Track Service
	#   ProcTrigger - LANDesk(R) Process Trigger Service
)

Export-ModuleMember -Variable *
