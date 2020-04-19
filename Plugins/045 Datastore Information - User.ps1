<# 
.SYNOPSIS  
 Checks and reports User datastore usage

.DESCRIPTION 
 check User datastore for utilization

 Add the following variables globalvariable.ps1 file to over default:
 $UserDSPercentFreeWarn - default is 20 (%), warning threshold
 $UserDSPercentFreeCrit - default is 10 (%), critical threshold
 $UserDSMatch           - Regex string that matches user datastore names
  
.NOTES
 1.0: Kelvin, 16/jan/2020 : Base version
 1.1: Kelvin, 24/mar/2020 : Rounded FreeSpaceGB
#>

function Get-UserDatastoreUsage {

param(
 [Parameter(Mandatory=$false)]
 [Int]$UserDSPercentFreeWarn=20,
 [Parameter(Mandatory=$false)]
 [Int]$UserDSPercentFreeCrit=10,
 [Parameter(Mandatory=$false)]
 [String]$UserDSMatch="User_datastore"
)


$r = @()
$status = "GREEN"

$Datastores = Get-Datastore | ?{$_.name -match $UserDSMatch}

foreach ($Datastore in $Datastores) {
  $PercentFree = [math]::Round(($Datastore.FreeSpaceGB/$Datastore.CapacityGB*100),0)
  $thisStatus = "GREEN"
  Switch ($PercentFree) {
    {$_ -lt $UserDSPercentFreeCrit} 
      { $status = "RED" ;
        $thisStatus = "RED" ;
        break ;
      }
    {$_ -lt $UserDSPercentFreeWarn}
      { $status = "AMBER"; 
        $thisStatus = "AMBER" ;
        break;
      }
  }

  if ($thisStatus -ne "GREEN"){
    $r += "$($Datastore.name): Total,$($Datastore.CapacityGB) Free,$([math]::Round($Datastore.FreeSpaceGB,2))`($PercentFree %`)"
  }
}

return @($r,$status)

} 

$Subject =  "User Datastore Out of Space"
$params = @{}
If (Get-Variable UserDSPercentFreeWarn -ErrorAction Ignore) {$params += @{UserDSPercentFreeWarn=$UserDSPercentFreeWarn}}
If (Get-Variable UserDSPercentFreeCrit -ErrorAction Ignore) {$params += @{UserDSPercentFreeCrit=$UserDSPercentFreeCrit}}
If (Get-Variable UserDSMatch -ErrorAction Ignore) {$params += @{UserDSMatch=$UserDSMatch}}

$result = Get-UserDatastoreUsage @param

