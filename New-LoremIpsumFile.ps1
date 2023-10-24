

funciton New-LoremIpsumFile {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [int]$WordCount,
        [Parameter(Mandatory = $true)]  
        [int]$SentenceLength,
        [parameter(Mandatory = $true)]
        [System.IO.FileInfo]$OutFilePath
    )
    $loremIpsum = @(
        "yummy",
        "shore",
        "yuck",
        "shoomy",
        "muleen",
        "push",
        "plash",
        "wombo",
        "lerish",
        "moosh",
        "olo",
        "po",
        "bambo",
        "slake",
        "plambo",
        "yake",
        "welease",
        "y",
        "e",
        "oy",
        "oi",
        "l",
        "olomort",
        "re",
        "zlinger",
        "ple",
        "lem",
        "al",
        "shee",
        "tum",
        "plub",
        "mlo",
        "teem"
    )

    $Words = (1..$WordCount).ForEach({Get-Random -InputObject $loremIpsum})

    $counter = 0
    $groupBy = $SentenceLength

    $sentences = do {
        ($Words[$counter..($counter+$groupBy)] -join ' ') + "."
        $counter = $counter + $groupBy
    } until ($counter -eq $Words.Count)

    $sentences | Out-File -LiteralPath $OutFilePath
}