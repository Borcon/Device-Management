<# 
.SYNOPSIS
    Intune WinGet GitHub Installer

.DESCRIPTION 
    This script starts winget-install.ps1 in GitHub directly.
    So you have the advantages of the version management in GitHub and if you change the winget-install.ps1, you don't need to update the intunewin package.

.NOTES 
    Put this command line as Install Cmd in Intune (this command uses x64 Powershell):
    "%systemroot%\sysnative\WindowsPowerShell\v1.0\powershell.exe" -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File winget-web-install.ps1 -AppId Notepad++.Notepad++ -AppName Notepad++ -GitHubPath "/Borcon/Device-Management/main/Apps/WinGet Template/winget-install.ps1"

    Logfiles are added to the eventlog application.

.Parameter GitHubPath 
    Specifies the relative path to the powershell file in GitHub

.Parameter AppId 
    Specifies the AppID

.Parameter AppName 
    Specifies the App Name
    App Name is used for log folder name

.Parameter UserSetup 
    Starts WinGet Install/Uninstall with scope User

.Parameter Uninstall 
    For Uninstall use this parameter

.Parameter Param 
    Any additional parameter for winget install/uninstall
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)] 
    [String] 
    $GitHubPath,

    [Parameter(Mandatory = $true)] 
    [String] 
    $AppId,

    [Parameter(Mandatory = $true)] 
    [String] 
    $AppName,

    [Parameter(Mandatory = $false)] 
    [Switch] 
    $UserSetup,

    [Parameter(Mandatory = $false)] 
    [Switch] 
    $Uninstall,

    [Parameter(Mandatory = $false)] 
    [String] 
    $Param
)




# ==========================================
# VARIABLES
# ==========================================
$ScriptUrl = "https://raw.gitHubusercontent.com/$GitHubPath"

# Build Parameter
$ScriptParam = "-AppId ""$AppId"" -AppName ""$AppName"""
if ($UserSetup) {$ScriptParam += " -UserSetup"}
if ($Uninstall) {$ScriptParam += " -Uninstall"}
if ($Param -ne "" -and $null -ne $Param) {$ScriptParam += " -Param ""$Param"""}

# Setup Action
$Action = "Install"
if ($Uninstall) {$Action = "Uninstall"}

# Eventlog
$EventSourceName = "App-Mgmt"




# ==========================================
# PREPARE
# ==========================================
# Check for Admin Rights
$User        = [Security.Principal.WindowsIdentity]::GetCurrent()
$AdminRights = (New-Object Security.Principal.WindowsPrincipal $User).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

# Eventlog - Register Source (Admin Rights needed)
if ($AdminRights) {
    if ([System.Diagnostics.EventLog]::SourceExists($EventSourceName) -eq $false) {
        Write-Host "Creating event source [$EventSourceName] on event log [Application]"
        [System.Diagnostics.EventLog]::CreateEventSource("$EventSourceName",'Application')
     } else { Write-Host "Event source [$EventSourceName] is already registered" }
}




# ==========================================
# MAIN
# ==========================================
# Run Web Powershell
try {

    $StartTime = Get-Date -Format "yyyy/MM/dd HH:mm:ss"

    # Download and Execute Script
    Invoke-WebRequest -Uri $ScriptUrl -OutFile .\Install.ps1
    Unblock-File -Path .\Install.ps1
    $Return = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy RemoteSigned -File .\Install.ps1 $ScriptParam" -Wait -PassThru -NoNewWindow

    # Direct Web Execution - Not Secure and some restrictions (exit command kills the starting script)
    # $Return = Invoke-Expression "& { $(Invoke-RestMethod $ScriptUrl) } $ScriptParam" -ErrorAction Stop

    $EndTime = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
    $TimeSpan = New-TimeSpan -Start $StartTime -End $EndTime

}
catch {
    $ErrorMessage = $_
    Write-Error $ErrorMessage.Exception.Message
}




# ==========================================
# EVENTLOG
# ==========================================
$Message = @"
###################################
$Action $AppName                
###################################                                                                                                                  
Setup Parameter: $ScriptParam
UserSetup: $UserSetup

Result: $($Return.ExitCode)
Install Duration: $($TimeSpan.ToString("mm' minutes 'ss' seconds'"))


"@

if ($ErrorMessage) {
    $Message += "Error: $ErrorMessage"
    Write-EventLog -LogName "Application" -Source $EventSourceName -EventID 1000 -EntryType Error -Message $Message
} else {
    Write-EventLog -LogName "Application" -Source $EventSourceName -EventID 1000 -EntryType Information -Message $Message
}

Exit 0