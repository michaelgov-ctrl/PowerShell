    $Jobs = Import-Csv .\test.csv
    $JobRoutes = $Jobs | Group-Object 'Route Destination'
    
    $ConsolidatedJobStats = foreach ($SingleRoute in $JobRoutes) {
        
        $UniqueRouteIDs = $SingleRoute.Group | Select-Object -Property 'ID' | Sort-Object { $_.'ID' -as [int] } -unique
        
        foreach ($SingleUniqueID in $UniqueRouteIDs) {
        
        <#  use to confirm job grouping
            $UniqueRouteIdJobs = $SingleRoute.Group | Where-Object { $_.'ID' -match $SingleUniqueID.'ID' }
            $UniqueRouteIdJobs.'Name'
        #>

            $UniqueRouteIdJobs = $SingleRoute.Group | Where-Object { $_.'ID' -match $SingleUniqueID.'ID' }
            $TimeArray = $UniqueRouteIdJobs.'Time To Run    ' | % {[TimeSpan]::FromMilliseconds([int]$_.Split(".")[1]) }
            $MeasuredTime = $TimeArray | Measure-Object -Property TotalMilliseconds -Average -Sum -Minimum

                [pscustomobject]@{ 
                    RouteName = $SingleRoute.Name
                    Name = $UniqueRouteIdJobs[0].'Name'
                    ID = $UniqueRouteIdJobs[0].'ID'
                    AccessionNumber = $UniqueRouteIdJobs[0].'Accession Number'
                    StartTime = ($UniqueRouteIdJobs | Sort-Object -Property "Queued Time")[0].'Queued Time'
                    TotalJobCount = [int]$MeasuredTime.Count 
                    TotalMoveTime = [string]([math]::Round(($MeasuredTime.Sum / 1000),3)) + " seconds"
                    AverageProcessingTime = [string]([math]::Round(($MeasuredTime.Average / 1000),3)) + " seconds"
                }

        }

    }

    $ConsolidatedJobStats | Sort-Object -Property AverageProcessingTime | Format-Table
