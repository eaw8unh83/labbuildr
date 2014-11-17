<#
.Synopsis
   labbuildr allows you to create Virtual Machines with VMware Workstation from Predefined Scenarios.
   Scenarios include Exchange 2013, SQL, Hyper-V, SCVMM, SCaleIO, OneFS
.DESCRIPTION
   labbuildr is a Self Installing Windows/Networker/NMM Environemnt Supporting Exchange 2013 and NMM 3.0
.LINK
   https://community.emc.com/blogs/bottk/2014/06/16/announcement-labbuildr-released
.EXAMPLE
    labbuildr.ps1 -action createshortcut
    Creates a Desktop SHortcut for labbuildr
.EXAMPLE
    labbuildr.ps1 -HyperV -HyperVNodes 3 -Cluster -ScaleIO -ScaleioDisks 3 -Gateway -Master vNextevalMaster -savedefaults -defaults -BuildDomain labbuildr
    installs a Hyper-V Cluster with 3 Nodes, ScaleIO MDM, SDS,SDC deployed
.EXAMPLE
   labbuildr.ps1 -AlwaysOn -AAGNodes 2 -SQLVER SQL2014
   Installs  a Always 2 Node Deployment with SQL2014
.EXAMPLE
    labbuildr -[scenario] -Driveletter F -Noautomount
    Installing with Sources extracted to USB Drive f:\Soures
    There was a demand for locating the Sources to an external drive without using a VHD. The Combination of Above switches allows for it
#>


[CmdletBinding(DefaultParametersetName = "action")]
param (
    <#
    Installs only a Domain Controller. Domaincontroller normally is installed automatically durin a Scenario Setup
    IP-Addresses: .10
    #>	
	[Parameter(ParameterSetName = "DConly")][switch]$DConly,	
    <#
    Selects the Always On Scenario
    IP-Addresses: .160 - .169
    #>
	[Parameter(ParameterSetName = "AAG")][switch]$AlwaysOn,
    <#
    Selects the Hyper-V Scenario
    IP-Addresses: .150 - .159
    #>
	[Parameter(ParameterSetName = "Hyperv")][switch]$HyperV,
    <# 
    Exchange Scenario: Installs a Standalone or DAG Exchange 2013 Installation.
    IP-Addresses: .110 - .119
    #>
	[Parameter(ParameterSetName = "Exchange")][switch]$Exchange,
    <#
    Selects the SQL Scenario
    IP-Addresses: .190
    #>
	[Parameter(ParameterSetName = "SQL")][switch]$SQL,
    <#
    Specify if Networker Scenario sould be installed
    IP-Addresses: .103
    #>
    [Parameter(ParameterSetName = "NWserver", Mandatory = $false)]
	[switch]$NWServer,
    <#
    Installs Isilon Nodes
    IP-Addresses: .40 - .56
    #>
	[Parameter(ParameterSetName = "Isilon")]
    [switch]$Isilon,
    <#
    Selects the Storage Spaces Scenario, still work in progress
    IP-Addresses: .170 - .179
    #>
	[Parameter(ParameterSetName = "Spaces")][switch]$Spaces,

    <#
    Selects the Blank Nodes Scenario
    IP-Addresses: .180 - .189
    #>
	[Parameter(ParameterSetName = "Blanknodes")][switch]$Blanknode,
    <#
    Selects the SOFS Scenario
    IP-Addresses: .210 - .219
    #>
    [Parameter(ParameterSetName = "SOFS")][switch]$SOFS,
    
   	<#
    Valid Parameters:
    'MountSource','RemoveAll','update','version','StartAll','StopAll','PauseAll','SuspendAll','UnpauseAll','suspend-vmx','remove-vmx','start-vmx','pause-vmx','list-deployed','list-running'
    #>
	[Parameter(ParameterSetName = "action", HelpMessage = "Specific actions to Control VM´s deployed by labbuildr")][ValidateSet('get-vmxinfo', 'get-vmx','get-vmxconfig','get-vmxsize','createshortcut', 'TestDomain','set-vmxsize','RemoveAll', 'update', 'version', 'StartAll', 'StopAll', 'stop-vmx', 'PauseAll', 'SuspendAll', 'UnpauseAll', 'suspend-vmx', 'remove-vmx', 'start-vmx', 'pause-vmx', 'list-deployed','list-templates','list-running')]$action = "version",
    <# 
    Specify a list of VM´s vor remove-vmx, suspend-vmx, start-vmx, stop-vmx, pause-vm
    #>	
    [Parameter(ParameterSetName = "action", Mandatory = $false)]$vmxlist,
	


    #### scenario options #####
    <#
    Determines if Exchange should be installed in a DAG
    #>
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)][switch]$DAG,
    <# Specify the Number of Exchange Nodes#>
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)][ValidateRange(1, 10)][int]$EXNodes = "1",
    <# Specify the Starting exchange Node#>
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)][ValidateRange(1, 9)][int]$EXStartNode = "1",
	<#
    Determines Exchange CU Version to be Installed
    Valid Versions are:
    'cu1','cu2','cu3','cu4','sp1','cu6'
    Default is SP1
    #>
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[ValidateSet('cu1', 'cu2', 'cu3', 'sp1','cu5','cu6')]$ex_cu = "cu6",
    <# schould we prestage users ? #>	
    [Parameter(ParameterSetName = "Exchange", Mandatory = $false)][switch]$nouser,
    <# Install a DAG without Management IP Address ? #>
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)][switch]$DAGNOIP,
    <# Specify Number of Spaces Hosts #>
    [Parameter(ParameterSetName = "Spaces", Mandatory = $false)][ValidateRange(1, 2)][int]$SpaceNodes = "1",


    <# Specify Number of Hyper-V Hosts #>
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)][ValidateRange(1, 9)][int][alias('hvnodes')]$HyperVNodes = "1",
	<# ScaleIO on hyper-v #>	
    [Parameter(ParameterSetName = "Hyperv", Mandatory = $false)][switch]$ScaleIO,
    <# Number of additional 100GB Disks for ScaleIO. The disk will be made ready for ScaleIO usage in Guest OS#>	
    [Parameter(ParameterSetName = "Hyperv", Mandatory = $false)][ValidateRange(1, 6)][int]$ScaleioDisks,
    <# SCVMM on last Node ? #>	
    [Parameter(ParameterSetName = "Hyperv", Mandatory = $false)][switch]$SCVMM,
    <# Starting Node for Blank Nodes#>
    [Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)][ValidateRange(1, 9)]$Blankstart = "1",
    <# How many Blank Nodes#>
	[Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)][ValidateRange(1, 10)]$BlankNodes = "1",



    <# How many SOFS Nodes#>
    [Parameter(ParameterSetName = "SOFS", Mandatory = $false)][ValidateRange(1, 10)]$SOFSNODES = "1",
    <# Starting Node for SOFS#>
    [Parameter(ParameterSetName = "SOFS", Mandatory = $false)][ValidateRange(1, 9)]$SOFSSTART = "1",  

 	

    <#
    Enable the default gateway 
    .103 will be set as default gateway, NWserver will have 2 Nics, NIC2 Pointing to NAT servibg as Gateway
    #>
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)]
	[Parameter(ParameterSetName = "DConly", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
	[Parameter(ParameterSetName = "Isilon", Mandatory = $false)]
    [Parameter(ParameterSetName = "NWserver", Mandatory = $false)]
    [Parameter(ParameterSetName = "SOFS", Mandatory = $false)]
    [switch]$Gateway,

    <# Specify the Number of Always On Nodes#>
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)][ValidateRange(1, 5)][int]$AAGNodes = "2",
    <#
    'SQL2012SP1', 'SQL2014'
    SQL version to be installed
    Needs to have:
    [sources]\SQL2012SP1 or
    [sources]\SQL2014
    #>
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[ValidateSet('SQL2012SP1', 'SQL2014')]$SQLVER = "SQL2014",
    <# Wich version of OS Master should be installed
    '2012R2U1MASTER','2012R2MASTER','2012R2UMASTER','2012MASTER','2012R2UEFIMASTER','vNextevalMaster','9867_RELEASE_SERVER'
    #>
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
    [Parameter(ParameterSetName = "DConly", Mandatory = $false)]
    [Parameter(ParameterSetName = "NWserver", Mandatory = $false)]
    [Parameter(ParameterSetName = "SOFS", Mandatory = $false)]
    [ValidateSet('2012R2U1MASTER','2012R2MASTER','2012R2UMASTER','2012MASTER','2012R2UEFIMASTER','vNextevalMaster','9867_RELEASE_SERVER')]$Master,
     <# select vmnet, number from 1 to 19#>                                        	
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
    [Parameter(ParameterSetName = "DConly", Mandatory = $false)]
    [Parameter(ParameterSetName = "NWserver", Mandatory = $false)]
    [Parameter(ParameterSetName = "SOFS", Mandatory = $false)]
    [Parameter(Mandatory = $false, HelpMessage = "Enter a valid VMware network Number vmnet between 1 and 19 ")]
	[ValidateRange(2, 19)]$VMnet = 2,
	


<# This stores the defaul config in defaults.xml#>
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)]
	[Parameter(ParameterSetName = "NWserver", Mandatory = $false)]
    [Parameter(ParameterSetName = "DConly", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
	[switch]$savedefaults,

<# reads the Default Config from defaults.xml
<config>
<nmm_ver>nmm82</nmm_ver>
<nw_ver>nw82</nw_ver>
<master>2012R2UEFIMASTER</master>
<sqlver>SQL2014</sqlver>
<ex_cu>cu6</ex_cu>
<vmnet>2</vmnet>
<BuildDomain>labbuildr</BuildDomain>
<MySubnet>10.10.0.0</MySubnet>
<AddressFamily>IPv4</AddressFamily>
<IPV6Prefix>FD00::</IPV6Prefix>
<IPv6PrefixLength>8</IPv6PrefixLength>
<NoAutomount>False</NoAutomount>
</config>
#>
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)]
	[Parameter(ParameterSetName = "NWserver", Mandatory = $false)]
    [Parameter(ParameterSetName = "DConly", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
   	[Parameter(ParameterSetName = "Isilon")]
    [Parameter(ParameterSetName = "SOFS", Mandatory = $false)]
	[switch]$defaults,
	

	
<# Specify if Machines should be Clustered, valid for Hyper-V and Blanknodes Scenario  #>
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)]
	[switch]$Cluster,

<# Wich ISIMASTER to Pick #>
    [Parameter(ParameterSetName = "Isilon")]
	[ValidateRange(2, 16)]$isi_nodes = 2,
   	[Parameter(ParameterSetName = "Isilon")]
	[ValidateSet('b.7.1.1.84r.vga','b.7.2.0.beta1.10r.vga','ISIMASTER')]$ISIMaster,


	
<#
Machine Sizes
'XS'  = 1vCPU, 512MB
'S'   = 1vCPU, 768MB
'M'   = 1vCPU, 1024MB
'L'   = 2vCPU, 2048MB
'XL'  = 2vCPU, 4096MB 
'XXL' = 4vCPU, 6144MB
'XXXL' = 4vCPU, 8192MB
#>
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)]
	[Parameter(ParameterSetName = "DConly", Mandatory = $false)]
	[Parameter(ParameterSetName = "Spaces", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
    [Parameter(ParameterSetName = "NWserver", Mandatory = $false)]
	[Parameter(ParameterSetName = "action", Mandatory = $false)]
    [Parameter(ParameterSetName = "SOFS", Mandatory = $false)]
	[ValidateSet('XS', 'S', 'M', 'L', 'XL', 'XXL')]$Size = "M",
	
	
<# Specify your own Domain name#>
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)]
	[Parameter(ParameterSetName = "DConly", Mandatory = $false)]
    [Parameter(ParameterSetName = "NWserver", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
    [Parameter(ParameterSetName = "SOFS", Mandatory = $false)]
	[ValidatePATTERN("[a-zA-Z]")][string]$BuildDomain,
	
<# Turn this one on if you would like to install a Hypervisor inside a VM #>
	[Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)]
	[switch]$VTbit,
		
####networker 	
    <# install Networker Modules for Microsoft #>
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
    [Parameter(ParameterSetName = "SOFS", Mandatory = $false)]
	[switch]$NMM,
    <#
Version Of Networker Modules
'nmm300','nmm301','nmm2012','nmm3012','nmm82'
#>
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
    [Parameter(ParameterSetName = "SOFS", Mandatory = $false)]
	[ValidateSet('nmm300', 'nmm301', 'nmm2012', 'nmm3012', 'nmm82')]$nmm_ver = "nmm82",
	
<# Indicates to install Networker Server with Scenario #>
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)]
	[Parameter(ParameterSetName = "DConly", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
    [Parameter(ParameterSetName = "SOFS", Mandatory = $false)]
	[Parameter(ParameterSetName = "Isilon")]
	[switch]$NW,
    <#
Version Of Networker Server / Client to be installed
'nw811','nw81','nw8102','nw8102','nw8104','nw8105','nw8112','nw8113','nw8114','nw8115','nw8116','nw82','nwunknown'
mus be extracted to [sourcesdir]\[nw_ver], ex. c:\sources\nw82
#>
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
	[Parameter(ParameterSetName = "DConly", Mandatory = $false)]
    [Parameter(ParameterSetName = "NWserver", Mandatory = $false)]
    [Parameter(ParameterSetName = "SOFS", Mandatory = $false)]
    [ValidateSet('nw8116','nw8115','nw8114', 'nw8113', 'nw811', 'nw81', 'nw8102', 'nw8102', 'nw8104', 'nw8105', 'nw8112', 'nw82','nw8202','nwunknown')]$nw_ver = "nw82",



### network Parameters ######

<# Disable Domainchecks for running DC
This should be used in Distributed scenario´s
 #>
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)]
	[Parameter(ParameterSetName = "DConly", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
    [Parameter(ParameterSetName = "NWserver", Mandatory = $false)]
	[Parameter(ParameterSetName = "Isilon", Mandatory = $false)]
    [switch]$NoDomainCheck,
<# Specify your own Class-C Subnet in format xxx.xxx.xxx.xxx #>
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[Parameter(ParameterSetName = "DConly", Mandatory = $false)]
    [Parameter(ParameterSetName = "NWserver", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
    [Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)]
	[Validatepattern(‘(?<Address>((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))’)]$MySubnet = "192.168.2.0",

<# Specify your IPfamilies #>
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)]
	[Parameter(ParameterSetName = "DConly", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
    [Parameter(ParameterSetName = "NWserver", Mandatory = $false)]
	[Parameter(ParameterSetName = "Isilon", Mandatory = $false)]
    [Validateset('IPv4','IPv6','IPv4IPv6')]$AddressFamily, 

<# Specify your IPv6 ULA Prefix, consider https://www.sixxs.net/tools/grh/ula/  #>
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)]
	[Parameter(ParameterSetName = "DConly", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
    [Parameter(ParameterSetName = "NWserver", Mandatory = $false)]
	[Parameter(ParameterSetName = "Isilon", Mandatory = $false)]
    [ValidateScript({$_ -match [IPAddress]$_ })]$IPV6Prefix,

<# Specify your IPv6 ULA Prefix Length, #>
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)]
	[Parameter(ParameterSetName = "DConly", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
    [Parameter(ParameterSetName = "NWserver", Mandatory = $false)]
	[Parameter(ParameterSetName = "Isilon", Mandatory = $false)]
    [Parameter(ParameterSetName = "SOFS", Mandatory = $false)]
    $IPv6PrefixLength,


### special mounting and vhd options
<# Path to the sources VHD if you relocated the VHS eg to an external USB Device #>
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)]
    [Parameter(ParameterSetName = "NWserver", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
    [Parameter(ParameterSetName = "SOFS", Mandatory = $false)]
	[ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include "sources.vhd" -ErrorAction SilentlyContinue })]$Sourcevhd,
<# 
Which Driveletter should the Sources be mounted / read from
Specify this Parameter together wit -noautomount if you do not run Sources from a VHD but have the extracted on a Drive in [Driveletter]:\Sources, eg. USB Device 
#>
	[Parameter(ParameterSetName = "default", Mandatory = $false)]
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)]
	[Parameter(ParameterSetName = "DConly", Mandatory = $false)]
    [Parameter(ParameterSetName = "NWserver", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
    [Parameter(ParameterSetName = "SOFS", Mandatory = $false)]
	[Validatepattern('[A-Z]{1}')][String]$Driveletter = $env:SystemDrive,
	
<# Surpress the Automaunt of Source.VHD
Cobine with -Driveltter to read from Extraxted Sources :-)
#>
	[Parameter(ParameterSetName = "default", Mandatory = $false)]
	[Parameter(ParameterSetName = "Hyperv", Mandatory = $false)]
	[Parameter(ParameterSetName = "AAG", Mandatory = $false)]
	[Parameter(ParameterSetName = "Exchange", Mandatory = $false)]
	[Parameter(ParameterSetName = "Blanknodes", Mandatory = $false)]
	[Parameter(ParameterSetName = "DConly", Mandatory = $false)]
    [Parameter(ParameterSetName = "NWserver", Mandatory = $false)]
	[Parameter(ParameterSetName = "SQL", Mandatory = $false)]
	[switch]$Noautomount,
	
<# Turn on Logging to Console#>
	[switch]$ConsoleLog
) # end Param

