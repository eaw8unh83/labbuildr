﻿<#
.Synopsis
   .\install-ecs.ps1
.DESCRIPTION
  install-ecs is a vmxtoolkit solutionpack for configuring and deploying emc elastic cloud staorage on centos

      Copyright 2014 Karsten Bott
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at
       http://www.apache.org/licenses/LICENSE-2.0
   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
.LINK
   https://github.com/bottkars/labbuildr/wiki/install-ecs.ps1
.EXAMPLE
#>


[CmdletBinding(DefaultParametersetName = "install")]
Param (
    [Parameter(ParameterSetName = "install", Mandatory = $false)]
    [ValidateSet('Centos7_3_1611')]
    [string]$centos_ver = 'Centos7_3_1611',
    [Parameter(ParameterSetName = "defaults", Mandatory = $false)]
    [Parameter(ParameterSetName = "install", Mandatory = $false)][switch]$Update,
    [Parameter(ParameterSetName = "install", Mandatory = $false)]
    [ValidateRange(1, 1)][int32]$Nodes = 1,
    [Parameter(ParameterSetName = "install", Mandatory = $false)]
    [switch]$rexray,
    [ValidateRange(0, 3)]
    [int]$SCSI_Controller = 0,
    [ValidateRange(1, 3)]
    [int]$SCSI_DISK_COUNT = 3,

    <# Specify your own Class-C Subnet in format xxx.xxx.xxx.xxx #>
    [Parameter(ParameterSetName = "install", Mandatory = $false)]
    [int32]$Startnode = 1,
    [int]$ip_startrange = 244,
    <#
    Size
    'XS'  = 1vCPU, 512MB
    'S'   = 1vCPU, 768MB
    'M'   = 1vCPU, 1024MB
    'L'   = 2vCPU, 2048MB
    'XL'  = 2vCPU, 4096MB 
    'TXL' = 4vCPU, 6144MB
    'XXL' = 4vCPU, 8192MB
    #>
    [ValidateSet('XS', 'S', 'M', 'L', 'XL', 'TXL', 'XXL')]$Size = "XL",
    $Nodeprefix = "ecsnode",
    [Parameter(Mandatory = $false)]
    $Scriptdir = (join-path (Get-Location) "labbuildr-scripts"),
    [Parameter(Mandatory = $false)]
    $Sourcedir = $Global:labdefaults.Sourcedir,
    [Parameter(Mandatory = $false)]
    $DefaultGateway = $Global:labdefaults.DefaultGateway,
    [Parameter(Mandatory = $false)]
    $guestpassword = "Password123!",
    $Rootuser = 'root',
    $Hostkey = $Global:labdefaults.HostKey,
    $Default_Guestuser = 'labbuildr',
    [Parameter(Mandatory = $false)]
    $Subnet = $Global:labdefaults.MySubnet,
    [Parameter(Mandatory = $false)]
    $DNS1 = $Global:labdefaults.DNS1,
    [Parameter(Mandatory = $false)]
    $DNS2 = $Global:labdefaults.DNS2,
    [switch]$Defaults,
    [switch]$vtbit,



    [Parameter(ParameterSetName = "install", Mandatory = $false)][switch]$FullClone,
    [Parameter(ParameterSetName = "install", Mandatory = $false)]
    [ValidateSet('mosaicme')]$PrepareBuckets,
    [Parameter(ParameterSetName = "install", Mandatory = $false)][ValidateSet('8192', '12288', '16384', '20480', '30720', '51200', '65536')]$Memory = "16384",
    [Parameter(ParameterSetName = "install", Mandatory = $false)]
    [ValidateSet('3.0.0.1')]$Branch = '3.0.0.1',
    [switch]$AdjustTimeouts,
    [Parameter(ParameterSetName = "install", Mandatory = $false)][switch]$EMC_ca,
    [Parameter(ParameterSetName = "install", Mandatory = $false)][switch]$uiconfig,
    [Parameter(ParameterSetName = "install", Mandatory = $false)][ValidateSet(150GB, 500GB, 520GB)][uint64]$Disksize = 150GB,

    [Parameter(ParameterSetName = "defaults", Mandatory = $false)]
    [Parameter(ParameterSetName = "install", Mandatory = $False)]
    [ValidateLength(1, 15)][ValidatePattern("^[a-zA-Z0-9][a-zA-Z0-9-]{1,15}[a-zA-Z0-9]+$")][string]$BuildDomain = "labbuildr",
    [Parameter(ParameterSetName = "install", Mandatory = $false)][ValidateSet('vmnet2', 'vmnet3', 'vmnet4', 'vmnet5', 'vmnet6', 'vmnet7', 'vmnet9', 'vmnet10', 'vmnet11', 'vmnet12', 'vmnet13', 'vmnet14', 'vmnet15', 'vmnet16', 'vmnet17', 'vmnet18', 'vmnet19')]$VMnet = $labdefaults.vmnet,
    [Parameter(ParameterSetName = "defaults", Mandatory = $false)][ValidateScript( { Test-Path -Path $_ })]$Defaultsfile = "./defaults.xml",
    [switch]$offline,
    [switch]$pausebeforescript,
    $Custom_IP







)
#requires -version 3.0
#requires -module vmxtoolkit
$latest_ecs = "3.0.0.1"
$Range = "24"
$Start = "1"
$IPOffset = 5
$Szenarioname = "ECS"
$Builddir = $PSScriptRoot
$Masterpath = $Builddir
If ($Defaults.IsPresent) {
    deny-labdefaults
}
try {
    Get-Item -Path $Sourcedir -ErrorAction Stop | Out-Null
}
catch
[System.Management.Automation.DriveNotFoundException] {
    Write-Warning "Make sure to have your Source Stick connected"
    exit
}
catch [System.Management.Automation.ItemNotFoundException] {
    write-warning "no sources directory found at $Sourcedir, please create or select different Directory"
    return
}
try {
    $Masterpath = $LabDefaults.Masterpath
}
catch {
    $Masterpath = $Builddir
}
$Hostkey = $labdefaults.HostKey

