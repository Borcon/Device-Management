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

    Return Codes:   x = WinGet install/uninstall command returns exit code
                    1 = Error with download or execute command

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
if ($Param -ne "" -and $null -ne $Param) {$ScriptParam += " -Param $Param"}




# ==========================================
# LOGGING
# ==========================================
# Cleanup Logs
if (Test-Path -Path $LogPath) {
    Remove-Item -Path $LogPath -Recurse -Force -Confirm:$false
}

# Create Log Path
New-Item -Path $LogPath -ItemType Directory | Out-Null

# Start Logging
Start-Transcript -Path $LogFile -Force -Append
Write-Host ''
Write-Host "Start Time: $StartTime"
Write-Host ''
Write-Host "Script Parameter: $ScriptParam"



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
    Write-Host "--> $ScriptUrl"
    Invoke-WebRequest -Uri $ScriptUrl -OutFile "$TempFolder\Install.ps1"

    # Unblock script
    Write-Host 'Unblock powershell script'
    Unblock-File -Path "$TempFolder\Install.ps1"

    # Execute script
    Write-Host 'Execute powershell script'
    $Return = Start-Process -FilePath 'powershell.exe' -ArgumentList "-ExecutionPolicy RemoteSigned -File ""$TempFolder\Install.ps1"" $ScriptParam" -Wait -PassThru -NoNewWindow
    $ExitCode = $Return.ExitCode
    Write-Host "--> Result: $ExitCode"

    # Direct Web Execution - Not Secure and some restrictions (exit command kills the starting script)
    # $Return = Invoke-Expression "& { $(Invoke-RestMethod $ScriptUrl) } $ScriptParam" -ErrorAction Stop

}
catch {

    Write-Error $_
    $ExitCode = 1

}

Write-Host ''

# Delete Temp Directory
Write-Host 'Remove download directory'
Remove-Item -Path $TempFolder -Recurse -Force -Confirm:$false

# Get end time and time span
$EndTime    = Get-Date -Format "yyyy\/MM\/dd HH:mm:ss"
$TimeSpan   = New-TimeSpan -Start $StartTime -End $EndTime

Write-Host ''
Write-Host "End Time: $(Get-Date -Format "yyyy\/MM\/dd HH:mm:ss")"
Write-Host "Install Duration: $($TimeSpan.ToString("mm' minutes 'ss' seconds'"))"
Write-Host ''

Stop-Transcript

Exit $ExitCode