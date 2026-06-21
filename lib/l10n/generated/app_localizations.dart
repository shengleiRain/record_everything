import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Life Items'**
  String get appName;

  /// No description provided for @common_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get common_save;

  /// No description provided for @common_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get common_cancel;

  /// No description provided for @common_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get common_delete;

  /// No description provided for @common_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get common_confirm;

  /// No description provided for @common_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get common_retry;

  /// No description provided for @common_ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get common_ok;

  /// No description provided for @settings_themeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settings_themeTitle;

  /// No description provided for @settings_themeMode_system.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get settings_themeMode_system;

  /// No description provided for @settings_themeMode_light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settings_themeMode_light;

  /// No description provided for @settings_themeMode_dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settings_themeMode_dark;

  /// No description provided for @settings_languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settings_languageTitle;

  /// No description provided for @settings_language_system.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get settings_language_system;

  /// No description provided for @settings_language_zh.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get settings_language_zh;

  /// No description provided for @settings_language_en.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settings_language_en;

  /// No description provided for @enum_projectStatus_active.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get enum_projectStatus_active;

  /// No description provided for @enum_projectStatus_completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get enum_projectStatus_completed;

  /// No description provided for @enum_projectStatus_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get enum_projectStatus_cancelled;

  /// No description provided for @enum_projectStatus_archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get enum_projectStatus_archived;

  /// No description provided for @enum_projectStatus_advance_complete.
  ///
  /// In en, this message translates to:
  /// **'Mark Complete'**
  String get enum_projectStatus_advance_complete;

  /// No description provided for @enum_projectStatus_advance_generic.
  ///
  /// In en, this message translates to:
  /// **'Advance'**
  String get enum_projectStatus_advance_generic;

  /// No description provided for @enum_itemStatus_pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get enum_itemStatus_pending;

  /// No description provided for @enum_itemStatus_completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get enum_itemStatus_completed;

  /// No description provided for @enum_itemStatus_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get enum_itemStatus_cancelled;

  /// No description provided for @enum_itemStatus_archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get enum_itemStatus_archived;

  /// No description provided for @enum_amountType_none.
  ///
  /// In en, this message translates to:
  /// **'No amount'**
  String get enum_amountType_none;

  /// No description provided for @enum_amountType_income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get enum_amountType_income;

  /// No description provided for @enum_amountType_expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get enum_amountType_expense;

  /// No description provided for @enum_billAmountType_income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get enum_billAmountType_income;

  /// No description provided for @enum_billAmountType_expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get enum_billAmountType_expense;

  /// No description provided for @enum_projectEventType_note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get enum_projectEventType_note;

  /// No description provided for @enum_projectEventType_status_change.
  ///
  /// In en, this message translates to:
  /// **'Status Change'**
  String get enum_projectEventType_status_change;

  /// No description provided for @enum_projectEventType_communication.
  ///
  /// In en, this message translates to:
  /// **'Communication'**
  String get enum_projectEventType_communication;

  /// No description provided for @enum_projectEventType_milestone.
  ///
  /// In en, this message translates to:
  /// **'Milestone'**
  String get enum_projectEventType_milestone;

  /// No description provided for @enum_projectEventType_delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get enum_projectEventType_delivery;

  /// No description provided for @enum_projectEventType_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get enum_projectEventType_other;

  /// No description provided for @enum_repeatPeriod_daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get enum_repeatPeriod_daily;

  /// No description provided for @enum_repeatPeriod_weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get enum_repeatPeriod_weekly;

  /// No description provided for @enum_repeatPeriod_monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get enum_repeatPeriod_monthly;

  /// No description provided for @enum_repeatPeriod_yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get enum_repeatPeriod_yearly;

  /// No description provided for @enum_repeatPeriod_custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get enum_repeatPeriod_custom;

  /// No description provided for @enum_reminderPreset_none.
  ///
  /// In en, this message translates to:
  /// **'No reminder'**
  String get enum_reminderPreset_none;

  /// No description provided for @enum_reminderPreset_dueDayMorning.
  ///
  /// In en, this message translates to:
  /// **'Due day 9:00 AM'**
  String get enum_reminderPreset_dueDayMorning;

  /// No description provided for @enum_reminderPreset_dayBeforeMorning.
  ///
  /// In en, this message translates to:
  /// **'1 day before 9:00 AM'**
  String get enum_reminderPreset_dayBeforeMorning;

  /// No description provided for @enum_reminderPreset_custom.
  ///
  /// In en, this message translates to:
  /// **'Custom time'**
  String get enum_reminderPreset_custom;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
