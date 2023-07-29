# Set the WinGet AppID for detecting the app
$AppIdToDetect = "Google.Chrome"

# Get WinGet Path (if admin context)
$ResolveWingetPath = Resolve-Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_*__8wekyb3d8bbwe" | Sort-Object { [version]($_.Path -replace '^[^\d]+_((\d+\.)*\d+)_.*', '$1') }
if ($ResolveWingetPath) {
    #If multiple version, pick last one
    $WingetPath = $ResolveWingetPath[-1].Path
}

# Get Winget Location in User context
$WingetCmd = Get-Command winget.exe -ErrorAction SilentlyContinue
if ($WingetCmd) {
    $Winget = $WingetCmd.Source
}
# Get Winget Location in System context
elseif (Test-Path "$WingetPath\winget.exe") {
    $Winget = "$WingetPath\winget.exe"
}

# Get "Winget List AppID"
$InstalledApp = & $Winget list --Id $AppIdToDetect --accept-source-agreements | Out-String

#Return if AppID existe in the list
if ($InstalledApp -match [regex]::Escape($AppIdToDetect)) {
    return "Installed!"
}
