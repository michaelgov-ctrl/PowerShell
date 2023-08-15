

<#
    Create test objects
#>

    $TestObject = [pscustomobject]@{
        Name = "Turtle"
        User = $env:USERNAME
        Location = "East-US"
    }
    $TestObjectArray = 0..2 | ForEach-Object { $TestObject.PsObject.Copy() }
    $i = 0
    $TestObjectArray | ForEach-Object { Add-Member -InputObject $_ -MemberType NoteProperty -Name AddedProperty$i -Value $i ; $i++ }
    $TestObjectArray | ForEach-Object { Add-Member -InputObject $_ -MemberType NoteProperty -Name RandomNumber -Value (Get-Random -Maximum 1000) }

<#
    Create test objects
#>

<#
    Create test function
#>

    function Test-Function {

        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [int]$OutInt
        )

            Write-Output $OutInt

    }

<#
    Create test function
#>

<#
    Runspace
#>

    #Send objects to RunSpaces and work with them via custom function
    $TestObjectArray | Start-RSJob -Name {$_.Name} -FunctionsToImport "Test-Function" -Throttle 3 -ScriptBlock { 
        $MatchingPropertyName = $_.PsObject.Properties.Name -match "AddedProperty"
        [pscustomobject]@{
            UniqueProperty = $_.$MatchingPropertyName
            FunctionTest = (Test-Function -OutInt $_.RandomNumber)
        }
        Write-Output ([string]$RSInteralObject.UniqueProperty + "; " + [string]$RSInteralObject.FunctionTest)
        Start-Sleep -Seconds (Get-Random -Maximum 60)
    }


    #Process RunSpace jobs as they complete and set timer
    $Timer = [Diagnostics.Stopwatch]::StartNew()
    $SecondToStopAfter = 20
    do {  
        $CurrentJobs = Get-RSJob
        $CompletedJobs = $CurrentJobs | Where-Object { $_.State -eq 'Completed' }

        Write-Host ("Waiting on " + ($CurrentJobs.Count - $CompletedJobs.Count) + " of " + $CurrentJobs.Count + " jobs.") -ForegroundColor Cyan

        $CompletedJobs | Where-Object { $_.HasMoreData -eq $true } | Receive-RSJob

        Start-Sleep -Seconds 4
    } until ( (($CompletedJobs.HasMoreData -eq $false).count -eq $CurrentJobs.Count) -or ($Timer.Elapsed.Seconds -gt $SecondToStopAfter) )
    $Timer.Stop()

    #Check for still running jobs
    $StillRunningJobs = Get-RSJob | Where-Object { $_.State -eq 'Running' }

    if ($null -ne $StillRunningJobs) { 
        $StillRunningJobs | ForEach-Object { write-host ("Runspace: " + [string]$_.Id + " did not complete in time. Please check the resources for " + $_.Name + " in Azure") }
    }

    $StillRunningJobs | Stop-RSJob

    #Remove all jobs
    Get-RSJob | Remove-RSJob

<#
    Runspace
#>

