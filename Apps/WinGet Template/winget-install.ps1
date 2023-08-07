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
$LogPath        = "$Env:ProgramData\Intune\Apps\Logs\$AppName"
$LogFile        = "$LogPath\$AppName.log"

if ($Uninstall) {
    $Action = 'UNINSTALL'
} else {
    $Action = 'INSTALL'
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




# ======================
# REQUIREMENTS
# ======================
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
    Stop-Transcript
    Exit 1
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
        Stop-Transcript
        Exit 2
    }

    #Get "Winget List AppID"
    Write-Host ''
    Write-Host '======================'
    Write-Host 'Check Uninstall Result'
    Write-Host '======================'
    $InstalledApp = & "$Winget" list --Id $AppId --accept-source-agreements | Out-String
    Write-Host "Result: $LASTEXITCODE"
    Write-Host '------------------------------ Output Console Start ------------------------------' -ForegroundColor DarkGray
    Write-Host $InstalledApp                                                                        -ForegroundColor DarkGray                 
    Write-Host '------------------------------ Output Console End --------------------------------' -ForegroundColor DarkGray

    # Check Uninstall Result
    if ($InstalledApp -match [regex]::Escape($AppId)) {

        Write-Host ''
        Write-Host '========================='  -ForegroundColor Red
        Write-Host 'Uninstall failed'           -ForegroundColor Red
        Write-Host '========================='  -ForegroundColor Red
        Write-Error $_
        Stop-Transcript
        Exit 3

    } else {

        Write-Host ''
        Write-Host '========================='  -ForegroundColor Green
        Write-Host 'Uninstall successfully'     -ForegroundColor Green
        Write-Host '========================='  -ForegroundColor Green

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
        Stop-Transcript
        Exit 4
    }

    #Get "Winget List AppID"
    Write-Host ''
    Write-Host '===================='
    Write-Host 'Check Install Result'
    Write-Host '===================='
    $InstalledApp = & "$Winget" list --Id $AppId --accept-source-agreements | Out-String
    Write-Host "Result: $LASTEXITCODE"
    Write-Host '------------------------------ Output Console Start ------------------------------' -ForegroundColor DarkGray
    Write-Host $InstalledApp                                                                        -ForegroundColor DarkGray
    Write-Host '------------------------------ Output Console End --------------------------------' -ForegroundColor DarkGray

    # Check Install Result
    if ($InstalledApp -match [regex]::Escape($AppId)) {

        Write-Host ''
        Write-Host '========================='  -ForegroundColor Green
        Write-Host 'Install successfully'       -ForegroundColor Green
        Write-Host '========================='  -ForegroundColor Green

    } else {

        Write-Host ''
        Write-Host '========================='  -ForegroundColor Red
        Write-Host 'Install failed'             -ForegroundColor Red
        Write-Host '========================='  -ForegroundColor Red
        Write-Error $_
        Stop-Transcript
        Exit 5

    }
}

Write-Host ''
Stop-Transcript
Exit $ExitCode