#requires -version 3.0
#requires -module vmxtoolkit 
###################################################
### VMware Master Script
### Karsten Bott
### Based Upon VLAB2GO Idea, First Draft labbuildr
### 09.08 Added -action Switch
### 11.08.added First Time VMware Start vor Master to be imported
### 12.08.2013 Added vmx Evaluation upon Memory
### 07.10.2013. Official release 1.0
### 08.10.2013 Cosmetical firstrun.pass fix for onerroraction
### 30.10.2013 Added SQL
### 30.10.2013 Added Online Update
### 30.10.2013 Added Console Logging
### 30.10.2013 Function Cleanup, started re-writeing for Log Functions
### 30.10.2013 changed checkuser to tes-user
### 30.10.2013 Added Advanced Mount Script
### 30.10.2013 New VHD for SQL, WAIK and SCVMM
### 03.11.2013 Munt-Routine completly Wre-Written tocheck for valid Mount Mountdrives
### 14.01.2014 Lots of Changes: Support for NMM Version, NW Versions and CU Versions. Starting / Stopping/Pausing/Resumiong of VM´s and many more
### 06.03.2014 Major Release networker2go
### 24.03.2014 Major release 2.5
### 08.04.2014 Finished SQL 2014, included always on for 2014
### 11.06.2014 Changed  Exchange Install Scripts for flexible DAG Creation, 1 to Multi Node DAG´s


###################################################
## COnstants to be moved to Params


###################################################
[string]$Myself = $MyInvocation.MyCommand
#$AddressFamily = 'IPv4'
$IPv4PrefixLength = '24'
$myself = $Myself.TrimEnd(".ps1")
$Starttime = Get-Date
$Builddir = $PSScriptRoot
$CurrentVersion = Get-Content  ($Builddir + "\version.$mySelf") -ErrorAction SilentlyContinue
$LogFile = "$Builddir\$(Get-Content env:computername).log"
$WAIKVER = "WAIK"
$domainsuffix = ".local"
$AAGDB = "AWORKS"
$major = "3.5"
$SourceScriptDir = "$Builddir\Scripts\"
$Adminuser = "Administrator"
$Adminpassword = "Password123!"
$Targetscriptdir = "C:\Scripts\"
$NodeScriptDir = "$Builddir\Scripts\Node\"
$Dots = [char]58
[string]$Commentline = "#######################################################################################################################"
$SCVMMVER = "SC2012 R2 SCVMM"
$WAIKVER = "WAIK"
#$SQLVER = "SQL2012SP1"
$DCNODE = "DCNODE"
$NWNODE = "NWSERVER"
$EXNODE1 = "E2013N1"
$EXNODE2 = "E2013N2"
$HVNODE1 = "HyperVN"
$AAGNODE1 = "AAGNode1"
$AAGNODE2 = "AAGNode2"
$SQLNODE1 = "SQLNODE1"
$Updatefile = "Update.zip"
$UpdateUri = "https://community.emc.com/blogs/bottk/2014/06/16/announcement-labbuildr-released"
$Edition = "Real COTS SDS Edition"
$RequiredModules = ('vmxtoolkit')
$NodeList = ($DCNODE, $EXNODE1, $EXNODE2, $HVNODE1, $NWNODE, $AAGNODE1, $AAGNODE2, $AAGNODE3, $SQLNODE1)
$Sleep = 10
$Driveletter = $Driveletter.Substring(0,1)
$Mountroot = $Driveletter.ToUpper() + ":"
[string]$Sources = "Sources"
# $Sourcedir = Split-Path Sourcevhd
$Sourcedir = "$Mountroot\$Sources"
$Sourceslink = "https://my.syncplicity.com/share/wmju8cvjzfcg04i/sources"
$Buildname = Split-Path -Leaf $Builddir
    $Scenarioname = "default"
    $Scenario = 1
$AddonFeatures = ("RSAT-ADDS", "RSAT-ADDS-TOOLS", "AS-HTTP-Activation", "NET-Framework-45-Features") 
##################
### VMrun Error Condition help to tune the Bug wher the VMRUN COmmand can not communicate with the Host !
$VMrunErrorCondition = @("Waiting for Command execution Available", "Error", "Unable to connect to host.", "Error: The operation is not supported for the specified parameters", "Unable to connect to host. Error: The operation is not supported for the specified parameters", "Error: vmrun was unable to start. Please make sure that vmrun is installed correctly and that you have enough resources available on your system.", "Error: The specified guest user must be logged in interactively to perform this operation")
$Host.UI.RawUI.WindowTitle = "$Buildname"




###################################################
# main function go here
###################################################
function copy-tovmx
{
	param ($Sourcedir)
	$Origin = $MyInvocation.MyCommand
	$count = (Get-ChildItem -Path $Sourcedir -file).count
	$incr = 1
	foreach ($file in Get-ChildItem -Path $Sourcedir -file)
	{
		Write-Progress -Activity "Copy Files to $Nodename" -Status $file -PercentComplete (100/$count * $incr)
		do
		{
			($cmdresult = &$vmrun -gu $Adminuser -gp $Adminpassword copyfilefromhosttoguest $CloneVMX $Sourcedir$file $TargetScriptdir$file) 2>&1 | Out-Null
			write-log "$origin $File $cmdresult"
		}
		until ($VMrunErrorCondition -notcontains $cmdresult)
		write-log "$origin $File $cmdresult"
		$incr++
	}
}

function convert-iptosubnet
{
	param ($Subnet)
	$subnet = [System.Version][String]([System.Net.IPAddress]$Subnet)
	$Subnet = $Subnet.major.ToString() + "." + $Subnet.Minor + "." + $Subnet.Build
	return, $Subnet
} #enc convert iptosubnet

function copy-vmxguesttohost
{
	param ($Guestpath, $Hostpath, $Guest)
	$Origin = $MyInvocation.MyCommand
	do
	{
		($cmdresult = &$vmrun -gu $Adminuser -gp $Adminpassword copyfilefromguesttohost "$Builddir\$Guest\$Guest.vmx" $Guestpath $Hostpath) 2>&1 | Out-Null
		write-log "$origin $Guestpath $Hostpath $cmdresult "
	}
	until ($VMrunErrorCondition -notcontains $cmdresult)
	write-log "$origin $File $cmdresult"
} # end copy-vmxguesttohost

function get-update
{
	param ([string]$UpdateSource, [string] $Updatedestination)
	$Origin = $MyInvocation.MyCommand
	$update = New-Object System.Net.WebClient
	$update.DownloadFile($Updatesource, $Updatedestination)
}

function Extract-Zip
{
	param ([string]$zipfilename, [string] $destination)
	$copyFlag = 16 # overwrite = yes
	$Origin = $MyInvocation.MyCommand
	if (test-path($zipfilename))
	{
		$shellApplication = new-object -com shell.application
		$zipPackage = $shellApplication.NameSpace($zipfilename)
		$destinationFolder = $shellApplication.NameSpace($destination)
		$destinationFolder.CopyHere($zipPackage.Items(), $copyFlag)
		write-log "$Origin extracting $zipfilename"
	}
}

function domainjoin
{

    param (

    $nodeIP,
    $nodename,
    [Validateset('IPv4','IPv6','IPv4IPv6')]$AddressFamily
    )
	
    $Origin = $MyInvocation.MyCommand
	invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script configurenode.ps1 -Parameter "-nodeip $Nodeip -IPv4subnet $IPv4subnet -nodename $Nodename -IPv4PrefixLength $IPv4PrefixLength -IPv6PrefixLength $IPv6PrefixLength -IPv6Prefix $IPv6Prefix -AddressFamily $AddressFamily $AddGateway -AddOnfeatures '$AddonFeatures' $CommonParameter" -nowait -interactive
	write-verbose "Waiting for Pass 2 (Node Configured)"
	While ($FileOK = (&$vmrun -gu Administrator -gp Password123! fileExistsInGuest $CloneVMX c:\Scripts\2.pass) -ne "The file exists.") { Write-Host -NoNewline "."; sleep $Sleep }
	write-host
	test-user Administrator
	invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script addtodomain.ps1 -Parameter "-Domain $BuildDomain -domainsuffix $domainsuffix" -nowait -interactive
	write-verbose "Waiting for Pass 3 (Domain Joined)"
	While ($FileOK = (&$vmrun -gu Administrator -gp Password123! fileExistsInGuest $CloneVMX c:\Scripts\3.pass) -ne "The file exists.") { Write-Host -NoNewline "."; sleep $Sleep }
	Write-Host
}


function status
{
	param ([string]$message)
	write-host -ForegroundColor Yellow $message
}

function workorder
{
	param ([string]$message)
	write-host -ForegroundColor Magenta $message
}

function progress
{
	param ([string]$message)
	write-host -ForegroundColor Gray $message
}

function debug
{
	param ([string]$message)
	write-host -ForegroundColor Red $message
}

function runtime
{
	param ($Time, $InstallProg)
	$Timenow = Get-Date
	$Difftime = $Timenow - $Time
	$StrgTime = ("{0:D2}" -f $Difftime.Hours).ToString() + $Dots + ("{0:D2}" -f $Difftime.Minutes).ToString() + $Dots + ("{0:D2}" -f $Difftime.Seconds).ToString()
	write-host "`r".padright(1, " ") -nonewline
	Write-Host -ForegroundColor Yellow "$InstallProg Setup Running Since $StrgTime" -NoNewline
}

function runvm-exe
{
	(param)
	#####tbd"
}

function write-log
{
	Param ([string]$line)
	$Logtime = Get-Date -Format "MM-dd-yyyy_hh-mm-ss"
	Add-Content $Logfile -Value "$Logtime  $line"
}

function remove-vmx
{
	param ($vmname)
	$Origin = $MyInvocation.MyCommand
	do
	{
		($cmdresult = &$vmrun deleteVM "$Builddir\$vmname\$vmname.vmx")
		write-log "$Origin deleteVM $vmname $cmdresult"
	}
	until ($VMrunErrorCondition -notcontains $cmdresult)
}

function stop-vmx
{
	param ($vmname,
		[Parameter(Mandatory = $false)][ValidateSet('Soft', 'Hard')]$Mode
	)
	$Origin = $MyInvocation.MyCommand
	do
	{
		($cmdresult = &$vmrun stop "$Builddir\\$vmname\\$vmname.vmx" $Mode 2>&1 | Out-Null)
		write-log "$Origin stop $vmname $cmdresult"
	}
	until ($VMrunErrorCondition -notcontains $cmdresult)
}

function pause-vmx
{
	param ($vmname)
	$Origin = $MyInvocation.MyCommand
	do
	{
		($cmdresult = &$vmrun pause "$Builddir\\$vmname\\$vmname.vmx" 2>&1 | Out-Null)
		write-log "$Origin pause $vmname $cmdresult"
	}
	until ($VMrunErrorCondition -notcontains $cmdresult)
}

function suspend-vmx
{
	param ($vmname)
	$Origin = $MyInvocation.MyCommand
	do
	{
		($cmdresult = &$vmrun suspend "$Builddir\\$vmname\\$vmname.vmx" 2>&1 | Out-Null)
		write-log "$Origin suspend $vmname $cmdresult"
	}
	until ($VMrunErrorCondition -notcontains $cmdresult)
}

function unpause-vmx
{
	param ($vmname)
	$Origin = $MyInvocation.MyCommand
	do
	{
		($cmdresult = &$vmrun unpause "$Builddir\\$vmname\\$vmname.vmx" 2>&1 | Out-Null)
		write-log "$Origin unpause $vmname $cmdresult"
	}
	until ($VMrunErrorCondition -notcontains $cmdresult)
}

<#	
	.SYNOPSIS
		We test if the Domaincontroller DCNODE is up and Running
	
	.DESCRIPTION
		Machine Sizes
    'XS'  = 1vCPU, 512MB
    'S'   = 1vCPU, 512MB
    'M'   = 1vCPU, 1024MB
    'L'   = 2vCPU, 2048MB
    'XL'  = 2vCPU, 4096MB 
    'XXL' = 4vCPU, 6144MB
   'XXXL' = 4vCPU, 8192MB

    numvcpus = "1"

    memsize = "768"

	.EXAMPLE
		PS C:\> test-dcrunning
	
	.NOTES
		Requires the DC inside labbuildr Runspace
