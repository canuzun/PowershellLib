#Get-AzVMImagePublisher -Location 'West Europe' | Select PublisherName
#Get-AzVMImageOffer -Location 'West Europe' -PublisherName 'MicrosoftWindowsServer' | Select Offer
#Get-AzVMImageSku -Location 'West Europe' -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' | Select Skus
##
##

param(
$location,
$resourceGroupName,
$vmName,
$type,
$vmUsername,
$vmPw,
$stopVM
)

#& 'C:\GitHub-repo\PowershellLib\AzureNewVM.ps1' "North Europe" GF-RG-NutShell-T-TestClients vm-wsql1 winsql2019 cuzun 0MMz!Q4J2gD5 False
# $location = "North Europe"
# $resourceGroupName = "GF-RG-NutShell-T-TestClients"
# $vmName = "vm-winsqlt1"
# $type = "winsql2019"
# $stopVM = $false
# $vmUsername = "cuzun"
# $vmPw = "0MMz!Q4J2gD5"

if($type -ne "win10" -and $type -ne "ubuntu" -and $type -ne "win7" -and $type -ne "server2016" -and $type -ne "server2019" -and $type -ne "winsql2019")
{
    Write-Host "Invalid type" : $type
    return
}

$stopWatch = new-object system.diagnostics.stopwatch
$stopWatch.Start()

Write-Host "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] : Starting"
#Get-AzSubscription

$vMSize = "Standard_D2"
if($type -eq "server2016" -or $type -ne "server2019")
{
    $vMSize = "Standard_D4s_v3"
}
$sshPublicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAmd4bua7IyxR+zAD9Xn6B99A7kbkDqK5jelxAr2lgAC61koCO/0PEXKt4wcsV99WErZGabGIOVNrwzudOHqlLUNkBXzC86UjUPH5Yn+xH3t9JEx18Jyq98LxqITz5hmI+fp2OPtjY+gmr0L+I+gYi05O8ojQZk3P0bJHx8mwyWrUpG/PPS/YJrOzm0d33sVd6If77FvqTFtc0jnx02GGY23Bl0pRkS7NH1mdwOUT+cnYyaacBAiwHVgSabyzlzJtqgiGSZ48GPiFgh4AwER0qStQ14jF4jdPJnIngQ00pcG3oOvG4ViQg+tiXJMpCmJ6biUQqOor7p4Pzb+uAMVeLHw== $vmUsername@$vmName"
$randomText = [guid]::NewGuid().ToString().Substring(0,4)
$securePw = ConvertTo-SecureString $vmPw -AsPlainText -Force
$vmCredentials = New-Object System.Management.Automation.PSCredential ($vmUsername, $securePw)

$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if($null -eq $resourceGroup)
{
    Write-Host "Resource Group not found, creating RG :" $resourceGroupName
    $resourceGroup = New-AzResourceGroup -Name $resourceGroupName -Location $location -ErrorAction Stop
}

$networkName = $resourceGroupName+"-vnet"
$vnet = Get-AzVirtualNetwork -Name $networkName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
if($null -eq $vnet)
{
    $ip1 = Get-Random -Minimum 1 -Maximum 240
    $ip2 = Get-Random -Minimum 1 -Maximum 240
    $addressPrefix = "10.$ip1.$ip2.0/24"
    $subnetPrefix = "10.$ip1.$ip2.0/27"
    $subnet = New-AzVirtualNetworkSubnetConfig -Name "default" -AddressPrefix $subnetPrefix -ErrorAction Stop
    $vnet = New-AzVirtualNetwork -Name $networkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $addressPrefix -Subnet $subnet -ErrorAction Stop
}
$subnet = $vnet.Subnets.Where({$_.Name -eq "default"})

$networkSecurityGroupName = $resourceGroupName+"-nsg"
$nsg = Get-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
if($null -eq $nsg)
{
    $sshRule = New-AzNetworkSecurityRuleConfig -Name ssh-rule -Description "Allow SSH" -Access Allow -Protocol Tcp -Direction Inbound -Priority 101 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -ErrorAction Stop
    $rdpRule = New-AzNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 102 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -ErrorAction Stop
    $nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $sshRule,$rdpRule -ErrorAction Stop
}

$publicIPAddressName = $vmName+"-pubip-"+$randomText
$publicIP = New-AzPublicIpAddress -Name $publicIPAddressName -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Dynamic -DomainNameLabel $vmName -ErrorAction Stop

$nicName = $vmName+"-ni-"+$randomText
$nic = New-AzNetworkInterface -Name $nicName -ResourceGroupName $resourceGroupName -Location $location -SubnetId $subnet.Id -PublicIpAddressId $publicIP.Id -NetworkSecurityGroupId $nsg.Id -ErrorAction Stop

