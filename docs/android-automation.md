# Android Automation

Installed local automation stack:

- Flutter and Dart official skills for Codex.
- `integration_test` for Flutter device tests.
- Android SDK `adb` for screenshots and low-level device control.
- Maestro CLI and Maestro MCP for AI-assisted Android UI automation.

Common commands:

```powershell
flutter test
flutter emulators --launch Pixel_9
flutter test integration_test -d emulator-5554
$env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8"
maestro --device emulator-5554 test --test-output-dir screenshots .maestro\smoke.yaml
.\tool\automation\adb_screenshot.ps1 -Name home
.\tool\automation\capture_pages.ps1
.\tool\automation\profile_run.ps1
.\tool\automation\run_all.ps1
```

Screenshots are written or collected into `screenshots/`, which is ignored by Git.
Business path coverage is documented in `docs/android-test-paths.md`.

The PowerShell helpers default to the first running `emulator-*` device. Avoid running Maestro against a physical phone unless you intentionally want to approve installation of Maestro's Android driver apps (`dev.mobile.maestro` and `dev.mobile.maestro.test`).

Codex Desktop loads Maestro MCP from `C:\Users\yinuo\.codex\config.toml`.
Restart Codex Desktop after installing or changing MCP servers.