#>
function set-vmxsize
{

param ($vmname,
[Parameter(Mandatory=$true)][ValidateSet('XS','S','M','L','XL','XXL')]$Size = "M"
)
switch ($size) {
    "XS"{
        $memsize = 512
        $vcpu = 1
        }
    "S"{
        $memsize = 768
        $vcpu = 1
        }
    "M"{
        $memsize = 1024
        $vcpu = 1
        }
    "L"{
        $memsize = 2048
        $vcpu = 2
        }
    "XL"{
        $memsize = 4096
        $vcpu = 2
        }
    "XXL"{
        $memsize = 6144
        $vcpu = 4
        }
    "XXXL"{
        $memsize = 8192
        $vcpu = 4
        }
        }# end switch size

	#### we set the current hostname inot the VMX Parameter file first !
    Write-Verbose -Message "Setting Machinesize"
    $content = Get-Content "$Builddir\$vmname\$vmname.vmx" | where {$_ -NotMatch "memsize"}
    $content += 'memsize = "'+$memsize+'"'
    $content = $content | where {$_ -NotMatch "numvcpus"}
    $content += 'numvcpus = "'+$vcpu+'"'
    set-Content -Path "$Builddir\$vmname\$vmname.vmx" -Value $content -Force
    #
    ####
}#end vmxsize
#### new get-functions start here
function get-vmxmemory
{
param (
[Parameter(Mandatory=$true)]$vmname
)

    $ErrorActionPreference ="silentlyContinue"
    Write-Verbose -Message "getting Machinesize"
    $vmxconfig = get-vmxconfig -vmname $vmname
    [int]$mymemsize = search-pattern -pattern "memsize" -vmxconfig $vmxconfig
    return ,$mymemsize
}#end get-vmxmemory

function Get-VMXProcessor
{
param (
[Parameter(Mandatory=$true)]$vmname
)

    $ErrorActionPreference ="silentlyContinue"
    Write-Verbose -Message "getting Machinesize"
    $vmxconfig = get-vmxconfig -vmname $vmname
    [int]$VMXProcessor = search-pattern -pattern "numvcpus" -vmxconfig $vmxconfig
    return ,$VMXProcessor
}#end Get-VMXProcessor


function Get-VMXScsiDisk
{
param (
[Parameter(Mandatory=$true)]$vmname
)

    $ErrorActionPreference ="silentlyContinue"
    Write-Verbose -Message "getting Machinesize"
    $vmxconfig = get-vmxconfig -vmname $vmname
    $VMXScsiDisk = search-pattern -Pattern "scsi\d{1,2}:\d{1,2}.filename" -vmxconfig $vmxconfig
    return ,$VMXScsiDisk
}#end Get-VMXScsiDisk

function Get-VMXScsiController
{
param (
[Parameter(Mandatory=$true)]$vmname
)

    $ErrorActionPreference ="silentlyContinue"
    Write-Verbose -Message "getting Controller"
    $vmxconfig = get-vmxconfig -vmname $vmname
    $VMXScsiController = search-pattern -Pattern "scsi\d{1,2}.virtualdev" -vmxconfig $vmxconfig
    return ,$VMXScsiController
}#end Get-VMXScsiControiller

function get-vmxsize
{

param (
[Parameter(Mandatory=$true)]$vmname
# [Parameter(Mandatory=$true)][ValidateSet('XS','S','M','L','XL','XXL')]$Size = "M"
)
<# switch ($size) {
   "XS"{
        $memsize = 512
        $vcpu = 1
        }
    "S"{
        $memsize = 768
        $vcpu = 1
        }
    "M"{
        $memsize = 1024
        $vcpu = 1
        }
    "L"{
        $memsize = 2048
        $vcpu = 2
        }
    "XL"{
        $memsize = 4096
        $vcpu = 2
        }
    "XXL"{
        $memsize = 6144
        $vcpu = 4
        }
    "XXXL"{
        $memsize = 8192
        $vcpu = 4
        }
        }# end switch size#>

	#### we set the current hostname inot the VMX Parameter file first !
    $ErrorActionPreference ="silentlyContinue"
    Write-Verbose -Message "getting Machinesize"
    $vmxconfig = get-vmxconfig -vmname $vmname
    [int]$mymemsize = search-pattern -pattern "memsize" -vmxconfig $vmxconfig
    # $mymemsize=[math]::Pow($mymemsize,20)
    [int]$mynumvcpus = search-pattern -pattern "numvcpus" -vmxconfig $vmxconfig
    #
    ####
    return ,$mymemsize,$mynumvcpus
}#end get-vmxsize

function search-pattern{
param($pattern,$vmxconfig)
$returnpattern = $vmxconfig| where {$_ -Match $pattern}
$returnpattern= $returnpattern.StartSplit(' = "')
$returnpattern = $returnpattern.TrimEnd('"')
Write-Verbose -Message $returnpattern
return, $returnpattern
}

<#	
	.SYNOPSIS
		We test if the Domaincontroller DCNODE is up and Running
	
	.DESCRIPTION
		A detailed description of the test-dcrunning function.
	
	.EXAMPLE
		PS C:\> test-dcrunning
	
	.NOTES
		Requires the DC inside labbuildr Runspace
#>
# function get-vmxconfig{
# param
# ($vmname
#)

# $vmxconfig = Get-Content "$Builddir\$vmname\$vmname.vmx"
# return ,$vmxconfig
#}##end get-vmxconfig

<#	
	.SYNOPSIS
		We test if the Domaincontroller DCNODE is up and Running
	
	.DESCRIPTION
		A detailed description of the test-dcrunning function.
	
	.EXAMPLE
		PS C:\> test-dcrunning
	
	.NOTES
		Requires the DC inside labbuildr Runspace
#>
function test-dcrunning
{
	$Origin = $MyInvocation.MyCommand
    
    if (!$NoDomainCheck.IsPresent){
	if (Test-Path "$Builddir\$DCNODE\$DCNODE.vmx")
	{
		if ((list-vmrun) -notcontains $DCNODE)
		{
			status "Domaincontroller not running, we need to start him first"
			get-vmx $DCNODE | Start-vmx  
			do
			{
				$DCOK = (test-vmxrunning -vmname $DCNODE)
			}
			until ($DCOK)
		}
	}#end if
	else
	{
		debug "Domaincontroller not found, giving up"
		break
	}#end else
} # end nodomaincheck
} #end test-dcrunning

<#	
	.SYNOPSIS
		This Function gets IP, Domainname and VMnet from the Domaincontroller.
	
	.DESCRIPTION
		A detailed description of the test-domainsetup function.
	
	.EXAMPLE
		PS C:\> test-domainsetup
	
	.NOTES
		Additional information about the function.
#>
function test-domainsetup
{
	test-dcrunning
	Write-Host -NoNewline -ForegroundColor DarkCyan "Testing Domain Name ...: "
	copy-vmxguesttohost -Guestpath "C:\scripts\domain.txt" -Hostpath "$Builddir\domain.txt" -Guest $DCNODE
	$holdomain = Get-Content $Builddir"\domain.txt"
	status $holdomain
	Write-Host -NoNewline -ForegroundColor DarkCyan "Testing Subnet.........: "
	copy-vmxguesttohost -Guestpath "C:\scripts\ip.txt" -Hostpath "$Builddir\ip.txt" -Guest $DCNODE
	$DomainIP = Get-Content $Builddir"\ip.txt"
	$IPv4subnet = convert-iptosubnet $DomainIP
	status $ipv4Subnet

	Write-Host -NoNewline -ForegroundColor DarkCyan "Testing Default Gateway: "
	copy-vmxguesttohost -Guestpath "C:\scripts\Gateway.txt" -Hostpath "$Builddir\Gateway.txt" -Guest $DCNODE
	$DomainGateway = Get-Content $Builddir"\Gateway.txt"
	status $DomainGateway

	Write-Host -NoNewline -ForegroundColor DarkCyan "Testing VMnet .........: "
	$Line = Select-String -Pattern "ethernet0.vnet" -Path "$Builddir\$DCNODE\$DCNODE.vmx"
	$myline = $Line.line.Trim('ethernet0.vnet = ')
	$MyVMnet = $myline.Replace('"', '')
	status $MyVMnet
	Write-Output $holdomain, $Domainip, $MyVMnet, $DomainGateway
	# return, $holdomain, $Domainip, $MyVMnet
} #end test-holdomain

function list-vmrun
{
	$runvms = @()
	# param ($vmname)
	
	$Origin = $MyInvocation.MyCommand
	do
	{
		(($cmdresult = &$vmrun List) 2>&1 | Out-Null)
		write-log "$origin $cmdresult"
	}
	until ($VMrunErrorCondition -notcontains $cmdresult)
	write-log "$origin $cmdresult"
	foreach ($runvm in $cmdresult)
	{
		if ($runvm -notmatch "Total running VMs")
		{
			$runvm = split-path $runvm -leaf -resolve
			$runvm = $runvm.TrimEnd(".vmx")
			$runvms += $runvm
			# Shell opject will be cretaed in next version containing name, vmpath , status
		}# end if
	}#end foreach
	return, $runvms
} #end do

<#	
	.SYNOPSIS
		A brief description of the get-vmx function.
	
	.DESCRIPTION
		A detailed description of the get-vmx function.
	
	.EXAMPLE
		PS C:\> get-vmx

	.NOTES
		Additional information about the function.
#>



function get-VMXinfo {
param(
[Parameter(Mandatory=$true)]$vmxname
)
    $ErrorActionPreference ="silentlyContinue"
	$VMXlist = get-vmx
	$VMXinfo = @()
#	$vmrun = list-vmrun
	foreach ($vmname in $vmxname)
	{
		[bool]$ismyvm = $false
		[uint64]$SizeOnDiskinMB = ""
		$Processes = get-process -id (Get-WmiObject -Class win32_process | where commandline -match $vmname).handle
		foreach ($Process in $Processes)
		{
			# Write-Verbose -Message $Process.processname
			# Write-Verbose -Message $VM
			if ($Process.ProcessName -ne "vmware")
			{
                $vmxconfig = get-vmxsize -vmname $vmname 
				$object = New-Object psobject
				$object | Add-Member VMname ([string]$vmname)
				$object | Add-Member ProcessName ([string]$Process.ProcessName)
				$object | Add-Member VirtualMemoryMB ([uint64]($Process.VirtualMemorySize64 / 1MB))
				$object | Add-Member PrivateMemoryMB ([uint64]($Process.PrivateMemorySize64 / 1MB))
				$object | Add-Member CPUtime ($Process.CPU)
                $object | Add-Member VMXconfig ($vmxconfig)
                $object | Add-Member Memory (get-vmxmemory -vmname $vmname)
                $object | Add-Member Processor (Get-VMXProcessor -vmname $vmname)
                $object | Add-Member ScsiController(Get-VMXScsiController -vmname $vmname)
                $object | Add-Member ScsiDisk (Get-VMXScsiDisk -vmname $vmname)
				foreach ($myVM in $VMXlist)
				{
					Write-Verbose -Message "Comparing $vmname with $myvm"
					Write-Verbose -Message $myVM.VMname
					Write-Verbose -Message $vmname
					if ($myVM -match $vmname)
					{
						$ismyvm = $true
						$SizeOnDiskinMB = ((Get-ChildItem -Path $Builddir\$vmname -Filter "Master*.vmdk").Length /1MB)
					}#end-if
				} #end freach myvm
				$object | Add-Member "Is$Myself" ([bool]$ismyvm)
				$object | Add-Member SizeOnDiskinMB ([uint64]$SizeOnDiskinMB)
				$VMXinfo += $object
			}
			
		}#  end foreach process
		
	}#end foreach
	Return, $vmxinfo
}# end get-VMXinfo

function list-vmx {
	[array]$vmxlist = @()
    $vmxlist = Get-ChildItem -Path $Builddir -Recurse -File -Filter "*.vmx" -Exclude "*master*"
	if ($vmxlist) {$vmxlist = $vmxlist.Name.Trim(".vmxf") }
	$vmxlist = $vmxlist | select -Unique
    # Write-verbose -Message $vmxlist -ErrorAction SilentlyContinue
	return, $vmxlist
} #end list-vmx

function test-vmxrunning
{
	param ($vmname)
	$Origin = $MyInvocation.MyCommand
	do
	{
		($cmdresult = &$vmrun List)
		write-log "$origin $cmdresult"
	}
	until ($VMrunErrorCondition -notcontains $cmdresult)
	write-log "$origin $cmdresult"
	if ($cmdresult -match $vmname) { write-host "$Vmname is in running state"; Return, $cmdresult }
	else { return, $false }
}

function test-user
{
	param ($whois)
	$Origin = $MyInvocation.MyCommand
	do
	{
		([string]$cmdresult = &$vmrun -gu $Adminuser -gp $Adminpassword listProcessesInGuest $CloneVMX)2>&1 | Out-Null
		write-log "$origin $UserLoggedOn"
		start-sleep -Seconds $Sleep
	}
	
	until (($cmdresult -match $whois) -and ($VMrunErrorCondition -notcontains $cmdresult))
	
}

function test-vmx
{
	param ($vmname)
	$return = Get-ChildItem "$Builddir\\$vmname\\$vmname.vmx" -ErrorAction SilentlyContinue
	return, $return
}

function test-source
{
	param ($SourceVer, $SourceDir)
	
	
	$SourceFiles = (Get-ChildItem $SourceDir -ErrorAction SilentlyContinue).Name
	#####
	
	foreach ($Version in ($Sourcever))
	{
		if ($Version -ne "")
		{
			write-verbose "Checking $Version"
			if (!($SourceFiles -contains $Version))
			{
				write-Host "$Sourcedir does not contain $Version"
				debug "Please Download and extraxct $Version to $Sourcedir"
				$Sourceerror = $true
			}
			else { write-verbose "found $Version, good..." }
		}
		
	}
	If ($Sourceerror) { return, $false }
	else { return, $true }
}

<#	
	.SYNOPSIS
		A brief description of the checkpass function.
	
	.DESCRIPTION
		A detailed description of the checkpass function.
	
	.PARAMETER Guestpassword
		A description of the Guestpassword parameter.
	
	.PARAMETER Guestuser
		A description of the Guestuser parameter.
	
	.PARAMETER pass
		A description of the pass parameter.
	
	.PARAMETER reboot
		A description of the reboot parameter.
	
	.EXAMPLE
		PS C:\> checkpass -Guestpassword 'Value1' -Guestuser $value2
	
	.NOTES
		Additional information about the function.
