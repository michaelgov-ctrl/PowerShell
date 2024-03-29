<#
This function displays a GUI to provide an interactive experience and then hands the result to the defined Remove-UserProfiles Function
The Remove-UserProfiles Function checks directories at in C:\Users\ of the target computers and checks if the LastWriteTime is greater than the timespan giver to the -OlderThan parameter (-OlderThan parameter must be provided in a second format) 

Written by michaelgov-ctrl 9/23/2022 
#>
function Get-NodePerformance {

    Param(
            [Parameter(Mandatory)]
            [string[]]$Computer,
            [Parameter(Mandatory)]
            [System.Management.Automation.PSCredential]$Credential
         )
    
                $CIMSession = New-CimSession -ComputerName $Computer -Credential $Credential -Authentication Negotiate
            
            if ($CIMSession -ne $null) {
    
                try {
    
                    $ProcessorInfo = Get-CimInstance -CimSession $CIMSession -ClassName Win32_Processor | Measure-Object -Property LoadPercentage -Average
    
                    $OSInfo = Get-CimInstance -CimSession $CIMSession -ClassName Win32_OperatingSystem
    
                    $Drives = Get-CimInstance -CimSession $CIMSession -ClassName Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3}
    
                    $DriveInfo = foreach($Drive in $Drives) {
    
                                [pscustomobject]@{
                                    DriveName = $Drive.DeviceID
                                    Size = [math]::Round(($Drive.Size / 1gb),2)
                                    FreeSpace = [math]::Round(($Drive.FreeSpace / 1gb),2)
                                    PercentFree = ($Drive.FreeSpace / $Drive.Size).ToString("P")
                                    }
    
                                }
    
                        [pscustomobject]@{
                            Computer = $Computer
                            IsUp = $true
                            WSManRunning = $true
                            ProcessorUsage = [string]$ProcessorInfo.Average + "%"
                            RamUsage = (($OSInfo.TotalVisibleMemorySize - $OSInfo.FreePhysicalMemory)/$OSInfo.TotalVisibleMemorySize).ToString("P")
                            DriveInfo = $DriveInfo
                            }
                    
                } catch {
    
                }
    
                $CIMSession | Remove-CimSession
    
            } else {
    
                [pscustomobject]@{
                    Computer = $Computer
                    IsUp = $true
                    WSManRunning = $true
                    ProcessorUsage = ''
                    RamUsage = ''
                    DriveInfo = ''
                }
    
            }
    
    }

