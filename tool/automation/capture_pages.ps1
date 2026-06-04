param(
  [string]$DeviceId = "emulator-5556",
  [string]$OutputDir = "screenshot",
  [string]$PackageName = "com.lifeitems.record_everything"
)

$ErrorActionPreference = "Stop"

$platformTools = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools"
$adb = Join-Path $platformTools "adb.exe"
if (!(Test-Path $adb)) {
  throw "adb.exe not found at $adb"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

function Invoke-Adb {
  param([string[]]$AdbArgs)
  & $adb -s $DeviceId @AdbArgs
}

function Save-Screen {
  param([string]$Name)
  $path = Join-Path $OutputDir "$Name.png"
  $remotePath = "/sdcard/$Name.png"
  Invoke-Adb @("shell", "screencap", "-p", $remotePath) | Out-Null
  Invoke-Adb @("pull", $remotePath, $path) | Out-Null
  Invoke-Adb @("shell", "rm", $remotePath) | Out-Null
  Write-Output $path
}

function Tap {
  param([int]$X, [int]$Y)
  Invoke-Adb @("shell", "input", "tap", "$X", "$Y") | Out-Null
  Start-Sleep -Milliseconds 800
}

Invoke-Adb @(
  "shell",
  "monkey",
  "-p",
  $PackageName,
  "-c",
  "android.intent.category.LAUNCHER",
  "1"
) | Out-Null
Start-Sleep -Seconds 5
Save-Screen "android-home"

Tap 325 2260
Save-Screen "android-items"
Tap 980 2055
Start-Sleep -Seconds 1
Save-Screen "android-item-new"
Invoke-Adb @("shell", "input", "keyevent", "4") | Out-Null
Start-Sleep -Milliseconds 800

Tap 540 2260
Save-Screen "android-bills"
Tap 980 2055
Start-Sleep -Seconds 1
Save-Screen "android-bill-new"
Invoke-Adb @("shell", "input", "keyevent", "4") | Out-Null
Start-Sleep -Milliseconds 800

Tap 760 2260
Save-Screen "android-statistics"

Tap 975 2260
Save-Screen "android-settings"