#>
function checkpass
{
	param ($pass, $reboot = 1, $Guestuser = $Adminuser, $Guestpassword = $Adminpassword)
	$Origin = $MyInvocation.MyCommand
	invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script pass.ps1 -nowait -interactive -Parameter " -pass $pass -reboot $reboot"
	write-Host
	write-verbose "Waiting for Pass $Pass"
	While ($FileOK = (&$vmrun -gu $Adminuser -gp $Adminpassword fileExistsInGuest $CloneVMX c:\Scripts\$Pass.pass) -ne "The file exists.") { Write-Host -NoNewline "."; write-log "$FileOK $Origin"; sleep $Sleep }
	write-host
}

function CreateShortcut
{
	$wshell = New-Object -comObject WScript.Shell
	$Deskpath = $wshell.SpecialFolders.Item('Desktop')
	# $path2 = $wshell.SpecialFolders.Item('Programs')
	# $path1, $path2 | ForEach-Object {
	$link = $wshell.CreateShortcut("$Deskpath\$Buildname.lnk")
	$link.TargetPath = "$psHome\powershell.exe"
	$link.Arguments = "-noexit -command $Builddir\profile.ps1"
	#  -command ". profile.ps1" '
	$link.Description = "$Buildname"
	$link.WorkingDirectory = "$Builddir"
	$link.IconLocation = 'powershell.exe'
	$link.Save()
	# }
	
}


function invoke-postsection
    {
    write-verbose "Setting Power Scheme"
	invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script powerconf.ps1 -interactive
	write-verbose "Configuring UAC"
    invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script set-uac.ps1 -interactive
    }

####################################################
$newLog = New-Item -ItemType File -Path $LogFile -Force

If ($ConsoleLog) { Start-Process -FilePath $psHome\powershell.exe -ArgumentList "Get-Content  -Path $LogFile -Wait " }
if ($PSCmdlet.MyInvocation.BoundParameters["verbose"].IsPresent)
    {
    $CommonParameter = '-verbose'
    }
if ($PSCmdlet.MyInvocation.BoundParameters["debug"].IsPresent)
    {
    $CommonParameter = 'debug'
    }
####################################################


###################################################
foreach ($Module in $RequiredModules){
# if(-not(Get-Module -name $Module))
#{
Write-Verbose "Loading $Module Modules"
Import-Module "$Builddir\$Module" -Force
#}
}


###################################################
switch ($PsCmdlet.ParameterSetName)
{
	"action" {
		switch ($action)
		{
			"TestDomain" {
				$Nodename = $DCNODE
				$CloneVMX = "$Builddir\$Nodename\$Nodename.vmx"
				invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script checkdom.ps1
				$Holdomain, $Holip, $MyVMnet, $MyGateway = test-domainsetup
                Write-Verbose -Message  ("MyGateway: $MyGateway")
                If ($MyGateway) {$Gateway = $True} 
                Write-Verbose -Message $Gateway.IsPresent
                
				# status "$mySelf is running with domain $Holdomain, Domaincontroller has ip $HolIP on $MyVMnet"
			} #end testdomain
			
			"MountSource" {
				if (!(Test-Path $Builddir\sources.vhd))
				{
					debug "Sources.vhd not found in $Builddir. We need sources.vhd from labbuildr Package"
					debug "Please Download from Package"
					Start-Process $Sourceslink
					break
				}
				
				
				
				Start-Process  "$psHome\powershell.exe" -wait -Verb Runas -ArgumentList "-ExecutionPolicy Bypass -command $Builddir\mount-sourcesv2.ps1 -sources $Source -Driveletter $Driveletter"
			} #End Mountsource
			
			"Version" {
				Status "labbuildr version $major-$CurrentVersion $Edition"
				Get-Content $Builddir\changes.txt
                status "Available commands"
                Get-Command -Module vmxtoolkit
                get-vmwareversion
				return
			} #end Version
			
			"StartAll" {
				
				test-dcrunning
				
				$allvms = list-vmx
				$nodelist = list-vmrun
				foreach ($Node in $allvms)
				{
					if ($Node -notin $NodeList)
					{
						status "Starting $Node"
						start-vmx -vmname $Node
					} #end if
					
				}# end foreach
				
			} #end start all
			
			"StopAll" {
				$nodelist = list-vmrun
				[array]::Reverse($NodeList)
				foreach ($Node in $nodelist)
				{
					If ($Node -ne $DCNODE)
					{
						status "Stopping Node $Node"
						stop-vmx -vmname $Node
					}
				}
				status "Stopping Domaincontroller"
				stop-vmx -vmname $DCNODE
			} #end stop all
			
			"PauseAll"{
				$nodelist = list-vmrun
				foreach ($Node in $nodelist)
				{
					If ($Node -ne $DCNODE)
					{
						status "Pausing VM $Node"
						pause-vmx -vmname $Node
					}
				}
				pause-vmx -vmname $DCNODE
			} #end pauseall
			
			"Suspendall"{
				$nodelist = list-vmrun
				[array]::Reverse($NodeList)
				foreach ($Node in $nodelist)
				{
					If ($Node -ne $DCNODE)
					{
						status "Suspending Node $Node"
						suspend-vmx -vmname $Node
					}
				}
				status "Suspending Domaincontroller"
				suspend-vmx -vmname $DCNODE
			} #end suspend all
			
			"UnPauseAll"{
				status "Unpause DC"
				unpause-vmx -vmname $DCNODE
				$nodelist = list-vmrun
				foreach ($Node in $nodelist)
				{
					
					If ($Node -ne $DCNODE)
					{
						status "UnPausing VM $Node"
						unpause-vmx -vmname $Node
					}
				}
				
			} #end unpauseal
			
			"remove-vmx" {
				if ($vmxlist)
				{
					
					foreach ($vm in $vmxlist)
					{
						Status "Removing VM $VM"
						stop-vmx -vmname $vm -Mode Hard
						remove-vmx -vmname $vm
					}
					status "Make sure to remove Nodes from AD ! "
				}#end-if vmxlist
				else
				{
					do
					{
						get-vmx -Path $Builddir	| where template -ne $True
						# $listrunning = list-vmrun
						# status "Running VM´s:"
						# write-host -ForegroundColor Gray ($listrunning, '')
						# $listvms = list-vmx
						# status "labbuildr depolyed VM´s:"
						# write-host -ForegroundColor Gray ($listvms, '')
						[string]$Removenode = read-host "Node to remove, enter to exit"
						if ($Removenode)
						{
							stop-vmx -vmname $removenode -Mode Hard
							Remove-vmx -vmname $removenode
						}
					}
					until (!($Removenode))
					status "Make sure to remove Nodes from AD ! "
				}#end-else
			}
			"list-templates"
			{
			get-vmx | Get-VMXTemplate | ft Templatename, config
			}
			"stop-vmx" {
				if ($vmxlist)
				{
					
					foreach ($vm in $vmxlist)
					{
						Status "Stopping VM $VM"
						stop-vmx $vm
					}
				}#end-if vmxlist
				else
				{
					do
					{
						$listrunning = list-vmrun
						status "Running VM´s:"
						write-host -ForegroundColor Gray ($listrunning, '')
						$listvms = list-vmx
						status "labbuildr depolyed VM´s:"
						write-host -ForegroundColor Gray ($listvms, '')
						[string]$node = read-host "Node to remove, enter to exit"
						if ($node)
						{
							stop-vmx $node
						}
					}
					until (!($node))
					status "Make sure to remove Nodes from AD ! "
				}#end-else
			}
			
			"list-deployed" {
				$listvms = get-vmx | where template -NE $true
				if (!$listvms) { debug "No Machines Deployed" }
				else
				{
					status "labbuildr deployed VM´s:"
					# write-host -ForegroundColor Gray ($listvms,'')
					return $listvms, " "
				}
			}#end list-deployed
			
			"list-running" {
				$listrunning = list-vmrun
				status "labbuildr Running VM´s:"
				# write-host -ForegroundColor Gray ($listrunning, '')
				Write-Output $listrunning
			}#end list-running
			
			"start-vmx" {
				
				if ($vmxlist)
				{
					foreach ($vm in $vmxlist)
					{
						Status "Starting VM $VM"
						start-vmx $vm
					}
					
				}
				else
				{
					do
					{
						$startablevmx = @()
						$listrunning = list-vmrun
						status "Running VM´s:"
						write-host -ForegroundColor Gray ($listrunning, '')
						$listvms = list-vmx
						Foreach ($vmx in $listvms)
						{
							If ($vmx -notin $listrunning)
							{
								$startablevmx += $vmx
							}
						}
						status "labbuildr Startable VM´s:"
						write-host -ForegroundColor Gray ($startablevmx, '')
						
						[string]$StartNode = read-host "Node to Start, enter to exit"
						if ($Startnode -and ($StartNode -in $startablevmx))
						{
							start-vmx $StartNode
						}
					}
					until (!($StartNode))
				}#end-else
				# status "Make sure to remove Nodes from AD ! "
			} #end start-vmx
			
			"stop-vmx" {
				if ($vmxlist)
				{
					
					foreach ($vm in $vmxlist)
					{
						# status "Stopping VM $VM"
						stop-vmx $vm
					}
				}#end-if vmxlist
				else
				{
					do
					{
						$listrunning = list-vmrun
						status "Running VM´s:"
						write-host -ForegroundColor Gray ($listrunning, '')
						[string]$stopNode = read-host "Node to stop, enter to exit"
						if ($stopNode)
						{
							stop-vmx $stopNode
						}
					}
					until (!($stopNode))
					# status "Make sure to remove Nodes from AD ! "
				}#end-else
			} #end stop-vmx
			
			"suspend-vmx" {
				if ($vmxlist)
				{
					
					foreach ($vm in $vmxlist)
					{
						Status "Suspending VM $VM"
						suspend-vmx $vm
					}
				}#end-if vmxlist
				else
				{
					do
					{
						$listrunning = list-vmrun
						status "Running VM´s:"
						write-host -ForegroundColor Gray ($listrunning, '')
						[string]$suspendNode = read-host "Node to Suspend, enter to exit"
						if ($suspendNode)
						{
							suspend-vmx $suspendNode
						}
					}
					until (!($suspendNode))
					# status "Make sure to remove Nodes from AD ! "
				}#end-else
			} #end suspend-vmx
			
			"pause-vmx" {
				if ($vmxlist)
				{
					
					foreach ($vm in $vmxlist)
					{
						Status "Pausing VM $VM"
						pause-vmx $vm
					}
				}#end-if vmxlist
				else
				{
					do
					{
						$listrunning = list-vmrun
						status "Running VM´s:"
						write-host -ForegroundColor Gray ($listrunning, '')
						[string]$pauseNode = read-host "Node to pause, enter to exit"
						if ($pauseNode)
						{
							pause-vmx $pauseNode
						}
					}
					until (!($pauseNode))
					# status "Make sure to remove Nodes from AD ! "
				}#end-else
			} #end pause-vmx
			
			"removeAll" {
				$removelist = list-vmx
				foreach ($RemoveNode in $removelist)
				{
					Write-Host "Removing VM $Removenode"
					stop-vmx $removenode -Mode Hard
					Remove-vmx -vmname $Removenode
				}
				
			} #end-removeall

            "set-vmxsize" {
            foreach ($vmname in $vmxlist){
            status "Stopping VM $vmname"
            stop-vmx -vmname $vmname
            workorder "Resize $vmname to $Size"
            set-vmxsize -vmname $vmname -Size $Size
            status "Starting VM $vmname"
            start-vmx $vmname
            } #end foreach
            } #end set-vmxsize
			
            "get-vmxsize" {
            $myvmxsize = @()
            foreach ($vmname in $vmxlist){
            Write-Verbose $vmname
            status "getting Size of VM $vmname"
            ,$vmxmemsize, $vmxnumvcpus = get-vmxsize $vmname
            $object = New-Object psobject
				$object | Add-Member VMname ([string]$vmname)
				$object | Add-Member numvcpus ($vmxnumvcpus)
				$object | Add-Member memsize ($vmxmemsize)
			$myvmxsize += $object
           
            } #end foreach
            Write-Verbose "$vmxmemsize, $vmxnumvcpus"
            return, $myvmxsize
            } #end set-vmxsize
			

			"update" {
				progress "Running version $Major.$CurrentVersion"
				status "Checking for Updates, Please wait"
				if ($Link = (Invoke-WebRequest -Uri $UpdateUri).Links | where { $_.OuterHTML -Match "$Updatefile" -and $_.Innertext -match "$Updatefile" })
				{
				$uri = $link.href
				$Updateversion = $uri.TrimStart("/servlet/JiveServlet/download/")
				$Updateversion = $Updateversion.TrimEnd("/$updatefile")
				progress "Version $Major.$Updateversion is available"
				if ($CurrentVersion -lt $Updateversion)
				{
					status "Downloading Updates, please be patient ....."
					$Updatepath = "$Builddir\Update"
					if (!(Get-Item -Path $Updatepath -ErrorAction SilentlyContinue))
					{
						$newDir = New-Item -ItemType Directory -Path "$Updatepath"
					}
					$UpdateSource = "https://community.emc.com/$uri"
					$UpdateDestination = "$Updatepath\$Updatefile"
					get-update -UpdateSource $UpdateSource -Updatedestination $UpdateDestination
					Extract-Zip -zipfilename "$Builddir\update\$Updatefile" -destination $Builddir
					if (Test-Path "$Builddir\deletefiles.txt")
					{
						$deletefiles = get-content "$Builddir\deletefiles.txt"
						foreach ($deletefile in $deletefiles)
						{
							if (Get-Item $Builddir\$deletefile -ErrorAction SilentlyContinue)
							{
								Remove-Item -Path $Builddir\$deletefile -Recurse -ErrorAction SilentlyContinue
								status "deleted $deletefile"
								write-log "deleted $deletefile"
							}
						}


					}#end testpath
				    $Updateversion | Set-Content ($Builddir+"\version.$mySelf") 
				    status "Update Done"
                    status "reloading vmxtoolkit Modules"
                    import-module $Builddir/vmxtoolkit -force
                    ./profile.ps1
					# Start-Process -FilePath powershell.exe -WorkingDirectory $Builddir -ArgumentList  (Join-Path $Builddir -ChildPath $MyInvocation.MyCommand) -NoNewWindow
					break
				} #current version
				else { Status "No update required, already newest version " }
				}# end if updatefile
				else
				{
				Write-Host "no updatefile available"
				}
			} # end Update
			
			"CreateShortcut"{
				status "Creating Desktop Shortcut for $Buildname"
				createshortcut
			}# end shortcut
			
			#"get-vmxconfig"{
		#		$VMXconig = get-vmxconfig -vmname $vmxlist
	# 			return, $VMXconig
			#}
			"get-VMXinfo"{
				$VMXinfo = get-VMXinfo -vmxname $vmxlist
				return, $VMXinfo
			}
			
			"get-vmx"{
				$vmxliste = get-vmx
				return, $vmxliste
			}
			
			
			
		}# END Paramset Actions
		return
	} # END Params
}