if ($LabDefaults.custom_domainsuffix) {
    $custom_domainsuffix = $LabDefaults.custom_domainsuffix
}
else {
    $custom_domainsuffix = "local"
}
if (!$Masterpath) {$Masterpath = $Builddir}
If (!$DNS1 -and !$DNS2) {
    Write-Warning "DNS Server not Set, exiting now"
}
If (!$DNS2 -and $DNS1) {
    $DNS2 = $DNS1
}
If (!$DNS1 -and $DNS2) {
    $DNS1 = $DNS2
}
[System.Version]$subnet = $Subnet.ToString()
$Subnet = $Subnet.major.ToString() + "." + $Subnet.Minor + "." + $Subnet.Build
$DefaultTimezone = "Europe/Berlin"
$Guestpassword = "Password123!"
$Rootuser = "root"
$Rootpassword = "Password123!"
$Guestuser = "$($Szenarioname.ToLower())user"
$Guestpassword = "Password123!"
$Node_requires = @()
$Node_requires = ('git','numactl','libaio','vim')

$repo = "https://github.com/EMCECS/ECS-CommunityEdition.git"
switch ($Branch) {
    "release-2.1" {
        $Docker_imagename = "emccorp/ecs-software-2.1"
        $Docker_image = "ecs-software-2.1"
        $Docker_imagetag = "latest"
        $Git_Branch = $Branch
    }
    "master" {
        $Docker_image = "ecs-software-2.2.1"
        $Docker_imagename = "emccorp/ecs-software-2.2.1"
        $Docker_imagetag = $latest_ecs
        $Git_Branch = $Branch
    }
    "develop" {
        $Docker_image = "ecs-software-3.0.0"
        $Docker_imagename = "emccorp/ecs-software-3.0.0"
        $Docker_imagetag = "latest"
        $Git_Branch = $Branch
    }
    "2.2.1.0" {
        $Docker_image = "ecs-software-2.2.1"
        $Docker_imagename = "emccorp/ecs-software-2.2.1"
        $Docker_imagetag = $Branch
        $Git_Branch = "master"
        #$repo = "https://github.com/bottkars/ECS-CommunityEdition.git"
    }
    "2.2.1.0-a" {
        $Docker_image = "ecs-software-2.2.1"
        $Docker_imagename = "emccorp/ecs-software-2.2.1"
        $Docker_imagetag = $Branch
        $Git_Branch = "master"
    }
    "3.0.0.1" {
        $Docker_image = "ecs-software-3.0.0"
        $Docker_imagename = "emccorp/ecs-software-3.0.0"
        $Docker_imagetag = "3.0.0.1"
        $Git_Branch = "master"
    }
    default {
        $Docker_image = "ecs-software-3.0.0"
        $Docker_imagename = "emccorp/ecs-software-3.0.0"
        $Docker_imagetag = "latest"
        $Git_Branch = "master"
    }
}
$Docker_basepath = Join-Path $Sourcedir "docker"
$Docker_Image_file = Join-Path $Docker_basepath "$($Docker_image)_$Docker_imagetag.tgz"
Write-Verbose "Docker Imagefile $Docker_Image_file"
if (!(test-path $Docker_basepath)) {
    New-Item -ItemType Directory $Docker_basepath -Force -Confirm:$false | Out-Null
}
if ($offline.IsPresent) {
    if (!(Test-Path $Docker_Image_file)) {
        Write-Warning "No offline image $Docker_Image_file present, exit now"
        exit
    }
}
try {
    $OS_Sourcedir = Join-Path $Sourcedir $OS
    $OS_CahcheDir = Join-Path $OS_Sourcedir "cache"
    $yumcachedir = Join-path -Path $OS_CahcheDir "yum"  -ErrorAction stop
}
catch [System.Management.Automation.DriveNotFoundException] {
    write-warning "Sourcedir not found. Stick not inserted ?"
    break
}
Write-Verbose "yumcachedir $yumcachedir"
####Build Machines#
$StopWatch = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($Node in $Startnode..(($Startnode - 1) + $Nodes)) {
    Write-Host -ForegroundColor White "Checking for $Nodeprefix$node"
    $Lab_VMX = ""
    $Lab_VMX = New-LabVMX -CentOS -CentOS_ver $centos_ver -Size $Size -SCSI_DISK_COUNT $SCSI_DISK_COUNT -SCSI_DISK_SIZE $Disksize -VMXname $Nodeprefix$Node -SCSI_Controller $SCSI_Controller -vtbit:$vtbit -memory $Memory -start
    if ($Lab_VMX) {
        $temp_object = New-Object System.Object
        $temp_object | Add-Member -type NoteProperty -name Name -Value $Nodeprefix$Node
        $temp_object | Add-Member -type NoteProperty -name Number -Value $Node
        $machinesBuilt += $temp_object
    }       
    else {
        Write-Warning "Machine $Nodeprefix$Node already exists"
    }
			
}
if ($PSCmdlet.MyInvocation.BoundParameters["verbose"].IsPresent) {
    Write-verbose "Now Pausing"
    pause
}

