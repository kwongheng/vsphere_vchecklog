<# 
.SYNOPSIS  
 Checks and reports management datastore usage. 

.DESCRIPTION 
 check management datastore for utilization. Management datastores is different from user's datastores as they are less dynamic
 So disk usage is usually static and don't change too fast over time. So their threshold is different for user datastores.

 Add the following variables globalvariable.ps1 file to over default:
 $MgmtDSPercentFreeWarn - Default is 10 (%), warning threshold
 $MgmtDSPercentFreeCrit - Default is 5 (%), critical threshold
 $MgmtDSNotMatch        - Regex string for datastores that are NOT mgmt datastores. Reason for this logic is that
                          usually, mgmt datastores have more random names than user datastores. So if it is easier to filter out
                          user datastores than to include mgmt datastores                          
 
.NOTES
 1.0: Kelvin, 16/jan/2020 : Base version
 1.1: Kelvin, 24/mar/2020 : Rounded FreeSpaceGB

#>

function Get-MgmtDatastoreUsage {

param(
 [Parameter(Mandatory=$false)]
 [Int]$MgmtDSPercentFreeWarn=10,
 [Parameter(Mandatory=$false)]
 [Int]$MgmtDSPercentFreeCrit=5,
 [Parameter(Mandatory=$false)]
 [String]$MgmtDSNotMatch="user_datastores"
)


$r = @()
$status = "GREEN"

$Datastores = Get-Datastore | ?{$_.name -notmatch $MgmtDSNotMatch}

foreach ($Datastore in $Datastores) {
  $PercentFree = [math]::Round(($Datastore.FreeSpaceGB/$Datastore.CapacityGB*100),0)
  $thisStatus = "GREEN"
  Switch ($PercentFree) {
    {$_ -lt $MgmtDSPercentFreeCrit} 
      { $status = "RED" ;
        $thisStatus = "RED" ;
        break ;
      }
    {$_ -lt $MgmtDSPercentFreeWarn}
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

$Subject =  "Management Datastore Out of Space"
$params = @{}
If (Get-Variable MgmtDSPercentFreeWarn -ErrorAction Ignore) {$params += @{MgmtDSPercentFreeWarn=$MgmtDSPercentFreeWarn}}
If (Get-Variable MgmtDSPercentFreeCrit -ErrorAction Ignore) {$params += @{MgmtDSPercentFreeCrit=$MgmtDSPercentFreeCrit}}
If (Get-Variable MgmtDSNotMatch -ErrorAction Ignore) {$params += @{MgmtDSNotMatch=$MgmtDSNotMatch}}

$result = Get-MgmtDatastoreUsage @param