function Remove-UserProfiles {

    Param(
        [Parameter(Mandatory)]
        [string]$ComputerName,
        [Parameter(Mandatory)]          
        [Object[]]$SessionVar,
        [Parameter(Mandatory)]
        [int]$OlderThan             #-OlderThan must be provided in Seconds format
    )

    $UserDirectories = Invoke-Command -Session $SessionVar -ScriptBlock { Get-ChildItem C:\Users\* }
    $StaleProfilesSansPublic = $null #initialized to null so second if clause only runs if Stale Profiles other than Public exist
    if ($UserDirectories -ne $null) { 

        $ProvidedAge = New-TimeSpan -Seconds $OlderThan
        $CurrentDate = Get-Date

        $StaleProfiles = foreach ($i in (0..($UserDirectories.Count - 1))) { 

                $UserLastWriteTime = $UserDirectories[$i].LastWriteTime     #for reasons beyond my comprehension LastWriteTime of the users profile seems to typically be a better representation time than LastUseTime of the Win32_UserProfile

                if (($CurrentDate - $UserLastWriteTime) -gt $ProvidedAge) {

                    $UserDirectories[$i].Name

                }

            }

        $StaleProfilesSansPublic = $StaleProfiles | Where-Object {$_ -notmatch "Public"}

    } else {

        $Header = "User Profile remover"
        $Message = "No Profiles Other than Public Were Found"
        $PopUp = New-Object -ComObject Wscript.Shell -ErrorAction Stop
        $PopupYesOrNo = $PopUp.Popup($Message,0,$Header,48)

    }

    if ($StaleProfilesSansPublic -ne $null) {
        foreach ($Profile in $StaleProfilesSansPublic) {

            $Header = "User Profile remover"
            $Message = "Would you like to remove the profile for user: " + [string]$Profile + " ?"
            $PopUp = New-Object -ComObject Wscript.Shell -ErrorAction Stop
            $PopupYesOrNo = $PopUp.Popup($Message,0,$Header,52)

            if ($PopupYesOrNo -eq 6) {

                try {

                    Invoke-Command -Session $SessionVar -ScriptBlock { Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.LocalPath.split('\')[-1] -eq [string]$using:Profile } | Remove-CimInstance }

                } catch {

                    $ErrorVariable += ([string]$Profile + "was unable to be removed")
                }

            }

        }

    } else {

        $Header = "User Profile remover"
        $Message = "No Profiles In That Age Range Were Found"
        $PopUp = New-Object -ComObject Wscript.Shell -ErrorAction Stop
        $PopupYesOrNo = $PopUp.Popup($Message,0,$Header,48)

    }

}

                                                ################ Begin Interactive GUI #####################

$TargetIP = $null
$IPValidated = $false
$TargetIsUp = $false
$Seconds = $null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form                                  ################ Initialize first page
$form.Text = 'User Profile Remover'
$form.Size = New-Object System.Drawing.Size(700,400)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(35,20)
$label.Text = "This script connects to the target station and checks performance"
$label.AutoSize = $true
$label.Font = "Microsoft Sans Serif,12,style=Bold"
$form.Controls.Add($label)

$labelTwo = New-Object System.Windows.Forms.Label
$labelTwo.Location = New-Object System.Drawing.Point(40,55)
$labelTwo.Text = "Please input IP address of target station to verify connection with target"
$labelTwo.AutoSize = $true
$labelTwo.Font = "Microsoft Sans Serif,10"
$form.Controls.Add($labelTwo)

$NextButton = New-Object System.Windows.Forms.Button
$NextButton.Location = New-Object System.Drawing.Point(550,280)
$NextButton.Size = New-Object System.Drawing.Size(80,60)
$NextButton.Text = 'Test Connectivity'
$NextButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$NextButton.Anchor = 'right,bottom'
$form.AcceptButton = $NextButton
$form.Controls.Add($NextButton)

$IPValidateTextBox = New-Object System.Windows.Forms.TextBox
$IPValidateTextBox.Location = New-Object System.Drawing.Size(100,100)
$IPValidateTextBox.Size = New-Object System.Drawing.Size(250,40)
$form.Controls.Add($IPValidateTextBox)

$form.TopMost = $true

$result = $form.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))

