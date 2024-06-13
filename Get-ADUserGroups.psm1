function Get-ADUserGroups {

    [CmdletBinding(DefaultParameterSetName = 'UserNames')]

    Param(
        [Parameter(Mandatory = $true,
        ParameterSetName = 'UserNames',
        Position = 0)]
        [string[]]$UserNames,

        [Parameter(Mandatory = $true,
        ParameterSetName = 'PipelineUserNames',
        ValueFromPipeline = $true)]
        [string[]]$PipelineUserNames            
    )
    process {        

        if ($PipelineUserNames) {
            $Users = $PipelineUserNames
        } else {
            $Users = $UserNames
        }

        $Users | % { (Get-ADUser -Filter { SamAccountName -eq $_ } -Properties MemberOf) | Select-Object -Property Name,@{name="MemberOf";expression={ ($_.MemberOf | % { $_.split(',')[0].split('=')[1] } | Sort-Object ) } } }
    
    }
}

<# example
[string]$date = Get-Date -Format 'yyyy-MM-dd'
(Import-Csv -LiteralPath "$HOME\Documents\Users.csv").UserNames | Get-ADUserGroups | Export-Csv -Path "$HOME\Documents\UserGroups($date).csv" -NoTypeInformation
#>
