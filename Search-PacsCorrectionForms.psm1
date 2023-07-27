function Search-PacsCorrectionForms {

    [CmdletBinding()]
    Param(
        [Parameter(Position = 0,Mandatory = $false)]
        [int]$BeginDate,
        [Parameter(Mandatory = $false)]  
        [array[]]$NameMatch,
        [Parameter(Mandatory = $false)]  
        [array[]]$AccMatch,
        [Parameter(Mandatory = $false)]  
        [array[]]$MrnMatch,
        [Parameter(Mandatory = $false)]  
        [switch]$Incomplete,
        [Parameter(Mandatory = $false)]  
        [switch]$Keep       
    )

        #           !!!!!!  API TOKEN GOES BELOW HERE   !!!!!!    
        $RedCapApiToken = ''
        #           !!!!!!  API TOKEN GOES ABOVE HERE   !!!!!! 
        
        <#
            Begin processing of date parameter        
        #>

        if ( $null -ne $BeginDate ) {
            
            if ( $BeginDate -ne 0 ) {

                $ReturnBeginDate = (Get-Date).AddDays(-$BeginDate)
                $DateBegin = [string]($ReturnBeginDate.Year) + "-" + [string]($ReturnBeginDate.Month) + "-" + [string]($ReturnBeginDate.Day) + " 00:00"
            
            } else {

                #if begin date is 0 set $DateBegin to $null to query all forms with api request
                $DateBegin = $null

            }

	} else {

            #default is to return last 30 days to prevent long process time
            $ReturnBeginDate = (Get-Date).AddDays(-30)
            $DateBegin = [string]($ReturnBeginDate.Year) + "-" + [string]($ReturnBeginDate.Month) + "-" + [string]($ReturnBeginDate.Day) + " 00:00"
    
        }

        <#
            End processing of date parameter
        #>

            <#
                Begin api request        
            #>

            $TcRestError = $null
    
            Try {
    
                $data = @{
                    token = "$RedCapApiToken"
                    content = 'record'
                    dateRangeBegin = "$DateBegin"
                    rawOrLabel = "label"
                    exportCheckboxLabel = "true"
                    format = 'json'
                    returnFormat = 'json'
                }
        
                $uri = 'https://[RedCapUrl]/api/'
    
                $CorrectionForms = Invoke-RestMethod -Uri $uri -Method Post -Body $data
    
            } Catch {
    
                $TcRestError = $_
    
            }

            <#
                End api request        
            #>

        <#
            Begin processing of api return results based on "*Match" parameters to output to html
        #>
    
        if ($null -eq $TcRestError) { 
	
            #Filter out complete forms if -Incomplete switch is given
	    if ($Incomplete) {

                $CorrectionForms = $CorrectionForms | Where-Object {($_.tech_form_complete -ne 'Complete') -or ($_.pacs_response_complete -ne 'Complete')}

            }

        if ($null -ne $CorrectionForms) {
            
            #select properties of objects to only return populated values and save to $PopulatedValueForms
            $PopulatedValueForms = foreach ($SingleForm in $CorrectionForms) {

                $TempPropVar = $SingleForm.psobject.Properties | Where-Object value | ForEach-Object name
            
                $SingleForm | Select-Object $TempPropVar
            
            }
            
                if ($null -ne $NameMatch) {

                    $MatchedNameForms = foreach ($SingleName in $NameMatch) {
                        
                        $PopulatedValueForms | Where-Object {($_.source_last_name -match $SingleName) -or ($_.source_first_name -match $SingleName) -or ($_.dest_last_name -match $SingleName) -or ($_.dest_first_name -match $SingleName)}
    
                    }
                    
                } 
                
                if ($null -ne $AccMatch) {

                    $MatchedAccForms = foreach ($SingleAcc in $AccMatch) {
                        
                        $PopulatedValueForms | Where-Object {($_.source_acc -match $SingleAcc) -or ($_.dest_acc -match $SingleAcc) -or ($_.pacs_notes -match $SingleAcc) -or ($_.notes -match $SingleAcc)}
    
                    }

                }
                
                if ($null -ne $MrnMatch) {

                    [array]$MatchedMrnForms = foreach ($SingleMrn in $MrnMatch) {
                        
                        $PopulatedValueForms |  Where-Object {($_.source_mrn -match $SingleMrn) -or ($_.dest_mrn -match $SingleMrn) -or ($_.pacs_notes -match $SingleMrn) -or ($_.notes -match $SingleMrn)}
    
                    }
    
                } 
                
                if (($null -ne $NameMatch) -or ($null -ne $AccMatch) -or ($null -ne $MrnMatch)) {

                    $FilteredForms = New-Object System.Collections.ArrayList
                    $MatchedNameForms | ForEach-Object {$FilteredForms.Add($_) | Out-Null}
                    $MatchedAccForms | ForEach-Object {$FilteredForms.Add($_) | Out-Null}
                    $MatchedMrnForms | ForEach-Object {$FilteredForms.Add($_) | Out-Null}
                    $ReturnedTechCorrections = $FilteredForms | Sort-Object {[int]$_.subject_id} -Unique

                } else {
                    
                    $ReturnedTechCorrections = $PopulatedValueForms | Sort-Object {[int]$_.subject_id} -Unique
    
                }

if ($null -ne $ReturnedTechCorrections) {

        <#
            Begin .html file to display returned forms
        #>

$Header = @"
<style>
    body
  {
      background-color:#242443;
      color:white;
  }

  TABLE {width: 50%; border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
  TD {width: 50%; border-width: 1px; padding: 3px; border-style: solid; border-color: black;}

    h3{
        background-color:#414B6C;
        color:white;
        text-align: center;
    }
</style>
"@

    $HtmlFormattedCorrections = foreach ($TC in $ReturnedTechCorrections) {
        $TicketNumber = $TC.subject_id
        $TC | ConvertTo-Html -Head $Header -PreContent "<h3>Ticket #$TicketNumber</h3>" -As List
    }
    
    $HtmlOutFileError = $null

    Try {
    
        $VariableFileName = "TechCorrectionForms_" + [string](Get-Date -Format "MM-dd-HH(HH-mm)") + ".html"
        $VariableFileNameDestPath = Join-Path -Path $home\Downloads -ChildPath $VariableFileName
        $HtmlFormattedCorrections | Out-File $VariableFileNameDestPath -Force
    
    } Catch {

        $HtmlOutFileError = $_

    }

        <#
            End .html file to display returned forms
        #>

        <#
            Begin display .html file and delete it unless the -Keep paramater is specified
        #>

    if ($null -eq $HtmlOutFileError) {

        if (Test-Path $VariableFileNameDestPath) {
            
                Invoke-Item $VariableFileNameDestPath

                if (-not ($Keep)) {
                
                    Start-Sleep -Seconds 5
                    Remove-Item -Path $VariableFileNameDestPath -Force
            
                }

        } else {

            Write-Error "Failed to create a .html file to $home\Downloads"

        }

    } else {

        #Failed if condition at line 205
        Write-Error $HtmlOutFileError.Exception
        break

    }

        <#
            Begin display .html file and delete it unless the -Keep paramater is specified
        #>

} else {

    #Failed if condition at line 153
    Write-Warning "No forms matched the provided criteria"
    break

}

        } else {
            
            #Failed if condition at line 98
            Write-Warning "No forms matched the provided date range or criteria"
            break

        }

        } else {
            
            #Failed if condition at line 89
            Write-Error $TcRestError.Exception
            break

        }

            <#
                End processing of api return results based on "*Match" parameters to output to html
            #>
    
}
