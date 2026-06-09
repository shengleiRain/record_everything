function Initialize-AndroidAutomationPath {
  $platformTools = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools"
  $maestroBin = Join-Path $HOME "tools\maestro\bin"
  $env:Path = "$platformTools;$maestroBin;$env:Path"
  $env:MAESTRO_CLI_NO_ANALYTICS = "true"
  $env:MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED = "true"
  $env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8"
  if (Test-Path "D:\apps\Android\Android Studio\jbr") {
    $env:JAVA_HOME = "D:\apps\Android\Android Studio\jbr"
  }
}

function Resolve-AndroidAutomationDevice {
  param([string]$DeviceId)

  if ($DeviceId -and $DeviceId.Trim().Length -gt 0 -and $DeviceId -ne "auto") {
    return $DeviceId
  }

  $devices = @(adb devices |
    Where-Object { $_ -match "^(emulator-\d+)\s+device$" } |
    ForEach-Object { $Matches[1] })

  if ($devices.Count -gt 0) {
    return $devices[0]
  }

  throw "No running Android emulator found. Start one with: flutter emulators --launch Pixel_9. Avoid using a physical device for Maestro because Android may require manual installation approval for dev.mobile.maestro."
}
