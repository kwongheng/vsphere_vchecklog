<# 
.SYNOPSIS  
 Checks for storage path status of ESXi hosts

.DESCRIPTION 
 Targetted for Hosts ruuning PowerPath as most of the scripts you find on the net are just for standard storage adapters.
 Checks for dead paths and standby paths. Also checks if the total paths is an odd number, this means there is a miconfiguration
 Odd paths on USB controller is ignored, but will flag if it shoes dead or standby.
  
.NOTES
## 1.0: Kelvin, 31/dec/2019 : Base version
## 1.1: Kelvin, 05/feb/2020 
##   Removed model, target and devices from error message
## 1.2: Kelvin, 05/feb/2020 
##   Re-instated $StorPModel as its used for evaluation. Also ensured that vmhba name exact match (with ":")
##   when grouping; previously its grouping vmhba32 and vmhba3 which is wrong.

#>

function Get-VMHostStorPStatus {

$r = @()
$status = "GREEN"

$VMHosts = Get-VMHost | ? {$_.ConnectionState -notmatch "(Not.Res|Disconn)"} | Sort-Object name

foreach ($VMhost in $VMhosts) {

  #This is required compared to other approaches in the net due to us using powerpath
  [ARRAY]$adapters = $VMHost.ExtensionData.config.StorageDevice.PlugStoreTopology.adapter
  $PlugStorePath = $VMhost.ExtensionData.Config.StorageDevice.PlugStoreTopology.path

  foreach ($adapter in $adapters) {
    $vmhba = $adapter.adapter.split("-")[2]
    $StorPModel = ($VMhost.ExtensionData.Config.StorageDevice.HostBusAdapter | ? {$_.device -eq $vmhba} ).model 
    $pathState = $VMHost.ExtensionData.config.MultipathState.path | ? { $_.Name -match $vmhba+":"} | Group-Object -Property pathstate
    #$StorPTarget = [INT]($PlugStorePath | ? { $_.name -match $vmhba } | Group-Object -property targetnumber | Measure-Object).count
    #$StorPDevices = [INT]($PlugStorePath | ? { $_.name -match $vmhba } | Group-Object -property device | Measure-Object).count
    $StorPActiveP = [INT]($pathState | ? { $_.Name -eq "active"}).Count
    $StorPDeadP = [INT]($pathState | ? { $_.Name -eq "dead"}).Count
    $StorPStandbyP = [INT]($pathState | ? { $_.Name -eq "standby"}).Count

    $errmsg = ""
    $thisStatus = "GREEN"
    if ($StorPDeadP -gt 0) {
      $errmsg = "Dead paths found:"
      $thisstatus = $status = "RED"
    }
    elseif ($StorPStandbyP -gt 0) {
      $errmsg += "Standby paths found:"
      #don't override a RED status
      if($status -ne "RED"){$thisStatus = $status = "AMBER"}
    }    
    elseif ($StorPActiveP % 2 -ne 0 -and $StorPModel -notmatch "USB") {
      $errmsg += "Odd paths found, check config:"
      #don't override a RED status
      if($status -ne "RED"){$thisStatus = $status = "AMBER"}
    }

    if ($thisStatus -ne "GREEN") {
      $errmsg += "{0},{1},ACTIVE:{2},DEAD:{3},Standby:{4}" -f $VMHost.Name,$vmhba,$StorPActiveP,$StorPDeadP,$StorPStandbyP
      $r += $errmsg
    }

  }
}

return @($r,$status)

} 

$Subject =  "Host Storage Paths Health"

$result = VMHostStorPStatus


