<# 
.SYNOPSIS  
 Checks and reports datastore cluster usage

.DESCRIPTION 
 Simple script to report on datastore cluster usage

 Add the following variables globalvariable.ps1 file to over default:
 $DSClusterPercentFreeWarn - default is 20 (%), warning threshold
 $DSClusterPercentFreeCrit - default is 10 (%) critical threshold
 $ExcludeDSClusterName     - Regex string to ignore some clusters
 
.NOTES
 1.0: Kelvin, 27/dec/2019 : Base version
 1.1: Kelvin, 12/feb/2019 :
   Correction to logic error, $status was not reset to green for the loop. As a result,
   once any cluster is red or amber all clusters are shown instead
   Also made format changes to error message and rounded up values for readability
 1.2: Kelvin, 20/feb/2019 : 
   Check to ensure CapacityGB > 0 to avoid div zero.

#>

function Get-DatastoreClusterUsage {

param(
 [Parameter(Mandatory=$false)]
 [Int]$DSClusterPercentFreeWarn=20,
 [Parameter(Mandatory=$false)]
 [Int]$DSClusterPercentFreeCrit=10,
 [Parameter(Mandatory=$false)]
 [String]$ExcludeDSClusterName="Excludeme"
)


$r = @()
$status = "GREEN"

#get-stat is outside the loop optimize execution time
$DSClusters = Get-DatastoreCluster | ?{$_.name -notmatch $ExcludeDSClusterName -and $_.CapacityGB -gt 0}
foreach ($DSCluster in $DSClusters) {
  $status = "GREEN"
  $PercentFree = [math]::Round($DSCluster.FreeSpaceGB/$DSCluster.CapacityGB*100,2)
  $TotalCapacityTB = [math]::Round([INT64]$DSCluster.CapacityGB/1024,2)
  $FreeCapacityTB = [math]::Round([INT64]$DSCluster.FreeSpaceGB/1024,2)
  Switch ($PercentFree) {
    {$_ -le $DSClusterPercentFreeCrit} 
      { $status = "RED" ; 
        $r += "{0}: %free < {1},Total {2}TB, Free {3}TB`({4}%`)" -f $DSCluster.name,$DSClusterPercentFreeCrit,$TotalCapacityTB,$FreeCapacityTB,$PercentFree
        break ;}
    {$_ -le $DSClusterPercentFreeWarn}
      { $status = "AMBER"; 
        $r += "{0}: %free < {1},Total {2}TB, Free {3}TB`({4}%`)" -f $DSCluster.name,$DSClusterPercentFreeWarn,$TotalCapacityTB,$FreeCapacityTB,$PercentFree
        break;}  
  }
}

return @($r,$status)

} 

$Subject =  "Datastore Cluster Usage"

$params = @{}
If (Get-Variable DSClusterPercentFreeWarn -ErrorAction Ignore) {$params += @{DSClusterPercentFreeWarn=$DSClusterPercentFreeWarn}}
If (Get-Variable DSClusterPercentFreeCrit -ErrorAction Ignore) {$params += @{DSClusterPercentFreeCrit=$DSClusterPercentFreeCrit}}
If (Get-Variable ExcludeDSClusterName -ErrorAction Ignore) {$params += @{ExcludeDSClusterName=$ExcludeDSClusterName}}

$result = Get-DatastoreClusterUsage @params