$vm = New-AzVMConfig -VMName $vmName -VMSize $vMSize -ErrorAction Stop
if($type -eq "win10")
{
    #https://docs.microsoft.com/en-us/azure/marketplace/cloud-partner-portal/virtual-machine/cpp-winrm-over-https
    #Enter-PSSession -ComputerName vm-ns-winrm1 --> check how this works w/o username & pw. Maybe same user and same pw issue?
    $vm = Set-AzVMOperatingSystem -VM $vm -Windows -ComputerName $vmName -Credential $vmCredentials -EnableAutoUpdate -TimeZone "Romance Standard Time" -WinRMHttp
    $vm = Set-AzVMSourceImage -VM $vm -PublisherName "MicrosoftWindowsDesktop" -Offer "Windows-10" -Skus "19h1-pron" -Version "latest"
}
elseif($type -eq "win7")
{
    $vm = Set-AzVMOperatingSystem -VM $vm -Windows -ComputerName $vmName -Credential $vmCredentials -EnableAutoUpdate -TimeZone "Romance Standard Time"
    $vm = Set-AzVMSourceImage -VM $vm -PublisherName "MicrosoftWindowsDesktop" -Offer "windows-7" -Skus "win7-enterprise" -Version "latest"
}
elseif($type -eq "ubuntu")
{
    #https://docs.microsoft.com/en-us/azure/virtual-machines/linux/cli-ps-findimage
    $vm = Set-AzVMOperatingSystem -Linux -VM $vm -ComputerName $vmName -Credential $vmCredentials -DisablePasswordAuthentication
    $vm = Set-AzVMSourceImage -VM $vm -PublisherName "Canonical" -Offer "UbuntuServer" -Skus "18.04-LTS" -Version "latest"    
    Add-AzVMSshPublicKey -VM $vm -KeyData $sshPublicKey -Path "/home/$vmusername/.ssh/authorized_keys"
    #sudo timedatectl set-timezone Europe/Copenhagen
}
elseif($type -eq "server2016")
{
    $vm = Set-AzVMOperatingSystem -VM $vm -Windows -ComputerName $vmName -Credential $vmCredentials -EnableAutoUpdate -TimeZone "Romance Standard Time"
    $vm = Set-AzVMSourceImage -VM $vm -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus "2016-Datacenter" -Version "latest"
}
elseif($type -eq "server2019")
{
    $vm = Set-AzVMOperatingSystem -VM $vm -Windows -ComputerName $vmName -Credential $vmCredentials -EnableAutoUpdate -TimeZone "Romance Standard Time"
    $vm = Set-AzVMSourceImage -VM $vm -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus "2019-Datacenter" -Version "latest"
}
elseif($type -eq "winsql2019")
{
    $vm = Set-AzVMOperatingSystem -VM $vm -Windows -ComputerName $vmName -Credential $vmCredentials -EnableAutoUpdate -TimeZone "Romance Standard Time"
    $vm = Set-AzVMSourceImage -VM $vm -PublisherName "microsoftsqlserver" -Offer "sql2019-ws2019" -Skus "sqldev" -Version "latest"
    
}

$vm = Set-AzVMBootDiagnostic -VM $vm -Disable
$vm = Add-AzVMNetworkInterface -VM $vm -Id $nic.Id
$osDiskName = $vmName+"-osdisk-ssd"
$vm = Set-AzVMOSDisk -VM $vm -Name $osDiskName -StorageAccountType StandardSSD_LRS -CreateOption FromImage

New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vm -ErrorAction Stop

$vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
#Configure autoshutdown
$autoShutdownProp = @{}
$autoShutdownProp.Add('status', 'Enabled')
$autoShutdownProp.Add('taskType', 'ComputeVmShutdownTask')
$autoShutdownProp.Add('dailyRecurrence', @{'time'= "1600"})
$autoShutdownProp.Add('timeZoneId', "Romance Standard Time")
$autoShutdownProp.Add('notificationSettings', @{status='Disabled'; timeInMinutes=15})
$autoShutdownProp.Add('targetResourceId', $vm.Id)

$scheduledShutdownResourceId = $vm.Id.Replace("Microsoft.Compute", "microsoft.devtestlab").Replace("virtualMachines", "schedules").Replace($vmName,"shutdown-computevm-"+$vmName)
New-AzResource -Location $location -ResourceId $scheduledShutdownResourceId -Properties $autoShutdownProp -Force -ErrorAction Stop

if($stopVM -eq $true)
{
	#Stop VM to be started when needed.
	Stop-AzVM -Name $vmName -ResourceGroupName $resourceGroupName -Force
}

Write-Host "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] : All done"
$fqdn = $publicIP.DnsSettings.Fqdn
Write-Host "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] : Connect and change the world! -> " $vmUsername@$fqdn
$stopWatch.Stop()
Write-Host "Time Elapsed :" $stopWatch.Elapsed