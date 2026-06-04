param(
  [string]$DeviceId = "emulator-5556",
  [string]$DartDefine = ""
)

$ErrorActionPreference = "Stop"

$args = @("run", "--profile", "-d", $DeviceId, "--trace-startup")
if ($DartDefine.Trim().Length -gt 0) {
  $args += "--dart-define=$DartDefine"
}

flutter @args
