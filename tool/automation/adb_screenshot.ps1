param(
  [string]$DeviceId = "emulator-5556",
  [string]$OutputDir = "screenshot",
  [string]$Name = "screen"
)

$ErrorActionPreference = "Stop"

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
