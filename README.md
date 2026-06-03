# 生活事项 Life Items

A unified life management app combining tasks, bills, and reminders into a single "LifeItem" model.

## Features

- **Dashboard**: Today's tasks, upcoming items, monthly overview
- **Life Items**: Tasks, expirations, bills, recurring items, subscriptions, consumables
- **Bill Records**: Income and expense tracking with monthly views
- **Statistics**: Monthly income/expense, item stats, 30-day forecast
- **Reminders**: Local notifications for due items
- **Export/Import**: JSON backup and restore
- **Quick Templates**: 11 pre-built templates for common items (rent, bills, subscriptions, etc.)

## Tech Stack

- Flutter 3.41 / Dart 3.11
- Riverpod (state management)
- Drift + SQLite (local database)
- go_router (navigation)
- flutter_local_notifications (reminders)
- fl_chart (charts, placeholder)
- intl (date formatting)

## Getting Started

1. Install Flutter: https://docs.flutter.dev/get-started/install
2. Clone the repository
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Generate Drift code:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
5. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
  main.dart                    # App entry, ProviderScope
  app.dart                     # MaterialApp.router, theme
  core/
    theme/                     # AppColors, AppTheme (Material 3)
    router/                    # GoRouter with ShellRoute
    utils/                     # MoneyFormatter, DateFormatter
    constants/                 # DefaultCategories
    notifications/             # NotificationService
  data/
    database/
      app_database.dart        # Drift database with default category seeding
      tables/                  # LifeItems, BillRecords, Categories
      daos/                    # DAOs with stream/query methods
    repositories/              # Repository layer (CRUD + business logic)
  domain/
    enums/                     # ItemType, AmountType, Status, RepeatPeriod
    models/                    # RepeatRule
  features/
    home/                      # Dashboard page + widgets
    life_item/                 # List, detail, edit pages + complete action sheet
    bill/                      # Bill list, edit pages + bill card
    statistics/                # Monthly stats page
    settings/                  # Settings, export/import
```

## Development

Regenerate Drift code after changing table/DAO definitions:
```bash
dart run build_runner build --delete-conflicting-outputs
```

Watch for changes during development:
```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Key Design Decisions

- **Amount stored as int cents** (e.g., 12.34 yuan = 1234) to avoid floating point issues
- **Overdue calculated dynamically** on query, not stored in database
- **BillRecord created separately** from LifeItem — items represent future tasks, bills represent actual transactions
- **RepeatRule as simple string** — supports daily, weekly, monthly, yearly, and `every:N:days`
