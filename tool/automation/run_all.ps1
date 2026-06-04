param(
  [string]$DeviceId = "emulator-5556",
  [string]$MaestroFlow = ".maestro\smoke.yaml"
)

$ErrorActionPreference = "Stop"

$platformTools = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools"
$maestroBin = Join-Path $HOME "tools\maestro\bin"
$env:Path = "$platformTools;$maestroBin;$env:Path"
$env:MAESTRO_CLI_NO_ANALYTICS = "true"
$env:MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED = "true"
if (Test-Path "D:\apps\Android\Android Studio\jbr") {
  $env:JAVA_HOME = "D:\apps\Android\Android Studio\jbr"
}

flutter test
flutter test integration_test -d $DeviceId

if (Test-Path $MaestroFlow) {
  flutter build apk --debug
  adb -s $DeviceId install -r build\app\outputs\flutter-apk\app-debug.apk
  maestro --device $DeviceId test $MaestroFlow
}

& (Join-Path $PSScriptRoot "capture_pages.ps1") -DeviceId $DeviceId
& (Join-Path $PSScriptRoot "adb_screenshot.ps1") -DeviceId $DeviceId -Name "after-run"

New-Item -ItemType Directory -Force -Path "screenshot" | Out-Null
Get-ChildItem -Path "." -File |
  Where-Object {
    $_.Name -in @("home-dashboard.png", "settings-tab.png") -or
    $_.Name -like "android-*.png"
  } |
  Move-Item -Destination "screenshot" -Force
