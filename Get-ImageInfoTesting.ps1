#Working with Shell.Application for Images

$SourceFolder = ./
$Shell = New-Object -ComObject Shell.Application
$ShellFolder = $Shell.NameSpace($SourceFolder)
$RatedObjects = $ShellFolder.Items() | Where-Object {$_.Type -eq 'JPG File'} | ForEach-Object {[pscustomobject]@{File=$_.Name;Rating=$ShellFolder.GetDetailsOf($_,19)}}
$RatedObjects

#Working with [System.Drawing.Bitmap] for images

$SpecificItem = (Get-ChildItem .\image001.jpg).FullName
$Image = [System.Drawing.Bitmap]::new($SpecificItem)
$PropertyItems = $Image.PropertyItems

$re = "(?:(?:^|[^.,=])\b(3(?:[ \.\-\,\t]*[6])(?:[ \.\-\,\t]*[0-9]){12})\b)"
$MatchedByteArrays = foreach ($i in 0..($PropertyItems.Count - 1)) {
    [pscustomobject]@{
        ByteArrayId = $PropertyItems[$i].Id
        Matches = Select-String -Pattern $re -InputObject ($PropertyItems[$i].Value -join " ") -AllMatches | % {$_.Matches}
    }
}
($MatchedByteArrays | Where-Object {$_.Matches -ne $null}).Matches
