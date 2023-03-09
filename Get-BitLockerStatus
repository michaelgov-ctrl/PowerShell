#example computer names
$Computers = @(
    'HostName1',
    'HostName2',
    'HostName3',
    'HostName4',
    'HostName5',
    'HostName6'
)

$ScriptBlock = {
    [pscustomobject]@{
        HostName = $env:COMPUTERNAME
        Status = (Get-BitLockerVolume).EncryptionPercentage
        Error = $false
        ErrorStatus = $null
    }
}

$SuccessfulObjects = Invoke-Command -ComputerName $Computers -Credential $creds -ScriptBlock $ScriptBlock -ErrorAction SilentlyContinue -ErrorVariable InvokeError | Select-Object -Property * -ExcludeProperty PSComputerName,RunspaceId

$UnSuccessfulCommands = $InvokeError | Where-Object {$Computers -contains $_.CategoryInfo.TargetName}

$UnSuccessfulObjects = ForEach ($UnSuccessfulCommand in $UnSuccessfulCommands) {
    [pscustomobject]@{
        HostName = $UnSuccessfulCommand.TargetObject
        Status = $null
        Error = $true
        ErrorStatus = $UnSuccessfulCommand.FullyQualifiedErrorId   
    }
}