if ($result -eq [System.Windows.Forms.DialogResult]::OK) {

    $TargetIP = $IPValidateTextBox.Text

    $ipv4 = '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'    ###IPV4 regex

    if ($TargetIP -notmatch $ipv4) {
                                                                     ########### validate provided IP address and display next page
        $form = New-Object System.Windows.Forms.Form
        $form.Text = 'User Profile Remover'
        $form.Size = New-Object System.Drawing.Size(700,400)
        $form.StartPosition = 'CenterScreen'
        $form.FormBorderStyle = 'FixedDialog'

        $label = New-Object System.Windows.Forms.Label
        $label.Location = New-Object System.Drawing.Point(35,20)
        $label.Text = "The input string does not match an IPv4 Address"
        $label.AutoSize = $true
        $label.Font = "Microsoft Sans Serif,12,style=Bold"
        $form.Controls.Add($label)

        $labelTwo = New-Object System.Windows.Forms.Label
        $labelTwo.Location = New-Object System.Drawing.Point(40,55)
        $labelTwo.Text = "Please input IP address of target station to verify connection with target"
        $labelTwo.AutoSize = $true
        $labelTwo.Font = "Microsoft Sans Serif,10"
        $form.Controls.Add($labelTwo)

        $NextButton = New-Object System.Windows.Forms.Button
        $NextButton.Location = New-Object System.Drawing.Point(550,280)
        $NextButton.Size = New-Object System.Drawing.Size(80,60)
        $NextButton.Text = 'Test Connectivity'
        $NextButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $NextButton.Anchor = 'right,bottom'
        $form.AcceptButton = $NextButton
        $form.Controls.Add($NextButton)

        $IPValidateTextBox = New-Object System.Windows.Forms.TextBox
        $IPValidateTextBox.Location = New-Object System.Drawing.Size(100,100)
        $IPValidateTextBox.Size = New-Object System.Drawing.Size(250,40)
        $form.Controls.Add($IPValidateTextBox)

        $result = $form.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))

        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {

            $TargetIP = $IPValidateTextBox.Text       ####### validate IP address

            if ($TargetIP -notmatch $ipv4) {
                do {

                    $form.Refresh()
                    $result = $form.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))
                    $TargetIP = $IPValidateTextBox.Text

                } while ( $TargetIP -notmatch $ipv4 )

                $IPValidated = $true

            } else {

                $IPValidated = $true

            }

        }

    } else {
        
        $IPValidated = $true

    }

}
    
    if ($IPValidated) {                                                           ################# test network connectivity and WSMan configuration

        $ConnectionTest = Test-Connection $TargetIP -Quiet -Count 2
        $WSManTest = Test-WSMan -ComputerName $TargetIP -ErrorAction SilentlyContinue

        if ($ConnectionTest -and $WSManTest) {
            
            $TargetIsUp = $true

        }

        elseif ( -not ($ConnectionTest) ) {

            $Header = "User Profile remover"
            $Message = "$TargetIP is not reachable"
            $PopUp = New-Object -ComObject Wscript.Shell -ErrorAction Stop
            $PopupYesOrNo = $PopUp.Popup($Message,0,$Header,48)

        }

        else {
        
            $Header = "User Profile remover"
            $Message = "$TargetIP is not configured for PSRemoting"
            $PopUp = New-Object -ComObject Wscript.Shell -ErrorAction Stop
            $PopupYesOrNo = $PopUp.Popup($Message,0,$Header,48)

        }

    }

        if ($TargetIsUp) {

            $creds = Get-Credential
            $re = "^*$" #optional regex to match admin account 

            if ($creds.UserName -match $re) {

                $ComputerInfo = Get-NodePerformance -Computer $TargetIP -Credential $creds

                $ProcessorUsage = $ComputerInfo.ProcessorUsage

                $RamUsage = $ComputerInfo.RamUsage

                $DriveInfo = $ComputerInfo.DriveInfo | Where-Object {$_.DriveName -eq "C:"}
                $DriveName = $DriveInfo.DriveName + "\ "
                $DriveSize = $DriveInfo.Size
                $DriveSpace = $DriveInfo.FreeSpace
                $DrivePercent = $DriveInfo.PercentFree

                #$HostName = [System.Net.Dns]::GetHostByAddress($TargetIP).Hostname  #$TargetIP comes from line 209
                #$Session = New-PSSession -ComputerName $HostName -Credential $creds #$creds comes from line 316
                $Session = New-PSSession -ComputerName $TargetIP -Credential $creds #$creds comes from line 316

                $UserDirectories = Invoke-Command -Session $Session -ScriptBlock {Get-ChildItem C:\Users\*}

                    $ProfileObjects = foreach ($UserDirectory in ($UserDirectories | Where-Object {$_.Name -ne "Public"})) {
    
                        $Name = $UserDirectory.Name
        
                        $LastWriteTime = ($UserDirectory.LastWriteTime -split " ")[0]

                        $DirPath = "C:\Users\" + $UserDirectory.Name
                        $FilesToMeasure = Invoke-Command -Session $Session -ScriptBlock { (Get-ChildItem $using:DirPath | Where-Object {$_.name -notmatch "OneDrive"} | Get-ChildItem -Recurse | Measure-Object -Property length -Sum -ErrorAction SilentlyContinue).Sum}
                        $FileSize = [string][math]::Round(($FilesToMeasure/1MB),2) + " MB"

                            "User: $Name, LastWriteTime: $LastWriteTime, ProfileSize: $FileSize"
        
                    } 

                $form = New-Object System.Windows.Forms.Form
                $form.Text = 'User Profile Remover'
                $form.Size = New-Object System.Drawing.Size(700,550)
                $form.StartPosition = 'CenterScreen'
                $form.FormBorderStyle = 'FixedDialog'
        
                $label = New-Object System.Windows.Forms.Label
                $label.Location = New-Object System.Drawing.Point(35,20)
                $label.Text = "Node: $TargetIP"
                $label.AutoSize = $true
                $label.Font = "Microsoft Sans Serif,12,style=Bold"
                $form.Controls.Add($label)
        
                $labelTwo = New-Object System.Windows.Forms.Label
                $labelTwo.Location = New-Object System.Drawing.Point(40,60)
                $labelTwo.Text = "Processor Usage = $ProcessorUsage"
                $labelTwo.AutoSize = $true
                $labelTwo.Font = "Microsoft Sans Serif,10"
                $form.Controls.Add($labelTwo)

                $labelThree = New-Object System.Windows.Forms.Label
                $labelThree.Location = New-Object System.Drawing.Point(40,90)
                $labelThree.Text = "RAM Usage = $RamUsage"
                $labelThree.AutoSize = $true
                $labelThree.Font = "Microsoft Sans Serif,10"
                $form.Controls.Add($labelThree)

                $labelFour = New-Object System.Windows.Forms.Label
                $labelFour.Location = New-Object System.Drawing.Point(40,120)
                $labelFour.Text = "Drive= $DriveName Size= $DriveSize : FreeSpace= $DriveSpace : PercentFree= $DrivePercent"
                $labelFour.AutoSize = $true
                $labelFour.Font = "Microsoft Sans Serif,10"
                $form.Controls.Add($labelFour)

                $labelFive = New-Object System.Windows.Forms.Label
                $labelFive.Location = New-Object System.Drawing.Point(35,160)
                $labelFive.Text = "User Profiles on $TargetIP"
                $labelFive.AutoSize = $true
                $labelFive.Font = "Microsoft Sans Serif,12,style=Bold"
                $form.Controls.Add($labelFive)

                $TextBox1 = New-Object System.Windows.Forms.TextBox 
                $TextBox1.Multiline = $True;
                $TextBox1.Location = New-Object System.Drawing.Size(40,200) 
                $TextBox1.Size = New-Object System.Drawing.Size(600,200)
                $TextBox1.Scrollbars = "Vertical" 
                $ProfileObjects | ForEach {
                    $TextBox1.AppendText($_ + [System.Environment]::Newline)
                }
                $form.Controls.Add($TextBox1)
        
                $NextButton = New-Object System.Windows.Forms.Button
                $NextButton.Location = New-Object System.Drawing.Point(560,430)
                $NextButton.Size = New-Object System.Drawing.Size(80,60)
                $NextButton.Text = 'Check User Profiles'
                $NextButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
                $NextButton.Anchor = 'right,bottom'
                $form.AcceptButton = $NextButton
                $form.Controls.Add($NextButton)
        
                $result = $form.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))

                if ($result -eq [System.Windows.Forms.DialogResult]::OK) {

                    $form = New-Object System.Windows.Forms.Form                                  ################ Initialize Second page
                    $form.Text = 'User Profile Remover'
                    $form.Size = New-Object System.Drawing.Size(700,400)
                    $form.StartPosition = 'CenterScreen'
                    $form.FormBorderStyle = 'FixedDialog'

                    $label = New-Object System.Windows.Forms.Label
                    $label.Location = New-Object System.Drawing.Point(35,20)
                    $label.Text = "Once an appropriate time is chosen a prompt will display for each profile older than the provided age"
                    $label.MaximumSize = New-Object System.Drawing.Size(600,350)
                    $label.AutoSize = $True
                    $label.Font = "Microsoft Sans Serif,12,style=Bold"
                    $form.Controls.Add($label)

                    $labelTwo = New-Object System.Windows.Forms.Label
                    $labelTwo.Location = New-Object System.Drawing.Point(40,80)
                    $labelTwo.Text = "Remove Profiles Older Than:"
                    $labelTwo.AutoSize = $true
                    $labelTwo.Font = "Microsoft Sans Serif,10"
                    $form.Controls.Add($labelTwo)

                    $NextButton = New-Object System.Windows.Forms.Button
                    $NextButton.Location = New-Object System.Drawing.Point(550,280)
                    $NextButton.Size = New-Object System.Drawing.Size(80,60)
                    $NextButton.Text = 'Check Profile Age'
                    $NextButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
                    $NextButton.Anchor = 'right,bottom'
                    $form.AcceptButton = $NextButton
                    $form.Controls.Add($NextButton)

                    $ComboBoxInt = New-Object System.Windows.Forms.ComboBox
                    $ComboBoxInt.Location  = New-Object System.Drawing.Point(50,110)
                    $ComboBoxInt.Width = 100
                    $ComboBoxInt.DropDownStyle = 'DropDownList'
                    foreach ($i in (1..12)) {
                        $ComboBoxInt.Items.Add($i) | Out-Null
                    }
                    $form.Controls.Add($ComboBoxInt)

                    $ComboBoxTimeSpan = New-Object System.Windows.Forms.ComboBox
                    $ComboBoxTimeSpan.Location  = New-Object System.Drawing.Point(180,110)
                    $ComboBoxTimeSpan.Width = 100
                    $ComboBoxTimeSpan.DropDownStyle = 'DropDownList'
                    $ComboBoxTimeSpan.Items.Add('Minutes')
                    $ComboBoxTimeSpan.Items.Add('Hours')
                    $ComboBoxTimeSpan.Items.Add('Days')
                    $ComboBoxTimeSpan.Items.Add('Months')
                    $ComboBoxTimeSpan.Items.Add('Years')
                    $form.Controls.Add($ComboBoxTimeSpan)

                    $form.Topmost = $true

                    $result = $form.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))

                    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                    
                        if($ComboBoxTimeSpan.Text -eq 'Minutes') {
                    
                        $Seconds = ([int]$ComboBoxInt.Text) * 60
                        
                        }

                        elseif ($ComboBoxTimeSpan.Text -eq 'Hours') {
                    
                        $Seconds = ([int]$ComboBoxInt.Text) * 3600
                        
                        }

                        elseif ($ComboBoxTimeSpan.Text -eq 'Days') {
                    
                        $Seconds = ([int]$ComboBoxInt.Text) * 86400
                        
                        }

                        elseif ($ComboBoxTimeSpan.Text -eq 'Months') {
                    
                        $Seconds = ([int]$ComboBoxInt.Text) * 2628288
                        
                        }            
                    
                        elseif ($ComboBoxTimeSpan.Text -eq 'Years') {
                    
                        $Seconds = ([int]$ComboBoxInt.Text) * 31536000
                        
                        }

                    }

                }

            } else {

                $Header = "User Profile remover"
                $Message = "Script will only execute with an elevated account please try again"
                $PopUp = New-Object -ComObject Wscript.Shell -ErrorAction Stop
                $PopupYesOrNo = $PopUp.Popup($Message,0,$Header,48)
            
            }


        }

       
                                                             ######### finally execute function #############
if ($Seconds -ne $null) {
        
        if ($Session -ne $null) {    ###$Session created at line 328

            Remove-UserProfiles -ComputerName $TargetIP -OlderThan $Seconds -SessionVar $Session    #-OlderThan must be provided in Seconds format
        
        } else {
            
            $Header = "User Profile remover"
            $Message = "Failed to open session, confirm password was entered correctly"
            $PopUp = New-Object -ComObject Wscript.Shell -ErrorAction Stop
            $PopupYesOrNo = $PopUp.Popup($Message,0,$Header,48)

        }

}