write-verbose "Config pre defaults"
if ($PSCmdlet.MyInvocation.BoundParameters["verbose"].IsPresent)
    {
    write-output $PSCmdlet.MyInvocation.BoundParameters
    }
###################################################
## do we want defaults ?
if ($defaults.IsPresent)
    {
    status "Loading defaults from $Builddir\defaults.xml"
    [xml]$Default = Get-Content -Path $Builddir\defaults.xml
    $nmm_ver = $Default.config.nmm_ver 
    $nw_ver = $Default.config.nw_ver
    if (!$Master) {$master = $Default.config.master}
    $SQLVER = $Default.config.sqlver
    $ex_cu = $Default.config.ex_cu
    if (!$vmnet) {$vmnet = $Default.config.vmnet}
    # $NW = $Default.config.nw
    if (!$BuildDomain) {$BuildDomain = $Default.config.Builddomain}
    $MySubnet = $Default.config.MySubnet
    if (!$AddressFamily) {$AddressFamily = $Default.config.AddressFamily}
    if (!$IPv6Prefix) {$IPV6Prefix = $Default.Config.IPV6Prefix}
    if (!$IPv6PrefixLength) {$IPv6PrefixLength = $Default.Config.IPV6PrefixLength}
    if (!$Noautomount.IsPresent) 
        {
        If ($Default.Config.NoAutomount -eq "true"){$Noautomount = $True}
        }

    #$Gateway = $Default.config.Gateway
    
<#
if ($PSCmdlet.MyInvocation.BoundParameters["verbose"].IsPresent)
    {
    
    pause
    }
#>
}
if (!$BuildDomain) { $BuildDomain = "labbuildr" }

write-verbose "After defaults !!!! "
Write-Verbose "Noautomount: $($Noautomount.IsPresent)"
#### do we have unset parameters ?
if (!$IPV6Prefix) 
    {
    $IPV6Prefix = 'FD00::'
    $IPv6PrefixLength = '8'
    }
if (!$AddressFamily){$AddressFamily = "IPv4" }

write-verbose "After adresss !!!! "
if (!$Isilon.IsPresent)
    {
    if (!$Master)
    {
    Write-Error "No Master was specified. See get-help .\labbuildr.ps1 -Parameter Master !!"
    break
    }
    if ($masterconfig = Get-ChildItem -Filter *.vmx -Path "$Builddir\$Master" | where extension -eq .vmx)
        {
        $MasterVMX = $masterconfig.FullName		
        Write-Verbose $MasterVMX
    }
    else 
        { 
        Write-Error "$master not found. Please download a Master from https://community.emc.com/blogs/bottk/2014/06/16/announcement-labbuildr-released"
        Write-Error "see get-help .\labbuildr.ps1 -online"

        break 
        }
    }
write-verbose "After Masterconfig !!!! "
###################################################

<#if ($AddressFamily -eq 'IPv6')
    {
    $AddressFamily = 'IPv6'
    $IPv4Subnet = "$IPV6Prefix$IPv4Subnet"
    }
    #>
##### What Sources are Required
if (!$Sourcevhd) 
    {
    if (Test-Path $Builddir\sources.vhd) 
        {
        $Sourcevhd = Join-Path $Builddir sources.vhd -ErrorAction SilentlyContinue
        }
    }
$Sourcever = @()

# $Sourcever = @("$nw_ver","$nmm_ver","E2013$ex_cu","$WAIKVER","$SQL2012R2")
if (!($DConly.IsPresent))
{
	if ($Exchange.IsPresent -or $DAG.IsPresent) 
        {
        $Sourcever += "E2013$ex_cu"
        $Scenarioname = "Exchange"
        $Scenario = 1
        }
	if (($NMM.IsPresent) -and ($Blanknode -eq $false)) { $Sourcever += $nmm_ver }
	if ($NW) { $Sourcever += $nw_ver }
	if ($SQL.IsPresent -or $AlwaysOn.IsPresent) 
        {
        $Sourcever += $SQLVER, $AAGDB
        $Scenarioname = "SQL"
        $Scenario = 2
        }
	if ($HyperV.IsPresent)
	{
		$Sourcever += $WAIKVER
        $Scenarioname = "Hyper-V"
        $Scenario = 3
		if ($SCVMM.IsPresent) { $Sourcever += $SCVMMVER }
        if ($ScaleIO.IsPresent) { $Sourcever += "Scaleio" }
	}
} # end not dconly

# Clear-Host
status $Commentline
status "# Welcome to labbuildr                                                                                                #"
status "# Version $($major).$($CurrentVersion) $Edition                                                                   #"
status "# this is an automated Deployment for VMware Workstation VMs on Windows                                               #"
status "# current supportet Guests are:                                                                                       #"
status "# Exchange 2013 Standalone or DAG, SQL 2012SP1 and 2014, Always On, Hyper-V, SCVMM, Networker, Blank Nodes            #"
status "# Available OS Masters are 2012, 2012R2, 2012R2Update and Techical Preview of vNext                                   #"
status "# EMC Integration for Networker, OneFS, Avamar, DD, ScaleIO and other VADP´s                                          #"
status "# Idea and Scripting by @HyperV_Guy                                                                                   #"
status $Commentline
workorder "Building Proposed Workorder"
if ($Blanknode.IsPresent)
{
	workorder "We are going to Install $BlankNodes Blank Nodes with size $Size in Domain $BuildDomain with Subnet $MySubnet using VMnet$VMnet"
    if ($Gateway.IsPresent){ workorder "The Gateway will be $IPv4Subnet.103"}
	if ($VTbit) { write-verbose "Virtualization will be enabled in the Nodes" }
	if ($Cluster.IsPresent) { write-verbose "The Nodes will be Clustered" }
}
if ($SOFS.IsPresent)
{
	workorder "We are going to Install $SOFSNODES SOFS Nodes with size $Size in Domain $BuildDomain with Subnet $MySubnet using VMnet$VMnet"
    if ($Gateway.IsPresent){ workorder "The Gateway will be $IPv4Subnet.103"}
	if ($Cluster.IsPresent) { write-verbose "The Nodes will be Clustered ( Single Node Clusters )" }
}
if ($ScaleIO.IsPresent)
{
	workorder "We are going to Install ScaleIO on Hyper-V $HyperVNodes Hyper-V  Nodes"
    if ($Gateway.IsPresent){ workorder "The Gateway will be $IPv4Subnet.103"}
	# if ($Cluster.IsPresent) { write-verbose "The Nodes will be Clustered ( Single Node Clusters )" }
}


if ($AlwaysOn.IsPresent)
{
	workorder "We are going to Install an SQL Always On Cluster with $AAGNodes Nodes with size $Size in Domain $BuildDomain with Subnet $MySubnet using VMnet$VMnet"
	# if ($NoNMM -eq $false) {status "Networker Modules will be installed on each Node"}
	if ($NMM.IsPresent) { debug "Networker Modules will be intalled by User selection" }
}
if ($Exchange.IsPresent)
{
	workorder "We are going to Install Exchange 2013 $ex_cu with Nodesize $Size in Domain $BuildDomain with Subnet $MySubnet using VMnet$VMnet"
	if ($DAG.IsPresent)
	{
		workorder "We will form a $EXNodes-Node DAG"
	}
	if ($NMM.IsPresent) { debug "Networker Modules will be intalled by User selection" }
}
if ($HyperV.IsPresent)
{
	
	
}#end Hyperv.ispresent
########
write-verbose "Evaluating Machine Type, Please wait ..."
#### Eval CPU
$Numcores = (gwmi win32_Processor).NumberOfCores
$NumLogCPU = (gwmi win32_Processor).NumberOfLogicalProcessors
$CPUType = (gwmi win32_Processor).Name
$MachineMFCT = (gwmi win32_ComputerSystem).Manufacturer
$MachineModel = (gwmi win32_ComputerSystem).Model
##### Eval Memory #####
$Totalmemory = 0
$Memory = (get-wmiobject -class "win32_physicalmemory" -namespace "root\CIMV2").Capacity
foreach ($Dimm in $Memory) { $Totalmemory = $Totalmemory + $Dimm }
$Totalmemory = $Totalmemory / 1GB

Switch ($Totalmemory)
{
	
	
	{ $_ -gt 0 -and $_ -le 8 }
	{
		$Computersize = 1
		$Exchangesize = "XL"
	}
	{ $_ -gt 8 -and $_ -le 16 }
	{
		$Computersize = 2
		$Exchangesize = "XL"
	}
	{ $_ -gt 16 -and $_ -le 32 }
	{
		$Computersize = 3
		$Exchangesize = "TXL"
	}
	
	else
	{
		$Computersize = 3
		$Exchangesize = "XXL"
	}
	
}

If ($NumLogCPU -le 4 -and $Computersize -le 2)
{
	debug "Bad, Running $mySelf on a $MachineMFCT $MachineModel with $CPUType with $Numcores Cores and $NumLogCPU Logicalk CPUs and $Totalmemory GB Memory "
}
If ($NumLogCPU -gt 4 -and $Computersize -le 2)
{
	write-verbose "Good, Running $mySelf on a $MachineMFCT $MachineModel with $CPUType with $Numcores Cores and $NumLogCPU Logical CPU and $Totalmemory GB Memory"
	Write-Host "Consider Adding Memory "
}
If ($NumLogCPU -gt 4 -and $Computersize -gt 2)
{
	Status "Excellent, Running $mySelf on a $MachineMFCT $MachineModel with $CPUType with $Numcores Cores and $NumLogCPU Logical CPU and $Totalmemory GB Memory"
}

#write-verbose "Found VMware Path in registry: $VMWAREpath"
# $vmwareproduct = (Get-ChildItem  $vmware).VersionInfo.Product
# $vmwareversion = (Get-ChildItem  $vmware).VersionInfo.Productversion
get-vmwareversion


[switch]$Automount = $true
if ([System.Environment]::OSVersion.Version.Major -lt 6)
{
	debug"Sorry, $Myself only supports Windows Version 7 or higher"
	break
}
if ([System.Environment]::OSVersion.Version.Major -ge 6)
{
	switch ([System.Environment]::OSVersion.Version.Minor)
	{
		"1" {
			status "Warning:  Running Windows7 SP1, Automount of Sources.vhd might not work. Please refer to Help for additional Info"
			[switch]$Automount = $true
            }
		"2" {
			status "Running Windows 8.0, excellent"
			[switch]$Automount = $true
		} #end W8
		"3" {
			status "Running Windows 8.1, excellent"
			[switch]$Automount = $true
		} #end W81
		else { status "Not tested on vNext" }
		
		
	}# end switch
} #endif

if (!($Noautomount.IsPresent))
{
	
	if (($MountPath = (mountvol)) -match "Sources")
	{
		#test sources
		$MountPath = $MountPath | where { $_ -match "sources" }
		$MountPath = $MountPath.Trim()
		write-verbose "As of mountvol we are Assuming sources.vhd is already mounted in $MountPath, checking Versions"
	}#end test sources
	else
	{
		# end test sources
		if ($automount.ispresent)
		{
			if (!(Test-Path $Sourcevhd))
			{
				debug "$Sourcevhd not found. We need sources.vhd from labbuildr Package"
				debug "Please Download from Package"
				Start-Process $Sourceslink
				break
			} # end if test-path
			
            workorder "Calling external mounter to try mounting $Sourcevhd in $Driveletter`:\$Sources"
            switch ([System.Environment]::OSVersion.Version.Minor)
	        {
		    "1" {
                    Start-Process  "$psHome\powershell.exe" -Verb Runas -ArgumentList "-ExecutionPolicy Bypass -command $Builddir\mount-sourcevhd.ps1 -Sourcevhd $Sourcevhd -Driveletter $Driveletter -mount"
                }
            default 
            {
            		Start-Process  "$psHome\powershell.exe" -wait -Verb Runas -ArgumentList "-ExecutionPolicy Bypass -command $Builddir\mount-sourcesv2.ps1 -Sourcevhd $Sourcevhd -Driveletter $Driveletter"
            }
		    }
        write-host "Waiting for external mount"
        do
            { 
            Write-Host -NoNewline "."
            sleep 5
            }
            until (Get-ChildItem -Path $Sourcedir -ErrorAction SilentlyContinue)
        Write-Host
        }

    
    }
}

if ($nw.IsPresent) { workorder "Networker $nw_ver Node will be installed" }


###### Dirty Check on first run :-(  not my preferred style ########

write-verbose "Checking Environment"

if (!(Get-ChildItem $Builddir\$master.pass -ErrorAction SilentlyContinue))
{
	.$vmware $MasterVMX
	New-Item -ItemType File $Builddir\$master.pass
}

if ($NW.IsPresent -or $NWServer.IsPresent)
{
    if (!$Scenarioname) {$Scenarioname = "nwserver";$Scenario = 8}
	if (!($Acroread = Get-ChildItem -Path $Sourcedir -Filter 'adberdr*'))
	{
		status "Adobe reader not found ...."
	}
	
	else
	{
		$Acroread = $Acroread | Sort-Object -Property Name -Descending
		$LatestReader = $Acroread[0].Name
		write-verbose "Found Adobe $LatestReader"
	}
	
	##### Check Java
	if (!($Java = Get-ChildItem -Path $Sourcedir -Filter 'jre-7u*'))
	{
		debug "Java 7 not found, please download from www.java.com"
		break
	}
	$Java = $Java | Sort-Object -Property Name -Descending
	$LatestJava = $Java[0].Name
	write-verbose "Found Java $LatestJava"
} #end $nw


if (!($SourceOK = test-source -SourceVer $Sourcever -SourceDir $Sourcedir))
{
	$SourceOK
	break
}

if ($savedefaults.IsPresent)
{
$defaultsfile = New-Item -ItemType file $Builddir\defaults.xml -Force
Status "saving defaults to $Builddir\defaults.xml"
$config =@()
$config += ("<config>")
$config += ("<nmm_ver>$nmm_ver</nmm_ver>")
$config += ("<nw_ver>$nw_ver</nw_ver>")
$config += ("<master>$Master</master>")
$config += ("<sqlver>$SQLVER</sqlver>")
$config += ("<ex_cu>$ex_cu</ex_cu>")
$config += ("<vmnet>$VMnet</vmnet>")
$config += ("<BuildDomain>$BuildDomain</BuildDomain>")
$config += ("<MySubnet>$MySubnet</MySubnet>")
$config += ("<AddressFamily>$AddressFamily</AddressFamily>")
$config += ("<IPV6Prefix>$IPV6Prefix</IPV6Prefix>")
$config += ("<IPv6PrefixLength>$IPv6PrefixLength</IPv6PrefixLength>")
$config += ("<NoAutomount>$($Noautomount.IsPresent)</NoAutomount>")
$config += ("</config>")
$config | Set-Content $defaultsfile
}


