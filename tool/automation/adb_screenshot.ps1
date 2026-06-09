param(
  [string]$DeviceId = "auto",
  [string]$OutputDir = "screenshots",
  [string]$Name = "screen"
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "android_device.ps1")
Initialize-AndroidAutomationPath
$DeviceId = Resolve-AndroidAutomationDevice -DeviceId $DeviceId
Write-Output "Using Android automation device: $DeviceId"

$platformTools = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools"
$adb = Join-Path $platformTools "adb.exe"
if (!(Test-Path $adb)) {
  throw "adb.exe not found at $adb"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputPath = Join-Path $OutputDir "$Name-$timestamp.png"

& $adb -s $DeviceId exec-out screencap -p > $outputPath
Write-Output $outputPath
