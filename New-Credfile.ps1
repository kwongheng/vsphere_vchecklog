<#
.SYNOPSIS  Generate encrypted password file

.DESCRIPTION This is created to overcome the limitation of using service accounts to 
  run scheduled task in Windows, as the account don't have logon rights, runas will not work
  This script is setup in a schedule task and run once using the service account, so that
  the same account can be used to decrypt and run scripts.

.NOTES  Author: Kelvin Wong, version 1.0 27 AUG 19
 1.0: Base version

.PARAMETER
  $Prefix = determins the name of the credential files used and produced

.INPUT
  $CredIn = "$prefix-creds.csv": preformated/prepopulated csv file to import credentials
            headers = name,username,password
            
.OUTPUT
  $CredOut = encrypted XML credential file, $prefix.creds

.EXAMPLE
 .\New-Credfile.ps1
#>
param(
[Parameter(Mandatory=$true)]
[String]$prefix
)

$ScriptPath = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($myInvocation.MyCommand.path)

$Scriptlog =  "$ScriptPath\$scriptName.log"
$CredIn = $ScriptPath + "\" + $prefix + "-creds.csv"
$CredOut =  $ScriptPath + "\" + $prefix + ".cred"

Write-Output "$(date) Writing to $CredOut" | out-file $Scriptlog
& whoami | out-file $Scriptlog -append

$Creds = @{}
Import-Csv $CredIn | % {
  $securepassword = ConvertTo-SecureString $_.password -AsPlainText -Force
  $Creditem = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $_.username,$securepassword
  $Creds += @{ $_.name = $Creditem}
}
$Creds | Export-Clixml -Path $CredOut

Write-Output "$(date) Completed" | out-file $Scriptlog -append
