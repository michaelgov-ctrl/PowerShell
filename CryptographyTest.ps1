$encryptedString = "K9SVOEGsk+RlVgN38Gf7uRSlJzhmPZ3NZqYBHtrzIsg="
$b = [System.Convert]::FromBase64String($encryptedString)
$i = $b[0..15]
$a = New-Object "System.Security.Cryptography.AesManaged"; $s = 128; $k = 256; $x = [System.Convert]::FromBase64String("7ITkvtK+h980wAtsWfIjFnEce6QITC/YdaNYgv0J+Zs=")
$a | % { $_.Mode = [System.Security.Cryptography.CipherMode]::CBC ; $_.Padding = [System.Security.Cryptography.PaddingMode]::Zeros; $_.BlockSize = $s;$_.KeySize = $k;$_.IV = $i;$_.Key = $x}
$d = $a.CreateDecryptor().TransformFinalBlock($b, 16, $b.Length - 16)
$a.Dispose()
[System.Text.Encoding]::UTF8.GetString($d).Trim([char]0)
