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

  /// No description provided for @nav_home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get nav_home;

  /// No description provided for @nav_items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get nav_items;

  /// No description provided for @nav_bills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get nav_bills;

  /// No description provided for @nav_stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get nav_stats;

  /// No description provided for @nav_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get nav_settings;

  /// No description provided for @page_home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get page_home;

  /// No description provided for @page_items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get page_items;

  /// No description provided for @page_bills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get page_bills;

  /// No description provided for @page_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get page_settings;

  /// No description provided for @page_billEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Bill'**
  String get page_billEdit;

  /// No description provided for @page_billNew.
  ///
  /// In en, this message translates to:
  /// **'New Bill'**
  String get page_billNew;

  /// No description provided for @page_billReadonly.
  ///
  /// In en, this message translates to:
  /// **'Bill (Read-only)'**
  String get page_billReadonly;

  /// No description provided for @page_itemEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Item'**
  String get page_itemEdit;

  /// No description provided for @page_itemNew.
  ///
  /// In en, this message translates to:
  /// **'New Item'**
  String get page_itemNew;

  /// No description provided for @page_itemReadonly.
  ///
  /// In en, this message translates to:
  /// **'Item (Read-only)'**
  String get page_itemReadonly;

  /// No description provided for @page_recycle.
  ///
  /// In en, this message translates to:
  /// **'Recycle Bin'**
  String get page_recycle;

  /// No description provided for @page_categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get page_categories;

  /// No description provided for @page_dataSafety.
  ///
  /// In en, this message translates to:
  /// **'Data Safety'**
  String get page_dataSafety;

  /// No description provided for @page_webdav.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Sync'**
  String get page_webdav;

  /// No description provided for @page_aiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get page_aiAssistant;

  /// No description provided for @page_search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get page_search;

  /// No description provided for @page_statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get page_statistics;

  /// No description provided for @page_itemList.
  ///
  /// In en, this message translates to:
  /// **'Life Items'**
  String get page_itemList;

  /// No description provided for @page_webdavConfig.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Config'**
  String get page_webdavConfig;

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

  /// No description provided for @cat_salary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get cat_salary;

  /// No description provided for @cat_bonus.
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get cat_bonus;

  /// No description provided for @cat_parttime.
  ///
  /// In en, this message translates to:
  /// **'Side Gig'**
  String get cat_parttime;

  /// No description provided for @cat_reimbursement.
  ///
  /// In en, this message translates to:
  /// **'Reimbursement'**
  String get cat_reimbursement;

  /// No description provided for @cat_investment.
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get cat_investment;

  /// No description provided for @cat_refund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get cat_refund;

  /// No description provided for @cat_income_other.
  ///
  /// In en, this message translates to:
  /// **'Other Income'**
  String get cat_income_other;

  /// No description provided for @cat_food.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get cat_food;

  /// No description provided for @cat_shopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get cat_shopping;

  /// No description provided for @cat_transport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get cat_transport;

  /// No description provided for @cat_housing.
  ///
  /// In en, this message translates to:
  /// **'Housing'**
  String get cat_housing;

  /// No description provided for @cat_utilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get cat_utilities;

  /// No description provided for @cat_telecom.
  ///
  /// In en, this message translates to:
  /// **'Phone & Internet'**
  String get cat_telecom;

  /// No description provided for @cat_medical.
  ///
  /// In en, this message translates to:
  /// **'Medical'**
  String get cat_medical;

  /// No description provided for @cat_subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get cat_subscription;

  /// No description provided for @cat_household.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get cat_household;

  /// No description provided for @cat_education.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get cat_education;

  /// No description provided for @cat_entertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get cat_entertainment;

  /// No description provided for @cat_gift.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get cat_gift;

  /// No description provided for @cat_travel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get cat_travel;

  /// No description provided for @cat_insurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get cat_insurance;

  /// No description provided for @cat_tax_fees.
  ///
  /// In en, this message translates to:
  /// **'Tax & Fees'**
  String get cat_tax_fees;

  /// No description provided for @cat_expense_other.
  ///
  /// In en, this message translates to:
  /// **'Other Expense'**
  String get cat_expense_other;

  /// No description provided for @cat_todo.
  ///
  /// In en, this message translates to:
  /// **'Todo'**
  String get cat_todo;

  /// No description provided for @cat_document.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get cat_document;

  /// No description provided for @cat_bill_reminder.
  ///
  /// In en, this message translates to:
  /// **'Bill Reminder'**
  String get cat_bill_reminder;

  /// No description provided for @cat_renewal.
  ///
  /// In en, this message translates to:
  /// **'Renewal'**
  String get cat_renewal;

  /// No description provided for @cat_warranty.
  ///
  /// In en, this message translates to:
  /// **'Warranty'**
  String get cat_warranty;

  /// No description provided for @cat_health.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get cat_health;

  /// No description provided for @cat_grocery_stock.
  ///
  /// In en, this message translates to:
  /// **'Grocery Stock'**
  String get cat_grocery_stock;

  /// No description provided for @cat_household_item.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get cat_household_item;

  /// No description provided for @cat_device.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get cat_device;

  /// No description provided for @cat_item_other.
  ///
  /// In en, this message translates to:
  /// **'Other Item'**
  String get cat_item_other;

  /// No description provided for @cat_personal_project.
  ///
  /// In en, this message translates to:
  /// **'Personal Project'**
  String get cat_personal_project;

  /// No description provided for @cat_client_project.
  ///
  /// In en, this message translates to:
  /// **'Client Project'**
  String get cat_client_project;

  /// No description provided for @cat_family_project.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get cat_family_project;

  /// No description provided for @cat_event.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get cat_event;

  /// No description provided for @cat_trip.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get cat_trip;

  /// No description provided for @cat_learning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get cat_learning;

  /// No description provided for @cat_photo_order.
  ///
  /// In en, this message translates to:
  /// **'Photo Order'**
  String get cat_photo_order;

  /// No description provided for @cat_photo_follow.
  ///
  /// In en, this message translates to:
  /// **'Photo Shoot'**
  String get cat_photo_follow;

  /// No description provided for @cat_project_other.
  ///
  /// In en, this message translates to:
  /// **'Other Project'**
  String get cat_project_other;

  /// No description provided for @toast_billDeletedReadonly.
  ///
  /// In en, this message translates to:
  /// **'Bill deleted, read-only'**
  String get toast_billDeletedReadonly;

  /// No description provided for @toast_itemCancelled.
  ///
  /// In en, this message translates to:
  /// **'Item cancelled'**
  String get toast_itemCancelled;

  /// No description provided for @toast_itemCompletedReadonly.
  ///
  /// In en, this message translates to:
  /// **'Item completed, read-only'**
  String get toast_itemCompletedReadonly;

  /// No description provided for @toast_itemReopened.
  ///
  /// In en, this message translates to:
  /// **'Item reopened'**
  String get toast_itemReopened;

  /// No description provided for @toast_itemDeferred.
  ///
  /// In en, this message translates to:
  /// **'Item deferred'**
  String get toast_itemDeferred;

  /// No description provided for @toast_itemCompleted.
  ///
  /// In en, this message translates to:
  /// **'Item completed'**
  String get toast_itemCompleted;

  /// No description provided for @toast_projectArchived.
  ///
  /// In en, this message translates to:
  /// **'Project archived'**
  String get toast_projectArchived;

  /// No description provided for @toast_projectDeletedReadonly.
  ///
  /// In en, this message translates to:
  /// **'Project completed, read-only'**
  String get toast_projectDeletedReadonly;

  /// No description provided for @toast_keepOneTemplateNode.
  ///
  /// In en, this message translates to:
  /// **'Keep at least one template node'**
  String get toast_keepOneTemplateNode;

  /// No description provided for @toast_noMergeTarget.
  ///
  /// In en, this message translates to:
  /// **'No merge target category'**
  String get toast_noMergeTarget;

  /// No description provided for @toast_mergedCategory.
  ///
  /// In en, this message translates to:
  /// **'Merged {name}'**
  String toast_mergedCategory(String name);

  /// No description provided for @toast_exportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export cancelled'**
  String get toast_exportCancelled;

  /// No description provided for @toast_backupExported.
  ///
  /// In en, this message translates to:
  /// **'Backup exported: {path}'**
  String toast_backupExported(String path);

  /// No description provided for @toast_exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String toast_exportFailed(String error);

  /// No description provided for @toast_configureWebdavFirst.
  ///
  /// In en, this message translates to:
  /// **'Please configure WebDAV first'**
  String get toast_configureWebdavFirst;

  /// No description provided for @toast_uploadedToWebdav.
  ///
  /// In en, this message translates to:
  /// **'Backup uploaded to WebDAV'**
  String get toast_uploadedToWebdav;

  /// No description provided for @toast_uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String toast_uploadFailed(String error);

  /// No description provided for @toast_importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String toast_importFailed(String error);

  /// No description provided for @toast_noBackupFiles.
  ///
  /// In en, this message translates to:
  /// **'No backup files'**
  String get toast_noBackupFiles;

  /// No description provided for @toast_importCancelled.
  ///
  /// In en, this message translates to:
  /// **'Import cancelled'**
  String get toast_importCancelled;

  /// No description provided for @toast_projectRestored.
  ///
  /// In en, this message translates to:
  /// **'Project restored'**
  String get toast_projectRestored;

  /// No description provided for @toast_itemRestored.
  ///
  /// In en, this message translates to:
  /// **'Item restored'**
  String get toast_itemRestored;

  /// No description provided for @toast_billRestored.
  ///
  /// In en, this message translates to:
  /// **'Bill restored'**
  String get toast_billRestored;

  /// No description provided for @toast_projectPermanentlyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Project permanently deleted'**
  String get toast_projectPermanentlyDeleted;

  /// No description provided for @toast_itemPermanentlyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Item permanently deleted'**
  String get toast_itemPermanentlyDeleted;

  /// No description provided for @toast_billPermanentlyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Bill permanently deleted'**
  String get toast_billPermanentlyDeleted;

  /// No description provided for @toast_comingSoon.
  ///
  /// In en, this message translates to:
  /// **'{title} coming soon'**
  String toast_comingSoon(String title);

  /// No description provided for @toast_connectionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get toast_connectionSuccess;

  /// No description provided for @toast_connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed, check config'**
  String get toast_connectionFailed;

  /// No description provided for @toast_connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}'**
  String toast_connectionError(String error);

  /// No description provided for @toast_configSaved.
  ///
  /// In en, this message translates to:
  /// **'Config saved'**
  String get toast_configSaved;

  /// No description provided for @toast_saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String toast_saveFailed(String error);

  /// No description provided for @toast_saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get toast_saved;

  /// No description provided for @toast_savedItems.
  ///
  /// In en, this message translates to:
  /// **'Saved {count} items'**
  String toast_savedItems(int count);

  /// No description provided for @toast_partialSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'{count} items failed, please check'**
  String toast_partialSaveFailed(int count);

  /// No description provided for @toast_voiceNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Voice input not supported, use keyboard mic'**
  String get toast_voiceNotSupported;

  /// No description provided for @toast_ocrFailed.
  ///
  /// In en, this message translates to:
  /// **'Recognition failed, try again or use a clearer image'**
  String get toast_ocrFailed;

  /// No description provided for @toast_saveError.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String toast_saveError(String error);
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
