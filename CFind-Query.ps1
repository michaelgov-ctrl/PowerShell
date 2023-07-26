<#

uses RZDCX API

DicomTag Values:
https://www.leadtools.com/help/sdk/v21/dh/to/data-element-tag-values.html

Modalizer-SDK Docs:
http://modalizer-sdk.hrzkit.com/group___q.html#ga7f3a01136b8057f6ca9959e0d4baee04

RZDCX API Blog:
https://dicomiseasy.blogspot.com/2021/01/move-all-studies-of-patients-with-id-in.html
#>


function CFind-Query {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if( (-Not ($_ | Test-Path)) -and (-Not ((Get-ChildItem -Path $_).Name -eq 'rzdcx.dll')) ){
                Write-Error "rzdcx.dll not found at the specified location"
                break
            } else {
                return $true
            }
        })]
        [System.IO.FileInfo]$PathToRzdcx64DLL,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RemoteScp,
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$QueryObjects    
    )

    #Start DICOM Service
    $RegSvr32Error = $null
    Try {
        $rzdcx64dll = $PathToRzdcx64DLL
        Start-Process regsvr32 -Verb runas -ArgumentList $rzdcx64dll
    } catch { $RegSvr32Error = $_ ; Write-Output $RegSvr32Error ; break }

    #Define Calling AE (SCU)
    $LocalListener="LOCAL_LISTENER"
    
    
    <#Manually Define Called AE and Host(SCP) if preferred 
    $RemoteSCP = [PSCustomObject]@{
        AeTitle = "REMOTE_AE"
        IpAddress = ""
        HostName = ""
        DicomPort = 104
    }
    #>
    
    #Define DICOM Objects from rzdcx service (rzdcx.dll)
    $DicomMethodCreationError = $null
    Try {
        $DicomRequester = New-Object -ComObject rzdcx.DCXREQ
        $DicomObject = New-Object -ComObject rzdcx.DCXOBJ
        $DicomElement = New-Object -ComObject rzdcx.DCXELM
    } catch { $DicomMethodCreationError = $_ ; Write-Output $DicomMethodCreationError ; break}

    #Test Connection to SCP
    $CEchoError = $null
    Try {

        $DicomRequester.Echo($LocalListener, $RemoteSCP.AeTitle, $RemoteSCP.HostName, $RemoteSCP.DicomPort)

    } catch {$CEchoError = $_ ; Write-Output $CEchoError ; break}

    if ($null -eq $CEchoError) {

        #Initialize ArrayList for ReturnedObjects
        $ReturnedObjectsArrayList = [System.Collections.ArrayList]@()

        foreach ($SingleQueryObject in $QueryObjects) {
        <#
            Craft Dicom Object to create granular C-Find request
            The provided object is populated on return by C-Find
        #>

            #Populate DicomTag.QueryRetrieveLevel Tag (Study Level)	
            $DicomElement.Init(0x00080052)
            $DicomElement.Value = "STUDY"
            $DicomObject.insertElement($DicomElement)

            #Populate DicomTag.PatientID Tag (Patient ID)
            $DicomElement.Init(0x00100020)
            if ($SingleQueryObject.PatientId) {
                $DicomElement.Value = $SingleQueryObject.PatientId
            } else {
                $DicomElement.Value = ''
            }
            $DicomObject.insertElement($DicomElement)

            #Populate DicomTag.StudyInstanceUID Tag (Study Instance UID)
            $DicomElement.Init(0x0020000d)
            if ($SingleQueryObject.PatientId) {
                $DicomElement.Value = $SingleQueryObject.StudyInstanceUID
            } else {
                $DicomElement.Value = ''
            }
            $DicomObject.insertElement($DicomElement)

            #Populate DicomTag.AccessionNumber (Accession Number)
            $DicomElement.Init(0x00080050)
            if ($SingleQueryObject.AccessionNumber) {
                $DicomElement.Value = $SingleQueryObject.AccessionNumber
            } else {
                $DicomElement.Value = ''
            }
            $DicomObject.insertElement($DicomElement)

            #Patient Root Query SOP UID (Patient Root Query/Retrieve Information Model â€“ FIND)
            $SopQueryUid = "1.2.840.10008.5.1.4.1.2.1.1"

                #Issue C-Find for patient
                $CFindError = $null
                Try {

                    $ExamCFind = $DicomRequester.Query($LocalListener, $RemoteSCP.AeTitle, $RemoteSCP.HostName, $RemoteSCP.DicomPort, $SopQueryUid, $DicomObject)
                
                } catch { $CFindError = $_ }


                    #Check for $CFindError and the method to check if returned CFind object is .AtEnd()
                    if (($null -eq $CFindError) -and ($ExamCFind.AtEnd() -eq $false)) {
                        
                        #Do-While loop as RegSvr32 returns a serialized array of objects
                        #So parse one, move to next one, check whether the end of the array has been reached with .AtEnd()
                        do {

                            #Read Values from returned CFind object to send to a uniform PSCustomObject
                            $ValueReturnError = $null
                            Try {

                                $ReturnedStudyVal = $ExamCFind.Get().GetElement(0x00080052).Value
                                $ReturnedPIDVal = $ExamCFind.Get().GetElement(0x00100020).Value
                                $ReturnedSUIDVal = $ExamCFind.Get().GetElement(0x0020000d).Value
                                $ReturnedAccVal = $ExamCFind.Get().GetElement(0x00080050).Value

                            } catch {$ValueReturnError = $_}

                                $ReturnedObject = [PSCustomObject]@{
                                    Study = $ReturnedStudyVal
                                    PatID = $ReturnedPIDVal
                                    StudyUID = $ReturnedSUIDVal
                                    AccNum = $ReturnedAccVal
                                    Error = $ValueReturnError
                                }
                            
                            #Add $ReturnedObject to $ReturnedObjectsArrayList
                            $ReturnedObjectsArrayList.Add($ReturnedObject) | Out-Null
                            
                            #Move to next object in serialized array
                            $ExamCFind.Next() | Out-Null

                        } until ($ExamCFind.AtEnd() -eq $true)

                    #If returned CFind found nothing
                    } elseif ($ExamCFind.AtEnd() -eq $true) {
                    
                        $ReturnedObject = [PSCustomObject]@{
                            Study = $null
                            PatID = $null
                            StudyUID = $null
                            AccNum = $null
                            Error = 'NotFound'
                        }

                        #Add $ReturnedObject to $ReturnedObjectsArrayList
                        $ReturnedObjectsArrayList.Add($ReturnedObject) | Out-Null
                    
                    #If CFind Failed
                    } elseif ($CFindError) {

                        $ReturnedObject = [PSCustomObject]@{
                            Study = $null
                            PatID = $null
                            StudyUID = $null
                            AccNum = $null
                            Error = $CFindError
                        }

                        #Add $ReturnedObject to $ReturnedObjectsArrayList
                        $ReturnedObjectsArrayList.Add($ReturnedObject) | Out-Null

                    }
                    
        }

            #Return ArrayList of all Objects
            $ReturnedObjectsArrayList

    }

    #Clean up DICOM COM Objects
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($DicomRequester) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($DicomObject) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($DicomElement) | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

}