if ($Gateway.IsPresent) {$AddGateway  = "-Gateway"}

If ($VMnet -ne 2) { debug "Setting different Network is untested and own Risk !" }
$MyVMnet = "vmnet$VMnet"

$IPv4Subnet = convert-iptosubnet $MySubnet


if (!$NoDomainCheck.IsPresent){
####################################################################
# DC Validation
$Nodename = $DCNODE
$CloneVMX = "$Builddir\$Nodename\$Nodename.vmx"
if (test-vmx $DCNODE)
{
	status "Domaincontroller already deployed, Comparing Workorder Paramters with Running Environment"
	test-dcrunning
    if ( $AddressFamily -match 'IPv4' )
        {
	    test-user -whois Administrator
	    write-verbose "Verifiying Domainsetup"
	    invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script checkdom.ps1
	    $BuildDomain, $RunningIP, $MyVMnet, $MyGateway = test-domainsetup
	    $IPv4Subnet = convert-iptosubnet $RunningIP
	    workorder "We will Use Domain $BuildDomain and Subnet $IPv4Subnet.0 for on $MyVMnet the Running Workorder"
	    If ($MyGateway) {$Gateway = $True 
        workorder "We will configure Default Gateway at $IPv4Subnet.103"
        Write-Verbose -Message $Gateway.IsPresent
        if ($Gateway.IsPresent) {$AddGateway  = "-Gateway"}
        Write-Verbose -Message $AddGateway
        }
    else
        {
        write-verbose " no domain check on IPv6only"
        }
    }
	
	
	
}#end test-domain

else
{
	
	###################################################
	# Part 1, Definition of Domain Controller
	###################################################
	#$Nodename = $DCNODE
	$DCName = $BuildDomain + "DC"
	#$CloneVMX = "$Builddir\$Nodename\$Nodename.vmx"
	$SourceScriptDir = "$Builddir\Scripts\dc\"
	###################################################
	Write-Verbose "IPv4Subnet :$IPv4Subnet"
    Write-Verbose "IPV6Prefix :$IPv6Prefix"
    Write-Verbose "IPv6Prefixlength : $IPv6PrefixLength"
    write-verbose $DCName
    Write-Verbose "AddressFamily =$AddressFamily"
    if ($PSCmdlet.MyInvocation.BoundParameters["verbose"].IsPresent)
    {

        
 
    Write-verbose "Now Pausing"
    pause
    }
	workorder "We will Build Domain $BuildDomain and Subnet $IPv4subnet.0  on $MyVMnet for the Running Workorder"
    if ($Gateway.IsPresent){ workorder "The Gateway will be $IPv4subnet.103"}
	
	$CloneOK = Invoke-expression "$Builddir\Scripts\clone-node.ps1 -Scenario $Scenario -Scenarioname $Scenarioname -Activationpreference 0 -Builddir $Builddir -Mastervmx $MasterVMX -Nodename $Nodename -Clonevmx $CloneVMX -vmnet $MyVMnet -Domainname $BuildDomain -Size 'L' -Mountdrive $Mountroot"
	
	###################################################
	#
	# DC Setup
	#
	###################################################
	if ($CloneOK)
	{
		write-verbose "Waiting for User logged on"

		test-user -whois Administrator
		Write-Host
        copy-tovmx -Sourcedir $NodeScriptDir
		copy-tovmx -Sourcedir $SourceScriptDir
        invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script new-dc.ps1 -Parameter "-dcname $DCName -IPv4subnet $IPv4subnet -IPv4Prefixlength $IPv4PrefixLength -IPv6PrefixLength $IPv6PrefixLength -IPv6Prefix $IPv6Prefix  -AddressFamily $AddressFamily $AddGateway $CommonParameter" -interactive -nowait
   
        
        if ($PSCmdlet.MyInvocation.BoundParameters["verbose"].IsPresent)
            {
            write-verbose "verbose enabled, Checkkeypress within VM $Dcname"
            While ($FileOK = (&$vmrun -gu Administrator -gp Password123! fileExistsInGuest $CloneVMX c:\Scripts\2.pass) -ne "The file exists.") { Write-Host -NoNewline "."; sleep $Sleep }
            }
        else 
            {
            status "Preparing Domain"
		    While ($FileOK = (&$vmrun -gu Administrator -gp Password123! fileExistsInGuest $CloneVMX c:\Scripts\2.pass) -ne "The file exists.") { Write-Host -NoNewline "."; sleep $Sleep }
            Write-Host
		    }
		test-user -whois Administrator
		invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script finishdomain.ps1 -Parameter "-domain $BuildDomain -domainsuffix $domainsuffix $CommonParameter" -interactive -nowait
		status "Creating Domain $BuildDomain"
		While ($FileOK = (&$vmrun -gu Administrator -gp Password123! fileExistsInGuest $CloneVMX c:\Scripts\3.pass) -ne "The file exists.") { Write-Host -NoNewline "."; sleep $Sleep }
		write-host
		status  "Domain Setup Finished"
		invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script dns.ps1 -Parameter "-IPv4subnet $IPv4Subnet -IPv4Prefixlength $IPV4PrefixLength -IPv6PrefixLength $IPv6PrefixLength -AddressFamily $AddressFamily  -IPV6Prefix $IPV6Prefix $CommonParameter"  -interactive
		invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script add_serviceuser.ps1 -interactive
	    write-verbose "Setting Password Policies"
		invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir  -Script pwpolicy.ps1 -interactive
        invoke-postsection
		# run-vmpowershell -Script gpo.ps1 -interactive
		# GPO on freetype domain ? Exchange Powershell Issues ?
	} #DC node End
}#end else createdc

####################################################################
### Scenario Deployment Begins .....                           #####
####################################################################
}

