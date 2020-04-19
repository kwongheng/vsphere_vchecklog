<# 
.SYNOPSIS  
 Check hardware status of ESXi hosts

.DESCRIPTION 
 Check hardware status of ESXi hosts 
 
.NOTES
## 1.0: Kelvin, 12/dec/2019 : Base version

#>

function Get-VMHostHealthState {

$r = @()
$status = "GREEN"

$VMHosts = Get-VMHost
foreach ($VMHost in $VMHosts) {
  $VMHostHealth = (Get-view $VMHost.id).runtime.healthSystemRuntime.systemHealthInfo.NumericSensorInfo | ? {$_.HealthState.Label -notmatch 'Green'}
  if (![string]::IsNullOrEmpty($VMHostHealth)) {
    $status = "RED" 
    $r += "$($VMHost.name), $($VMHostHealth.Name), $($VMHostHealth.SensorType), $($VMHostHealth.HealthState.Label)"  
  }  
}

return @($r,$status)

} 

$Subject =  "ESXi Hosts Hardware Status"

$result = Get-VMHostHealthState

