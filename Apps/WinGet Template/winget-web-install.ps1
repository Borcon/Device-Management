<# 
.SYNOPSIS
    Intune WinGet GitHub Installer

.DESCRIPTION 
    This script starts winget-install.ps1 in GitHub directly.
    So you have the advantages of the version management in GitHub and if you change the winget-install.ps1, you don't need to update the intunewin package.

.NOTES 
    Version 1.2
    Put this command line as Install Cmd in Intune (this command uses x64 Powershell):
    "%systemroot%\sysnative\WindowsPowerShell\v1.0\powershell.exe" -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File winget-web-install.ps1 -AppId Notepad++.Notepad++ -AppName Notepad++ -GitHubPath "Borcon/Device-Management/main/Apps/WinGet%20Template/winget-install.ps1"

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
# Logging
$LogPath   = "$Env:ProgramData\Intune\Apps\Logs\$AppName"
$LogFile   = "$LogPath\WinGet-Web-Install.log"
$StartTime = Get-Date -Format "yyyy\/MM\/dd HH:mm:ss"

# Github Path
$ScriptUrl = "https://raw.gitHubusercontent.com/$GitHubPath"

# Build Parameter
$ScriptParam = "-AppId ""$AppId"" -AppName ""$AppName"""
if ($UserSetup) {$ScriptParam += " -UserSetup"}
if ($Uninstall) {$ScriptParam += " -Uninstall"}
if ($Param -ne "" -and $null -ne $Param) {$ScriptParam += " -Param ""$Param"""}

# Setup Action
$Action = 'Install'
if ($Uninstall) {$Action = 'Uninstall'}

# Eventlog
$EventLogName       = 'Intune'
$EventSourceName    = 'App'




# ==========================================
# LOGGING
# ==========================================
# Cleanup Logs
if (Test-Path -Path $LogFile -PathType Leaf) {
    Remove-Item -Path $LogFile -Force -Confirm:$false
}

# Start Logging
Start-Transcript -Path $LogFile -Force -Append
Write-Host "Start Time: $StartTime"
Write-Host ''



# ==========================================
# PREPARE
# ==========================================
# Check for Admin Rights
Write-Host 'Check for admin rights'
$User        = [Security.Principal.WindowsIdentity]::GetCurrent()
$AdminRights = (New-Object Security.Principal.WindowsPrincipal $User).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

# Eventlog - Register Source (Admin Rights needed)
if ($AdminRights -eq $true) {

    Write-Host '--> User has admin rights'

    try {

        Write-Host ''
        Write-Host 'Check eventlog configuration'
        
        # Create Eventlog if not exists
        if ([System.Diagnostics.EventLog]::Exists($EventLogName) -eq $false) {
            Write-Host "--> Create eventlog $EventLogName"
            New-EventLog -Logname $EventLogName -Source $EventSourceName -ErrorAction Stop
        } else {
            Write-Host "--> Eventlog $EventLogName already exists - Nothing to do"
        }

        # Create Eventlog Source if not exists
        if ([System.Diagnostics.EventLog]::SourceExists($EventSourceName) -eq $false) {
            Write-Host "--> Creating event source [$EventSourceName] on event log [$EventLogName]"
            [System.Diagnostics.EventLog]::CreateEventSource("$EventSourceName",$EventLogName)
        } else { 
            Write-Host "--> Event source [$EventSourceName] is already registered" 
        }

    }
    catch {

        $ErrorMessage = $_
        Write-Host 'Failed to configure eventlog' -ForegroundColor Red
        Write-Error $ErrorMessage.Exception.Message

    }

} else {

    Write-Host '--> User has no admin rights'

}




# ==========================================
# MAIN
# ==========================================
# Run Web Powershell
try {

    Write-Host ''

    # Create Temp Directory for Download
    Write-Host 'Check download folder'
    $TempFolder = "$ENV:TEMP\WinGet_$AppName"
    if (-not(Test-Path -Path $TempFolder)) {
        Write-Host "--> Create download folder $TempFolder"
        New-Item -Path $TempFolder -ItemType Directory -Force | Out-Null
    }

    # Download script
    Write-Host 'Download powershell script'
    Invoke-WebRequest -Uri $ScriptUrl -OutFile "$TempFolder\Install.ps1"

    # Unblock script
    Write-Host 'Unblock powershell script'
    Unblock-File -Path "$TempFolder\Install.ps1"

    # Execute script
    Write-Host 'Execute powershell script'
    $Return = Start-Process -FilePath 'powershell.exe' -ArgumentList "-ExecutionPolicy RemoteSigned -File ""$TempFolder\Install.ps1"" $ScriptParam" -Wait -PassThru -NoNewWindow
    $ExitCode = $Return.ExitCode
    Write-Host "Result: $ExitCode"

    # Direct Web Execution - Not Secure and some restrictions (exit command kills the starting script)
    # $Return = Invoke-Expression "& { $(Invoke-RestMethod $ScriptUrl) } $ScriptParam" -ErrorAction Stop

}
catch {

    $ErrorMessage = $_
    Write-Error $ErrorMessage.Exception.Message
    $ExitCode = 1

}

Write-Host ''

# Delete Temp Directory
Write-Host 'Remove download directory'
Remove-Item -Path $TempFolder -Recurse -Force -Confirm:$false

# Get end time and time span
$EndTime = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
$TimeSpan = New-TimeSpan -Start $StartTime -End $EndTime




# ==========================================
# EVENTLOG
# ==========================================
$Message = @"
###################################
$Action $AppName                
###################################                                                                                                                  
Setup Parameter: $ScriptParam

Result: $ExitCode
Install Duration: $($TimeSpan.ToString("mm' minutes 'ss' seconds'"))

Log Path: $LogPath

"@

# Write Eventlog
try {

    Write-Host 'Write Eventlog'
    if ($ErrorMessage) {
        $Message += "Error: $ErrorMessage"
        Write-EventLog -LogName $EventLogName -Source $EventSourceName -EventID 1 -EntryType Error -Message $Message
    } else {
        Write-EventLog -LogName $EventLogName -Source $EventSourceName -EventID 1 -EntryType Information -Message $Message
    }

}
catch {

    Write-Error $_

}

Write-Host ''
Write-Host "End Time: $(Get-Date -Format "yyyy\/MM\/dd HH:mm:ss")"
Write-Host ''

Stop-Transcript

Exit $ExitCode