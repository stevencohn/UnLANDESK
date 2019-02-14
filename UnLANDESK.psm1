#*************************************************************************************************
# Disable LANDesk and then re-enable if you really need to.
#
# Requires PowerShell Windows Management Framework 5.0
#
#  Open a PowerShell command window AS ADMINISTRATOR
#  PS C:\> Import-Module .\UnLANDESK.psm1 -force
#  PS C:\> Disable-LANDesk
#  PS C:\> Enable-LANDesk
#  PS C:\> Show-LanDesk
#
# The commands are re-entrant so you can run them over and over without a problem.
#
# No guarantees, warranties, assurances, promises, support, or licenses are granted
# either explicitly or implicitly. Use at your own risk and responsibility.
#
#*************************************************************************************************

# Path of Registry key for LANDesk installation
$LANDeskKey = 'HKLM:\SOFTWARE\WOW6432Node\landesk'

# Name of LANDesk Windows Task Scheduler task, runs vulscan.exe
$ScheduledTaskName = 'LANDESK Agent Health Bootstrap Task'

# Ordered list of LANDesk service names, most annoying first
$ServiceNames = @(
    'Intel Local Scheduler Service', `  # LocalSch.exe
                                        # - Intel Local Scheduler Service

    'ISSUSER', `                        # issuser.exe
                                        # - LANDESK Remote Control Service
                                        # - parent of rcgui.exe

    'LANDesk Targeted Multicast', `     # tmvsvc.exe
                                        # - LANDesk Targeted Multicast
                                        # - parent of SelfElectController.exe

    'CBA8', `                           # residentAgent.exe
                                        # - LANDesk(R) Management Agent
                                        # - parent of collector.exe, LDRegWatch.exe

    'Softmon', `                        # SoftMon.exe
                                        # - LANDesk(R) Software Monitoring Service

	'LDXDD'                             # xddclient.exe
                                        # - LanDesk(R) Extended device discovery service (Startup:Manual)
    )

# These appear to be old and no longer used?
#   tracksvc    - LANDesk(R) Power Management Track Service
#   ProcTrigger - LANDesk(R) Process Trigger Service


#=================================================================================================
# Disable-LANDesk
#=================================================================================================

function Disable-LANDesk
{
    if ($PSVersionTable.PSVersion.Major -lt 5)
    {
        Write-Host 'UnLANDESK requires PowerShell Windows Management Framework 5.0 or greater' -ForegroundColor Yellow
        return
    }

    if (-not (Test-Path $LANDeskKey))
    {
        Write-Host 'LANDesk doesn''t appear to be installed on this machine. You''re good to go!'
        return
    }

    $changes = 0

    # Apparently most but not all actions are initiated remotely so we need to
    # disable all inbound LANDesk firewall rules first

    Write-Host
    Write-Host 'Checking Inbound LANDesk Firewall rules' -ForegroundColor Yellow
    $rules = (Get-NetFirewallRule -DisplayName LANDesk* | ? { `
        $_.Enabled -eq 'True' } | Disable-NetFirewallRule | measure).Count

    if ($rules -gt 0)
    {
        Write-Work "Disabled $rules LANDesk firewall rules"
    }
    else
    {
        Write-OK "All LANDesk firewall rules already disabled"
    }

    # Disable scheduled task to prevent it from auto-repairing the configuration

    Write-Host
    Write-Host "Checking $ScheduledTaskName" -ForegroundColor Yellow
    if ((Get-ScheduledTask -TaskName $ScheduledTaskName).State -ne 'Disabled')
    {
        $foo = Disable-ScheduledTask -TaskName $ScheduledTaskName | measure
        Write-Work 'Disabled task'
    }
    else
    {
        Write-OK 'Task is already disabled'
    }

    # we could use "gwmi win32_service" command to find all services within the LANDesk pathname
    # but we want to process the services in a specific order to disable the most intrusive first

    <# Quick dump of all services and pathnames:

       gwmi win32_service | % { `
         new-object psobject -Property @{ `
            Started = $_.Started `
            DisplayName = $_.DisplayName `
            Name = $_.Name; `
            PathNm = $_.PathName } } | sort -Property Started,PathNm
    #>


    $ServiceNames | % `
    {
        $name = $_
		$service = Get-Service -Name $name -ErrorAction:SilentlyContinue
		if ($service)
		{
			Write-Host
			Write-Host "Checking service `"$name`"" -ForegroundColor Yellow

			# Disable the service

			if ($service.StartType -ne 'Disabled')
			{
				Write-Work "sc config `"$name`" start= disabled"
				cmd /c sc config  "$name" start= disabled
				$changes++
			}
			else
			{
				Write-OK 'Service already set to Disabled'
			}

			# Set the failure action to "Take No Action" to prevent a restart

			$nofail = $true
			$failure = cmd /c sc qfailure "$name"
			$failure | ? { $_ -like "*FAILURE_ACTIONS*" } | % `
			{
				Write-Work "sc failure `"$name`" reset= 0 actions= `"`""
				cmd /c sc failure "$name" reset= 0 actions= `"`"
				$nofail = $false
				$changes++
			}

			if ($nofail)
			{
				Write-OK 'Service fail mode already set to No Action'
			}

			# Stop the service

			if ($service.Status -ne 'Stopped')
			{
				if ($service.CanStop)
				{
					Write-Work "sc stop `"$name`""
					cmd /c sc stop "$name"
				}
				else
				{
					Write-Work "Killing `"$name`""
					Get-Process -Name $name -ErrorAction Ignore | Stop-Process -Force
				}

				$changes++
			}
			else
			{
				Write-OK 'Service already Stopped'
			}
		}
    }

    Write-Host
    Write-Host 'Checking rogue processes' -ForegroundColor Yellow
    $pchanges = $changes

    Get-Process | ? { $_ -and $_.Path -and $_.Path.StartsWith('C:\Program Files (x86)\LANDesk') } | % `
    {
        $process = $_
        $procName = $process.Name
        $procPath = $process.Path
        Write-Work "Killing `"$procName`" ($procPath)"
        Stop-Process -Name $procName -Force
        $changes++
    }

    if ($pchanges -eq $changes)
    {
        Write-OK 'No rogue processes found'
    }

    Write-Host
    Write-Host 'Checking installation folder' -ForegroundColor Yellow
    $dirpath = 'C:\Program Files (x86)\LANDesk'
    if (Test-Path $dirpath)
    {
        Write-Work 'Hiding LANDesk installation folder' -ForegroundColor Yellow
        Rename-Item 'C:\Program Files (x86)\LANDesk' 'C:\Program Files (x86)\LANDesk-HIDDEN' 
    }
    else
    {
        Write-OK 'Folder already hidden'
    }

    if ($changes -gt 0)
    {
        Write-Host
        Write-Host '*** LANDesk is now disabled' -ForegroundColor Green
        Write-Host '*** A reboot is highly recommended as soon as possible' -ForegroundColor Green
    }

    Write-Host
}


