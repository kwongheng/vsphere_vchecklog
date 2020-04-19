<# 
.SYNOPSIS  
 Checks up time for Mgmt VMs are within scope

.DESCRIPTION 
 This scripts ensures that mgmt VMs are reboot within required number of days,
 this mostly impacts linux boxed due to fsck rescan requirements to keep the filesystem healthy, 
 but there is no harm extending to all other OSes.
 
 Add the following variables globalvariable.ps1 file to over default:
 $UptimeDaysWarn - Default is 300 (days), warning threshold before VMs should be rebooted
 $UptimeDaysCrit - Default is 360 (days), critical threshold before VMs should be rebooted
 $MgmtVMMatch    - Default is "mgmt" (assuming your mgmt VMs have that in their name), regex string to include the VMs you want to watch
 $MgmtVMNotMatch - Regex string to ignore VMs from the ones above

.NOTES
## 1.0: Kelvin, 12/dec/2019 : Base version
## 1.1: Kelvin, 07/feb/2020 : Changed stats from sys.uptime.latest to sys.osuptime.latest
  sys.uptime.latest resets everytime there is a vmotion and not usable. 
  changed uptime defaults to 300, 360

#>

function Get-VMUpdate {

param(
 [Parameter(Mandatory=$false)]
 [Int]$UptimeDaysWarn=300,
 [Parameter(Mandatory=$false)]
 [Int]$UptimeDaysCrit=360,
 [Parameter(Mandatory=$false)]
 [String]$MgmtVMMatch="mgmt",
 [Parameter(Mandatory=$false)]
 [String]$MgmtVMNotMatch="excludeme"
)


$r = @()
$status = "GREEN"

#get-stat is outside the loop optimize execution time
$VMs = Get-VM | ?{$_.name -match $MgmtVMMatch -and $_.name -notmatch $MgmtVMNotMatch -and $_.PowerState -eq "PoweredOn"} | sort name
$VMStats = Get-Stat -Entity $VMs -Stat sys.osuptime.latest -Realtime -MaxSamples 1
foreach ($VMStat in $VMStats) {
  $VMDaysUp = (New-Timespan -Seconds $VMStat.Value).Days
  $VMName = $VMStat.Entity
  Switch ($VMDaysUp) {
    {$_ -ge $UptimeDaysCrit} 
      {
      $r += "$VMName, $VMDaysUp Days" ;
      $status = "RED" ;
      break ;
      }
    {$_ -ge $UptimeDaysWarn}
      {
      $r += "$VMName, $VMDaysUp Days" ;
      $status = $(if($status -ne "RED"){"AMBER"}else{$status}) ;
      break ;
      }  
  }
}

return @($r,$status)

} 

$Subject =  "Management VMs Reboot Required"

$params = @{}
If (Get-Variable UptimeDaysWarn -ErrorAction Ignore) {$params += @{UptimeDaysWarn=$UptimeDaysWarn}}
If (Get-Variable UptimeDaysCrit -ErrorAction Ignore) {$params += @{UptimeDaysCrit=$UptimeDaysCrit}}
If (Get-Variable MgmtVMMatch -ErrorAction Ignore) {$params += @{MgmtVMMatch=$MgmtVMMatch}}
If (Get-Variable MgmtVMNotMatch -ErrorAction Ignore) {$params += @{MgmtVMNotMatch=$MgmtVMNotMatch}}

$result = Get-VMUpdate @params


