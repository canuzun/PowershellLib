#https://superuser.com/questions/1258478/how-to-get-ecsda-with-p-256-and-sha256-in-openssl
#https://www.openssl.org/docs/man1.0.2/man1/openssl-dgst.html
$openSslPath = "C:\Enigma-repo\Certificate.Generation.Service\source\lib\openssl-1.1\x64\bin\openssl.exe"
$outputPath = "C:\gfengineering\sign-verify"
$dataFilePath = "$outputPath\data.txt" 
$hashFilePath = "$outputPath\hash.txt"
$sigFilePath = "$outputPath\data.sig"
$sigFileBase64Path = "$outputPath\data.sig.txt"


$keyName = "signPOC"
#create the private key
$keyFilePath = "$outputPath\$keyName.pem"
$arguments = "ecparam -name prime256v1 -genkey -noout -out $keyFilePath"
$output = Start-Process -FilePath $openSslPath -ArgumentList $arguments  -NoNewWindow -Wait 
$output

#extract public part from the private key
$publicKeyFilePath = "$outputPath\$keyName-pub.pem"
$arguments = "ec -in $keyFilePath -pubout -out $publicKeyFilePath"
$output = Start-Process -FilePath $openSslPath -ArgumentList $arguments  -NoNewWindow -Wait 
$output

$dataFilePathExists = Test-Path -Path $dataFilePath
if($true -eq $dataFilePathExists){
    Remove-Item -Path $dataFilePath -Recurse -Force | Out-Null
}
$myContent = "%7b%22ClientFqdn%22%3a%22pc54321.emea.group.grundfos.com%22%2c%22SaveToStatus%22%3atrue%2c%22StatusFieldName%22%3a%22myFieldName%22%2c%22Command%22%3a%22%7b%5c%22CommandType%5c%22%3a%5c%22ChocoInstall%5c%22%2c%5c%22Argument%5c%22%3a%5c%22Get-ItemProperty+HKLM%3a%5c%5c%5c%5cSoftware%5c%5c%5c%5cWow6432Node%5c%5c%5c%5cMicrosoft%5c%5c%5c%5cWindows%5c%5c%5c%5cCurrentVersion%5c%5c%5c%5cUninstall%5c%5c%5c%5c*+%7c+Select-Object+DisplayName%2c+DisplayVersion%2c+Publisher%2c+InstallDate+%7c+Format-Table+-AutoSize%5c%22%7d%22%2c%22Version%22%3a%222.0%22%2c%22Id%22%3a%22314f7c0d-3fad-4879-b2d4-dedddb828810%22%2c%22Type%22%3a%22RemoteCommand%22%2c%22CorrelationId%22%3a%22314f7c0d-3fad-4879-b2d4-dedddb828810%22%2c%22TimestampUtc%22%3a%222021-10-26T11%3a21%3a58.081374%2b00%3a00%22%7d"
Set-Content -Path $dataFilePath -Value $myContent

$arguments = "dgst -sha256 -out $hashFilePath $dataFilePath"
$output = Start-Process -FilePath $openSslPath -ArgumentList $arguments  -NoNewWindow -Wait 
$output

$hash = Get-Content -Path $hashFilePath
$hash = $hash.Substring($hash.LastIndexOf(' ') + 1, $hash.Length - $hash.LastIndexOf(' ') - 1)
Set-Content -Path $hashFilePath -Value $hash

$arguments = "dgst -sha256 -sign $keyFilePath -out $sigFilePath $hashFilePath"
$output = Start-Process -FilePath $openSslPath -ArgumentList $arguments  -NoNewWindow -Wait 
$output

$arguments = "enc -base64 -in $sigFilePath -out $sigFileBase64Path"
$output = Start-Process -FilePath $openSslPath -ArgumentList $arguments  -NoNewWindow -Wait 
$output

Remove-Item -Path $sigFilePath -Recurse -Force | Out-Null
Start-Sleep -Seconds 2

$arguments = "enc -d -base64 -in $sigFileBase64Path -out $sigFilePath"
$output = Start-Process -FilePath $openSslPath -ArgumentList $arguments  -NoNewWindow -Wait 
$output

$arguments = "dgst -sha256 -verify $publicKeyFilePath -signature $sigFilePath $hashFilePath"
$output = Start-Process -FilePath $openSslPath -ArgumentList $arguments  -NoNewWindow -Wait 
$output