switch ($PsCmdlet.ParameterSetName)
{
	"Exchange"{
        
        if ($DAG.IsPresent){
        # we need ipv4
        if ($AddressFamily -notmatch 'ipv4')
            { 
            $EXAddressFamiliy = 'IPv4IPv6'
            }
        else
        {
        $EXAddressFamiliy = $AddressFamily
        }

        if ($DAGNOIP.IsPresent)
			{
				$DAGIP = ([System.Net.IPAddress])::None
			}
			else { $DAGIP = "$IPv4subnet.110" }
        }
        # else {$exnodes = 1} # end else dag
		
		foreach ($EXNODE in ($EXStartNode..($EXNodes+$EXStartNode-1)))
            {
			###################################################
			# Setup Exchange Node
			# Init
			$Nodeip = "$IPv4Subnet.11$EXNODE"
			$Nodename = "E2013N" + $EXNODE
			$CloneVMX = "$Builddir\$Nodename\$Nodename.vmx"
			$EXLIST += $CloneVMX
		    $SourceScriptDir = "$Builddir\Scripts\Exchange\"
		    $Exprereqdir = "$Sourcedir\EXPREREQ\"
            $AddonFeatures = "RSAT-ADDS, RSAT-ADDS-TOOLS, AS-HTTP-Activation, NET-Framework-45-Features" 
			###################################################
	    	
            Write-Verbose $IPv4Subnet
            Write-Verbose "IPv4PrefixLength = $IPv4PrefixLength"
            write-verbose $Nodename
            write-verbose $Nodeip
            Write-Verbose "IPv6Prefix = $IPV6Prefix"
            Write-Verbose "IPv6PrefixLength = $IPv6PrefixLength"
            Write-Verbose "Addressfamily = $AddressFamily"
            Write-Verbose "EXAddressFamiliy = $EXAddressFamiliy"
            if ($PSCmdlet.MyInvocation.BoundParameters["verbose"].IsPresent)
                { 
                Write-verbose "Now Pausing"
                pause
                }
		    test-dcrunning
		    status $Commentline
		    workorder "Creating Exchange Host $Nodename with IP $Nodeip in Domain $BuildDomain"
		    $CloneOK = Invoke-expression "$Builddir\Scripts\clone-node.ps1 -Scenario $Scenario -Scenarioname $Scenarioname -Activationpreference $EXNode -Builddir $Builddir -Mastervmx $MasterVMX -Nodename $Nodename -Clonevmx $CloneVMX -vmnet $MyVMnet -Domainname $BuildDomain -Exchange -Size $Exchangesize -Mountdrive $Mountroot "
		    ###################################################
		    If ($CloneOK)
            {
			write-verbose "Copy Configuration files, please be patient"
			copy-tovmx -Sourcedir $NodeScriptDir
			copy-tovmx -Sourcedir $SourceScriptDir
			copy-tovmx -Sourcedir $Exprereqdir
			write-verbose "Waiting for User"
			test-user -whois Administrator
			write-verbose "Joining Domain"
			domainjoin -Nodename $Nodename -Nodeip $Nodeip -BuildDomain $BuildDomain -AddressFamily $EXAddressFamiliy
			write-verbose "Setup Database Drives"
			invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script makedisks.ps1
			write-verbose "Setup Exchange Prereq Roles and features"
            invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script exchange_roles.ps1 -interactive -nowait
            While ($FileOK = (&$vmrun -gu $BuildDomain\Administrator -gp Password123! fileExistsInGuest $CloneVMX c:\Scripts\exchange_roles.ps1.pass) -ne "The file exists.")
			{
				sleep $Sleep
			} #end while
			
			write-verbose "Setup Exchange Prereqs"
			invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script exchange_pre.ps1 -interactive
			write-verbose "Setting Power Scheme"
			invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script powerconf.ps1 -interactive
			write-verbose "Installing Exchange, this may take up to 60 Minutes ...."
			invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script exchange.ps1 -interactive -nowait -Parameter "$CommonParameter -ex_cu $ex_cu"
			# run-vmpowershell -Script $exchange.ps1 -interactive -nowait
			status "Waiting for Pass 4 (Exchange Installed)"
			$EXSetupStart = Get-Date
			While ($FileOK = (&$vmrun -gu $BuildDomain\Administrator -gp Password123! fileExistsInGuest $CloneVMX c:\Scripts\exchange.ps1.pass) -ne "The file exists.")
			{
				sleep $Sleep
				runtime $EXSetupStart "Exchange"
			} #end while
			Write-Host
			test-user -whois Administrator
			write-verbose "Performing Exchange Post Install Tasks:"
    		invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script exchange_post.ps1 -interactive
            invoke-postsection

            if ($EXNode -eq ($EXNodes+$EXStartNode-1)) #are we last sever in Setup ?!
                {
                #####
                # change here for DAG Specific Setup....
                if ($DAG.IsPresent) 
                    {
				    write-verbose "Creating DAG"
				    invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -activeWindow -interactive -Script create_dag.ps1 -Parameter "-DAGIP $DAGIP -AddressFamily $EXAddressFamiliy $CommonParameter"
				    } # end if $DAG
                if (!($nouser.ispresent))
                    {
                    write-verbose "Creating Accounts and Mailboxes:"
	                do
				        {
					    ($cmdresult = &$vmrun -gu Administrator -gp Password123! runPrograminGuest  $CloneVMX -activeWindow -interactive c:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe ". 'C:\Program Files\Microsoft\Exchange Server\V15\bin\RemoteExchange.ps1'; Connect-ExchangeServer -auto; C:\Scripts\User.ps1 -subnet $IPv4Subnet -AddressFamily $AddressFamily -IPV6Prefix $IPV6Prefix $CommonParameter") 2>&1 | Out-Null
					    if ($BugTest) { debug $Cmdresult }
				        }
				    until ($VMrunErrorCondition -notcontains $cmdresult)
                    } #end creatuser
            }# end if last server
             
						
			write-verbose "Setting Local Security Policies"
			invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script create_security.ps1 -interactive
			
			
			########### Entering networker Section ##############
			if ($NMM.IsPresent)
			{
				write-verbose "Install NWClient"
				invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script nwclient.ps1 -interactive -Parameter $nw_ver
				write-verbose "Install NMM"
				invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script nmm.ps1 -interactive -Parameter $nmm_ver
			    write-verbose "Performin NMM Post Install Tasks"
			    invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script nmm_done.ps1 -interactive
			    checkpass -pass 5 -reboot 1
			    test-user -whois NMMBackupUser
			    Write-Host
			    #### to get rid of the temporary profile problem, we do restart a second time ....
			    if ($FileOK = (&$vmrun -gu Administrator -gp Password123! fileExistsInGuest $CloneVMX c:\USERS\NMMBACKUPUSER\NTUSER.DAT) -ne "The file exists.") { debug "Rebooting due to missing Profile"; invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script pass6.ps1 }

            }# end nmm
			########### leaving NMM Section ###################
		} # End Cloneok
		
	}	#end foreach exnode
		
		
		

	} #End Switchblock Exchange
	
	"AAG" {
		# we need a DC, so check it is running
		test-dcrunning
		status "Avalanching SQL Install on $AAGNodes Always On Nodes"
        $ListenerIP = "$IPv4Subnet.169"
        If ($AddressFamily -match 'IPv6')
            {
            $ListenerIP = "$IPV6Prefix$ListenerIP"
            } # end addressfamily
		$AAGLIST = @()
		foreach ($AAGNode in (1..$AAGNodes))
		{
			###################################################
			# Setup of a AlwaysOn Node
			# Init
			$Nodeip = "$IPv4Subnet.16$AAGNode"
			$Nodename = "AAGNODE" + $AAGNODE
			$CloneVMX = "$Builddir\$Nodename\$Nodename.vmx"
			$AAGLIST += $CloneVMX
			$SourceScriptDir = "$Builddir\Scripts\AAG\"
            $AddonFeatures = "RSAT-ADDS, RSAT-ADDS-TOOLS, AS-HTTP-Activation, NET-Framework-45-Features, Failover-Clustering, RSAT-Clustering, WVR"
			###################################################
			Write-Verbose $IPv4Subnet
            write-verbose $Nodeip
            Write-Verbose $Nodename
            Write-Verbose $ListenerIP
            if ($PSCmdlet.MyInvocation.BoundParameters["verbose"].IsPresent)
            { 
            Write-verbose "Now Pausing"
            pause
            }
			# Clone Base Machine
			status $Commentline
			status "Creating $Nodename with IP $Nodeip for Always On Availability Group"
			$CloneOK = Invoke-expression "$Builddir\Scripts\clone-node.ps1 -Scenario $Scenario -Scenarioname $Scenarioname -Activationpreference $AAGNode -Builddir $Builddir -Mastervmx $MasterVMX -Nodename $Nodename -Clonevmx $CloneVMX -vmnet $MyVMnet -Domainname $BuildDomain -size $Size -Mountdrive $Mountroot "
			###################################################
			If ($CloneOK)
			{
				write-verbose "Copy Configuration files, please be patient"
				copy-tovmx -Sourcedir $SourceScriptDir
				copy-tovmx -Sourcedir $NodeScriptDir
				write-verbose "Waiting for User"
				test-user -whois Administrator
				write-verbose "Joining Domain"
			    domainjoin -Nodename $Nodename -Nodeip $Nodeip -BuildDomain $BuildDomain -AddressFamily $AddressFamily
				write-verbose "Starting $SQLVER Setup on $Nodename"
				invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script setup_sql.ps1 -Parameter "-SQLVER $SQLVER" -interactive -nowait
				$SQLSetupStart = Get-Date
                invoke-postsection
			}
			
		} ## end foreach AAGNODE
		
		If ($CloneOK)
		{
			####### Check for all SQl Setups Done .. ####
			write-verbose "Checking SQL INSTALLED and Rebooted on All Machines"
			foreach ($AAGNode in $AAGLIST)
			{
				
				While ($FileOK = (&$vmrun -gu $builddomain\Administrator -gp Password123! fileExistsInGuest $AAGNode c:\Scripts\sql.pass) -ne "The file exists.")
				{
					runtime $SQLSetupStart "$SQLVER $Nodename"
				}
            write-verbose "Configuring UAC on $AAGNode"
            invoke-vmxpowershell -config $AAGNode -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script set-uac.ps1 -interactive
            Write-Verbose "Setting SQL Server Roles on $AAGNode"
            invoke-vmxpowershell -config $AAGNode -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script set-sqlroles.ps1 -interactive
            

			} # end aaglist
			
			write-host
			write-verbose "Forming AlwaysOn WFC Cluster"
	        invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script createcluster.ps1 -Parameter "-Nodeprefix 'AAGNODE' -IPAddress '$IPv4Subnet.160' -IPV6Prefix $IPV6Prefix -IPv6PrefixLength $IPv6PrefixLength -AddressFamily $AddressFamily $CommonParameter" -interactive
			
			write-verbose "Enabling AAG"
			invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script enableaag.ps1 -interactive
			
			write-verbose "Creating AAG"

			invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script createaag.ps1 -interactive -Parameter "-Nodeprefix 'AAGNODE' -AgName '$BuildDomain-AAGgroup' -DatabaseList 'AdventureWorks2012' -BackupShare '\\vmware-host\Shared Folders\Sources\AWORKS' -IPv4Subnet $IPv4Subnet -IPV6Prefix $IPV6Prefix -AddressFamily $AddressFamily $CommonParameter"
			foreach ($CloneVMX in $AAGLIST)
            {
                if ($NMM.IsPresent)
                    {
				    status "Installing Networker $nmm_ver an NMM $nmm_ver on all Nodes"
					status $CloneVMX
					write-verbose "Install NWClient"
					invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script nwclient.ps1 -interactive -Parameter $nw_ver
                    write-verbose "Configuring UAC"
                    invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script set-uac.ps1 -interactive
                    write-verbose "Finishing Always On"
                    invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script finishaag.ps1 -interactive -nowait
					test-user -whois SVC_SQLADM
					write-verbose "Install NMM"
					invoke-vmxpowershell -config $CloneVMX -ScriptPath $Targetscriptdir -Script nmm.ps1 -interactive -Parameter $nmm_ver -Guestuser "$builddomain\SVC_SQLADM" -Guestpassword "Password123!"
					} # end !NMM
				else 
                    {
                    invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script finishaag.ps1 -interactive -nowait
                    }# end else nmm
				}
			status "Done"			
     #       } #end aaglist
			
			
		}# end cloneok
	} # End Switchblock AAG
	
	"HyperV" {
        $Firstnode = 1 #for later use
        $Clusternum = 1 # for later use
        $FirstVMX =  "$Builddir\$Nodename\HVNODE$Firstnode.vmx"
		$HVLIST = @()
        $AddonFeatures = "RSAT-ADDS, RSAT-ADDS-TOOLS, AS-HTTP-Activation, NET-Framework-45-Features, Hyper-V, Hyper-V-Tools, Hyper-V-PowerShell, WindowsStorageManagementService"
        if ($Cluster.IsPresent) {$AddonFeatures = "$AddonFeatures, Failover-Clustering, RSAT-Clustering, WVR"}
		if ($ScaleIO.IsPresent) {$cloneparm = " -scaleio -disks $ScaleioDisks"}
        foreach ($HVNODE in ($Firstnode..$HyperVNodes))
		{
			if ($HVNODE -eq $HyperVNodes -and $SCVMM.IsPresent) { $Size = "L" }
			###################################################
			# Hyper-V  Node Setup
			# Init
			$Nodeip = "$IPv4Subnet.15$HVNode"
			$Nodename = "HVNODE$HVNode"
			$CloneVMX = "$Builddir\$Nodename\$Nodename.vmx"
			$SourceScriptDir = "$Builddir\Scripts\HyperV\"
            Write-Verbose $IPv4Subnet
            write-verbose $Nodeip
            Write-Verbose $Nodename
            Write-Verbose $AddonFeatures
            if ($PSCmdlet.MyInvocation.BoundParameters["verbose"].IsPresent)
                { 
                Write-verbose "Now Pausing"
                pause
                }
			###################################################
			# Clone BAse Machine
			status $Commentline
			status "Creating Hyper-V Node  $Nodename"
			# status "Hyper-V Development is still not finished and untested, be careful"
			test-dcrunning
			$CloneOK = Invoke-expression "$Builddir\Scripts\clone-node.ps1 -Scenario $Scenario -Scenarioname $Scenarioname -Activationpreference $HVNode -Builddir $Builddir -Mastervmx $MasterVMX -Nodename $Nodename -Clonevmx $CloneVMX -vmnet $MyVMnet -Domainname $BuildDomain -Hyperv -size $size -Mountdrive $Mountroot $cloneparm"
			###################################################
			If ($CloneOK)
			{
				write-verbose "Copy Configuration files, please be patient"
				copy-tovmx -Sourcedir $NodeScriptDir
				copy-tovmx -Sourcedir $SourceScriptDir
				write-verbose "Waiting for User"
				test-user -whois Administrator
				write-verbose "Joining Domain"
				domainjoin -Nodename $Nodename -Nodeip $Nodeip -BuildDomain $BuildDomain -AddressFamily $AddressFamily -AddOnfeatures $AddonFeatures
				
				# invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script hyperv.ps1
				# write-verbose "Installing Hyper-V Role"
				# checkpass -pass 4 -reboot 1
				test-user Administrator
				write-verbose "Setting up Virtual Machine"
				invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script createvm.ps1 -interactive
				# checkpass -pass 5 -reboot 1
				# test-user -whois Administrator
				invoke-postsection

                   if ($ScaleIO.IsPresent)
                    {
                    switch ($HVNODE){
                1
                    {
                    Write-Output " Installing MDM"
                    invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script install-scaleio.ps1 -Parameter "-Role MDM -disks $ScaleioDisks" -interactive -nowait
                    }
                2
                    {
                    Write-Output " Installing MDM"
                    invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script install-scaleio.ps1 -Parameter "-Role MDM -disks $ScaleioDisks" -interactive -nowait
                    }
                3
                    {                    
                    Write-Output " Installing TB"
                    Invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script install-scaleio.ps1 -Parameter "-Role TB -disks $ScaleioDisks" -interactive 
                    }
                default
                    {
                    invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script install-scaleio.ps1 -Parameter "-Role SDS -disks $ScaleioDisks" -interactive 
                    }
                }
                    }
                          
			} # end Clone OK
		} # end HV foreach
		########### leaving NMM Section ###################
		
		if ($Cluster.IsPresent)
		{
			write-host
			write-verbose "Forming Hyper-V Cluster"
			invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script createcluster.ps1 -Parameter "-Nodeprefix 'HVNODE' -IPAddress '$IPv4Subnet.150' -IPV6Prefix $IPV6Prefix -IPv6PrefixLength $IPv6PrefixLength -AddressFamily $AddressFamily $CommonParameter" -interactive
		}

                                                                                                                                                             
		if ($SCVMM.IsPresent)
		{
			write-verbose "Building SCVMM Setup Configruration"
			invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script vmm_config -interactive
			write-verbose "Installing SQL Binaries"
			invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script setup_sql.ps1 -Parameter "-SQLVER $SQLVER" -interactive -nowait
			$SQLSetupStart = Get-Date
			While ($FileOK = (&$vmrun -gu $builddomain\Administrator -gp Password123! fileExistsInGuest $CloneVMX c:\Scripts\sql.pass) -ne "The file exists.")
			{
				runtime $SQLSetupStart "$SQLVER"
			}
			write-host
			#test-user -whois "SVC_SQLADM"
			
			write-verbose "Installing SCVMM PREREQS"
			invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword  -ScriptPath $Targetscriptdir -Script vmm_pre.ps1 -interactive 
			write-verbose "Installing SCVMM"
			invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword  -ScriptPath $Targetscriptdir -Script vmm.ps1 -interactive 
			
		}
		if ($NMM.IsPresent)
		{
			write-verbose "Install NWClient"
			invoke-vmxpowershell -config $CloneVMX -ScriptPath $Targetscriptdir -Script nwclient.ps1 -interactive -Parameter $nw_ver -Guestuser $Adminuser -Guestpassword $Adminpassword
			write-verbose "Install NMM"
			invoke-vmxpowershell -config $CloneVMX -ScriptPath $Targetscriptdir -Script nmm.ps1 -interactive -Parameter $nmm_ver -Guestuser "$builddomain\SVC_SQLADM" -Guestpassword "Password123!"
		}# End NoNmm
<#
	if ($ScaleIO.IsPresent)
        {
        write-verbose "configuring mdm"
		invoke-vmxpowershell -config $FirstVMX -ScriptPath $Targetscriptdir -Script configure-mdm.ps1 -interactive -Parameter $CommonParameter -Guestuser $Adminuser -Guestpassword $Adminpassword
        }	#>
	} # End Switchblock hyperv


###### new SOFS Block
	"SOFS" {
        $AddonFeatures = "File-Services, RSAT-File-Services, RSAT-ADDS, RSAT-ADDS-TOOLS, Failover-Clustering, RSAT-Clustering, WVR"
		foreach ($Node in ($SOFSSTART..$SOFSNODES))
		{
			###################################################
			# Setup of a Blank Node
			# Init
			$Nodeip = "$IPv4Subnet.21$Node"
			$Nodename = "SOFSNode$Node"
			$CloneVMX = "$Builddir\$Nodename\$Nodename.vmx"
			$SourceScriptDir = "$Builddir\Scripts\SOFS\"
            $Size = "XL"
			###################################################
			# we need a DC, so check it is running
		    Write-Verbose $IPv4Subnet
            write-verbose $Nodename
            write-verbose $Nodeip
            Write-Verbose $Size
            if ($PSCmdlet.MyInvocation.BoundParameters["verbose"].IsPresent)
                { 
                Write-verbose "Now Pausing"
                pause
                }

			test-dcrunning
			
			
			# Clone Base Machine
			status $Commentline
			status "Creating SOFS Node Host $Nodename with IP $Nodeip"
			$CloneOK = Invoke-expression "$Builddir\Scripts\clone-node.ps1 -Scenario $Scenario -Scenarioname $Scenarioname -Activationpreference $Node -Builddir $Builddir -Mastervmx $MasterVMX -Nodename $Nodename -Clonevmx $CloneVMX -vmnet $MyVMnet -Domainname $BuildDomain -size $Size -Mountdrive $Mountroot "
			
			###################################################
			If ($CloneOK)
			{
				write-verbose "Copy Configuration files, please be patient"
				copy-tovmx -Sourcedir $NodeScriptDir
				copy-tovmx -Sourcedir $SourceScriptDir
				write-verbose "Waiting for User"
				test-user -whois Administrator
				write-verbose "Joining Domain"
				domainjoin -Nodename $Nodename -Nodeip $Nodeip -BuildDomain $BuildDomain -AddressFamily $AddressFamily -AddonFeatures $AddonFeatures
				invoke-postsection

			}# end Cloneok
			
		} # end foreach
		# if ($Cluster)
		# {
			write-host
			write-verbose "Forming SOFS Cluster"
			invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script createcluster.ps1 -Parameter "-Nodeprefix 'SOFS' -IPAddress '$IPv4Subnet.210' -IPV6Prefix $IPV6Prefix -IPv6PrefixLength $IPv6PrefixLength -AddressFamily $AddressFamily $CommonParameter" -interactive
			invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script new-sofsserver.ps1 -Parameter "-SOFSNAME 'SOFSServer'  $CommonParameter" -interactive

		# }

	} # End Switchblock SOFS



###### end SOFS Block


	
	"Blanknodes" {
		
		foreach ($Node in ($Blankstart..$BlankNodes))
		{
			###################################################
			# Setup of a Blank Node
			# Init
			$Nodeip = "$IPv4Subnet.18$Node"
			$Nodename = "Node$Node"
			$CloneVMX = "$Builddir\$Nodename\$Nodename.vmx"
			# $SourceScriptDir = "$Builddir\Scripts\Exchange\"
			###################################################
			# we need a DC, so check it is running
		    Write-Verbose $IPv4Subnet
            write-verbose $Nodename
            write-verbose $Nodeip
            if ($PSCmdlet.MyInvocation.BoundParameters["verbose"].IsPresent)
                { 
                Write-verbose "Now Pausing"
                pause
                }

			test-dcrunning
			
			
			# Clone Base Machine
			status $Commentline
			status "Creating Blank Node Host $Nodename with IP $Nodeip"
			if ($VTbit)
			{
				$CloneOK = Invoke-expression "$Builddir\Scripts\clone-node.ps1 -Scenario $Scenario -Scenarioname $Scenarioname -Activationpreference $Node -Builddir $Builddir -Mastervmx $MasterVMX -Nodename $Nodename -Clonevmx $CloneVMX -vmnet $MyVMnet -Domainname $BuildDomain -Hyperv -size $size -Mountdrive $Mountroot"
			}
			else
			{
				$CloneOK = Invoke-expression "$Builddir\Scripts\clone-node.ps1 -Scenario $Scenario -Scenarioname $Scenarioname -Activationpreference $Node -Builddir $Builddir -Mastervmx $MasterVMX -Nodename $Nodename -Clonevmx $CloneVMX -vmnet $MyVMnet -Domainname $BuildDomain -size $Size -Mountdrive $Mountroot "
			}
			###################################################
			If ($CloneOK)
			{
				write-verbose "Copy Configuration files, please be patient"
				copy-tovmx -Sourcedir $NodeScriptDir
				write-verbose "Waiting for User"
				test-user -whois Administrator
				write-verbose "Joining Domain"
				domainjoin -Nodename $Nodename -Nodeip $Nodeip -BuildDomain $BuildDomain -AddressFamily $AddressFamily -AddOnfeatures $AddonFeatures
				invoke-postsection
			}# end Cloneok
			
		} # end foreach
	} # End Switchblock Blanknode
	
	"Spaces" {
		
		foreach ($Node in (1..$SpaceNodes))
		{
			###################################################
			# Setup of a Blank Node
			# Init
			$Nodeip = "$IPv4Subnet.17$Node"
			$Nodename = "Spaces$Node"
			$CloneVMX = "$Builddir\$Nodename\$Nodename.vmx"
			$SourceScriptDir = "$Builddir\Scripts\Spaces"
			###################################################
			# we need a DC, so check it is running
		    Write-Verbose $IPv4Subnet
            write-verbose $Nodename
            write-verbose $Nodeip
            if ($PSCmdlet.MyInvocation.BoundParameters["verbose"].IsPresent)
                { 
                Write-verbose "Now Pausing"
                pause
                }

			test-dcrunning
			if ($SpaceNodes -gt 1) {$AddonFeatures = "Failover-Clustering, RSAT-Clustering"}
			status $Commentline
			status "Creating Storage Spaces Node Host $Nodename with IP $Nodeip"
			$CloneOK = Invoke-expression "$Builddir\Scripts\clone-node.ps1 -Scenario $Scenario -Scenarioname $Scenarioname -Activationpreference $Node -Builddir $Builddir -Mastervmx $MasterVMX -Nodename $Nodename -Clonevmx $CloneVMX -vmnet $MyVMnet -Domainname $BuildDomain -size $Size -Mountdrive $Mountroot -AddOnfeatures $AddonFeature"
			###################################################
			If ($CloneOK)
			{
				write-verbose "Copy Configuration files, please be patient"
				copy-tovmx -Sourcedir $NodeScriptDir
				write-verbose "Waiting for User"
				test-user -whois Administrator
				write-verbose "Joining Domain"
				domainjoin -Nodename $Nodename -Nodeip $Nodeip -BuildDomain $BuildDomain -AddressFamily $AddressFamily -AddOnfeatures $AddonFeatures
				invoke-postsection
			}# end Cloneok
			
		} # end foreach
		
		if ($SpaceNodes -gt 1)
		{
			write-host
			write-verbose "Forming Storage Spaces Cluster"
			invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script createcluster.ps1 -Parameter "-Nodeprefix 'Spaces' -IPAddress '$IPv4Subnet.170' -IPV6Prefix $IPV6Prefix -IPv6PrefixLength $IPv6PrefixLength -AddressFamily $AddressFamily $CommonParameter" -interactive
		}
		
		
	} # End Switchblock Spaces	
	"SQL" {
		$Node = 1 # chnge when supporting Nodes Parameter and AAG
		###################################################
		# Setup of a Blank Node
		# Init
		$Nodeip = "$IPv4Subnet.19$Node"
		$Nodename = "SQLNODE$Node"
		$CloneVMX = "$Builddir\$Nodename\$Nodename.vmx"
		$SourceScriptDir = "$Builddir\Scripts\SQL\"
		###################################################
		# we need a DC, so check it is running
        Write-Verbose $IPv4Subnet
        write-verbose $Nodename
        write-verbose $Nodeip
        if ($PSCmdlet.MyInvocation.BoundParameters["verbose"].IsPresent)
             { 
             Write-verbose "Now Pausing"
             pause
             }
        if ($Cluster.IsPresent) {$AddonFeatures = "Failover-Clustering"}
# -AddOnfeatures $AddonFeatures
		test-dcrunning
		# Clone Base Machine
		status $Commentline
		status "Creating $SQLVER Node $Nodename with IP $Nodeip"
		$CloneOK = Invoke-expression "$Builddir\Scripts\clone-node.ps1 -Scenario $Scenario -Scenarioname $Scenarioname -Activationpreference $Node -Builddir $Builddir -Mastervmx $MasterVMX -Nodename $Nodename -Clonevmx $CloneVMX -vmnet $MyVMnet -Domainname $BuildDomain -size $Size -Mountdrive $Mountroot "
		###################################################
		If ($CloneOK)
		{
			write-verbose "Copy Configuration files, please be patient"
			copy-tovmx -Sourcedir $NodeScriptDir
			write-verbose "Copy Setup files, please be patient"
			copy-tovmx -Sourcedir $SourceScriptDir
			write-verbose "Waiting for User"
			test-user -whois Administrator
			write-verbose "Joining Domain"
			domainjoin -Nodename $Nodename -Nodeip $Nodeip -BuildDomain $BuildDomain -AddressFamily $AddressFamily -AddOnfeatures $AddonFeatures
			write-verbose "Installing SQL Binaries"
			invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script setup_sql.ps1 -Parameter "-SQLVER $SQLVER" -interactive -nowait
			$SQLSetupStart = Get-Date
			While ($FileOK = (&$vmrun -gu $builddomain\Administrator -gp Password123! fileExistsInGuest $CloneVMX c:\Scripts\sql.pass) -ne "The file exists.")
			{
				runtime $SQLSetupStart "$SQLVER"
			}
			write-host
			test-user -whois administrator
			if ($NMM.IsPresent)
			{
				write-verbose "Install NWClient"
				invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script nwclient.ps1 -interactive -Parameter $nw_ver
				write-verbose "Install NMM"
				invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script nmm.ps1 -interactive -Parameter $nmm_ver
			}# End NoNmm
			
			invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script finish_sql.ps1 -interactive -Parameter
			invoke-postsection
		}# end Cloneok
	} #end Switchblock SQL
    "Isilon" {
		
		foreach ($Node in (1..$isi_nodes))
		{
			###################################################
			# Setup of a Blank Node
			# Init
			$Nodename = "isi_Node$Node"
			$CloneVMX = "$Builddir\$Nodename\$Nodename.vmx"
            $MasterVMX = "$Builddir\$isimaster\$isimaster.vmx"
			# $SourceScriptDir = "$Builddir\Scripts\Exchange\"
			###################################################
			# we need a DC, so check it is running
			# test-dcrunning
		    # Clone Base Machine
			status $Commentline
			status "Creating isilon Node $Nodename"
		
				$CloneOK = Invoke-expression "$Builddir\Scripts\clone-node.ps1 -Scenario $Scenario -Scenarioname $Scenarioname -Activationpreference $Node -Builddir $Builddir -Mastervmx $MasterVMX -Nodename $Nodename -Clonevmx $CloneVMX -vmnet $MyVMnet -Isilon  -Domainname $BuildDomain -size $Size -Mountdrive $Mountroot "
			}
			###################################################
			If ($CloneOK){
			
			}# end Cloneok
			
		status "Isilon Setup done"
        workorder "In cluster Setup, please spevcify the following Values already propagated in ad:"
        Progress "Assign internal Addresses from .41 to .56 according to your Subnet"
        Write-Host -NoNewline -ForegroundColor DarkCyan "Cluster Name  ...........: "
        Status "isi2go"
        Workorder -NoNewline -ForegroundColor DarkCyan  "Interface int-a"
        Write-Host -NoNewline -ForegroundColor DarkCyan "Netmask int-a............: "
        Status "255.255.255.0"
        Write-Host -NoNewline -ForegroundColor DarkCyan "Internal Low IP .........: "
        Status "your vmnet1 .41"
        Write-Host -NoNewline -ForegroundColor DarkCyan "Intenal High IP .........: "
        Status "your vmnet1 .56"      
        Workorder -NoNewline -ForegroundColor DarkCyan  "Interface ext-1"        
        Write-Host -NoNewline -ForegroundColor DarkCyan "Netmask ext-1............: "
        Status "255.255.255.0"
        Write-Host -NoNewline -ForegroundColor DarkCyan "External Low IP .........: "
        Status "$IPv4Subnet.41"
        Write-Host -NoNewline -ForegroundColor DarkCyan "External High IP ........: "
        Status "$IPv4Subnet.56"
        Write-Host -NoNewline -ForegroundColor DarkCyan "Default Gateway..........: "
        Status "$MySubnet.103"
        Workorder "Configure Smartconnect"
        Write-Host -NoNewline -ForegroundColor DarkCyan "smartconnect Zone Name...: "
        Status "onefs.$BuildDomain.local"
        Write-Host -NoNewline -ForegroundColor DarkCyan "smartconnect Service IP .: "
        Status "$IPv4Subnet.40"
        Workorder -NoNewline -ForegroundColor DarkCyan  "Configure DNS Settings"
        Write-Host -NoNewline -ForegroundColor DarkCyan "DNS Server...............: "
        Status "$IPv4Subnet.10"
        Write-Host -NoNewline -ForegroundColor DarkCyan "Search Domain............: "
        Status "$BuildDomain.local"
        ######### Setting Master back to Default Master
		$MasterVMX = $masterconfig.FullName
        ###############################################
        } # end isilon

}