#=================================================================================================
# Enable-LANDesk
#=================================================================================================

function Enable-LANDesk ()
{
    if ($PSVersionTable.PSVersion.Major -lt 5)
    {
        Write-Host 'UnLANDESK requires PowerShell Windows Management Framework 5.0 or greater' -ForegroundColor Yellow
        return
    }

    if (-not (Test-Path $LANDeskKey))
    {
        Write-Host 'LANDesk doesn''t appear to be installed on this machine. You''re good to go!'
        return
    }

    Write-Host
    Write-Host 'Checking installation folder' -ForegroundColor Yellow
    $dirpath = 'C:\Program Files (x86)\LANDesk-HIDDEN'
    if (Test-Path $dirpath)
    {
        Write-Work 'Unhiding LANDesk installation folder' -ForegroundColor Yellow
        Rename-Item 'C:\Program Files (x86)\LANDesk-HIDDEN' 'C:\Program Files (x86)\LANDesk'
    }
    else
    {
        Write-OK 'Folder already visible'
    }

    $ServiceNames | % `
    {
        $name = $_
		$service = Get-Service -Name $name -ErrorAction:SilentlyContinue
		if ($service)
		{
			Write-Host
			Write-Host "Checking service `"$name`"" -ForegroundColor Yellow

			# Enable the service

			if ($service.StartType -eq 'Disabled')
			{
				Write-Work "sc config `"$name`" start= auto"
				cmd /c sc config  "$name" start= auto
			}
			else
			{
				Write-OK 'Service already set to Auto'
			}

			# FAILURE_ACTIONS will be restored automatically by LANDesk agents
			# so no need to change them here

			# Start the service if we can so LANDesk Portal Manager can be used immediately

			if ($service.Status -eq 'Stopped')
			{
				if ($service.CanStart)
				{
					Write-Work "sc start `"$name`""
					cmd /c sc start "$name"
				}
				else
				{
					Write-OK "Service `"$name`" will auto-start as needed"
				}
			}
			else
			{
				Write-OK 'Service already started'
			}
		}
    }

    # Do we really need to enable the Agent Health task?
    # I think all it does is repair modified configurations

    Write-Host
    Write-Host "Checking $ScheduledTaskName" -ForegroundColor Yellow
    if ((Get-ScheduledTask -TaskName $ScheduledTaskName).State -eq 'Disabled')
    {
        $foo = Enable-ScheduledTask -TaskName $ScheduledTaskName | measure
        Write-Work 'Enabled task'
    }
    else
    {
        Write-OK 'Task is already enabled'
    }

    # Enable the LANDesk firewall rules to allow BT in

    Write-Host
    Write-Host 'Checking Inbound LANDesk Firewall rules' -ForegroundColor Yellow
    $rules = (Get-NetFirewallRule -DisplayName LANDesk* | ? { `
        $_.Enabled -eq 'False' } | Enable-NetFirewallRule | measure).Count

    if ($rules -gt 0)
    {
        Write-Work "Enabled $rules LANDesk firewall rules"
    }
    else
    {
        Write-OK 'All LANDesk firewall rules already enabled'
    }

    Write-Host
    Write-Host '*** LANDesk is enabled' -ForegroundColor DarkMagenta
    Write-Host
}


