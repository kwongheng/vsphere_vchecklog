# vsphere_vchecklog
Alternate version of vCheck-like script but writing status to logs instead

The scripts are developed by looking at the vchecks scripts and plugins. Many of the coding style and codes were used but not credited properly. I apologize in advance and do let me know if any of those codes need to be credited accordinly.

## Introduction
This set of scripts were developed using similar concept as vchecks but for a more real world enterprise usage. Its not that vcheck is not good, but when you are in a big company, having to read a vcheck email to check the status of daily is very tired. vChecks suffers from the following:
- Lack of over RAG (red/amber/green) status on subject line. I agree that its hard to really determine what should be red or amber. But in an enterprise operations, RAG give a quick overview of your status. So if the subject says green, you really don't need to read through the email. Having said that, this script doesn't send any emails, more about this later.
- You don't know if a plugin was successfully executed or not. When a vcheck plugin executes, it either produces a select object or doesn't. Not producing a select object could also mean that script did not execute. For enterprise operations, its essential to know if each health is executed and the status even if its all green.
- If I need to run vchecks continuously, say every 30 mins or hour, it may not be achievable because in an enterprise setting, it may take a while to complete a full run of vchecks.

## Use Case
With the above, I set out to develop a set of scripts that does what vcheck does but sends the results to a log file instead. This log file can be read or ingested by another script, you can send an email from it or, for example, use a splunk agent to ingest into a health check dashboard. The latter is basically my use case. This provided me an ability to run the same scripts globally in various regions and have the logs shipped into a splunk dashboard to show a global health check dashboard. Obvious, this dashboard don't just display vsphere health status, it also display health status of a lot of other component, e.g. UCS, NSX, etc

### Log file format
Each plugn after execution will produce a status. The default format is as follows:

>$StatusTime,Region="$Region",Site="$Site",Type="$Type",Component="$Component",Hostname="$Hostname",Subject="$Subject",StatusText="$StatusText",Value="$StatusValue"

For example
>$StatusTime,Region="SG",Site="Site1",Type="Compute",Component="vSphere",Hostname="vcenter1",Subject="Datastore Health check",StatusText="RED",Value="Issue: Datastore1 > 95% usage"

The format above is a generic format that can be used by any script to produce an output, it is not just used for vsphere. The format was chosen to be ingested via splunk agent and how splunk interprets each line. You can change this format in the main script according to your use case. 

- $StatusTime: this is the time the command is run
- $Region: where is this executed from? e.g. APAC, EMEA or US, GB, SG, etc
- $Site: In that region which site is this executed from? ie. most company will have site code for diffent DCs
- $Type: Is this storage? network? compute? You can use this to group your components
- $Component: Is this vsphere? VMAX? UCS?
- $Hostname: e.g vcenter name, UCS name, etc
- $Subject: What are you testing? e.g. "Datastore Health Check", "NSX Manager Service Health"
- $StatusText: RED, AMBER or GREEN
- $StatusValue: What error do you want do display when the status is red or amber? By default green is blank
  You will notice that I used "|" as a newline delimited. Agent this is nuanced for splunk to convert "|" to newline
  when display the text in a dashboard, you don't need this. 

## Implementation
First of, a caveat that these set of scripts were developed over 2-3 weeks, has no localization and is specifically built for the use case I explained above.  I am not a developer but a scripter with an operational work. So I apologize that my script quality is not up there with the powershell gurus.

As I have explained, the script was developed to be able to run in an enterprise setting with security around it. One common theme is security and supportability. For example, you cannot run this with your admin account since this is not supportable and in enterprise settings, you need to change the password regularly, other colleagues cannot support this script if you scheduled it with your account. Neither should you run with a local vsphere or any admin account, you should run it with a READ-ONLY account. This is to prevent accidental coding errors using an admin account that could be destructive or someone changing the script to perform admin executiions. Also, many times we execute scripts with a service account with NO INTERACTIVE LOGON, this presents a challenge and how the scripts are coded. This means that you cannot logon as the service account to setup your scripts, you need to logon with your own account and configure an workaround.

### Accounts required
The scripts are developed so that you can schedule them from Windows scheduler using a service account with NO INTERACTIVE LOGON. 

You need two accounts:
- A service account (Task_account) with rights to schedule and run scripts on a windows server.
  This account is also used to encrypt the vcro_account's credential, so that it can read this file
  and supply the credentials during the script run.
- A read-only account (vcro_acccount) with access to the vcenters you are check.

### Credential files
These 3 files encrypts the requierd vcro_account:
- New-Credfile.cmd
- New-Credfile.ps1
- vsphere-creds.csv

1. Create a scheduled one time task using New-Credfile.cmd (why I use CMD is explained later below) with Task_account
2. Edit vsphere-creds.csv and enter all required credentials
3. Run the task and it will generate an encrypted vsphere-creds.cred (from CLIXML) file. This is read during script execution
4. REMEMBER, don't touch or edit vsphere-creds.cred file with your account or anyone else as this will invalid the signature. 
   If that happens, you just need to run step 1 again.

### Main script + plugins
These form the main script:
- Get-vCenterHealthStatus.cmd
- Get-vCenterHealthStatus.ps1
- GlobalVariables.ps1
- /plugins folder

1. Create a schedule task with Get-vCenterHealthStatus.cmd using Task_account
2. Edit GlobalVariables.ps1 to localize your execution
3. Review each script in /plugins and adjust for your environment
4. Prefix disabled_ to disable any plugin script.

*Note: The reason I prefer to use CMD to run scheduled task instead of scheduling the PS1 file. This gives me more flexibility to change the execution codes without having to update the scheduled tasks. For example, I can change the CMD file to run another file instead for testing and switch that back after without updating the already scheduled task.*

