<#
.SYNOPSIS  Performs health check on vSphere

.DESCRIPTION Performs a comprehensive health check on vCenter, ESXi hosts,
  datastores, storage paths, swtiches, virtual machines, etc and
  output the status to OutLogs. This can then be ingested by other agents like
  splunk for dashboard display
  
.NOTES 
 1.0: Kelvin, 12 DEC 2019 : Base version

.PARAMETER GblVar (optional)
  The name of the global variable ps1 file to use

.INPUT
  globalvariables.ps1 - file containing variables used by the script, instead of passing via arguments

.EXAMPLE
 .\Get-vSphereHealthStatus.ps1
 .\Get-vSphereHealthStatus.ps1 -gblvar anotherfile.ps1
#>

param(
[String]$GblVar = "GlobalVariables.ps1"
)


;Global function that all modules can call to write to own log file.
function Write-Log {

param(
 [Parameter(Mandatory=$true)]
 [String]$Message,
 [Parameter(Mandatory=$false)] 
 [ValidateSet("Error","Warn","Info")] 
 [string]$Level="Info"
)

  Write-Output "$(date):$($Level):$Message" | Out-File $ScriptLog -append

}

#Prunes logs older than 25 days, so that they don't take up space
function Prune-Log {

param(
 [Parameter(Mandatory=$true)]
 [String]$LogFile
)

 $OldLog = join-path $(split-path $LogFile -parent) $($(split-path $LogFile -leaf)+"2")

 if ((date).day % 25 -eq 0) {
   if (Test-Path $OldLog) {
     $OldLog_dt = (Get-Item $OldLog).CreationTime
     if (!((get-date).Day -eq $OldLog_dt.Day -and (get-date).Month -eq $OldLog_dt.Month)) {
       Remove-Item $OldLog -ErrorAction Ignore
       Rename-Item $LogFile -NewName $OldLog -ErrorAction Ignore
       Write-Log "Archived $LogFile and deleted $OldLog"
     }
   }
   else {
     Rename-Item $LogFile -NewName $OldLog -ErrorAction Ignore
     Write-Log "Archived $LogFile"     
   }
 }

}

#region INIT
$ScriptPath = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($myInvocation.MyCommand.path)
$scriptlog = "$ScriptPath\$ScriptName.log"

$GblVar = $ScriptPath + "\" + $GblVar
. $GblVar

Prune-Log $ScriptLog
#endregion

#region load modules

if (!(Get-Module -Name VMware.VimAutomation.Core) -and (Get-Module -ListAvailable -Name VMware.VimAutomation.Core)) {  
  #Write-Output "loading the VMware COre Module..."  
  Import-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue
#  sleep 5
  if (!(Get-Module -Name VMware.VimAutomation.Core)) {  
    # Error out if loading fails  
    Write-Log "Cannot load the VMware Module. Is the PowerCLI installed?" -level ERROR
    return ;
  }  
}  
#endregion


#region ** MAIN **
Write-Log "Script Started"

try {$creds = Import-Clixml $credfile}
catch { ($_.Exception.Message | out-file $scriptlog -append) ; return } 
$vcred = $creds.vc

$PluginsFolder = "$ScriptPath\plugins\"
$Plugins = Get-ChildItem -Path $PluginsFolder -filter "*.ps1" | ? {$_.Name -notmatch "disabled_"} | Sort-Object FullName | Select FullName

foreach ($key in $vcenters.keys) {

  $Site = $key
  $Hostname = $vcenters[$key]
    
  Write-Log "Connecting to vCenter $Hostname"
  try { Connect-ViServer $Hostname -credential $vcred -ea Stop }
  catch { ($_.Exception.Message | out-file $scriptlog -append) ; return } 
  
  foreach ($Plugin in $Plugins) {

    $vCheck      = $Plugin.FullName
    $psFileName  = Split-Path $vCheck -Leaf
    $StatusTime  = [DateTime]::UtcNow.ToString('O')

    Write-Log "Processing... $vCheck" 

    $result = ""
    try {. $vCheck}
    catch {$result = "$($_.Exception.Message)| $psFileName"}
        
    $StatusText  = "RED"
    $StatusValue = ""

    #$result can be only string or an array (with status)
    if ($result.GetType().name -eq "String") {
      $StatusValue = $result -join "|"
    }
    elseif ($result[0].count -gt 0) {
      $StatusValue = $result[0] -join "|"
      $StatusText = $result[1]
    }
    else {
      $StatusText = $result[1]
    }

    $OutLogRow = "$StatusTime,"
    $OutLogRow += "Region=`"$Region`","
    $OutLogRow += "Site=`"$Site`","
    $OutLogRow += "Type=`"$Type`","
    $OutLogRow += "Component=`"$Component`","
    $OutLogRow += "Hostname=`"$Hostname`","
    $OutLogRow += "Subject=`"$Subject`","
    $OutLogRow += "StatusText=`"$StatusText`","
    $OutLogRow += "Value=`"$StatusValue`""
         
    $OutLogRow | Out-File $OutLog -append

  }

  Disconnect-ViServer $Hostname -confirm:$false | out-null

}

Write-Log "Script completed" 

