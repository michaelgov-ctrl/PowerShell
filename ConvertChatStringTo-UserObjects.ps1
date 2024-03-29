#example chatstring
$ChatString = "

john doe
12345
123456789

jane doe
54321
987654321

"

[array]$toArray = $ChatString.Split("`n") | Where-Object {$_.Trim("")}


$SliceCounter = 0

$ArrayOfEntityObjects = while ((3 * $SliceCounter) -lt $toArray.Count){

    [array]$Entity = $toArray | Select-Object -First 3 -skip (3 * $SliceCounter)

    [pscustomobject]@{
        Name = $Entity[0]
        Ext = $Entity[1]
        Tele = $Entity[2]
    }

    $SliceCounter ++

} 

