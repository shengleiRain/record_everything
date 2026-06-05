# Mobile UI Automated Test Strategy

## Rule

Any future UI or navigation change must update the automated tests in the same change set. A page change is not complete until affected widget tests and integration smoke tests are reviewed and adjusted.

## Coverage Matrix

| Area | Unit/provider coverage | Widget coverage | Integration smoke |
| --- | --- | --- | --- |
| Home agenda | `calendar_window_test.dart`, `home_agenda_provider_test.dart` | `home_calendar_widget_test.dart`, `mobile_redesign_widget_test.dart` | Home calendar, selected day agenda, quick create sheet |
| Life items | Repository/provider range tests | List filters, detail action sheet, edit entry smoke | Create/read/filter/detail/complete |
| Bills | Repository range tests, monthly providers | Month summary, day grouping, filters | Group/filter/edit-route |
| Statistics | Provider aggregation through seeded DB | Redesigned summary sections | Statistics tab reachability |
| Settings | Import/export providers | Data management and preference sections | Settings tab reachability |

## Test Stability Rules

- Prefer `ValueKey` for controls that scripts tap frequently.
- Avoid selecting text fields by index; use label text or key.
- Avoid one giant end-to-end script. Split flows by page or business capability.
- Use in-memory Drift databases through `test/helpers/test_app.dart`.
- Keep tests deterministic by seeding explicit data before opening the page.

## Required Commands

Run these before considering a UI change complete:

```powershell
flutter test
flutter analyze
git diff --check
```

Run the integration smoke when an emulator/device is available:

```powershell
flutter test integration_test/app_smoke_test.dart
```
