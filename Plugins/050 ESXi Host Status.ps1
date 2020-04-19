<# 
.SYNOPSIS  
 Checks ESXi host status

.DESCRIPTION 
 Checks if ESXi hosts are in disconnect or offline state.

 Add the following variables globalvariable.ps1 file to over default:
 $VMHostNotMatch - Regex string to ignore hosts you don't want to check

.NOTES
## 1.0: Kelvin, 12/dec/2019 : Base version

#>

function Get-VMHostState {

param(
 [Parameter(Mandatory=$false)]
 [String]$VMHostNotMatch="Excludeme"
)


$r = @()
$status = "GREEN"

$VMHosts = Get-VMHost | ? ( $_.name -notmatch $VMHostNotMatch)
foreach ($VMHost in $VMHosts) {
  if ($VMHost.ConnectionState -match "(Not.Res|Disconn)") {
    $status = "RED" 
    $r += "$($VMHost.name), $($VMHost.ConnectionState)"
  }

}

return @($r,$status)

} 

$Subject =  "ESXi Hosts Status"

$params = @{}
If (Get-Variable VMHostNotMatch -ErrorAction Ignore) {$params += @{VMHostNotMatch=$VMHostNotMatch}}

$result = Get-VMHostState @params