if ($NW.IsPresent -or $NWServer.IsPresent)
{
	###################################################
	# Networker Setup
	###################################################
	$Nodeip = "$IPv4Subnet.103"
	$Nodename = $NWNODE
	$CloneVMX = "$Builddir\$Nodename\$Nodename.vmx"
    [string]$AddonFeatures = "RSAT-ADDS, RSAT-ADDS-TOOLS, AS-HTTP-Activation, NET-Framework-45-Features" 
	###################################################
	status $Commentline
	status "Creating Networker Server $Nodename"
  	Write-Verbose $IPv4Subnet
    write-verbose $Nodename
    write-verbose $Nodeip
    if ($PSCmdlet.MyInvocation.BoundParameters["verbose"].IsPresent)
        { 
        Write-verbose "Now Pausing"
        pause
        }

	test-dcrunning
	$CloneOK = Invoke-expression "$Builddir\Scripts\clone-node.ps1 -Scenario $Scenario -Scenarioname $Scenarioname -Activationpreference 9 -Builddir $Builddir -Mastervmx $MasterVMX -Nodename $Nodename -Clonevmx $CloneVMX -vmnet $MyVMnet -Domainname $BuildDomain -NW $AddGateway -size $Size -Mountdrive $Mountroot"
	###################################################
	If ($CloneOK)
	{
		$SourceScriptDir = "$Builddir\Scripts\NW\"
		write-verbose "Copy Configuration files, please be patient"
		copy-tovmx -Sourcedir $NodeScriptDir
		copy-tovmx -Sourcedir $SourceScriptDir
		write-verbose "Waiting for User"
		test-user -whois Administrator
		write-verbose "Joining Domain"
				domainjoin -Nodename $Nodename -Nodeip $Nodeip -BuildDomain $BuildDomain -AddressFamily $AddressFamily
		# Setup Networker
		While (([string]$UserLoggedOn = (&$vmrun -gu Administrator -gp Password123! listProcessesInGuest $CloneVMX)) -notmatch "owner=$BuildDomain\\Administrator") { write-host -NoNewline "." }
		write-verbose "Building Networker Server"
		############ java
		write-verbose "installing JAVA"
		$Parm = "/s"
		$Execute = "\\vmware-host\Shared Folders\Sources\$LatestJava"
		do
		{
			($cmdresult = &$vmrun -gu Administrator -gp Password123! runPrograminGuest  $CloneVMX -activeWindow  $Execute $Parm) 2>&1 | Out-Null
			write-log "$origin $cmdresult"
		}
		until ($VMrunErrorCondition -notcontains $cmdresult)
		write-log "$origin $cmdresult"
		###################adobe
		write-verbose "installing Acrobat Reader"
		$Parm = "/sPB /rs"
		$Execute = "\\vmware-host\Shared Folders\Sources\$LatestReader"
		do
		{
			($cmdresult = &$vmrun -gu Administrator -gp Password123! runPrograminGuest  $CloneVMX -activeWindow  $Execute $Parm) 2>&1 | Out-Null
			write-log "$origin $cmdresult"
		}
		until ($VMrunErrorCondition -notcontains $cmdresult)
		write-log "$origin $cmdresult"
		###################
		
		write-verbose "installing Networker Server"
		invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script nwserver.ps1 -Parameter $nw_ver
		write-verbose "Waiting for NSR Media Daemon to start"
		While (([string]$UserLoggedOn = (&$vmrun -gu Administrator -gp Password123! listProcessesInGuest $CloneVMX)) -notmatch "nsrmmdbd.exe") { write-host -NoNewline "." }
		write-host
		invoke-postsection
		write-verbose "Creating Networker users"
		invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script nsruserlist.ps1 -interactive
		status "Creating AFT Device"
		invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script create-nsrdevice.ps1 -interactive -Parameter "-AFTD AFTD1"
		write-verbose "Creating Networker Clients, Groups and Saveset resources"
		invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script create-nsrres.ps1 -interactive
		do
		{
			($cmdresult = &$vmrun -gu Administrator -gp Password123! runPrograminGuest  $CloneVMX -activeWindow -interactive -nowait "C:\Program Files (x86)\Java\jre7\bin\javaws.exe" -import -silent -system -shortcut -association http://localhost:9000/gconsole.jnlp
			) 2>&1 | Out-Null
			write-log "$origin $cmdresult"
		}
		until ($VMrunErrorCondition -notcontains $cmdresult)
		write-log "$origin $cmdresult"
        if ($Gateway.IsPresent){
                write-verbose "Opening Firewall on Networker Server for your Client"
                invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script firewall.ps1 -interactive
                progress "Installing NAT Gateway, Please configure Manually"
                status " please visit https://community.emc.com/blogs/bottk/2014/04/11/updatenetworker2go-now-supports-nat-gateway-on-nwserver for Details"
        		invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script add-rras.ps1 -interactive
                checkpass -pass rras -reboot 1

        }


		status "Starting DAG Backup"
		invoke-vmxpowershell -config $CloneVMX -Guestuser $Adminuser -Guestpassword $Adminpassword -ScriptPath $Targetscriptdir -Script start-savegrp.ps1 -interactive -nowait
		progress "Please finish NMC Setup by Double-Clicking Networker Management Console from Desktop on $NWNODE.$builddomain.local"
		
	}
} #Networker End

$endtime = Get-Date
$Runtime = ($endtime - $Starttime).TotalMinutes
status "Finished Creation of $mySelf in $Runtime Minutes "
status "Deployed VM´s in Scenario $Scenarioname"
get-vmx | where scenario -match $Scenarioname | ft vmxname,state,activationpreference

return
