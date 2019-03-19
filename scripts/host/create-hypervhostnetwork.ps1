
Write-Host "Hello from $env:COMPUTERNAME"
Write-Host "create-hypervhostnetwork.ps1 called"

#Need to inherit from parent session and push to parent. How to do that?
# if ($null -eq $ENV:pw) {
#     $c = Get-Credential -UserName "$ENV:USERDOMAIN\$ENV:USERNAME" -Message "Storing you username/pw in this session for saving vagrant from prompting for it on every UP."
#     $ENV:UN = "$ENV:USERDOMAIN\$ENV:USERNAME"
#     $ENV:PW = $c.GetNetworkCredential().Password
# }


############  Default switch has to be massaged: #############
Write-Host "Testing if the Default Switch exists"
$defaultAdapter = Get-Netadapter | Where-Object -Property Name -like "*Default Switch*"
if ($null -eq $defaultAdapter) {
    Write-Error "No Hyper-v switch 'Default Switch' is found. Restart the computer `
    to recreate the default swithc and try again."
}
else { Write-Host "Default switch already exists" }

Write-Host "Default Switch found. Enabling and disabling the Hyper-v switch to ensure it is functional"
$defaultAdapter | Disable-NetAdapter -Confirm:$false
$defaultAdapter | Enable-NetAdapter
Get-NetAdapterBinding -Name "vEthernet (Default Switch)" -DisplayName "File and Printer Sharing for Microsoft Networks" | Disable-NetAdapterBinding
Get-NetAdapterBinding -Name "vEthernet (Default Switch)" -DisplayName "File and Printer Sharing for Microsoft Networks" | Enable-NetAdapterBinding

Write-Host "Setting connection profile to private for Default switch"

#Problem paa Peters maskine
Get-NetConnectionProfile -InterfaceIndex $defaultAdapter.ifIndex | Set-NetConnectionProfile -NetworkCategory Private
Write-Host "Default switch config complete."


############  SMB 3.0 is needed for shares: #############
Write-host "Checking for SMB 3.0 enabled"
$smb = Get-WindowsOptionalFeature -Online | Where-Object {$_.FeatureName -like "SmbDirect"}
if ($null -eq $smb) {
    Write-Host "SMB 3.0 not found. Installing it"
    Enable-WindowsOptionalFeature -Online -FeatureName SmbDirect
    Write-Host "SMB 3.0 is now enabled"
}
else { Write-Host "SMB3.0 is already enabled - continuing"}


############  Hyper-v VagrantNatSwitch: #############
Write-Host "Creating new NAT Hyper-V network on your host, if it does not already exist"
$switchName = "VagrantNatSwitch"
$natSwitch = Get-VMSwitch | Where-Object -Property Name -like "*$switchName*"
if ($null -eq $natSwitch) {
    Write-Output "No Hyper-v switch VagrantNatSwitch is found. Creating one."
    New-VMSwitch -SwitchName $switchName -SwitchType Internal
    $adapter = Get-NetAdapter | Where-Object -Property InterfaceAlias -like "*$switchName*"
    New-NetIPAddress -IPAddress 192.168.10.1 -PrefixLength 24 -InterfaceIndex $adapter.ifIndex
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses ("1.0.0.1", "192.168.1.26")
    Get-NetConnectionProfile -InterfaceIndex $adapter.ifIndex | Set-NetConnectionProfile -NetworkCategory Private
    Write-Output "New Hyper-v Vagrant nat switch $switchName is created"
}
else {
    Write-Output "Hyper-v switch $switchName already exists - continuing"
}


############  Vagrant Nat network: #############
Write-Host "Looking for the VagrantNatNetwork on this machine"
$natnetworks = Get-NetNat | Where-Object -Property Name -like "*VagrantNatNetwork*"
if ($null -eq $natnetworks) {
    Write-Output "No netnat is found. Creating the VagrantNatNetwork"
    New-NetNat -Name "VagrantNatNetwork" -InternalIPInterfaceAddressPrefix 192.168.10.0/24
    Write-Output "New vagrant NAT network has been created"
}
else {
    Write-Output "Vagrant NAT network already exists - continuing"
}