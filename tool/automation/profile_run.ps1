param(
  [string]$DeviceId = "auto",
  [string]$DartDefine = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "android_device.ps1")
Initialize-AndroidAutomationPath
$DeviceId = Resolve-AndroidAutomationDevice -DeviceId $DeviceId
Write-Output "Using Android automation device: $DeviceId"

$args = @("run", "--profile", "-d", $DeviceId, "--trace-startup")
if ($DartDefine.Trim().Length -gt 0) {
  $args += "--dart-define=$DartDefine"
}

flutter @args
