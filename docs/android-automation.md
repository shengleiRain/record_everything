# Android Automation

Installed local automation stack:

- Flutter and Dart official skills for Codex.
- `integration_test` for Flutter device tests.
- Android SDK `adb` for screenshots and low-level device control.
- Maestro CLI and Maestro MCP for AI-assisted Android UI automation.

Common commands:

```powershell
flutter test
flutter test integration_test -d emulator-5556
maestro --device emulator-5556 test .maestro\smoke.yaml
.\tool\automation\adb_screenshot.ps1 -DeviceId emulator-5556 -Name home
.\tool\automation\capture_pages.ps1 -DeviceId emulator-5556
.\tool\automation\profile_run.ps1 -DeviceId emulator-5556
.\tool\automation\run_all.ps1 -DeviceId emulator-5556
```

Screenshots are written or collected into `screenshot/`, which is ignored by Git.
Business path coverage is documented in `docs/android-test-paths.md`.

Codex Desktop loads Maestro MCP from `C:\Users\yinuo\.codex\config.toml`.
Restart Codex Desktop after installing or changing MCP servers.
