#*************************************************************************************************
# Helper functions for enable/disable scripts
# Include with:
#   Import-Module (Resolve-Path $PSScriptRoot\Helpfuls.psm1).Path -Scope Local -Force
#*************************************************************************************************

function CheckRequirements
{
	param($name, $key)

	if ($PSVersionTable.PSVersion.Major -lt 5)
	{
		Write-Host "$name requires PowerShell Windows Management Framework 5.0 or greater" -ForegroundColor Yellow
		return $false
	}

	if (-not (Test-Path $key))
	{
		Write-Host "$name doesn't appear to be installed on this machine. You're good to go!"
		return $false
	}

	return $true
}


function DisableFirewallRules
{
	param($name, [bool] $shouldProcess)

	Write-Host
	Write-Host "Checking Inbound $name Firewall rules" -ForegroundColor Yellow
	
	if ($shouldProcess)
	{
		$count = (Get-NetFirewallRule -DisplayName "$name`*" | ? { `
			$_.Enabled -eq 'True' } | Disable-NetFirewallRule | measure).Count
	}
	else
	{
		$rules = Get-NetFirewallRule -DisplayName "$name`*" | Where Enabled -eq 'True'
		$rules | % { Write-Host $_.Displayname -ForegroundColor DarkGray }
		$count = $rules.Count
	}

    if ($rules -gt 0)
    {
		WriteWork "Disabled $count $name firewall rules"
		return 1
    }

	WriteOK "All $name firewall rules already disabled"
    return 0
}


function DisableScheduledTask
{
	param($taskName, [bool] $shouldProcess)

	Write-Host
    Write-Host "Checking $taskName" -ForegroundColor Yellow
    if ((Get-ScheduledTask -TaskName $taskName).State -ne 'Disabled')
    {
		if ($shouldProcess)
		{
			$t = Disable-ScheduledTask -TaskName $taskName | measure
		}

		WriteWork 'Disabled task'
		return 1
    }

	WriteOK 'Task is already disabled'
    return 0
}


# we could use "gwmi win32_service" command to find all services within the app pathname
# but we want to process the services in a specific order to disable the most intrusive first
<# Quick dump of all services and pathnames:
	gwmi win32_service | % { `
		new-object psobject -Property @{ `
		Started = $_.Started `
		DisplayName = $_.DisplayName `
		Name = $_.Name; `
		PathNm = $_.PathName } } | sort -Property Started,PathNm
#>

function DisableServices
{
	param($names, [bool] $shouldProcess)

	$changes = 0

	Write-Host
	Write-Host "Checking services" -ForegroundColor Yellow

	$names | % `
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
				WriteWork "sc config `"$name`" start= disabled"

				if (ShouldProcess1 $shouldProcess "sc config `"$name`" start= disabled")
				{
					cmd /c sc config "$name" start= disabled
				}

				$changes++
			}
			else
			{
				WriteOK 'Service already set to Disabled'
			}

			# Set the failure action to "Take No Action" to prevent a restart

			$nofail = $true
			$failure = cmd /c sc qfailure "$name"
			$failure | ? { $_ -like "*FAILURE_ACTIONS*" } | % `
			{
				WriteWork "sc failure `"$name`" reset= 0 actions= `"`""

				if (ShouldProcess1 $shouldProcess "sc failure `"$name`" reset= 0 actions= `"`"")
				{
					cmd /c sc failure "$name" reset= 0 actions= `"`"
				}

				$nofail = $false
				$changes++
			}

			if ($nofail)
			{
				WriteOK 'Service fail mode already set to No Action'
			}

			# Stop the service

			if ($service.Status -ne 'Stopped')
			{
				if ($service.CanStop)
				{
					WriteWork "sc stop `"$name`""

					if (ShouldProcess1 $shouldProcess "sc stop `"$name`"")
					{
						cmd /c sc stop "$name"
					}
				}
				else
				{
					WriteWork "Killing `"$name`""
					Get-Process -Name $name -ErrorAction Ignore | Stop-Process -Force
				}

				$changes++
			}
			else
			{
				WriteOK 'Service already Stopped'
			}
		}
		else
		{
			Write-Host "    Service not found `"$name`"" -ForegroundColor DarkGray
		}
	}

	return $changes
}


function EnableFirewallRules
{
	param($name, [bool] $shouldProcess)

	Write-Host
	Write-Host "Checking Inbound $name Firewall rules" -ForegroundColor Yellow

	if ($shouldProcess)
	{
		$count = (Get-NetFirewallRule -DisplayName "$name`*" | ? { `
					$_.Enabled -eq 'False' } | Enable-NetFirewallRule | measure).Count
	}
	else
	{
		$rules = Get-NetFirewallRule -DisplayName "$name`*" | Where Enabled -eq 'False'
		$rules | % { Write-Host $_.Displayname -ForegroundColor DarkGray }
		$count = $rules.Count
	}

	if ($rules -gt 0)
	{
		WriteWork "Enabled $count $name firewall rules"
		return 1
	}

	WriteOK 'All LANDesk firewall rules already enabled'
	return 0
}


function EnableScheduledTask
{
	param($taskName, [bool] $shouldProcess)

	Write-Host
    Write-Host "Checking $taskName" -ForegroundColor Yellow
    if ((Get-ScheduledTask -TaskName $taskName).State -eq 'Disabled')
    {
		if ($shouldProcess)
		{
			$t = Enable-ScheduledTask -TaskName $taskName | measure
		}

		WriteWork 'Enabled task'
		return 1
    }

	WriteOK 'Task is already enabled'
	return 0
}



function EnableServices
{
	param($names, [bool] $shouldProcess)

	Write-Host
	Write-Host "Checking services" -ForegroundColor Yellow

	$names | % `
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
				if (ShouldProcess1 $shouldProcess "sc config `"$name`" start= auto")
				{
					WriteWork "sc config `"$name`" start= auto"
				}

				cmd /c sc config "$name" start= auto
			}
			else
			{
				WriteOK 'Service already set to Auto'
			}

			# FAILURE_ACTIONS will be restored automatically by LANDesk agents
			# so no need to change them here

			if ($service.Status -eq 'Stopped')
			{
				if ($service.CanStart)
				{
					WriteWork "sc start `"$name`""

					if (ShouldProcess1 $shouldProcess "sc start `"$name`"")
					{
						cmd /c sc start "$name"
					}
				}
				else
				{
					WriteOK "Service `"$name`" will auto-start as needed"
				}
			}
			else
			{
				WriteOK 'Service already started'
			}
		}
		else
		{
			Write-Host "    Service not found `"$name`"" -ForegroundColor DarkGray
		}
    }
}


function HideInstallationFolder
{
	param($installPath, [bool] $shouldProcess)

	$changes = 0

	if ($installPath.EndsWith('\'))
	{
		$installPath = $installPath.Substring(0, $installPath.Length - 1)
	}

	Write-Host
	Write-Host 'Checking installation folder' -ForegroundColor Yellow
	if (Test-Path $installPath)
	{
		WriteWork 'Hiding installation folder'

		if (ShouldProcess1 $shouldProcess "Rename-Item `"$installPath`" `"$installPath`-HIDDEN`"")
		{
			Rename-Item $installPath "$installPath`-HIDDEN"
		}

		$changes++
	}
	else
	{
		WriteOK 'Folder already hidden'
	}

	return $changes
}


function ShowFirewallRules
{
	param($name)

	Write-Host
    Write-Host "Finding Inbound $name Firewall rules" -ForegroundColor Yellow
    Get-NetFirewallRule -DisplayName "$name`*" | % `
    {
        $rule = $_
        if ($rule.Enabled -eq $true)
        {
            WriteWork "$($rule.DisplayName) - $($rule.Profile) ... Enabled"
        }
        else
        {
            WriteOK "$($rule.DisplayName) - $($rule.Profile) ... Disabled"
        }
    }
}


function ShowInstallationFolder
{
	param($installPath)

	if ($installPath.EndsWith('\'))
	{
		$installPath = $installPath.Substring(0, $installPath.Length - 1)
	}

	Write-Host
	Write-Host "Checking installation folder: $installPath" -ForegroundColor Yellow
	if (Test-Path $installPath)
	{
		WriteWork 'Installation folder is exposed'
	}
	else
	{
		WriteOK 'Installation folder is HIDDEN'
	}
}


function ShowRogueProcesses
{
	param($installPath)

	Write-Host
	Write-Host 'Finding rogue processes' -ForegroundColor Yellow

	if ($installPath.EndsWith('\'))
	{
		$installPath = $installPath.Substring(0, $installPath.Length - 1)
	}

	$numproc = 0
	Get-Process | ? { $_ -and $_.Path -and $_.Path.StartsWith($installPath) } | % `
	{
		$process = $_
		$procName = $process.Name
		$procPath = $process.Path
		WriteWork "`"$procName`" ($procPath)"
		$numproc++
	}

	if ($numproc -eq 0)
	{
		WriteOK 'None found'
	}
}


function ShowScheduledTask
{
	param($name)

	Write-Host
	Write-Host "Finding task $name" -ForegroundColor Yellow
	$task = Get-ScheduledTask -TaskName $name
	if ($task.State -ne 'Disabled')
	{
		WriteWork "$($task.TaskName) is $($task.State)"
	}
	else
	{
		WriteOK "$($task.TaskName) is $($task.State)"
	}
}


function ShowServices
{
	param($names, [bool] $shouldProcess)

	Write-Host
	Write-Host "Finding services" -ForegroundColor Yellow
	$names | % `
	{
		$name = $_
		$service = Get-Service -Name $name -ErrorAction:SilentlyContinue
		if ($service)
		{
			if (($service.Status -ne 'Stopped') -or ($service.StartType -ne 'Disabled'))
			{
				WriteWork "$($service.DisplayName) ($($service.Name)) $($service.StartType)... $($service.Status)"
			}
			else
			{
				WriteOK "$($service.DisplayName) ($($service.Name)) $($service.StartType)... $($service.Status)"
			}
		}
		else
		{
			Write-Host "    Service not found `"$name`"" -ForegroundColor DarkGray
		}
	}
}


function StopRogueProcesses
{
	param($installPath, [bool] $shouldProcess)

	$changes = 0

	Write-Host
	Write-Host 'Checking rogue processes' -ForegroundColor Yellow
	$pchanges = $changes

	Get-Process | ? { $_ -and $_.Path -and $_.Path.StartsWith($installPath) } | % `
	{
		$process = $_
		$procName = $process.Name
		$procPath = $process.Path
		WriteWork "Killing `"$procName`" ($procPath)"

		if (ShouldProcess1 $shouldProcess "Stop-Process -Name $procName -Force")
		{
			Stop-Process -Name $procName -Force
		}

		$changes++
	}

	if ($pchanges -eq $changes)
	{
		WriteOK 'No rogue processes found'
	}

	return $changes
}


function UnhideInstallationFolder
{
	param($installPath, [bool] $shouldProcess)

	$changes = 0

	if ($installPath.EndsWith('\'))
	{
		$installPath = $installPath.Substring(0, $installPath.Length - 1)
	}

	Write-Host
	Write-Host 'Checking installation folder' -ForegroundColor Yellow
	if (Test-Path "$installPath`-HIDDEN")
	{
		WriteWork 'Unhiding installation folder'

		if (ShouldProcess1 $shouldProcess "Rename-Item `"$installPath`-HIDDEN`" `"$installPath`"")
		{
			Rename-Item "$installPath-HIDDEN" $installPath
		}

		$changes++
	}
	else
	{
		WriteOK 'Folder already visible'
	}
	
	return $changes
}


# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

function ShouldProcess1
{
	param([bool] $shouldProcess, $text)

	if (-not $shouldProcess)
	{
		Write-Host "TEST: $text" -ForegroundColor DarkGray
	}

	return $shouldProcess
}


function WriteOK ($string)
{
	$greenCheck = @{ Object = [Char]8730; ForegroundColor = 'Green'; NoNewLine = $true }

	Write-Host '  ' -NoNewline
	Write-Host @greenCheck
	Write-Host " $string" -ForegroundColor Gray
}


function WriteWork ($string)
{
	$redTriangle = @{ Object = [Char]9658; Foreground = 'Red'; NoNewLine = $true }

	Write-Host '  ' -NoNewline
	Write-Host @redTriangle
	Write-Host " $string" -ForegroundColor Gray
}


Export-ModuleMember -Function *
