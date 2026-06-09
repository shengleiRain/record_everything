param(
  [string]$DeviceId = "auto",
  [string]$MaestroFlow = ".maestro",
  [string]$OutputDir = "screenshots"
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "android_device.ps1")
Initialize-AndroidAutomationPath
$DeviceId = Resolve-AndroidAutomationDevice -DeviceId $DeviceId
Write-Output "Using Android automation device: $DeviceId"

flutter test
flutter test integration_test -d $DeviceId

if (Test-Path $MaestroFlow) {
  flutter build apk --debug
  adb -s $DeviceId install -r build\app\outputs\flutter-apk\app-debug.apk
  New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
  $flowItem = Get-Item $MaestroFlow
  if ($flowItem.PSIsContainer) {
    Get-ChildItem -Path $flowItem.FullName -Filter "*.yaml" |
      Sort-Object Name |
      ForEach-Object {
        maestro --device $DeviceId test --test-output-dir $OutputDir $_.FullName
      }
  } else {
    maestro --device $DeviceId test --test-output-dir $OutputDir $flowItem.FullName
  }
}

& (Join-Path $PSScriptRoot "capture_pages.ps1") -DeviceId $DeviceId
& (Join-Path $PSScriptRoot "adb_screenshot.ps1") -DeviceId $DeviceId -Name "after-run"

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Get-ChildItem -Path "." -File |
  Where-Object {
    $_.Name -in @("home-dashboard.png", "settings-tab.png") -or
    $_.Name -like "android-*.png"
  } |
  Move-Item -Destination $OutputDir -Force