#=================================================================================================
# Show-LANDesk
#=================================================================================================

function Show-LANDesk
{
    if ($PSVersionTable.PSVersion.Major -lt 5)
    {
        Write-Host 'UnLANDESK requires PowerShell Windows Management Framework 5.0 or greater' -ForegroundColor Yellow
        return
    }

    if (-not (Test-Path $LANDeskKey))
    {
        Write-Host 'LANDesk doesn''t appear to be installed on this machine. You''re good to go!'
        return
    }

    # firewall rules

    Write-Host
    Write-Host 'Finding Inbound LANDesk Firewall rules' -ForegroundColor Yellow
    Get-NetFirewallRule -DisplayName LANDesk* | % `
    {
        $rule = $_
        if ($rule.Enabled -eq $true)
        {
            Write-Work "$($rule.DisplayName) - $($rule.Profile) ... Enabled"
        }
        else
        {
            Write-OK "$($rule.DisplayName) - $($rule.Profile) ... Disabled"
        }
    }

    # watchdog task

    Write-Host
    Write-Host "Finding task $ScheduledTaskName" -ForegroundColor Yellow
    $task = Get-ScheduledTask -TaskName $ScheduledTaskName
    if ($task.State -ne 'Disabled')
    {
        Write-Work "$($task.TaskName) is $($task.State)"
    }
    else
    {
        Write-OK "$($task.TaskName) is $($task.State)"
    }

    # services

    Write-Host
    Write-Host "Finding services" -ForegroundColor Yellow
    $ServiceNames | % `
    {
        $name = $_
		$service = Get-Service -Name $name -ErrorAction:SilentlyContinue
		if ($service)
		{
			if (($service.Status -ne 'Stopped') -or ($service.StartType -ne 'Disabled'))
			{
				Write-Work "$($service.DisplayName) ($($service.Name)) $($service.StartType)... $($service.Status)"
			}
			else
			{
				Write-OK "$($service.DisplayName) ($($service.Name)) $($service.StartType)... $($service.Status)"
			}
		}
    }

    # rogue processes

    Write-Host
    Write-Host 'Finding rogue processes' -ForegroundColor Yellow

    $numproc = 0
    Get-Process | ? { $_ -and $_.Path -and $_.Path.StartsWith('C:\Program Files (x86)\LANDesk') } | % `
    {
        $process = $_
        $procName = $process.Name
        $procPath = $process.Path
        Write-Work "`"$procName`" ($procPath)"
        $numproc++
    }

    if ($numproc -eq 0)
    {
        Write-OK 'None found'
    }

    # installation folder

    $dirpath = 'C:\Program Files (x86)\LANDesk'
    Write-Host
    Write-Host "Checking installation folder: $dirpath" -ForegroundColor Yellow
    if (Test-Path $dirpath)
    {
        Write-Work 'Installation folder is exposed'
    }
    else
    {
        Write-OK 'Installation folder is HIDDEN'
    }

    Write-Host
}


#=================================================================================================
# Helpers
#=================================================================================================

function Write-OK ($string)
{
    $greenCheck = @{ Object = [Char]8730; ForegroundColor = 'Green'; NoNewLine = $true }

    Write-Host '  ' -NoNewline
    Write-Host @greenCheck
    Write-Host " $string" -ForegroundColor Gray
}


function Write-Work ($string)
{
    $redTriangle = @{ Object = [Char]9658; Foreground = 'Red'; NoNewLine = $true }

    Write-Host '  ' -NoNewline
    Write-Host @redTriangle
    Write-Host " $string" -ForegroundColor Gray
}


Export-ModuleMember -Function Disable-LANDesk
Export-ModuleMember -Function Enable-LANDesk
Export-ModuleMember -Function Show-LANDesk
