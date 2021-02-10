$CertName = "myCert"
$SelfSignedCertificate = New-SelfSignedCertificate -CertStoreLocation cert:\LocalMachine\my -DnsName $CertName -KeyLength 2048 -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider"
$Thumbprint = $SelfSignedCertificate.Thumbprint
Add-Type -AssemblyName System.Web
$PasswordPlainText = [System.Web.Security.Membership]::GeneratePassword(18,6)
$PasswordSecure = ConvertTo-SecureString -String $PasswordPlainText -Force -AsPlainText
$CertLocation = "Cert:\LocalMachine\my\" + $Thumbprint
$ExportPath = "C:\tmp"
$CertFileName = $ExportPath + "\" + $CertName + ".pfx"
Export-PfxCertificate -cert $CertLocation -FilePath $CertFileName -Password $PasswordSecure 
$Content = "Password = $PasswordPlainText` Thumbprint = " + $Thumbprint
$FileName = $ExportPath + "\" + $CertName + "-pw.txt"
$Content | Out-File $FileName
Remove-Item -Path $CertLocation -DeleteKey