Write-Host -ForegroundColor White "Starting Node Configuration"

if (!$machinesBuilt) {
    Write-Host -ForegroundColor Yellow "no machines have been built. script only runs on new installs of mesos scenrario"
    break
}

# $Node_requires = $Node_requires -join ","
foreach ($Node in $machinesBuilt) {
    if (!$Custom_IP) {
        $ip_byte = ($ip_startrange + $Node.Number) 
        $ip = "$subnet.$ip_byte"
    }
    else {
        $IP = $Custom_IP
    }
    $ip_byte = ($ip_startrange + $Node.Number)
		
    $Nodeclone = Get-VMX $Node.Name

    Write-Verbose "Configuring Node $($Node.Number) $($Node.Name) with $IP"
    $Hostname = $Nodeclone.vmxname.ToLower()
    $Nodeclone | Set-LabCentosVMX -ip $IP -CentOS_ver $centos_ver -Additional_Packages $Node_requires -Host_Name $Hostname -DNS1 $DNS1 -DNS2 $DNS2 -VMXName $Nodeclone.vmxname
#    $Nodeclone | Set-LabCentosVMX -ip $IP -CentOS_ver $centos_ver -Additional_Packages $Node_requires -Additional_Epel_Packages $Epel_Packages -Host_Name $Hostname -DNS1 $DNS1 -DNS2 $DNS2 -VMXName $Nodeclone.vmxname
    ##### Prepare
    if ($EMC_ca.IsPresent) {
        $files = Get-ChildItem -Path "$Sourcedir\EMC_ca"
        foreach ($File in $files) {
            $NodeClone | copy-VMXfile2guest -Sourcefile $File.FullName -targetfile "/etc/pki/ca-trust/source/anchors/$($File.Name)" -Guestuser $Rootuser -Guestpassword $Guestpassword
        }
        $Scriptblock = "update-ca-trust"
        Write-Verbose $Scriptblock
        $Bashresult = $NodeClone | Invoke-VMXBash -Scriptblock $Scriptblock -Guestuser $Rootuser -Guestpassword $Guestpassword -logfile $Logfile
    }

 #   $Scriptblock = "/usr/bin/easy_install ecscli"
 #   Write-Verbose $Scriptblock
 #   $Bashresult = $NodeClone | Invoke-VMXBash -Scriptblock $Scriptblock -Guestuser $Rootuser -Guestpassword $Guestpassword -logfile $Logfile
    ####### docker path´s
    #Docker_basepath = Join-Path $Sourcedir $Docker
    #Docker_Image_file = Join-Path $Docker_basepath "$($Docker_image)_$Docker_imagetag.tgz"
$Git_Branch = 'develop'
$Scriptblock = "git clone -b $Git_Branch --single-branch $repo"
Write-Verbose $Scriptblock
$Bashresult = $NodeClone | Invoke-VMXBash -Scriptblock $Scriptblock -Guestuser $Rootuser -Guestpassword $Guestpassword -logfile $Logfile


Pause
    ####pause
    Write-Verbose $Docker_Image_file
    if (!(Test-Path $Docker_Image_file) -and !($offline.IsPresent)) {
        New-Item -ItemType Directory $Docker_basepath -ErrorAction SilentlyContinue | Out-Null
        $Scriptblock = "docker pull $($Docker_imagename):$Docker_imagetag"
        Write-Verbose $Scriptblock
        $Bashresult = $NodeClone | Invoke-VMXBash -Scriptblock $Scriptblock -Guestuser $Rootuser -Guestpassword $Guestpassword -logfile $Logfile
        $Scriptblock = "docker save $($Docker_imagename):$Docker_imagetag | gzip -c >  /mnt/hgfs/Sources/docker/$($Docker_image)_$Docker_imagetag.tgz"
        Write-Verbose $Scriptblock
        $Bashresult = $NodeClone | Invoke-VMXBash -Scriptblock $Scriptblock -Guestuser $Rootuser -Guestpassword $Guestpassword # -logfile $Logfile
    }
    else {
        if (!(Test-Path $Docker_Image_file)) {
            Write-Warning "no docker Image available, exiting now ..."
            exit
        }
        [switch]$offline_available = $true
    }
    $Scriptblock = "git clone -b $Git_Branch --single-branch $repo"
    Write-Verbose $Scriptblock
    $Bashresult = $NodeClone | Invoke-VMXBash -Scriptblock $Scriptblock -Guestuser $Rootuser -Guestpassword $Guestpassword -logfile $Logfile
    Write-Host -ForegroundColor Magenta " ==>Installing ECS Singlenode, this may take a while ..."
    if ($pausebeforescript.ispresent) {
        pause
    }
    if ($Branch -ge "2.2.0.1") {
        Write-Host -ForegroundColor white " ==>install ecs with loading docker image"
        $Scriptblock = "cd /ECS-CommunityEdition/ecs-single-node;/usr/bin/sudo -s python /ECS-CommunityEdition/ecs-single-node/step1_ecs_singlenode_install.py --disks $($devices -join " ") --ethadapter eno16777984 --hostname $hostname --imagename $Docker_imagename --imagetag $Docker_imagetag --load-image /mnt/hgfs/Sources/docker/$($Docker_image)_$Docker_imagetag.tgz"# &> /tmp/ecsinst_step1.log"
    }
    else {
        $Scriptblock = "cd /ECS-CommunityEdition/ecs-single-node;/usr/bin/sudo -s python /ECS-CommunityEdition/ecs-single-node/step1_ecs_singlenode_install.py --disks $($devices -join " ") --ethadapter eno16777984 --hostname $hostname"#  &> /tmp/ecsinst_step1.log"
    }
    $Bashresult = $NodeClone | Invoke-VMXBash -Scriptblock $Scriptblock -Guestuser $Guestuser -Guestpassword $Guestpassword -logfile $Logfile
    Write-Host -ForegroundColor Magenta " ==>Setting automatic startup of docker and ecs container"
    $Scriptlets = (
        "systemctl enable docker.service",
        #"echo 'docker start ecsstandalone' `>>/etc/rc.local",
        "cat > /etc/systemd/system/docker-ecsstandalone.service <<EOF
[Unit]`
Description=EMC ECS Standalone Container`
Requires=docker.service`
After=docker.service`
[Service]`
Restart=always`
ExecStart=/usr/bin/docker start -a ecsstandalone`
ExecStop=/usr/bin/docker stop -t 2 ecsstandalone`
[Install]`
WantedBy=default.target`
",
        "systemctl daemon-reload",
        "systemctl enable docker-ecsstandalone",
        "systemctl start docker-ecsstandalone"
    )
    #'chmod +x /etc/rc.d/rc.local')
    #>
    foreach ($Scriptblock in $Scriptlets) {
        Write-Verbose $Scriptblock
        $Bashresult = $NodeClone | Invoke-VMXBash -Scriptblock $Scriptblock -Guestuser $Rootuser -Guestpassword $Guestpassword
    }
}
if ($uiconfig.ispresent) {
    Write-Warning "Please wait up to 5 Minutes and Connect to https://$($ip):443
Use root:ChangeMe for Login
"
}
else {
    Write-Host -ForegroundColor White "Starting ECS Install Step 2 for creation of Datacenters and Containers.
This might take up to 45 Minutes
Approx. 2000 Objects are to be created
you may chek the opject count with your bowser at http://$($IP):9101"
    # $Logfile =  "/tmp/ecsinst_Step2.log"
    #$Scriptblock = "/usr/bin/sudo -s python /ECS-CommunityEdition/ecs-single-node/step2_object_provisioning.py --ECSNodes=$IP --Namespace=$($BuildDomain)ns1 --ObjectVArray=$($BuildDomain)OVA1 --ObjectVPool=$($BuildDomain)OVP1 --UserName=$Guestuser --DataStoreName=$($BuildDomain)ds1 --VDCName=vdc1 --MethodName= &> /tmp/ecsinst_step2.log"
    # curl --insecure https://192.168.2.211:443

    Write-Host -ForegroundColor White "waiting for Webserver to accept logins"
    $Scriptblock = "curl -i -k https://$($ip):4443/login -u root:ChangeMe"
    Write-verbose $Scriptblock
    $Bashresult = $NodeClone | Invoke-VMXBash -Scriptblock $Scriptblock -Guestuser $Guestuser -Guestpassword $Guestpassword -Confirm:$false -SleepSec 60
    if ($AdjustTimeouts.isPresent) {
        Write-Host -ForegroundColor Gray " ==>Adjusting Timeouts"
        $Scriptblock = "/usr/bin/sudo -s sed -i -e 's\30, 60, InsertVDC\300, 300, InsertVDC\g' /ECS-CommunityEdition/ecs-single-node/step2_object_provisioning.py"
        Write-verbose $Scriptblock
        $Bashresult = $NodeClone | Invoke-VMXBash -Scriptblock $Scriptblock -Guestuser $Guestuser -Guestpassword $Guestpassword -logfile $Logfile   # -Confirm:$false -SleepSec 60
    }
    <#
if ($Branch -eq "feature-ecs-2.2")
    {
    $Methods = ('UploadLicense','CreateObjectVarray','InsertVDC','CreateObjectVpool','CreateNamespace')
    }
else
    {
    #>
    $Methods = ('UploadLicense', 'CreateObjectVarray', 'CreateDataStore', 'InsertVDC', 'CreateObjectVpool', 'CreateNamespace')
    $Namespace_Name = "ns1"
    $Pool_Name = "Pool_$Node"
    $Replicaton_Group_Name = "RG_1"
    $Datastore_Name = "DS1"
    $VDC_NAME = "VDC_$Node"
    foreach ( $Method in $Methods ) {
        Write-Host -ForegroundColor Gray " ==>running Method $Method, monitor tail -f /var/log/vipr/emcvipr-object/ssm.log"
        $Scriptblock = "cd /ECS-CommunityEdition/ecs-single-node;/usr/bin/sudo -s python /ECS-CommunityEdition/ecs-single-node/step2_object_provisioning.py --ECSNodes=$IP --Namespace=$Namespace_Name --ObjectVArray=$Pool_Name --ObjectVPool=$Replicaton_Group_Name --UserName=$Guestuser --DataStoreName=$Datastore_Name --VDCName=$VDC_NAME --MethodName=$Method"
        Write-verbose $Scriptblock
        $Bashresult = $NodeClone | Invoke-VMXBash -Scriptblock $Scriptblock -Guestuser $Guestuser -Guestpassword $Guestpassword -logfile $Logfile
    }
    $Method = 'CreateUser'
    Write-Host -ForegroundColor Gray " ==>running Method $Method"
    $Scriptblock = "cd /ECS-CommunityEdition/ecs-single-node;/usr/bin/sudo -s python /ECS-CommunityEdition/ecs-single-node/step2_object_provisioning.py --ECSNodes=$IP --Namespace=$Namespace_Name --ObjectVArray=$Pool_Name --ObjectVPool=$Replicaton_Group_Name --UserName=$Guestuser --DataStoreName=$Datastore_Name --VDCName=$VDC_NAME --MethodName=$Method;exit 0"
    Write-verbose $Scriptblock
    $Bashresult = $NodeClone | Invoke-VMXBash -Scriptblock $Scriptblock -Guestuser $Guestuser -Guestpassword $Guestpassword -logfile $Logfile
    if ("mosaicme" -in $PrepareBuckets) {
        $Method = 'CreateUser'
        Write-Host -ForegroundColor Gray " ==>running Method $Method"
        $Scriptblock = "cd /ECS-CommunityEdition/ecs-single-node;/usr/bin/sudo -s python /ECS-CommunityEdition/ecs-single-node/step2_object_provisioning.py --ECSNodes=$IP --Namespace=$Namespace_Name --ObjectVArray=$Pool_Name --ObjectVPool=$Replicaton_Group_Name --UserName=mosaicme --DataStoreName=$Datastore_Name --VDCName=$VDC_NAME --MethodName=$Method;exit 0"
        Write-verbose $Scriptblock
        $Bashresult = $NodeClone | Invoke-VMXBash -Scriptblock $Scriptblock -Guestuser $Guestuser -Guestpassword $Guestpassword -logfile $Logfile
    }
    $Method = 'CreateSecretKey'
    Write-Host -ForegroundColor Gray " ==>running Method $Method"
    $Scriptblock = "/usr/bin/sudo -s python /ECS-CommunityEdition/ecs-single-node/step2_object_provisioning.py --ECSNodes=$IP --Namespace=$Namespace_Name --ObjectVArray=$Pool_Name --ObjectVPool=$Replicaton_Group_Name --UserName=$Guestuser --DataStoreName=$Datastore_Name --VDCName=$VDC_NAME --MethodName=$Method"
    Write-verbose $Scriptblock
    $Bashresult = $NodeClone | Invoke-VMXBash -Scriptblock $Scriptblock -Guestuser $Guestuser -Guestpassword $Guestpassword -logfile $Logfile
}
$StopWatch.Stop()
Write-host -ForegroundColor White "ECS Deployment took $($StopWatch.Elapsed.ToString())"
Write-Host -ForegroundColor White "Success !? Browse to https://$($IP):443 and login with root/ChangeMe"