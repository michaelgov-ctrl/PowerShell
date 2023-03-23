<#

This function returns the general performance of the target node(s)

-Michael Governanti 1/20/2023

#>

function Get-HostInfo {

    [CmdletBinding(DefaultParameterSetName = 'ServerList')]
    Param(
        [Parameter(Mandatory = $true,
        ParameterSetName = 'ServerList',
        Position = 0)]
        [ValidateSet('VNAServerList','DictationServerList','WorklistServerList','SecondaryApplicationServers')]
        [string[]]$ServerList,

        [Parameter(Mandatory = $true,
        ParameterSetName = 'ComputerName')]
        [string[]]$ComputerName,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'ServerList')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ComputerName')]
        [string]$UserName            
    )

     $re = "^AdminAccountSyntax$"

     if ($UserName -match $re) {

        $DomainUserName = "contoso.com\" + $UserName

        $creds = Get-Credential -Credential $DomainUserName

        $SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

        $RunspacePool = [runspacefactory]::CreateRunspacePool(

            1, #Min Runspaces

            10 #Max Runspaces

        )

        $PowerShell = [powershell]::Create()

        $PowerShell.RunspacePool = $RunspacePool

        $RunspacePool.Open()

        $jobs = New-Object System.Collections.ArrayList

        if ($ServerList) {

            if ($ServerList -eq 'VNAServerList') {

                $ComputerArray = @(
			#ServerList
                )

            }
            elseif ($ServerList -eq 'DictationServerList') {

                $ComputerArray = @(
			#ServerList
                )

            }
            elseif ($ServerList -eq 'WorklistServerList') {

                $ComputerArray = @(
			#ServerList
                )

            }
            else {
		
		#SecondaryApplicationServers
                $ComputerArray = @(
			#ServerList
                )

            }

        } else {

            $ComputerArray = $ComputerName

        }

        foreach($Computer in $ComputerArray) {

            $PowerShell = [powershell]::Create()

            $PowerShell.RunspacePool = $RunspacePool

            [void]$PowerShell.AddScript({

                Param (
                    $Computer,
                    $Creds
                )

                if (Test-Connection $Computer -Count 2 -Quiet) {

                    if (Test-WSMan $Computer -ErrorAction SilentlyContinue) {

                        $ipv4 = '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'    ###IPV4 regex

                            if ($Computer -match $ipv4) {
                            
                                try {

                                    $HostName = [System.Net.Dns]::GetHostByAddress($Computer).Hostname

                                } catch {

                                    [pscustomobject]@{
                                        Host = $Computer
                                        ResolvedDNS = $false
                                    }

                                }

                            } else {

                               $HostName = $Computer

                            }

                        $CIMSession = New-CimSession -ComputerName $HostName -Credential $creds -Authentication Negotiate

                        if ($CIMSession -ne $null) {

                            try {

                                $NetworkInfo = Get-CimInstance -CimSession $CIMSession -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=$true

                                $ComputerSystem = Get-CimInstance -CimSession $CIMSession -Class Win32_ComputerSystem

                                $ProcessorInfo = Get-CimInstance -CimSession $CIMSession -ClassName Win32_Processor

                                $OSInfo = Get-CimInstance -CimSession $CIMSession -ClassName Win32_OperatingSystem

                                $RAMInfo = Get-CimInstance -CimSession $CIMSession -ClassName Win32_PhysicalMemory

                                $Drives = Get-CimInstance -CimSession $CIMSession -ClassName Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3}

                                $DriveInfo = foreach($Drive in $Drives) {

                                                [pscustomobject]@{
                                                DriveName = $Drive.DeviceID
                                                Size = [string]([math]::Round(($Drive.Size / 1gb),2)) + "GB"
                                                FreeSpace = [string]([math]::Round(($Drive.FreeSpace / 1gb),2)) + "GB"
                                                PercentFree = ($Drive.FreeSpace / $Drive.Size).ToString("P")
                                                }

                                            }

                                <#
                                            ### REPRESENTATIVE OBJECT TO BE RETURNED ###
                                #>

                                    [pscustomobject]@{
                                        IP = ($NetworkInfo).IPAddress
                                        HostName = ($ComputerSystem).Name
                                        ProcessorName = $ProcessorInfo[0].Name
                                        ProcCoreCount = ($ProcessorInfo.NumberOfCores | Measure-Object -sum).sum
                                        ProcessorUsage = [string]([math]::Round((($ProcessorInfo | Measure-Object -Property LoadPercentage -Average).Average),2)) + "%"
                                        TotalRam = [string](($RAMInfo | Measure-Object -Property capacity -Sum).sum /1gb) + "GB"
                                        RamUsage = (($OSInfo.TotalVisibleMemorySize - $OSInfo.FreePhysicalMemory)/$OSInfo.TotalVisibleMemorySize).ToString("P")
                                        DriveInfo = $DriveInfo
                                        LastBootTime = $OSInfo.LastBootUpTime
                                     }
                                
                                <#
                                           ### REPRESENTATIVE OBJECT TO BE RETURNED ###
                                #>

                            } catch {

                            }

                            $CIMSession | Remove-CimSession

                        } else {

                            [pscustomobject]@{
	                            Node = $Computer
                                IsUp = $true
                                WSManRunning = $true
                            }

                        }

                    } else {

                        [pscustomobject]@{
	                    Node = $Computer
                            IsUp = $true
                            WSManRunning = $false
                        }

                    }

                } else {

                    [pscustomobject]@{
	                Node = $Computer
                        IsUp = $false
                        WSManRunning = $false
                    }

                }
        
            })

            [void]$PowerShell.AddParameter('Creds',$creds).AddParameter('Computer',$Computer)
    
            $Handle = $PowerShell.BeginInvoke()

            $CurrentJob = [pscustomobject]@{
                PowerShell=$PowerShell
                Handle=$Handle
            }

            [void]$jobs.Add($CurrentJob)

        }

        do {

            Start-Sleep -Seconds 1

        } until ($RunspacePool.GetAvailableRunspaces() -eq 10)

        $return = $jobs | ForEach {
            $_.Powershell.EndInvoke($_.handle)
            $_.PowerShell.Dispose()
        }

        $jobs.clear()

        return $return

    } else {

        Throw "Please use an elevated account for administrative access"

    }

}
