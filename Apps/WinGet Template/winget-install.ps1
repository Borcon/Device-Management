<# 
.SYNOPSIS
    Intune WinGet Template Version 1.0

.DESCRIPTION 
    This script can install/uninstall any application via WinGet.

.NOTES 
    Put this command line as Install Cmd in Intune (this command uses x64 Powershell):
    "%systemroot%\sysnative\WindowsPowerShell\v1.0\powershell.exe" -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File winget-install.ps1 -AppId Notepad++.Notepad++ -AppName Notepad++

    Logfiles can be found here: C:\ProgramData\Intune\Apps\Logs

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

# Variables
$LogPath        = "$Env:ProgramData\Intune\Apps\Logs\$AppName"
$LogFile        = "$LogPath\$AppName.log"

if ($Uninstall) {
    $Action = "UNINSTALL"
} else {
    $Action = "INSTALL"
}




# ======================
# PREPARE
# ======================
# Cleanup Logs
if (Test-Path -Path $LogFile -PathType Leaf) {
    Remove-Item -Path $LogFile -Force
}

# Start Logging
Start-Transcript -Path $LogFile -Force -Append

Write-Host ""
Write-Host "============================================="
Write-Host " $Action"
Write-Host "============================================="
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

Write-Host ""
Write-Host "WinGet Path: $Winget"
Write-Host ""

if (-not(Test-Path -Path $Winget -PathType Leaf)) {
    Write-Error "Winget not found - Exit 1"
    Stop-Transcript
    Exit 1
}




# ======================
# MAIN
# ======================
# UNINSTALL
if ($Uninstall) {

    try {
        Write-Host "==============="
        Write-Host "Uninstall Setup"
        Write-Host "==============="
        Write-Host "$Winget uninstall --exact --id $AppId --silent --accept-source-agreements $Param"
        $Process = & "$Winget" uninstall --exact --id $AppId --silent --accept-source-agreements $Param | Out-String
        Write-Host "Result: $LASTEXITCODE"
        Write-Host "------------------------------ Console Output ------------------------------"
        Write-Host $Process
        Write-Host "------------------------------ Console Output ------------------------------"
    }
    catch {
        Write-Host ""
        Write-Host "========================="
        Write-Error "Uninstall failed"
        Write-Host "========================="
        Stop-Transcript
        Exit 2
    }

    #Get "Winget List AppID"
    Write-Host ""
    Write-Host "======================"
    Write-Host "Check Uninstall Result"
    Write-Host "======================"
    $InstalledApp = & "$Winget" list --Id $AppId --accept-source-agreements | Out-String
    Write-Host "Result: $LASTEXITCODE"
    Write-Host "------------------------------ Output Console Start ------------------------------"
    Write-Host $InstalledApp
    Write-Host "------------------------------ Output Console End ------------------------------"

    # Check Uninstall Result
    if ($InstalledApp -match [regex]::Escape($AppId)) {

        Write-Host ""
        Write-Host "========================="
        Write-Error "Uninstall failed"
        Write-Host "========================="
        Stop-Transcript
        Exit 3

    } else {

        Write-Host ""
        Write-Host "========================="
        Write-Host "Uninstall successfully"
        Write-Host "========================="

    }
    
} else {

    # INSTALL
    try {
        if ($UserSetup) {
            Write-Host "=================="
            Write-Host "Install User Setup"
            Write-Host "=================="
            Write-Host "$Winget install --exact --id $AppId --silent --accept-package-agreements --accept-source-agreements --scope=user $Param"
            $Process = & "$Winget" install --exact --id $AppId --silent --accept-package-agreements --accept-source-agreements --scope=user $Param
            Write-Host "Result: $LASTEXITCODE"
            Write-Host "------------------------------ Output Console Start ------------------------------"
            Write-Host $Process
            Write-Host "------------------------------ Output Console End ------------------------------"
        } else {
            Write-Host "====================="
            Write-Host "Install Machine Setup"
            Write-Host "====================="
            Write-Host "$Winget install --exact --id $AppId --silent --accept-package-agreements --accept-source-agreements --scope=machine $Param"
            $Process = & "$Winget" install --exact --id $AppId --silent --accept-package-agreements --accept-source-agreements --scope=machine $Param
            Write-Host "Result: $LASTEXITCODE"
            Write-Host "------------------------------ Output Console Start ------------------------------"
            Write-Host $Process
            Write-Host "------------------------------ Output Console End ------------------------------"
        }
    }
    catch {
        Write-Host ""
        Write-Host "========================="
        Write-Error "Install failed"
        Write-Host "========================="
        Stop-Transcript
        Exit 4
    }

    #Get "Winget List AppID"
    Write-Host ""
    Write-Host "===================="
    Write-Host "Check Install Result"
    Write-Host "===================="
    $InstalledApp = & "$Winget" list --Id $AppId --accept-source-agreements | Out-String
    Write-Host "Result: $LASTEXITCODE"
    Write-Host "------------------------------ Output Console Start ------------------------------"
    Write-Host $InstalledApp
    Write-Host "------------------------------ Output Console End ------------------------------"

    # Check Install Result
    if ($InstalledApp -match [regex]::Escape($AppId)) {

        Write-Host ""
        Write-Host "========================="
        Write-Host "Install successfully"
        Write-Host "========================="

    } else {

        Write-Host ""
        Write-Host "========================="
        Write-Error "Install failed"
        Write-Host "========================="
        Stop-Transcript
        Exit 5

    }
}

Stop-Transcript
Exit 0