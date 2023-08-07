<# 
.SYNOPSIS
    Intune WinGet Template

.DESCRIPTION 
    This script can install/uninstall any application via WinGet.

.NOTES 
    Version 1.1

    Put this command line as Install Cmd in Intune (this command uses x64 Powershell):
    "%systemroot%\sysnative\WindowsPowerShell\v1.0\powershell.exe" -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File winget-install.ps1 -AppId Notepad++.Notepad++ -AppName Notepad++

    Logfiles can be found here: C:\ProgramData\Intune\Apps\Logs

    Return Codes:   x = WinGet install/uninstall command returns exit code
                    1 = WinGet not found
                    2 = Uninstall failed
                    3 = Uninstall failed (WinGet check after uninstall)
                    4 = Install failed
                    5 = Install failed (WinGet check after install)

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

Param (
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
# Variables
$LogPath            = "$Env:ProgramData\Intune\Apps\Logs\$AppName"
$LogFile            = "$LogPath\$AppName.log"
$StartTime          = Get-Date -Format "yyyy\/MM\/dd HH:mm:ss"

# Eventlog
$EventLogName       = 'Intune'
$EventSourceName    = 'App'

if ($Uninstall) {
    $Action = 'UNINSTALL'
} else {
    $Action = 'INSTALL'
}




# ==========================================
# FUNCTIONS
# ==========================================
function ExitScript {
    param (
        [Parameter(Mandatory=$true)]
        [int] $ExitCode,

        [Parameter(Mandatory=$false)]
        [string] $ErrorMessage
    )

    # Get end time and time span
    $EndTime = Get-Date -Format "yyyy\/MM\/dd HH:mm:ss"
    $TimeSpan = New-TimeSpan -Start $StartTime -End $EndTime


    # =============
    # EVENTLOG
    # =============
    # Get Commandline for eventlog
    if ($UserSetup -eq $true) {
        $Command = """$Winget"" install --exact --id $AppId --silent --accept-package-agreements --accept-source-agreements --scope=user $Param"
    } elseif ($Uninstall -eq $true) {
        $Command = """$Winget"" uninstall --exact --id $AppId --silent --accept-source-agreements $Param"
    } else {
        $Command = """$Winget"" install --exact --id $AppId --silent --accept-package-agreements --accept-source-agreements --scope=machine $Param"
    }

$Message = @"
###################################
$Action $AppName                
###################################                                                                                                                  
Command: $Command
Result: $ExitCode
Install Duration: $($TimeSpan.ToString("mm' minutes 'ss' seconds'"))
Log Path: $LogPath
"@

    # Write Eventlog
    try {

        Write-Host ''
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
    Write-Host "Install Duration: $($TimeSpan.ToString("mm' minutes 'ss' seconds'"))"
    Write-Host "End Time: $EndTime"
    Write-Host ''

    Stop-Transcript
    Exit $ExitCode

}



# ======================
# PREPARE
# ======================
# Cleanup Logs
if (Test-Path -Path $LogFile -PathType Leaf) {
    Remove-Item -Path $LogFile -Force -Confirm:$false
}

# Start Logging
Start-Transcript -Path $LogFile -Force -Append

Write-Host ''
Write-Host '============================================='  -ForegroundColor Cyan
Write-Host " $Action"                                       -ForegroundColor Cyan
Write-Host '============================================='  -ForegroundColor Cyan
Write-Host "Computername: $($env:USERNAME)"
Write-Host "Username    : $($env:USERNAME)"
Write-Host ''
Write-Host "Start Time  : $StartTime"
Write-Host ''



# ======================
# REQUIREMENTS
# ======================
# Check for Admin Rights
Write-Host 'Check for admin rights'
$User        = [Security.Principal.WindowsIdentity]::GetCurrent()
$AdminRights = (New-Object Security.Principal.WindowsPrincipal $User).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)


if ($AdminRights -eq $true) {

    Write-Host '--> User has admin rights'
    Write-Host ''

    # Check/Install VC Redist
    try {

        # Trust Powershell Gallery
        if ((Get-PSRepository -Name 'PSGallery').InstallationPolicy -ne "Trusted") {
            Write-Host 'Set PSGallery as Trusted'
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
        }

        Write-Host 'Check Visual C++ Redist 2013 and 2015-2022'
        $VcRedist2013InstallState = Get-ChildItem -Recurse HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall,HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Where-Object {$_.GetValue("DisplayName") -like "*Visual C++ 2013 Redistributable*"}
        $VcRedist2022InstallState = Get-ChildItem -Recurse HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall,HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Where-Object {$_.GetValue("DisplayName") -like "*Visual C++ 2015-2022 Redistributable*"}

        if ($VcRedist2013InstallState.Count -lt 2 -or $VcRedist2022InstallState.Count -lt 2) {
            Write-Host 'Install Powershell Module VcRedist'
            Install-Module -Name VcRedist -Force -Scope AllUsers
        }

        if ($VcRedist2013InstallState.Count -lt 2) {
            Write-Host 'Download and install Microsoft Visual C++ 2013 Redistributable'
            Get-VcList -Release 2013 | Save-VcRedist -Path $PSScriptRoot | Install-VcRedist -Silent -Force
        }

        if ($VcRedist2022InstallState.Count -lt 2) {
            Write-Host 'Download and install Microsoft Visual C++ 2015-2022 Redistributable'
            Get-VcList -Release 2022 | Save-VcRedist -Path $PSScriptRoot | Install-VcRedist -Silent -Force
        }

    }
    catch {

        $ErrorMessage = $_
        Write-Host 'Check/Install of C++ Redist failed' -ForegroundColor Red
        Write-Error $ErrorMessage.Exception.Message

    }

    try {

        # Eventlog - Register Source (Admin Rights needed)
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

# Get WinGet Path (if admin context)
$ResolveWingetPath = Resolve-Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_*__8wekyb3d8bbwe" | Sort-Object { [version]($_.Path -replace '^[^\d]+_((\d+\.)*\d+)_.*', '$1') }
if ($ResolveWingetPath) {
    #If multiple version, pick last one
    $WingetPath = $ResolveWingetPath[-1].Path
}

#Get Winget Location in User context
$WingetCmd = Get-Command winget.exe -ErrorAction SilentlyContinue
if ($WingetCmd) {
    $Winget = $WingetCmd.Source
}
#Get Winget Location in System context
elseif (Test-Path "$WingetPath\winget.exe") {
    $Winget = "$WingetPath\winget.exe"
}

Write-Host ''
Write-Host "WinGet Path: $Winget"
Write-Host ''

if (-not(Test-Path -Path $Winget -PathType Leaf)) {
    Write-Error 'Winget not found - Exit 1'
    ExitScript -ExitCode 1 -ErrorMessage 'Winget not found'
}




# ======================
# MAIN
# ======================
# UNINSTALL
if ($Uninstall) {

    try {
        Write-Host '==============='
        Write-Host 'Uninstall Setup'
        Write-Host '==============='
        Write-Host "$Winget uninstall --exact --id $AppId --silent --accept-source-agreements $Param"
        $Process = & "$Winget" uninstall --exact --id $AppId --silent --accept-source-agreements $Param | Out-String
        $ExitCode = $LASTEXITCODE
        Write-Host "Result: $ExitCode"
        Write-Host '------------------------------ Output Console Start ------------------------------' -ForegroundColor DarkGray
        Write-Host $Process                                                                             -ForegroundColor DarkGray
        Write-Host '------------------------------ Output Console End --------------------------------' -ForegroundColor DarkGray
    }
    catch {
        Write-Host ''
        Write-Host '========================='  -ForegroundColor Red
        Write-Host 'Uninstall failed'           -ForegroundColor Red
        Write-Host '========================='  -ForegroundColor Red
        Write-Error $_
        ExitScript -ExitCode 2 -ErrorMessage 'Uninstall failed'
    }

    #Get "Winget List AppID"
    Write-Host ''
    Write-Host '======================'
    Write-Host 'Check Uninstall Result'
    Write-Host '======================'
    $InstalledApp = & "$Winget" list --Id $AppId --accept-source-agreements | Out-String
    $ExitCode = $LASTEXITCODE
    Write-Host "Result: $ExitCode"
    Write-Host '------------------------------ Output Console Start ------------------------------' -ForegroundColor DarkGray
    Write-Host $InstalledApp                                                                        -ForegroundColor DarkGray                 
    Write-Host '------------------------------ Output Console End --------------------------------' -ForegroundColor DarkGray

    # Check Uninstall Result
    if ($InstalledApp -match [regex]::Escape($AppId)) {

        Write-Host ''
        Write-Host '========================='  -ForegroundColor Red
        Write-Host 'Uninstall failed'           -ForegroundColor Red
        Write-Host '========================='  -ForegroundColor Red
        Write-Error 'Uninstall failed after winget list check'
        ExitScript -ExitCode 3 -ErrorMessage 'Uninstall failed after winget list check'

    } else {

        Write-Host ''
        Write-Host '========================='  -ForegroundColor Green
        Write-Host 'Uninstall successfully'     -ForegroundColor Green
        Write-Host '========================='  -ForegroundColor Green
        $ExitCode = 0

    }
    
} else {

    # INSTALL
    try {
        if ($UserSetup) {
            Write-Host '=================='
            Write-Host 'Install User Setup'
            Write-Host '=================='
            Write-Host "$Winget install --exact --id $AppId --silent --accept-package-agreements --accept-source-agreements --scope=user $Param"
            $Process = & "$Winget" install --exact --id $AppId --silent --accept-package-agreements --accept-source-agreements --scope=user $Param
            $ExitCode = $LASTEXITCODE
            Write-Host "Result: $ExitCode"
            Write-Host '------------------------------ Output Console Start ------------------------------' -ForegroundColor DarkGray
            Write-Host $Process                                                                             -ForegroundColor DarkGray
            Write-Host '------------------------------ Output Console End --------------------------------' -ForegroundColor DarkGray
        } else {
            Write-Host '====================='
            Write-Host 'Install Machine Setup'
            Write-Host '====================='
            Write-Host "$Winget install --exact --id $AppId --silent --accept-package-agreements --accept-source-agreements --scope=machine $Param"
            $Process = & "$Winget" install --exact --id $AppId --silent --accept-package-agreements --accept-source-agreements --scope=machine $Param
            $ExitCode = $LASTEXITCODE
            Write-Host "Result: $ExitCode"
            Write-Host '------------------------------ Output Console Start ------------------------------' -ForegroundColor DarkGray
            Write-Host $Process                                                                             -ForegroundColor DarkGray
            Write-Host '------------------------------ Output Console End --------------------------------' -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Host ''
        Write-Host '========================='  -ForegroundColor Red
        Write-Host 'Install failed'             -ForegroundColor Red
        Write-Host '========================='  -ForegroundColor Red
        Write-Error $_
        ExitScript -ExitCode 4 -ErrorMessage 'Install failed'
    }

    #Get "Winget List AppID"
    Write-Host ''
    Write-Host '===================='
    Write-Host 'Check Install Result'
    Write-Host '===================='
    $InstalledApp = & "$Winget" list --Id $AppId --accept-source-agreements | Out-String
    $ExitCode = $LASTEXITCODE
    Write-Host "Result: $ExitCode"
    Write-Host '------------------------------ Output Console Start ------------------------------' -ForegroundColor DarkGray
    Write-Host $InstalledApp                                                                        -ForegroundColor DarkGray
    Write-Host '------------------------------ Output Console End --------------------------------' -ForegroundColor DarkGray

    # Check Install Result
    if ($InstalledApp -match [regex]::Escape($AppId)) {

        Write-Host ''
        Write-Host '========================='  -ForegroundColor Green
        Write-Host 'Install successfully'       -ForegroundColor Green
        Write-Host '========================='  -ForegroundColor Green
        $ExitCode = 0

    } else {

        Write-Host ''
        Write-Host '========================='  -ForegroundColor Red
        Write-Host 'Install failed'             -ForegroundColor Red
        Write-Host '========================='  -ForegroundColor Red
        Write-Error 'Install failed after winget list check'
        ExitScript -ExitCode 5 -ErrorMessage 'Install failed after winget list check'

    }
}

# Exit Script
ExitScript -ExitCode $ExitCode







