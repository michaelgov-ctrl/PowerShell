    function Job-Manager {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $true)]
            [int]$MinutesToStopAfter,
            [Parameter(Mandatory = $true)]
            [string]$JobName,
            [Parameter(Mandatory = $true)]
            [string]$FailedJobFormatString
        )
            Write-Host "If the job doesnt return in $MinutesToStopAfter minutes it will be force ended" -ForegroundColor Green
            $Timer = [Diagnostics.Stopwatch]::StartNew()
            $SecondToStopAfter = $MinutesToStopAfter * 60
            do {
                $CurrentJobs = Get-Job | Where-Object { $_.Name -match $JobName }
                $FinishedJobs = $CurrentJobs | Where-Object { ($_.State -eq 'Completed') -or ($_.State -eq 'Failed') }
                Write-Host ("Waiting on " + ($CurrentJobs.Count - $FinishedJobs.Count) + " of " + $CurrentJobs.Count + " jobs: " + [string]("{0:mm\:ss}" -f $Timer.Elapsed) + " minutes elapsed.") -ForegroundColor Cyan
                Start-Sleep -Seconds 5
                #break loop waiting for jobs if it is taking longer than $SecondsToStopAfter
            } until ( ($FinishedJobs.Count -eq $CurrentJobs.Count) -or ($Timer.Elapsed.TotalSeconds -gt $SecondToStopAfter) )
            $Timer.Stop()

        #Check for still running jobs and stop any that may exist
            $UnfinishedJobs = Get-Job | Where-Object { ($_.Name -match $JobName) -and ($_.State -ne 'Completed') }

            if ($null -ne $UnfinishedJobs) {
                $UnfinishedJobs | Receive-Job
                $UnfinishedJobs | ForEach-Object { Write-Host ($FailedJobFormatString -f $_.id, $_.Name) -ForegroundColor Red }
                $UnfinishedJobs | Stop-Job
            }

        #Get returned jobs and remove all jobs
            $ReturnedObjects = Get-Job -State Completed | Receive-Job
            Get-Job | Where-Object { $_.Name -match $JobName } | Remove-Job
        
            $ReturnedObjects

    }


    (0..(Get-Random -Minimum 1 -Maximum 10)) | ForEach-Object { Start-Job -Name ("test" + $_) -ScriptBlock {Start-Sleep -Seconds (Get-Random -Minimum 25 -Maximum 85)} }
    $MinutesToStopAfter = 1
    $JobName = 'test'
    $FailedJobFormatString = "Job: {0} did not complete in time. Please check the expected outcome for {1}"
    Job-Manager -MinutesToStopAfter $MinutesToStopAfter -JobName $JobName -FailedJobFormatString $FailedJobFormatString
