#$creds = Get-Credential

$WorkStations = Import-Csv -Path "Inventory.csv"

$MissingIP = $WorkStations | % { if ($_.IP -eq '') {$_} }

$HasIP = $WorkStations | % { if ($_.IP -ne '') {$_} }

#Testing if IP is reachable and validating current file

    [runspacefactory]::CreateRunspacePool()

    $SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

    $RunspacePool = [runspacefactory]::CreateRunspacePool( 
        1, #Min Runspaces
        25 #Max Runspaces
    )

    $PowerShell = [powershell]::Create()
    $PowerShell.RunspacePool = $RunspacePool
    $RunspacePool.Open()

    $jobs = New-Object System.Collections.ArrayList

    ForEach ($Station in $HasIP) {
        $PowerShell = [powershell]::Create()
        $PowerShell.RunspacePool = $RunspacePool
        [void]$PowerShell.AddScript({

            Param (
                $Station,
                $Creds
            )

                $Ip = $Station.IP

                if (Test-Connection -ComputerName $Ip -Count 2 -Quiet){

                    New-SmbMapping -RemotePath \\$Ip\c$ -UserName $Creds.UserName -Password $Creds.GetNetworkCredential().Password -ErrorAction SilentlyContinue | Out-Null

                        if ( Test-Path "\\$Ip\c$\<FilePath>" ) { #filepath goes here

                            $HashedFile = (Get-FileHash "\\$Ip\c$\<FilePath>").Hash #filepath goes here

                            if ( $HashedFile -eq "*" ) { #expected file hash goes here

                                [pscustomobject]@{
                                    IP = $Ip
                                    Host = $Station.HostName
                                    Location = $Station.User
                                    RadWhereCOMdll = $true
                                    FileAge = (get-childitem "\\$Ip\c$\<FilePath>").LastWriteTime #filepath goes here
                                    FileHash = $HashedFile
                                }

                            } else {

                                $CopyError = $null

                                Copy-Item -Path "\\$PathToGoodConfigFile" -Destination "\\$Ip\c$\<FilePath>" -Force -ErrorAction Continue -ErrorVariable CopyError #filepath goes here

                                if ( -not $CopyError ) {

                                    [pscustomobject]@{
                                        IP = $Ip
                                        Host = $Station.HostName
                                        Location = $Station.User
                                        RadWhereCOMdll = $true
                                        FileAge = (get-childitem "\\$Ip\c$\<FilePath>").LastWriteTime #filepath goes here
                                        FileHash = (Get-FileHash "\\$Ip\c$\<FilePath>").Hash #filepath goes here
                                    }

                                } else {

                                    [pscustomobject]@{
                                        IP = $Ip
                                        Host = $Station.HostName
                                        Location = $Station.User
                                        RadWhereCOMdll = $false
                                        FileAge = (get-childitem "\\$Ip\c$\<FilePath>").LastWriteTime #filepath goes here
                                        FileHash = (Get-FileHash "\\$Ip\c$\<FilePath>").Hash #filepath goes here
                                    }

                                }
                            }

                        } else {

                            [pscustomobject]@{
                                IP = $Ip
                                Host = $Station.HostName
                                Location = $Station.User
                                RadWhereCOMdll = $false
                                FileAge = $null
                                FileHash = $null
                            }

                        }

                    Remove-SmbMapping -RemotePath \\$Ip\c$ -Force

                } else {

                    [pscustomobject]@{
                        IP = $Ip
                        Host = $Station.HostName
                        Location = $Station.User
                        RadWhereCOMdll = "UNREACHABLE"
                        FileAge = $null
                        FileHash = $null
                    }

                }

        })

        [void]$PowerShell.AddParameter('Creds',$Creds).AddParameter('Station',$Station)
        $Handle = $PowerShell.BeginInvoke()

        $CurrentJob = [pscustomobject]@{
            PowerShell=$PowerShell
            Handle=$Handle
        }

        [void]$jobs.Add($CurrentJob)

    }

<#

below DoWhile loop is only useful if trying to run above script block as job block, wait till finished, then pass information to next part of script

as well these are just some options for how to output the $SortedObjects info

#>

    do {

        Start-Sleep -Seconds 1

    } until ($RunspacePool.GetAvailableRunspaces() -eq 25) #match to line 15 for max job count

    $ReachableObjects = $jobs | ForEach {
        $_.Powershell.EndInvoke($_.handle)
        $_.PowerShell.Dispose()
    }

    $jobs.clear()

#sort and return meaningful objects

$SortedObjects = $ReachableObjects | Sort-Object -Property FileHash

$SortedObjects | Format-Table

$SortedObjects | Export-Csv -Path $home\Downloads\FileHashStatus.csv -NoTypeInformation -Force
