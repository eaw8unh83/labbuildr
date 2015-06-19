﻿<#
.Synopsis

.DESCRIPTION
   import-viprva

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
   https://community.emc.com/blogs/bottk/2014/06/16/announcement-labbuildr-released
.EXAMPLE
#>
[CmdletBinding()]
Param(
[Parameter(ParameterSetName = "defaults", Mandatory = $false)][switch]$Defaults,
[Parameter(ParameterSetName = "defaults", Mandatory=$false)]$viprmaster = "vipr-2.2.1.0.1106",
[Parameter(ParameterSetName = "defaults",Mandatory=$false)][ValidateScript({$_ -match [IPAddress]$_ })][ipaddress]$subnet = "192.168.2.0",
[Parameter(ParameterSetName = "defaults", Mandatory = $false)][ValidateScript({ Test-Path -Path $_ })]$Defaultsfile=".\defaults.xml"
)

$targetname = "vipr1"
$ViprURL = "ftp://ftp.emc.com/ViPR/ViPR_Controller_Download.zip"
$viprmaster = "vipr-2.2.1.0.1106"
Measure-Command {
If ($Defaults.IsPresent)
    {
     $labdefaults = Get-labDefaults
     $vmnet = "vmnet$($labdefaults.vmnet)"
     $subnet = $labdefaults.MySubnet
     $BuildDomain = $labdefaults.BuildDomain
     $Sourcedir = $labdefaults.Sourcedir
     $Defaultgateway = $labdefaults.DefaultGateway
     }

if (!($Sourcedir))
    {
    Write-Warning "we need a Directory for sources specified"
    }

[System.Version]$subnet = $Subnet.ToString()
$Subnet = $Subnet.major.ToString() + "." + $Subnet.Minor + "." + $Subnet.Build
if (!$Defaultgateway)
    {
    $Defaultgateway = "$subnet.9"
    }
if (get-vmx $targetname)
    {
    Write-Warning " the Virtual Machine already exists"
    Break
    }

if ($gateway)
    {
    $defaultgateway = "$subnet.103"
    }
    else
    {
    $defaultgateway = "$subnet.9"
    }

$Disks = ('disk1','disk2','disk5')
$masterpath = "$PSScriptRoot\$viprmaster"
$Missing = @()
foreach ($Disk in $Disks)
    {
    if (!(Test-Path -Path "$masterpath\*$Disk.vmdk"))
        {
        if (!(Test-Path "$Sourcedir\ViPRC*\vipr*controller-1+0.ova"))
            {
            Write-Warning "Vipr OVA Not Found, we try for Zip Package in Sources"
            if (!(Test-Path "$Sourcedir\*vipr*down*.zip"))
                {
                Write-Warning "Vipr Controller Download Package not found
                               we will try download"
                
                $Zippackage = Split-Path -Leaf $ViprURL
                Get-LABFTPFile -Source $ViprURL -Defaultcredentials -Target $Sourcedir\$Zippackage -Verbose
                }
            $Zipfiles = Get-ChildItem "$Sourcedir\*vipr*down*.zip"
            $Zipfiles = $Zipfiles| Sort-Object -Property Name -Descending
		    $LatestZip = $Zipfiles[0].FullName
	        write-verbose "We are going to extract $LatestZip now"    	
            Expand-LABZip -zipfilename $LatestZip -destination $Sourcedir
            }
            $Viprova = Get-ChildItem "$Sourcedir\ViPRC*\vipr*controller-1+0.ova" -ErrorAction SilentlyContinue
            $Viprova = $Viprova| Sort-Object -Property Name -Descending
		    $LatestViprOVA = $Viprova[0].FullName
            $LatestVipr = $Viprova[0].Name.Replace("-controller-1+0.ova","")
            $LatestViprLic = Get-ChildItem -Path "$Sourcedir\ViPRC*\*" -Filter *.lic
            Write-Warning "We found $LatestVipr"
            $masterpath = "$Sourcedir\$LatestVipr"
            if (!$LatestViprOVA)
                { 
                Write-Warning "Could not find any ViprOVA in $Sourcedir to use"
                exit
                }
            
            Write-warning "$Disk not found, deflating ViprDisk from OVA"
            & $global:vmwarepath\7za.exe x "-o$masterpath" -y $LatestViprOVA "*$Disk.vmdk" 
            if (!(Test-Path "$Sourcedir\$LatestVipr\$($LatestViprLic.Name)"))
                {
                Copy-Item $LatestViprLic.FullName -Destination "$masterpath\$($LatestViprLic.Name)" -Force
                }
        }

    }


Write-Warning "importing the disks "

if(!(Test-Path $PSScriptRoot\$targetname))
    {
    New-Item -ItemType Directory $PSScriptRoot\$targetname | Out-Null
    }
foreach ($Disk in $Disks)
    {
    
    $SOURCEDISK = Get-ChildItem -Path "$masterpath\vipr-*$disk.vmdk"
    $TargetDisk = "$PSScriptRoot\$targetname\$Disk.vmdk"
    if (Test-Path $TargetDisk)
        { 
        write-warning "Master $TargetDisk already present, no conversion needed"
        }
    else
        {
        write-warning "converting $TargetDisk"
        & $VMwarepath\vmware-vdiskmanager.exe -r $SOURCEDISK.FullName -t 0 $TargetDisk  2>&1 | Out-Null
        If ($Disk -match "Disk5")
            {
            # will need this for the storageos installer once figure out ovf-env disk :-)
            # & $VMwarepath\vmware-vdiskmanager.exe $PSScriptRoot\$targetname\disk3.vmdk -x 122GB
            }
        }
    }


# & $global:vmwarepath\OVFTool\ovftool.exe --lax --skipManifestCheck  --name=$targetname $masterpath\viprmaster.ovf $PSScriptRoot 
Write-Verbose " Copy base vm config to new master"

Copy-Item $PSScriptRoot\scripts\viprmaster\viprmaster.vmx $targetname\$targetname.vmx
$vmx = get-vmx $targetname
$vmx | Set-VMXTemplate -unprotect
$vmx | Set-VMXNetworkAdapter -Adapter 0 -AdapterType vmxnet3 -ConnectionType custom
$vmx | Set-VMXVnet -Adapter 0 -vnet vmnet2
$vmx | Set-VMXDisplayName -DisplayName $targetname
Write-Verbose "Generating CDROM"

Write-Verbose "Creating OVFenvironment"
$ovfenv = '<?xml version="1.0" encoding="UTF-8"?>
<Environment
     xmlns="http://schemas.dmtf.org/ovf/environment/1"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xmlns:oe="http://schemas.dmtf.org/ovf/environment/1"
     xmlns:ve="http://www.vmware.com/schema/ovfenv"
     oe:id="vipr1"
     ve:vCenterId="vm-21012">
   <PlatformSection>
      <Kind>VMware ESXi</Kind>
      <Version>5.5.0</Version>
      <Vendor>VMware, Inc.</Vendor>
      <Locale>de_DE</Locale>
   </PlatformSection>
   <PropertySection>
         <Property oe:key="network_1_ipaddr" oe:value="'+$subnet+'.9"/>
         <Property oe:key="network_1_ipaddr6" oe:value="::0"/>
         <Property oe:key="network_gateway" oe:value="'+$defaultgateway+'"/>
         <Property oe:key="network_gateway6" oe:value="::0"/>
         <Property oe:key="network_netmask" oe:value="255.255.255.0"/>
         <Property oe:key="network_prefix_length" oe:value="24"/>
         <Property oe:key="network_vip" oe:value="'+$subnet+'.9"/>
         <Property oe:key="network_vip6get" oe:value="::0"/>
         <Property oe:key="node_count" oe:value="1"/>
   </PropertySection>
</Environment>
'

if ($PSCmdlet.MyInvocation.BoundParameters["verbose"].IsPresent)
    {
    Write-Host -ForegroundColor Yellow $ovfenv
    }

<#
$ovfenv = Get-Content $PSScriptRoot\scripts\viprmaster\ovf-env.xml
$ovfenv -replace "192.168.2",$subnet | Set-Content -Path $PSScriptRoot\scripts\viprmaster\cd\ovf-env.xml -Force
#>
$ovfenv  | Set-Content -Path $PSScriptRoot\scripts\viprmaster\cd\ovf-env.xml -Force
convert-VMXdos2unix -Sourcefile $PSScriptRoot\scripts\viprmaster\cd\ovf-env.xml -Verbose
& $Global:vmwarepath\mkisofs.exe -J -R -o "$PSScriptRoot\$Targetname\vipr.iso" $PSScriptRoot\scripts\viprmaster\cd 2>&1 | Out-Null
$config = $vmx | get-vmxconfig
    write-verbose "injecting CDROM"
    $config = $config | where {$_ -NotMatch "ide0:0"}
    $config += 'ide0:0.present = "TRUE"'
    $config += 'ide0:0.fileName = "vipr.iso"'
    $config += 'ide0:0.deviceType = "cdrom-image"'
$Config | set-Content -Path $vmx.config
$vmx | Start-VMX
Write-Host -ForegroundColor Yellow "
Successfully Deployed $viprmaster
wait a view minutes for storageos to be up and running
point your browser to https://vipr1 and follow the wizard steps
The License File can be found in $masterpath
"

}