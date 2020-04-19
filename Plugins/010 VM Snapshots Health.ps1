<# 
.SYNOPSIS  
 Checks the clusters for snapshot issues

.DESCRIPTION 
 In vcheck this is done via 3 scripts. I consolidated them into one in order to reduce
 execution time as loopping thru VM snapshots is time consuming and reduce repeated coding
 
 This scripts, thus scans all valid clusters for for old snapshots and checks for:
  * old snapshots
  * phantom snapshots
  * VMs that need consolidation
  
 As we need to ensure per run don't exceed 1 hour and due to the long execution time in large sites,
 a limited number of VMs are scanned per run and will cycle through all VMs until all is completed
 A file for each vc is used to track the cycles, delete the file if you want to start a new cycle.
 VMs that have issues are stored in a file and added to be rescanned each cycle until they are resolved

 Add the following variables globalvariable.ps1 file to over default:
 $SnapshotAge           - Default is 5 (days), determines how long before you flag snapshot for attention
 $SnapShotVMLimit       - Default is 500. By limiting #VMs checked, this reduces execution time. 
 $SnapshotExcludeName   - regex string to ignore some snapshots names, like those used by PCF
 $SnapshotIgnoreCluster - regex string if you want to ignore some clusters
 $SnapshotIgnoreVmName - regex string if you wnat to ignore some VMs

.NOTES
## 1.0: Kelvin, 12/dec/2019 : Base version
## 2.0: Kelvin, 13/jan/2020 : Redone using scan cycles
## 3.0: Kelvin, 30/jan/2020 : Redone next logic, now tracking cycles in file, previous logic too difficult
## 3.1: Kelvin, 30/jan/2020 : Fixed some spelling mistake it should be @params at line 136
## 3.2: Kelvin, 06/feb/2020 : $IssueVMs is not defined on 1st run because $vmlist does not exists. FIXED
## 3.3: Kelvin, 03/Mar/2020 : Fixed logic flaw where VMs with issue is never rechecked.
                              Changed default snapshotage to 5
## 3.4: Kelvin, 05/Mar/2020 : Correct typo where $result was accidently renames as $StatueMessageesult
#>


function Get-SnapshotHealth {

param(
 [Parameter(Mandatory=$false)]
 [Int]$SnapshotAge=5,
 [Parameter(Mandatory=$false)]
 [Int]$SnapShotVMLimit=500,
 [Parameter(Mandatory=$false)]
 [String]$SnapshotExcludeName="excludeme",
 [Parameter(Mandatory=$false)]
 [String]$SnapshotIgnoreCluster="excludeme",
 [Parameter(Mandatory=$false)]
 [String]$SnapshotIgnoreVmName="Excludeme"
)

#used for tracking VM with snaphot issues and cycles
$VMList = $PluginsFolder + "Snapshot_VM_List_" + $Hostname + ".txt"
$CycleTracker = $PluginsFolder + "Snapshot_cycle_" + $Hostname + ".txt"

#Grab the list of VMs with issues and reset the list
if (!(Test-Path $VMList)) {
  New-Item $VMList -ItemType "file" | Out-Null
}
$IssueVMs = Get-Content $VMlist
Clear-Content $VMlist


#Setup the next cycle or restart cycle if no cycletracker file
if (Test-Path $CycleTracker) {
  [int]$CurrentCycle = get-content $CycleTracker
}
else {
  New-Item $CycleTracker -ItemType "file" | Out-Null
  $CurrentCycle = 0  
}
$CurrentCycle + 1 | Set-Content $CycleTracker 

$VMSkip = $CurrentCycle * $SnapShotVMLimit
Write-Log "Processing... $($Subject):Collecting VMs, cycle:$CurrentCycle skipping:$VMSkip"

$VMs = Get-Cluster | ? {$_.name -notmatch $SnapshotIgnoreCluster} | 
  Get-VM | ? {$_.name -notmatch $SnapshotIgnoreVmName} | select -first $SnapShotVMLimit -skip $VMSkip


#if no more VMs are found, just check the current list of saved VMs and start new cycle
#if not append existing list to current list of VMs
if ($VMs.count -eq 0) {
  $VMs = $IssueVMs | % {Get-VM $_} 

  Write-Log "Processing... $($Subject):End of collection, will start a new cycle on next scan"
  $CurrentCycle = 0  
  $CurrentCycle | Out-file $CycleTracker | Out-Null
  $IssueVMS | Add-Content $VMList 
}
else {
  $VMs += $IssueVMs | % {Get-VM $_}
}
$VMs = $VMs | Sort-Object -Unique  #remove duplicates

$StatusMessage = @()
$StatusText = "GREEN"
   
#start of health checks
$Subtitle = "VMs with Snapshots Over $SnapshotAge Days Old"
Write-Log "Processing... $($Subject):$Subtitle"
$Items = $VMs | Get-Snapshot | ? { $_.name -notmatch $SnapshotExcludeName -and $_.Created -lt $(Date).AddDays(-$SnapshotAge) }   
$Items | % {$_.vm.name | Add-Content $VMList}
if (!([string]::IsNullOrEmpty($Items))) {
  $StatusMessage += $Subtitle
  $Items | % { $StatusMessage += "$($_.vm.name), $($_.name), $($_.created)"}  
  $StatusText = "RED"
}

$Subtitle =  "VMs with Snapshots that need consolidation"
Write-Log "Processing... $($Subject):$Subtitle"
$Items =  $VMs | ?{$_.ExtensionData.RunTime.ConsolidationNeeded}
$Items | % {$_.name | Add-Content $VMList}
if (!([string]::IsNullOrEmpty($Items))) {
  $StatusMessage += $Subtitle
  $Items | % { $StatusMessage += "$($_.name)"}  
  $StatusText = $(if($StatusText -eq "GREEN"){"AMBER"}else{$StatusText})
}

$Subtitle = "VMs with Phantom Snapshots"
Write-Log "Processing... $($Subject):$Subtitle"
$Items =  $VMs | Get-HardDisk | ? {$_.Filename -match "-\d{6}.vmdk"} | ? {!($_.parent | Get-Snapshot)} 
$Items | % {$_.parent.name | Add-Content $VMList}
if (!([string]::IsNullOrEmpty($Items))) {
  $StatusMessage += $Subtitle
  $Items | % { $StatusMessage += "$($_.parent.name), $($_.filename)"}  
  $StatusText = $(if($StatusText -eq "GREEN"){"AMBER"} else{$StatusText})
}


#remove duplicates from list
(Get-Content $VMList | Sort-Object -Unique) | Out-File $VMList -Force | Out-Null

return @($StatusMessage,$StatusText)

}

$Subject =  "VM Snapshots Health Check"

$params = @{}
If (Get-Variable SnapshotAge -ErrorAction Ignore) {$params += @{SnapshotAge=$SnapshotAge}}
If (Get-Variable SnapShotVMLimit -ErrorAction Ignore) {$params += @{SnapShotVMLimit=$SnapShotVMLimit}}
If (Get-Variable SnapshotExcludeName -ErrorAction Ignore) {$params += @{SnapshotExcludeName=$SnapshotExcludeName}}
If (Get-Variable SnapshotIgnoreCluster -ErrorAction Ignore) {$params += @{SnapshotIgnoreCluster=$SnapshotIgnoreCluster}}
If (Get-Variable SnapshotIgnoreVmName -ErrorAction Ignore) {$params += @{SnapshotIgnoreVmName=$SnapshotIgnoreVmName}}

$result = Get-SnapshotHealth @params
