import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';
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
/// import 'l10n/app_localizations.dart';
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
    Locale('ko'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'Spitout'**
  String get appTitle;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get tabAnalytics;

  /// No description provided for @tabCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get tabCalendar;

  /// No description provided for @tabMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get tabMine;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @homeSelectBillMonth.
  ///
  /// In en, this message translates to:
  /// **'Select month'**
  String get homeSelectBillMonth;

  /// No description provided for @homePickerHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe up or down to pick'**
  String get homePickerHint;

  /// No description provided for @homeBackToCurrentMonth.
  ///
  /// In en, this message translates to:
  /// **'Back to current month'**
  String get homeBackToCurrentMonth;

  /// No description provided for @homeTodayExpense.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get homeTodayExpense;

  /// No description provided for @homeWeekExpense.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get homeWeekExpense;

  /// No description provided for @homeMonthExpense.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get homeMonthExpense;

  /// No description provided for @homeDetailCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get homeDetailCategory;

  /// No description provided for @homeDetailDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get homeDetailDate;

  /// No description provided for @homeDetailAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get homeDetailAmount;

  /// No description provided for @homeDetailCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get homeDetailCurrency;

  /// No description provided for @homeDetailNativeAmount.
  ///
  /// In en, this message translates to:
  /// **'In base currency'**
  String get homeDetailNativeAmount;

  /// No description provided for @homeDetailMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get homeDetailMembers;

  /// No description provided for @homeDetailCreator.
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get homeDetailCreator;

  /// No description provided for @homeDetailLastEditor.
  ///
  /// In en, this message translates to:
  /// **'Last edited by'**
  String get homeDetailLastEditor;

  /// No description provided for @homeDetailEditHistory.
  ///
  /// In en, this message translates to:
  /// **'Edit history'**
  String get homeDetailEditHistory;

  /// No description provided for @homeDetailEditHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'View only'**
  String get homeDetailEditHistoryHint;

  /// No description provided for @homeDetailEditButton.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get homeDetailEditButton;

  /// No description provided for @homeDetailNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No edit history'**
  String get homeDetailNoHistory;

  /// No description provided for @homeDeleteDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this entry?'**
  String get homeDeleteDetailTitle;

  /// No description provided for @homeDeleteDetailMessage.
  ///
  /// In en, this message translates to:
  /// **'This will delete the \"{name}\" record. This action cannot be undone.'**
  String homeDeleteDetailMessage(Object name);

  /// No description provided for @commonEmpty.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get commonEmpty;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get commonFailed;

  /// No description provided for @commonOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed, please try again later'**
  String get commonOperationFailed;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get commonFinish;

  /// No description provided for @commonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get commonOther;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Note...'**
  String get commonNoteHint;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get commonCurrent;

  /// No description provided for @commonTutorial.
  ///
  /// In en, this message translates to:
  /// **'Tutorial'**
  String get commonTutorial;

  /// No description provided for @commonConfigure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get commonConfigure;

  /// No description provided for @commonPressAgainToExit.
  ///
  /// In en, this message translates to:
  /// **'Press again to exit'**
  String get commonPressAgainToExit;

  /// No description provided for @commonWeekdayMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get commonWeekdayMonday;

  /// No description provided for @commonWeekdayTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get commonWeekdayTuesday;

  /// No description provided for @commonWeekdayWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get commonWeekdayWednesday;

  /// No description provided for @commonWeekdayThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get commonWeekdayThursday;

  /// No description provided for @commonWeekdayFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get commonWeekdayFriday;

  /// No description provided for @commonWeekdaySaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get commonWeekdaySaturday;

  /// No description provided for @commonWeekdaySunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get commonWeekdaySunday;

  /// No description provided for @homeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get homeExpense;

  /// No description provided for @homeNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get homeNoRecords;

  /// No description provided for @homeSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get homeSelectDate;

  /// No description provided for @homeYear.
  ///
  /// In en, this message translates to:
  /// **'{year}'**
  String homeYear(int year);

  /// No description provided for @homeMonth.
  ///
  /// In en, this message translates to:
  /// **'{month}M'**
  String homeMonth(String month);

  /// No description provided for @homeMonthExpenseOf.
  ///
  /// In en, this message translates to:
  /// **'Month {month}'**
  String homeMonthExpenseOf(String month);

  /// No description provided for @homeNoRecordsSubtext.
  ///
  /// In en, this message translates to:
  /// **'Tap the plus button at the bottom to add a record'**
  String get homeNoRecordsSubtext;

  /// No description provided for @homeBaseCurrencyNeedLedger.
  ///
  /// In en, this message translates to:
  /// **'Please create a ledger first'**
  String get homeBaseCurrencyNeedLedger;

  /// No description provided for @homeBaseCurrencySwitched.
  ///
  /// In en, this message translates to:
  /// **'Base currency switched to {code}'**
  String homeBaseCurrencySwitched(String code);

  /// No description provided for @homePullCloudSuccess.
  ///
  /// In en, this message translates to:
  /// **'Synced cloud ledger data'**
  String get homePullCloudSuccess;

  /// No description provided for @homePullCloudFailed.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed, please try again later'**
  String get homePullCloudFailed;

  /// No description provided for @homePullLocalSuccess.
  ///
  /// In en, this message translates to:
  /// **'Refreshed local ledger data & config'**
  String get homePullLocalSuccess;

  /// No description provided for @homePullCloudFailedButLocalOk.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync failed; refreshed local data (rates/config)'**
  String get homePullCloudFailedButLocalOk;

  /// No description provided for @homePullCloudHealed.
  ///
  /// In en, this message translates to:
  /// **'Auto-recovered and synced {count} cloud records'**
  String homePullCloudHealed(int count);

  /// No description provided for @homePullCloudGap.
  ///
  /// In en, this message translates to:
  /// **'Some cloud history could not be auto-restored. Please use \'Restore from cloud\' on the sync page'**
  String get homePullCloudGap;

  /// No description provided for @homeSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing ledger data'**
  String get homeSyncing;

  /// No description provided for @homeSwitchMonthHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe the list left/right to switch months'**
  String get homeSwitchMonthHint;

  /// No description provided for @analyticsMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get analyticsMonth;

  /// No description provided for @analyticsYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get analyticsYear;

  /// No description provided for @analyticsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get analyticsAll;

  /// No description provided for @analyticsWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get analyticsWeek;

  /// Hint shown on the analytics page to swipe the list left/right to switch the period (week/month/year).
  ///
  /// In en, this message translates to:
  /// **'Swipe left/right on the list to switch {period}'**
  String analyticsSwipePeriodHint(Object period);

  /// No description provided for @analyticsTrend.
  ///
  /// In en, this message translates to:
  /// **'Expense Trend'**
  String get analyticsTrend;

  /// No description provided for @analyticsTotalExpenseLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Expense'**
  String get analyticsTotalExpenseLabel;

  /// No description provided for @analyticsDailyExpense.
  ///
  /// In en, this message translates to:
  /// **'Daily Expense'**
  String get analyticsDailyExpense;

  /// No description provided for @analyticsMoMLastWeek.
  ///
  /// In en, this message translates to:
  /// **'vs Last Week'**
  String get analyticsMoMLastWeek;

  /// No description provided for @analyticsMoMLastMonth.
  ///
  /// In en, this message translates to:
  /// **'vs Last Month'**
  String get analyticsMoMLastMonth;

  /// No description provided for @analyticsMoMLastYear.
  ///
  /// In en, this message translates to:
  /// **'vs Last Year'**
  String get analyticsMoMLastYear;

  /// No description provided for @analyticsCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get analyticsCategoryLabel;

  /// No description provided for @analyticsExpenseRatio.
  ///
  /// In en, this message translates to:
  /// **'Expense Ratio'**
  String get analyticsExpenseRatio;

  /// No description provided for @analyticsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get analyticsThisWeek;

  /// No description provided for @analyticsBackToThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Back to This Week'**
  String get analyticsBackToThisWeek;

  /// No description provided for @analyticsBackToThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Back to This Month'**
  String get analyticsBackToThisMonth;

  /// No description provided for @analyticsBackToThisYear.
  ///
  /// In en, this message translates to:
  /// **'Back to This Year'**
  String get analyticsBackToThisYear;

  /// No description provided for @analyticsWeekN.
  ///
  /// In en, this message translates to:
  /// **'Week {week}'**
  String analyticsWeekN(int week);

  /// No description provided for @analyticsSelectWeek.
  ///
  /// In en, this message translates to:
  /// **'Select week'**
  String get analyticsSelectWeek;

  /// No description provided for @ledgersTitle.
  ///
  /// In en, this message translates to:
  /// **'Ledger Management'**
  String get ledgersTitle;

  /// No description provided for @ledgersNew.
  ///
  /// In en, this message translates to:
  /// **'New Ledger'**
  String get ledgersNew;

  /// No description provided for @ledgersClear.
  ///
  /// In en, this message translates to:
  /// **'Clear Ledger'**
  String get ledgersClear;

  /// No description provided for @ledgersClearMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to clear all transactions in ledger \"{name}\"? This action cannot be undone.\\nThe ledger will be kept, only transaction data will be deleted.'**
  String ledgersClearMessage(Object name);

  /// No description provided for @ledgerDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Default Ledger'**
  String get ledgerDefaultName;

  /// No description provided for @ledgersEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Ledger'**
  String get ledgersEdit;

  /// No description provided for @ledgersDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Ledger'**
  String get ledgersDelete;

  /// No description provided for @ledgersDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete Ledger'**
  String get ledgersDeleteConfirm;

  /// No description provided for @ledgersDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this ledger and all its records? This action cannot be undone.\\nIf there is a backup in the cloud, it will also be deleted.'**
  String get ledgersDeleteMessage;

  /// No description provided for @ledgersDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get ledgersDeleted;

  /// No description provided for @ledgersDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete Failed'**
  String get ledgersDeleteFailed;

  /// No description provided for @ledgersClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Ledger'**
  String get ledgersClearTitle;

  /// No description provided for @ledgersClearSuccess.
  ///
  /// In en, this message translates to:
  /// **'Ledger cleared'**
  String get ledgersClearSuccess;

  /// No description provided for @ledgersCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Ledger created'**
  String get ledgersCreateSuccess;

  /// No description provided for @ledgerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Ledger Name'**
  String get ledgerNameLabel;

  /// No description provided for @ledgerNameHint.
  ///
  /// In en, this message translates to:
  /// **'Please enter the ledger name'**
  String get ledgerNameHint;

  /// No description provided for @ledgersDefaultLedgerName.
  ///
  /// In en, this message translates to:
  /// **'Default Ledger'**
  String get ledgersDefaultLedgerName;

  /// No description provided for @ledgersCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get ledgersCurrency;

  /// No description provided for @ledgersMonthStartDay.
  ///
  /// In en, this message translates to:
  /// **'Month start day'**
  String get ledgersMonthStartDay;

  /// No description provided for @ledgersMonthStartDayHint.
  ///
  /// In en, this message translates to:
  /// **'Statistics and budgets use this day (1-28) as the start of each monthly period'**
  String get ledgersMonthStartDayHint;

  /// No description provided for @ledgersMonthStartDayNatural.
  ///
  /// In en, this message translates to:
  /// **'1st (calendar month)'**
  String get ledgersMonthStartDayNatural;

  /// No description provided for @ledgersMonthStartDayValue.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of each month'**
  String ledgersMonthStartDayValue(int day);

  /// No description provided for @ledgersSearchCurrency.
  ///
  /// In en, this message translates to:
  /// **'Search: Chinese or code'**
  String get ledgersSearchCurrency;

  /// No description provided for @ledgersCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get ledgersCreate;

  /// No description provided for @ledgersRecords.
  ///
  /// In en, this message translates to:
  /// **'Records: {count}'**
  String ledgersRecords(String count);

  /// No description provided for @ledgersExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense: {expense}'**
  String ledgersExpense(String expense);

  /// No description provided for @ledgersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No ledgers'**
  String get ledgersEmpty;

  /// No description provided for @ledgersSectionLocal.
  ///
  /// In en, this message translates to:
  /// **'Local ledgers'**
  String get ledgersSectionLocal;

  /// No description provided for @ledgersSectionCloud.
  ///
  /// In en, this message translates to:
  /// **'Spitout Cloud ledgers'**
  String get ledgersSectionCloud;

  /// No description provided for @ledgersSectionLocalEmpty.
  ///
  /// In en, this message translates to:
  /// **'No local ledgers. Local ledgers stay on this device only.'**
  String get ledgersSectionLocalEmpty;

  /// No description provided for @ledgersSectionCloudEmpty.
  ///
  /// In en, this message translates to:
  /// **'No cloud ledgers. Cloud ledgers sync across your devices.'**
  String get ledgersSectionCloudEmpty;

  /// No description provided for @ledgersSectionCloudSignInHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Spitout Cloud to use cloud ledgers'**
  String get ledgersSectionCloudSignInHint;

  /// No description provided for @ledgersStorageLocation.
  ///
  /// In en, this message translates to:
  /// **'Storage location'**
  String get ledgersStorageLocation;

  /// No description provided for @ledgersStorageLocalHint.
  ///
  /// In en, this message translates to:
  /// **'Stored on this device only, never uploaded'**
  String get ledgersStorageLocalHint;

  /// No description provided for @ledgersStorageCloudHint.
  ///
  /// In en, this message translates to:
  /// **'Uploaded to Spitout Cloud and synced across your devices'**
  String get ledgersStorageCloudHint;

  /// No description provided for @ledgersActionMoveToCloud.
  ///
  /// In en, this message translates to:
  /// **'Move to Spitout Cloud'**
  String get ledgersActionMoveToCloud;

  /// No description provided for @ledgersActionMoveToLocal.
  ///
  /// In en, this message translates to:
  /// **'Move to local'**
  String get ledgersActionMoveToLocal;

  /// No description provided for @ledgersActionCopyToLocal.
  ///
  /// In en, this message translates to:
  /// **'Copy to local'**
  String get ledgersActionCopyToLocal;

  /// No description provided for @ledgersMoveToCloudMessage.
  ///
  /// In en, this message translates to:
  /// **'Ledger \"{name}\" will be uploaded to Spitout Cloud and synced across your devices.'**
  String ledgersMoveToCloudMessage(String name);

  /// No description provided for @ledgersMoveToLocalMessage.
  ///
  /// In en, this message translates to:
  /// **'Ledger \"{name}\" will be deleted from Spitout Cloud and kept on this device only. Other devices will no longer see it.'**
  String ledgersMoveToLocalMessage(String name);

  /// No description provided for @ledgersCopyToLocalMessage.
  ///
  /// In en, this message translates to:
  /// **'A local copy of ledger \"{name}\" will be created. The cloud ledger stays unchanged.'**
  String ledgersCopyToLocalMessage(String name);

  /// No description provided for @ledgersMoveToCloudSuccess.
  ///
  /// In en, this message translates to:
  /// **'Moved to Spitout Cloud'**
  String get ledgersMoveToCloudSuccess;

  /// No description provided for @ledgersMoveToLocalSuccess.
  ///
  /// In en, this message translates to:
  /// **'Moved to local'**
  String get ledgersMoveToLocalSuccess;

  /// No description provided for @ledgersCopyToLocalSuccess.
  ///
  /// In en, this message translates to:
  /// **'Copied to local'**
  String get ledgersCopyToLocalSuccess;

  /// No description provided for @ledgersSwitched.
  ///
  /// In en, this message translates to:
  /// **'Switched to ledger \"{name}\"'**
  String ledgersSwitched(String name);

  /// No description provided for @categoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Category Management'**
  String get categoryTitle;

  /// No description provided for @categoryExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get categoryExpense;

  /// No description provided for @categoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No categories'**
  String get categoryEmpty;

  /// No description provided for @categoryLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed: {error}'**
  String categoryLoadFailed(String error);

  /// No description provided for @importReading.
  ///
  /// In en, this message translates to:
  /// **'Reading file…'**
  String get importReading;

  /// No description provided for @importPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get importPreparing;

  /// No description provided for @importColumnNumber.
  ///
  /// In en, this message translates to:
  /// **'Column {number}'**
  String importColumnNumber(Object number);

  /// No description provided for @importConfirmMapping.
  ///
  /// In en, this message translates to:
  /// **'Confirm Mapping'**
  String get importConfirmMapping;

  /// No description provided for @importCategoryMapping.
  ///
  /// In en, this message translates to:
  /// **'Category Mapping'**
  String get importCategoryMapping;

  /// No description provided for @importNoDataParsed.
  ///
  /// In en, this message translates to:
  /// **'No data parsed. Please return to previous page to check CSV content or separator.'**
  String get importNoDataParsed;

  /// No description provided for @importNoLedger.
  ///
  /// In en, this message translates to:
  /// **'Please create a ledger before importing'**
  String get importNoLedger;

  /// No description provided for @importInvalidRowsSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count} unparsable row(s) skipped (invalid amount or date)'**
  String importInvalidRowsSkipped(int count);

  /// No description provided for @importFieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get importFieldDate;

  /// No description provided for @importFieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get importFieldType;

  /// No description provided for @importFieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get importFieldAmount;

  /// No description provided for @importFieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get importFieldCategory;

  /// No description provided for @importFieldNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get importFieldNote;

  /// No description provided for @importPreview.
  ///
  /// In en, this message translates to:
  /// **'Data Preview'**
  String get importPreview;

  /// No description provided for @importPreviewLimit.
  ///
  /// In en, this message translates to:
  /// **'Showing first {shown} of {total} records'**
  String importPreviewLimit(Object shown, Object total);

  /// No description provided for @importCategoryNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Category not selected'**
  String get importCategoryNotSelected;

  /// No description provided for @importCategoryMappingDescription.
  ///
  /// In en, this message translates to:
  /// **'Please select corresponding local categories for each category name:'**
  String get importCategoryMappingDescription;

  /// No description provided for @importKeepOriginalName.
  ///
  /// In en, this message translates to:
  /// **'Keep original name'**
  String get importKeepOriginalName;

  /// No description provided for @importProgress.
  ///
  /// In en, this message translates to:
  /// **'Importing, success: {ok}, failed: {fail}'**
  String importProgress(Object fail, Object ok);

  /// No description provided for @importCancelImport.
  ///
  /// In en, this message translates to:
  /// **'Cancel Import'**
  String get importCancelImport;

  /// No description provided for @importCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Complete'**
  String get importCompleteTitle;

  /// No description provided for @importSelectCategoryFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select category mapping first'**
  String get importSelectCategoryFirst;

  /// No description provided for @importNextStep.
  ///
  /// In en, this message translates to:
  /// **'Next Step'**
  String get importNextStep;

  /// No description provided for @importPreviousStep.
  ///
  /// In en, this message translates to:
  /// **'Previous Step'**
  String get importPreviousStep;

  /// No description provided for @importStartImport.
  ///
  /// In en, this message translates to:
  /// **'Start Import'**
  String get importStartImport;

  /// No description provided for @importAutoDetect.
  ///
  /// In en, this message translates to:
  /// **'Auto Detect'**
  String get importAutoDetect;

  /// No description provided for @importInProgress.
  ///
  /// In en, this message translates to:
  /// **'Import in Progress'**
  String get importInProgress;

  /// No description provided for @importProgressDetail.
  ///
  /// In en, this message translates to:
  /// **'Imported {done} / {total} records, success {ok}, failed {fail}'**
  String importProgressDetail(
    Object done,
    Object fail,
    Object ok,
    Object total,
  );

  /// No description provided for @importBackgroundImport.
  ///
  /// In en, this message translates to:
  /// **'Background Import'**
  String get importBackgroundImport;

  /// No description provided for @importCancelled.
  ///
  /// In en, this message translates to:
  /// **'Import Cancelled'**
  String get importCancelled;

  /// No description provided for @importCompleted.
  ///
  /// In en, this message translates to:
  /// **'Import Completed{cancelled}, success {ok}, failed {fail}'**
  String importCompleted(Object cancelled, Object fail, Object ok);

  /// No description provided for @importSkippedNonTransactionTypes.
  ///
  /// In en, this message translates to:
  /// **'Skipped {count} non-transaction records (debts, etc.)'**
  String importSkippedNonTransactionTypes(Object count);

  /// No description provided for @importTransactionFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed, all changes have been rolled back: {error}'**
  String importTransactionFailed(Object error);

  /// No description provided for @importFileOpenError.
  ///
  /// In en, this message translates to:
  /// **'Unable to open file picker: {error}'**
  String importFileOpenError(String error);

  /// No description provided for @mineTitle.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get mineTitle;

  /// No description provided for @mineLanguageSettings.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get mineLanguageSettings;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language Settings'**
  String get languageTitle;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get languageSystemDefault;

  /// No description provided for @mineSlogan.
  ///
  /// In en, this message translates to:
  /// **'No nickname set'**
  String get mineSlogan;

  /// No description provided for @mineDisplayNameEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Set nickname'**
  String get mineDisplayNameEditTitle;

  /// No description provided for @mineDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a nickname'**
  String get mineDisplayNameHint;

  /// No description provided for @mineDisplayNameSaved.
  ///
  /// In en, this message translates to:
  /// **'Nickname updated'**
  String get mineDisplayNameSaved;

  /// No description provided for @mineGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get mineGreetingMorning;

  /// No description provided for @mineGreetingNoon.
  ///
  /// In en, this message translates to:
  /// **'Good noon'**
  String get mineGreetingNoon;

  /// No description provided for @mineGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get mineGreetingAfternoon;

  /// No description provided for @mineGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get mineGreetingEvening;

  /// No description provided for @mineGreetingNight.
  ///
  /// In en, this message translates to:
  /// **'Good night'**
  String get mineGreetingNight;

  /// No description provided for @mineGreetingNamed.
  ///
  /// In en, this message translates to:
  /// **'{greeting}, {name}'**
  String mineGreetingNamed(String greeting, String name);

  /// No description provided for @mineAvatarDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Avatar'**
  String get mineAvatarDelete;

  /// No description provided for @mineAvatarUploadNew.
  ///
  /// In en, this message translates to:
  /// **'Upload New Avatar'**
  String get mineAvatarUploadNew;

  /// No description provided for @mineCloudService.
  ///
  /// In en, this message translates to:
  /// **'Cloud Service'**
  String get mineCloudService;

  /// No description provided for @mineCloudServiceLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get mineCloudServiceLoading;

  /// No description provided for @mineSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get mineSyncTitle;

  /// No description provided for @mineSyncNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get mineSyncNotLoggedIn;

  /// No description provided for @mineSyncNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Cloud not configured'**
  String get mineSyncNotConfigured;

  /// No description provided for @mineSyncLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Local ledger, device only'**
  String get mineSyncLocalOnly;

  /// No description provided for @mineSyncNoRemote.
  ///
  /// In en, this message translates to:
  /// **'No cloud data'**
  String get mineSyncNoRemote;

  /// No description provided for @mineSyncInSync.
  ///
  /// In en, this message translates to:
  /// **'Synced (local {count} records)'**
  String mineSyncInSync(Object count);

  /// No description provided for @mineSyncLocalNewer.
  ///
  /// In en, this message translates to:
  /// **'Local updated ({count} records, upload recommended)'**
  String mineSyncLocalNewer(Object count);

  /// No description provided for @mineSyncCloudNewer.
  ///
  /// In en, this message translates to:
  /// **'Cloud updated (download to sync)'**
  String get mineSyncCloudNewer;

  /// No description provided for @mineSyncDifferent.
  ///
  /// In en, this message translates to:
  /// **'Local and cloud differ, download to compare'**
  String get mineSyncDifferent;

  /// No description provided for @mineSyncError.
  ///
  /// In en, this message translates to:
  /// **'Failed to get status'**
  String get mineSyncError;

  /// No description provided for @mineSyncDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Status Details'**
  String get mineSyncDetailTitle;

  /// No description provided for @mineSyncLocalRecords.
  ///
  /// In en, this message translates to:
  /// **'Local records: {count}'**
  String mineSyncLocalRecords(Object count);

  /// No description provided for @mineSyncCloudRecords.
  ///
  /// In en, this message translates to:
  /// **'Cloud records: {count}'**
  String mineSyncCloudRecords(Object count);

  /// No description provided for @mineSyncCloudLatest.
  ///
  /// In en, this message translates to:
  /// **'Cloud latest record time: {time}'**
  String mineSyncCloudLatest(Object time);

  /// No description provided for @mineSyncLocalFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Local fingerprint: {fingerprint}'**
  String mineSyncLocalFingerprint(Object fingerprint);

  /// No description provided for @mineSyncCloudFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Cloud fingerprint: {fingerprint}'**
  String mineSyncCloudFingerprint(Object fingerprint);

  /// No description provided for @mineSyncMessage.
  ///
  /// In en, this message translates to:
  /// **'Message: {message}'**
  String mineSyncMessage(Object message);

  /// No description provided for @mineUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get mineUploadTitle;

  /// No description provided for @mineUploadNeedLogin.
  ///
  /// In en, this message translates to:
  /// **'Login required'**
  String get mineUploadNeedLogin;

  /// No description provided for @mineUploadNeedCloudService.
  ///
  /// In en, this message translates to:
  /// **'Available in cloud service mode only'**
  String get mineUploadNeedCloudService;

  /// No description provided for @mineUploadInProgress.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get mineUploadInProgress;

  /// No description provided for @mineUploadRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing...'**
  String get mineUploadRefreshing;

  /// No description provided for @mineUploadSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get mineUploadSynced;

  /// No description provided for @mineUploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get mineUploadSuccess;

  /// No description provided for @mineUploadSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Current ledger synced to cloud'**
  String get mineUploadSuccessMessage;

  /// No description provided for @mineDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download & Sync'**
  String get mineDownloadTitle;

  /// No description provided for @mineDownloadNeedCloudService.
  ///
  /// In en, this message translates to:
  /// **'Available in cloud service mode only'**
  String get mineDownloadNeedCloudService;

  /// No description provided for @mineDownloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync Complete'**
  String get mineDownloadComplete;

  /// No description provided for @mineDownloadResult.
  ///
  /// In en, this message translates to:
  /// **'Imported: {inserted} records'**
  String mineDownloadResult(Object inserted);

  /// No description provided for @mineLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get mineLoginTitle;

  /// No description provided for @mineLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only needed for sync'**
  String get mineLoginSubtitle;

  /// No description provided for @cloudReloginTitle.
  ///
  /// In en, this message translates to:
  /// **'Re-login'**
  String get cloudReloginTitle;

  /// No description provided for @cloudReloginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Re-logged in'**
  String get cloudReloginSuccess;

  /// No description provided for @mineLoggedInAccount.
  ///
  /// In en, this message translates to:
  /// **'Logged in'**
  String get mineLoggedInAccount;

  /// No description provided for @mineLogoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to logout'**
  String get mineLogoutSubtitle;

  /// No description provided for @mineLogoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get mineLogoutConfirmTitle;

  /// No description provided for @mineLogoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?\nYou won\'t be able to use cloud sync after logout.'**
  String get mineLogoutConfirmMessage;

  /// No description provided for @mineLogoutButton.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get mineLogoutButton;

  /// No description provided for @mineAutoSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto sync ledger'**
  String get mineAutoSyncTitle;

  /// No description provided for @mineAutoSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto upload to cloud after recording'**
  String get mineAutoSyncSubtitle;

  /// No description provided for @mineAutoSyncNeedLogin.
  ///
  /// In en, this message translates to:
  /// **'Login required to enable'**
  String get mineAutoSyncNeedLogin;

  /// No description provided for @mineCategoryManagement.
  ///
  /// In en, this message translates to:
  /// **'Category Management'**
  String get mineCategoryManagement;

  /// No description provided for @mineCategoryManagementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Edit custom categories'**
  String get mineCategoryManagementSubtitle;

  /// No description provided for @mineRecurringTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recurring Bills'**
  String get mineRecurringTransactions;

  /// No description provided for @mineRecurringTransactionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage recurring bills'**
  String get mineRecurringTransactionsSubtitle;

  /// No description provided for @mineReminderSettings.
  ///
  /// In en, this message translates to:
  /// **'Reminder Settings'**
  String get mineReminderSettings;

  /// No description provided for @mineReminderSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set daily recording reminders'**
  String get mineReminderSettingsSubtitle;

  /// No description provided for @categoryEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get categoryEditTitle;

  /// No description provided for @categoryNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get categoryNewTitle;

  /// No description provided for @categoryDetailTooltip.
  ///
  /// In en, this message translates to:
  /// **'Category Summary'**
  String get categoryDetailTooltip;

  /// No description provided for @categoryDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Default Category'**
  String get categoryDefaultTitle;

  /// No description provided for @categoryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Category Name'**
  String get categoryNameLabel;

  /// No description provided for @categoryNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter category name'**
  String get categoryNameHint;

  /// No description provided for @categoryNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter category name'**
  String get categoryNameRequired;

  /// No description provided for @categoryNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Category name cannot exceed 4 characters'**
  String get categoryNameTooLong;

  /// No description provided for @categoryNameDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Category name already exists'**
  String get categoryNameDuplicate;

  /// No description provided for @categoryIconLabel.
  ///
  /// In en, this message translates to:
  /// **'Category Icon'**
  String get categoryIconLabel;

  /// No description provided for @categoryCurrentIcon.
  ///
  /// In en, this message translates to:
  /// **'Current Icon'**
  String get categoryCurrentIcon;

  /// No description provided for @categorySaveError.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get categorySaveError;

  /// No description provided for @categoryUpdated.
  ///
  /// In en, this message translates to:
  /// **'Category \"{name}\" updated'**
  String categoryUpdated(Object name);

  /// No description provided for @categoryCreated.
  ///
  /// In en, this message translates to:
  /// **'Category \"{name}\" created'**
  String categoryCreated(Object name);

  /// No description provided for @categoryCannotDelete.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete'**
  String get categoryCannotDelete;

  /// No description provided for @categoryClearUnused.
  ///
  /// In en, this message translates to:
  /// **'Clear Unused Categories'**
  String get categoryClearUnused;

  /// No description provided for @categoryClearUnusedTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Unused Categories'**
  String get categoryClearUnusedTitle;

  /// No description provided for @categoryClearUnusedMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} unused categories? This action cannot be undone.'**
  String categoryClearUnusedMessage(Object count);

  /// No description provided for @categoryClearUnusedListTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories to be deleted:'**
  String get categoryClearUnusedListTitle;

  /// No description provided for @categoryClearUnusedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No unused categories'**
  String get categoryClearUnusedEmpty;

  /// No description provided for @categoryClearUnusedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} categories'**
  String categoryClearUnusedSuccess(Object count);

  /// No description provided for @categoryClearUnusedFailed.
  ///
  /// In en, this message translates to:
  /// **'Clear failed'**
  String get categoryClearUnusedFailed;

  /// No description provided for @categoryDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Delete failed'**
  String get categoryDeleteError;

  /// No description provided for @categorySubCategoryCreated.
  ///
  /// In en, this message translates to:
  /// **'Subcategory added: {name}'**
  String categorySubCategoryCreated(Object name);

  /// No description provided for @categoryParentCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Belongs To'**
  String get categoryParentCategoryTitle;

  /// No description provided for @categorySelectParentTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get categorySelectParentTitle;

  /// No description provided for @categoryHasSubCategories.
  ///
  /// In en, this message translates to:
  /// **'This category has subcategories and cannot be modified'**
  String get categoryHasSubCategories;

  /// No description provided for @categorySearchCategory.
  ///
  /// In en, this message translates to:
  /// **'Search categories'**
  String get categorySearchCategory;

  /// No description provided for @categoryTopLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Top-level'**
  String get categoryTopLevelLabel;

  /// No description provided for @categorySecondLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Second-level'**
  String get categorySecondLevelLabel;

  /// No description provided for @categoryExpenseList.
  ///
  /// In en, this message translates to:
  /// **'Dining-Transport-Shopping-Entertainment-Home-Family-Communication-Utilities-Housing-Medical-Education-Pets-Sports-Digital-Travel-Alcohol & Tobacco-Baby Care-Beauty-Repair-Social-Learning-Car-Taxi-Subway-Delivery-Property-Parking-Donation-Give Gift-Tax-Beverage-Clothing-Snacks-Send Red Packet-Fruit-Game-Books-Lover-Decoration-Daily Goods-Lottery-Stock-Social Security-Express-Work-Transfer-Other'**
  String get categoryExpenseList;

  /// No description provided for @categoryExpenseDining.
  ///
  /// In en, this message translates to:
  /// **'Dining-Breakfast-Lunch-Dinner-Meituan Delivery-Ele.me Delivery-JD Delivery-Restaurant-Food'**
  String get categoryExpenseDining;

  /// No description provided for @categoryExpenseSnacks.
  ///
  /// In en, this message translates to:
  /// **'Snacks-Cookies-Chips-Candy-Chocolate-Nuts'**
  String get categoryExpenseSnacks;

  /// No description provided for @categoryExpenseFruit.
  ///
  /// In en, this message translates to:
  /// **'Fruit-Apple-Banana-Orange-Grape-Watermelon-Other Fruits'**
  String get categoryExpenseFruit;

  /// No description provided for @categoryExpenseBeverage.
  ///
  /// In en, this message translates to:
  /// **'Beverage-Milk Tea-Coffee-Juice-Soda-Mineral Water'**
  String get categoryExpenseBeverage;

  /// No description provided for @categoryExpensePastry.
  ///
  /// In en, this message translates to:
  /// **'Pastry-Cake-Bread-Dessert-Baked Goods'**
  String get categoryExpensePastry;

  /// No description provided for @categoryExpenseCooking.
  ///
  /// In en, this message translates to:
  /// **'Cooking Ingredients-Vegetables-Meat-Seafood-Seasoning-Grain & Oil'**
  String get categoryExpenseCooking;

  /// No description provided for @categoryExpenseShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping-Supermarket-Daily Necessities-Clothing-Shoes-Bags'**
  String get categoryExpenseShopping;

  /// No description provided for @categoryExpensePets.
  ///
  /// In en, this message translates to:
  /// **'Pets-Pet Food-Pet Supplies-Pet Medical-Pet Grooming'**
  String get categoryExpensePets;

  /// No description provided for @categoryExpenseTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport-Transit Card-Taxi-Parking Fee-Fuel'**
  String get categoryExpenseTransport;

  /// No description provided for @categoryExpenseCar.
  ///
  /// In en, this message translates to:
  /// **'Car-Car Maintenance-Car Repair-Car Insurance-Car Wash-Traffic Fine'**
  String get categoryExpenseCar;

  /// No description provided for @categoryExpenseClothing.
  ///
  /// In en, this message translates to:
  /// **'Apparel-Top-Pants-Dress-Shoes-Apparel Accessories'**
  String get categoryExpenseClothing;

  /// No description provided for @categoryExpenseDailyGoods.
  ///
  /// In en, this message translates to:
  /// **'Daily Goods-Personal Care-Paper Products-Cleaning Supplies-Kitchen Supplies'**
  String get categoryExpenseDailyGoods;

  /// No description provided for @categoryExpenseEducation.
  ///
  /// In en, this message translates to:
  /// **'Education-Tuition-Training Fee-Books-Stationery-Office Supplies-Learning'**
  String get categoryExpenseEducation;

  /// No description provided for @categoryExpenseInvestLoss.
  ///
  /// In en, this message translates to:
  /// **'Investment Loss-Stock Loss-Fund Loss-Other Investment Loss'**
  String get categoryExpenseInvestLoss;

  /// No description provided for @categoryExpenseEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment-Movie-KTV-Amusement Park-Bar-Other Entertainment'**
  String get categoryExpenseEntertainment;

  /// No description provided for @categoryExpenseGame.
  ///
  /// In en, this message translates to:
  /// **'Game-Game Top up-Game Equipment-Game Membership'**
  String get categoryExpenseGame;

  /// No description provided for @categoryExpenseHealthProducts.
  ///
  /// In en, this message translates to:
  /// **'Health Products-Vitamins-Health Food-Nutritional Supplements'**
  String get categoryExpenseHealthProducts;

  /// No description provided for @categoryExpenseSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription-Video Membership-Music Membership-Cloud Storage-Other Subscription'**
  String get categoryExpenseSubscription;

  /// No description provided for @categoryExpenseSports.
  ///
  /// In en, this message translates to:
  /// **'Sports-Gym-Sports Equipment-Sports Course-Outdoor Activity'**
  String get categoryExpenseSports;

  /// No description provided for @categoryExpenseHousing.
  ///
  /// In en, this message translates to:
  /// **'Housing-Utilities-Property Fee-Rent-Mortgage-Renovation-Broadband'**
  String get categoryExpenseHousing;

  /// No description provided for @categoryExpenseHome.
  ///
  /// In en, this message translates to:
  /// **'Home-Furniture-Appliances-Decorations-Bedding'**
  String get categoryExpenseHome;

  /// No description provided for @categoryExpenseBeauty.
  ///
  /// In en, this message translates to:
  /// **'Beauty-Skincare-Cosmetics-Haircut-Nail Care'**
  String get categoryExpenseBeauty;

  /// No description provided for @categoryExpenseTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer-Living Cost-Family-Parents-Lover-Borrow Money'**
  String get categoryExpenseTransfer;

  /// No description provided for @appearanceThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get appearanceThemeMode;

  /// No description provided for @appearanceThemeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get appearanceThemeModeSystem;

  /// No description provided for @appearanceThemeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get appearanceThemeModeLight;

  /// No description provided for @appearanceThemeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get appearanceThemeModeDark;

  /// No description provided for @appearanceExpenseColorScheme.
  ///
  /// In en, this message translates to:
  /// **'Expense Color'**
  String get appearanceExpenseColorScheme;

  /// No description provided for @appearanceExpenseColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red for expense'**
  String get appearanceExpenseColorRed;

  /// No description provided for @appearanceExpenseColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green for expense'**
  String get appearanceExpenseColorGreen;

  /// No description provided for @appearanceExpenseColorApplied.
  ///
  /// In en, this message translates to:
  /// **'Color scheme updated'**
  String get appearanceExpenseColorApplied;

  /// No description provided for @reminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording Reminder'**
  String get reminderTitle;

  /// No description provided for @reminderBody.
  ///
  /// In en, this message translates to:
  /// **'Don\'t forget to record today\'s income and expenses 💰'**
  String get reminderBody;

  /// No description provided for @reminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set daily recording reminder time'**
  String get reminderSubtitle;

  /// No description provided for @reminderDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Recording Reminder'**
  String get reminderDailyTitle;

  /// No description provided for @reminderDailySubtitle.
  ///
  /// In en, this message translates to:
  /// **'When enabled, will remind you to record at specified time'**
  String get reminderDailySubtitle;

  /// No description provided for @reminderTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder Time'**
  String get reminderTimeTitle;

  /// No description provided for @commonSelectTime.
  ///
  /// In en, this message translates to:
  /// **'Select Time'**
  String get commonSelectTime;

  /// No description provided for @reminderTestNotification.
  ///
  /// In en, this message translates to:
  /// **'Send Test Notification'**
  String get reminderTestNotification;

  /// No description provided for @reminderTestSent.
  ///
  /// In en, this message translates to:
  /// **'Test notification sent'**
  String get reminderTestSent;

  /// No description provided for @reminderTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Test Notification'**
  String get reminderTestTitle;

  /// No description provided for @reminderTestBody.
  ///
  /// In en, this message translates to:
  /// **'This is a test notification, tap to see the effect'**
  String get reminderTestBody;

  /// No description provided for @reminderCheckBattery.
  ///
  /// In en, this message translates to:
  /// **'Check Battery Optimization Status'**
  String get reminderCheckBattery;

  /// No description provided for @reminderBatteryStatus.
  ///
  /// In en, this message translates to:
  /// **'Battery Optimization Status'**
  String get reminderBatteryStatus;

  /// No description provided for @reminderManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer: {value}'**
  String reminderManufacturer(Object value);

  /// No description provided for @reminderModel.
  ///
  /// In en, this message translates to:
  /// **'Model: {value}'**
  String reminderModel(Object value);

  /// No description provided for @reminderAndroidVersion.
  ///
  /// In en, this message translates to:
  /// **'Android Version: {value}'**
  String reminderAndroidVersion(Object value);

  /// No description provided for @reminderBatteryIgnored.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization: Ignored ✅'**
  String get reminderBatteryIgnored;

  /// No description provided for @reminderBatteryNotIgnored.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization: Not ignored ⚠️'**
  String get reminderBatteryNotIgnored;

  /// No description provided for @reminderBatteryAdvice.
  ///
  /// In en, this message translates to:
  /// **'Recommend disabling battery optimization for proper notifications'**
  String get reminderBatteryAdvice;

  /// No description provided for @reminderCheckChannel.
  ///
  /// In en, this message translates to:
  /// **'Check Notification Channel Settings'**
  String get reminderCheckChannel;

  /// No description provided for @reminderChannelStatus.
  ///
  /// In en, this message translates to:
  /// **'Notification Channel Status'**
  String get reminderChannelStatus;

  /// No description provided for @reminderChannelEnabled.
  ///
  /// In en, this message translates to:
  /// **'Channel enabled: Yes ✅'**
  String get reminderChannelEnabled;

  /// No description provided for @reminderChannelDisabled.
  ///
  /// In en, this message translates to:
  /// **'Channel enabled: No ❌'**
  String get reminderChannelDisabled;

  /// No description provided for @reminderChannelImportance.
  ///
  /// In en, this message translates to:
  /// **'Importance: {value}'**
  String reminderChannelImportance(Object value);

  /// No description provided for @reminderChannelSoundOn.
  ///
  /// In en, this message translates to:
  /// **'Sound: On 🔊'**
  String get reminderChannelSoundOn;

  /// No description provided for @reminderChannelSoundOff.
  ///
  /// In en, this message translates to:
  /// **'Sound: Off 🔇'**
  String get reminderChannelSoundOff;

  /// No description provided for @reminderChannelVibrationOn.
  ///
  /// In en, this message translates to:
  /// **'Vibration: On 📳'**
  String get reminderChannelVibrationOn;

  /// No description provided for @reminderChannelVibrationOff.
  ///
  /// In en, this message translates to:
  /// **'Vibration: Off'**
  String get reminderChannelVibrationOff;

  /// No description provided for @reminderChannelDndBypass.
  ///
  /// In en, this message translates to:
  /// **'Do Not Disturb: Can bypass'**
  String get reminderChannelDndBypass;

  /// No description provided for @reminderChannelDndNoBypass.
  ///
  /// In en, this message translates to:
  /// **'Do Not Disturb: Cannot bypass'**
  String get reminderChannelDndNoBypass;

  /// No description provided for @reminderChannelAdvice.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Recommended settings:'**
  String get reminderChannelAdvice;

  /// No description provided for @reminderChannelAdviceImportance.
  ///
  /// In en, this message translates to:
  /// **'• Importance: Urgent or High'**
  String get reminderChannelAdviceImportance;

  /// No description provided for @reminderChannelAdviceSound.
  ///
  /// In en, this message translates to:
  /// **'• Enable sound and vibration'**
  String get reminderChannelAdviceSound;

  /// No description provided for @reminderChannelAdviceBanner.
  ///
  /// In en, this message translates to:
  /// **'• Allow banner notifications'**
  String get reminderChannelAdviceBanner;

  /// No description provided for @reminderChannelAdviceXiaomi.
  ///
  /// In en, this message translates to:
  /// **'• Xiaomi phones need individual channel setup'**
  String get reminderChannelAdviceXiaomi;

  /// No description provided for @reminderChannelGood.
  ///
  /// In en, this message translates to:
  /// **'✅ Notification channel well configured'**
  String get reminderChannelGood;

  /// No description provided for @reminderOpenAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Open App Settings'**
  String get reminderOpenAppSettings;

  /// No description provided for @reminderAppSettingsMessage.
  ///
  /// In en, this message translates to:
  /// **'Please allow notifications and disable battery optimization in settings'**
  String get reminderAppSettingsMessage;

  /// No description provided for @reminderDescription.
  ///
  /// In en, this message translates to:
  /// **'Tip: When recording reminder is enabled, the system will send notifications at the specified time daily to remind you to record expenses.'**
  String get reminderDescription;

  /// No description provided for @reminderAndroidInstructions.
  ///
  /// In en, this message translates to:
  /// **'If notifications don\'t work properly, check:\n• App is allowed to send notifications\n• Disable battery optimization/power saving for app\n• Allow app to run in background and auto-start\n• Android 12+ needs exact alarm permission\n\n📱 Xiaomi phone special settings:\n• Settings > App Management > Spitout > Notification Management\n• Tap \"Recording Reminder\" channel\n• Set importance to \"Urgent\" or \"High\"\n• Enable \"Banner notifications\", \"Sound\", \"Vibration\"\n• Security Center > App Management > Permissions > Auto-start\n\n🔒 Lock background methods:\n• Find Spitout in recent tasks\n• Pull down app card to show lock icon\n• Tap lock icon to prevent cleanup'**
  String get reminderAndroidInstructions;

  /// No description provided for @categoryDetailLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed'**
  String get categoryDetailLoadFailed;

  /// No description provided for @categoryDetailSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Category Summary'**
  String get categoryDetailSummaryTitle;

  /// No description provided for @categoryDetailTotalCount.
  ///
  /// In en, this message translates to:
  /// **'Total Count'**
  String get categoryDetailTotalCount;

  /// No description provided for @categoryDetailTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get categoryDetailTotalAmount;

  /// No description provided for @categoryDetailAverageAmount.
  ///
  /// In en, this message translates to:
  /// **'Average Amount'**
  String get categoryDetailAverageAmount;

  /// No description provided for @categoryDetailSortTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get categoryDetailSortTitle;

  /// No description provided for @categoryDetailSortTimeDesc.
  ///
  /// In en, this message translates to:
  /// **'Time ↓'**
  String get categoryDetailSortTimeDesc;

  /// No description provided for @categoryDetailSortTimeAsc.
  ///
  /// In en, this message translates to:
  /// **'Time ↑'**
  String get categoryDetailSortTimeAsc;

  /// No description provided for @categoryDetailSortAmountDesc.
  ///
  /// In en, this message translates to:
  /// **'Amount ↓'**
  String get categoryDetailSortAmountDesc;

  /// No description provided for @categoryDetailSortAmountAsc.
  ///
  /// In en, this message translates to:
  /// **'Amount ↑'**
  String get categoryDetailSortAmountAsc;

  /// No description provided for @categoryDetailNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get categoryDetailNoTransactions;

  /// No description provided for @categoryDetailNoTransactionsSubtext.
  ///
  /// In en, this message translates to:
  /// **'No transactions in this category yet'**
  String get categoryDetailNoTransactionsSubtext;

  /// No description provided for @categoryDetailDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed'**
  String get categoryDetailDeleteFailed;

  /// No description provided for @categoryMigrationTransactionLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} records'**
  String categoryMigrationTransactionLabel(int count);

  /// No description provided for @categoryTemplateEntryFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat Template'**
  String get categoryTemplateEntryFlat;

  /// No description provided for @categoryTemplateEntryHierarchical.
  ///
  /// In en, this message translates to:
  /// **'Hierarchical Template'**
  String get categoryTemplateEntryHierarchical;

  /// No description provided for @categoryTemplateFlatTitle.
  ///
  /// In en, this message translates to:
  /// **'Flat Category Template'**
  String get categoryTemplateFlatTitle;

  /// No description provided for @categoryTemplateHierarchicalTitle.
  ///
  /// In en, this message translates to:
  /// **'Hierarchical Category Template'**
  String get categoryTemplateHierarchicalTitle;

  /// No description provided for @categoryTemplateSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String categoryTemplateSelectedCount(int count);

  /// No description provided for @categoryTemplateSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get categoryTemplateSelectAll;

  /// No description provided for @categoryTemplateDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get categoryTemplateDeselectAll;

  /// No description provided for @categoryTemplateConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Categories'**
  String get categoryTemplateConfirmTitle;

  /// No description provided for @categoryTemplateConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Add the selected {count} categories to your category list?'**
  String categoryTemplateConfirmMessage(int count);

  /// No description provided for @categoryTemplateAddSuccess.
  ///
  /// In en, this message translates to:
  /// **'Added {count} categories'**
  String categoryTemplateAddSuccess(int count);

  /// No description provided for @categoryTemplateAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add: {error}'**
  String categoryTemplateAddFailed(String error);

  /// No description provided for @categoryManageAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get categoryManageAdd;

  /// No description provided for @categoryManageDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Categories'**
  String get categoryManageDelete;

  /// No description provided for @categoryManageConfirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get categoryManageConfirmDelete;

  /// No description provided for @categoryManageReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Long press to reorder'**
  String get categoryManageReorderHint;

  /// No description provided for @categorySharedManageBannerOwner.
  ///
  /// In en, this message translates to:
  /// **'Shared ledger: category changes here sync to all members'**
  String get categorySharedManageBannerOwner;

  /// No description provided for @categorySharedManageBannerEditor.
  ///
  /// In en, this message translates to:
  /// **'This shared ledger uses the owner\'s categories; edits here only affect your personal categories'**
  String get categorySharedManageBannerEditor;

  /// No description provided for @categorySyncFailedBeforeInvite.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sync categories before creating the invite. Check your network and try again'**
  String get categorySyncFailedBeforeInvite;

  /// No description provided for @categorySortSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save order. Please try again'**
  String get categorySortSaveFailed;

  /// No description provided for @categoryDeleteOptionAll.
  ///
  /// In en, this message translates to:
  /// **'Delete categories and all data (incl. subcategories)'**
  String get categoryDeleteOptionAll;

  /// No description provided for @categoryDeleteOptionMigrate.
  ///
  /// In en, this message translates to:
  /// **'Delete and migrate all data to another category (incl. subcategories)'**
  String get categoryDeleteOptionMigrate;

  /// No description provided for @categoryDeleteOptionPromote.
  ///
  /// In en, this message translates to:
  /// **'Delete categories and data (excl. subcategories, subcategories become top-level)'**
  String get categoryDeleteOptionPromote;

  /// No description provided for @categoryDeleteSelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Selected Categories'**
  String get categoryDeleteSelectedTitle;

  /// No description provided for @categoryDeleteSelectedSubtitleWithSub.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} selected categories and clear their data? (including subcategories and data) This action cannot be undone.'**
  String categoryDeleteSelectedSubtitleWithSub(int count);

  /// No description provided for @categoryDeleteSelectedSubtitleWithoutSub.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} selected categories and clear their data? (excluding subcategories and data) This action cannot be undone.'**
  String categoryDeleteSelectedSubtitleWithoutSub(int count);

  /// No description provided for @categoryMigrateSelectTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Target Category'**
  String get categoryMigrateSelectTargetTitle;

  /// No description provided for @categoryMigrateConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm (Migrate data and delete categories)'**
  String get categoryMigrateConfirmButton;

  /// No description provided for @categoryMigrateChildLabel.
  ///
  /// In en, this message translates to:
  /// **'Sub · {parent}'**
  String categoryMigrateChildLabel(Object parent);

  /// No description provided for @subcategoryEditParent.
  ///
  /// In en, this message translates to:
  /// **'Edit Parent Category'**
  String get subcategoryEditParent;

  /// No description provided for @subcategoryAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Subcategory'**
  String get subcategoryAdd;

  /// No description provided for @subcategoryDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Subcategories'**
  String get subcategoryDelete;

  /// No description provided for @subcategoryDeleteOptionAll.
  ///
  /// In en, this message translates to:
  /// **'Delete categories and all data under them'**
  String get subcategoryDeleteOptionAll;

  /// No description provided for @subcategoryDeleteOptionMigrate.
  ///
  /// In en, this message translates to:
  /// **'Delete categories and migrate all data to another category'**
  String get subcategoryDeleteOptionMigrate;

  /// No description provided for @subcategoryDeleteSelectedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} selected categories and clear their data? This action cannot be undone.'**
  String subcategoryDeleteSelectedSubtitle(int count);

  /// No description provided for @subcategoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No subcategories yet'**
  String get subcategoryEmpty;

  /// No description provided for @cloudSupabaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Supabase URL'**
  String get cloudSupabaseUrlLabel;

  /// No description provided for @cloudSupabaseUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://xxx.supabase.co'**
  String get cloudSupabaseUrlHint;

  /// No description provided for @cloudAnonKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Anon Key'**
  String get cloudAnonKeyLabel;

  /// No description provided for @cloudMultiDeviceWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-Device Tips'**
  String get cloudMultiDeviceWarningTitle;

  /// No description provided for @cloudMultiDeviceWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'Upload before switching devices, download on the new device before editing. Don\'t edit the same ledger on two devices at once. Tap for details →'**
  String get cloudMultiDeviceWarningMessage;

  /// No description provided for @cloudWebdavUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Server URL'**
  String get cloudWebdavUrlLabel;

  /// No description provided for @cloudWebdavUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://dav.jianguoyun.com/dav/'**
  String get cloudWebdavUrlHint;

  /// No description provided for @cloudWebdavUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get cloudWebdavUsernameLabel;

  /// No description provided for @cloudWebdavPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get cloudWebdavPasswordLabel;

  /// No description provided for @cloudWebdavPathHint.
  ///
  /// In en, this message translates to:
  /// **'/Spitout'**
  String get cloudWebdavPathHint;

  /// No description provided for @cloudS3EndpointLabel.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get cloudS3EndpointLabel;

  /// No description provided for @cloudS3EndpointHint.
  ///
  /// In en, this message translates to:
  /// **'s3.amazonaws.com or custom endpoint'**
  String get cloudS3EndpointHint;

  /// No description provided for @cloudS3RegionLabel.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get cloudS3RegionLabel;

  /// No description provided for @cloudS3RegionHint.
  ///
  /// In en, this message translates to:
  /// **'us-east-1 (leave blank for auto)'**
  String get cloudS3RegionHint;

  /// No description provided for @cloudS3AccessKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Access Key'**
  String get cloudS3AccessKeyLabel;

  /// No description provided for @cloudS3AccessKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Your Access Key ID'**
  String get cloudS3AccessKeyHint;

  /// No description provided for @cloudS3SecretKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Secret Key'**
  String get cloudS3SecretKeyLabel;

  /// No description provided for @cloudS3SecretKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Your Secret Access Key'**
  String get cloudS3SecretKeyHint;

  /// No description provided for @cloudS3BucketLabel.
  ///
  /// In en, this message translates to:
  /// **'Bucket Name'**
  String get cloudS3BucketLabel;

  /// No description provided for @cloudS3BucketHint.
  ///
  /// In en, this message translates to:
  /// **'spitout-data'**
  String get cloudS3BucketHint;

  /// No description provided for @cloudS3UseSSLLabel.
  ///
  /// In en, this message translates to:
  /// **'Use HTTPS'**
  String get cloudS3UseSSLLabel;

  /// No description provided for @cloudS3PortLabel.
  ///
  /// In en, this message translates to:
  /// **'Port (optional)'**
  String get cloudS3PortLabel;

  /// No description provided for @cloudS3PortHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank for default'**
  String get cloudS3PortHint;

  /// No description provided for @cloudSupabaseBucketLabel.
  ///
  /// In en, this message translates to:
  /// **'Storage Bucket Name'**
  String get cloudSupabaseBucketLabel;

  /// No description provided for @cloudSupabaseBucketHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank for default: spitout-backups'**
  String get cloudSupabaseBucketHint;

  /// No description provided for @authRememberAccount.
  ///
  /// In en, this message translates to:
  /// **'Remember account'**
  String get authRememberAccount;

  /// No description provided for @authRememberAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Auto-fill on next login'**
  String get authRememberAccountHint;

  /// No description provided for @cloudFirstSaveSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Configuration Saved'**
  String get cloudFirstSaveSwitchTitle;

  /// No description provided for @cloudFirstSaveSwitchMessage.
  ///
  /// In en, this message translates to:
  /// **'Switch to this cloud service as the active sync configuration now?'**
  String get cloudFirstSaveSwitchMessage;

  /// No description provided for @cloudSaveOnlyNoSwitch.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get cloudSaveOnlyNoSwitch;

  /// No description provided for @cloudSaveAndSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch Now'**
  String get cloudSaveAndSwitch;

  /// No description provided for @cloudClearConfig.
  ///
  /// In en, this message translates to:
  /// **'Clear configuration'**
  String get cloudClearConfig;

  /// No description provided for @cloudClearConfigConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear cloud configuration'**
  String get cloudClearConfigConfirmTitle;

  /// No description provided for @cloudClearConfigConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Clear this cloud service configuration?\nBacked-up data on the cloud will not be deleted. You can reconfigure and restore anytime.'**
  String get cloudClearConfigConfirmMessage;

  /// No description provided for @cloudClearConfigDone.
  ///
  /// In en, this message translates to:
  /// **'Configuration cleared'**
  String get cloudClearConfigDone;

  /// No description provided for @cloudPurgeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear cloud ledgers, please try again later'**
  String get cloudPurgeFailed;

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get authLogin;

  /// No description provided for @authAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get authAccount;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authInvalidAccount.
  ///
  /// In en, this message translates to:
  /// **'Please enter your account'**
  String get authInvalidAccount;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Account or password is incorrect.'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorAccountNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Account not verified, please complete verification before logging in.'**
  String get authErrorAccountNotConfirmed;

  /// No description provided for @authErrorRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts, please try again later.'**
  String get authErrorRateLimit;

  /// No description provided for @authErrorNetworkIssue.
  ///
  /// In en, this message translates to:
  /// **'Network error, please check your connection and try again.'**
  String get authErrorNetworkIssue;

  /// No description provided for @authErrorLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed, please try again later.'**
  String get authErrorLoginFailed;

  /// No description provided for @exportCsvHeaderType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get exportCsvHeaderType;

  /// No description provided for @exportCsvHeaderCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get exportCsvHeaderCategory;

  /// No description provided for @exportCsvHeaderSubCategory.
  ///
  /// In en, this message translates to:
  /// **'Subcategory'**
  String get exportCsvHeaderSubCategory;

  /// No description provided for @exportCsvHeaderAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get exportCsvHeaderAmount;

  /// No description provided for @exportCsvHeaderNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get exportCsvHeaderNote;

  /// No description provided for @exportCsvHeaderTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get exportCsvHeaderTime;

  /// No description provided for @exportSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Successful'**
  String get exportSuccessTitle;

  /// No description provided for @exportSuccessMessageAndroid.
  ///
  /// In en, this message translates to:
  /// **'Saved to:\n{path}'**
  String exportSuccessMessageAndroid(String path);

  /// No description provided for @exportFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Failed'**
  String get exportFailedTitle;

  /// No description provided for @exportTypeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get exportTypeExpense;

  /// No description provided for @exportSuccessMessageIos.
  ///
  /// In en, this message translates to:
  /// **'Exported to app documents:\n{path}'**
  String exportSuccessMessageIos(String path);

  /// No description provided for @currencyCNY.
  ///
  /// In en, this message translates to:
  /// **'Chinese Yuan'**
  String get currencyCNY;

  /// No description provided for @currencyUSD.
  ///
  /// In en, this message translates to:
  /// **'US Dollar'**
  String get currencyUSD;

  /// No description provided for @currencyEUR.
  ///
  /// In en, this message translates to:
  /// **'Euro'**
  String get currencyEUR;

  /// No description provided for @currencyJPY.
  ///
  /// In en, this message translates to:
  /// **'Japanese Yen'**
  String get currencyJPY;

  /// No description provided for @currencyHKD.
  ///
  /// In en, this message translates to:
  /// **'Hong Kong Dollar'**
  String get currencyHKD;

  /// No description provided for @currencyTWD.
  ///
  /// In en, this message translates to:
  /// **'New Taiwan Dollar'**
  String get currencyTWD;

  /// No description provided for @currencyGBP.
  ///
  /// In en, this message translates to:
  /// **'British Pound'**
  String get currencyGBP;

  /// No description provided for @currencyAUD.
  ///
  /// In en, this message translates to:
  /// **'Australian Dollar'**
  String get currencyAUD;

  /// No description provided for @currencyCAD.
  ///
  /// In en, this message translates to:
  /// **'Canadian Dollar'**
  String get currencyCAD;

  /// No description provided for @currencyKRW.
  ///
  /// In en, this message translates to:
  /// **'South Korean Won'**
  String get currencyKRW;

  /// No description provided for @currencySGD.
  ///
  /// In en, this message translates to:
  /// **'Singapore Dollar'**
  String get currencySGD;

  /// No description provided for @currencyMYR.
  ///
  /// In en, this message translates to:
  /// **'Malaysian Ringgit'**
  String get currencyMYR;

  /// No description provided for @currencyTHB.
  ///
  /// In en, this message translates to:
  /// **'Thai Baht'**
  String get currencyTHB;

  /// No description provided for @currencyIDR.
  ///
  /// In en, this message translates to:
  /// **'Indonesian Rupiah'**
  String get currencyIDR;

  /// No description provided for @currencyPHP.
  ///
  /// In en, this message translates to:
  /// **'Philippine Peso'**
  String get currencyPHP;

  /// No description provided for @currencyVND.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese Dong'**
  String get currencyVND;

  /// No description provided for @currencyINR.
  ///
  /// In en, this message translates to:
  /// **'Indian Rupee'**
  String get currencyINR;

  /// No description provided for @currencyRUB.
  ///
  /// In en, this message translates to:
  /// **'Russian Ruble'**
  String get currencyRUB;

  /// No description provided for @currencyBYN.
  ///
  /// In en, this message translates to:
  /// **'Belarusian Ruble'**
  String get currencyBYN;

  /// No description provided for @currencyNZD.
  ///
  /// In en, this message translates to:
  /// **'New Zealand Dollar'**
  String get currencyNZD;

  /// No description provided for @currencyCHF.
  ///
  /// In en, this message translates to:
  /// **'Swiss Franc'**
  String get currencyCHF;

  /// No description provided for @currencySEK.
  ///
  /// In en, this message translates to:
  /// **'Swedish Krona'**
  String get currencySEK;

  /// No description provided for @currencyNOK.
  ///
  /// In en, this message translates to:
  /// **'Norwegian Krone'**
  String get currencyNOK;

  /// No description provided for @currencyDKK.
  ///
  /// In en, this message translates to:
  /// **'Danish Krone'**
  String get currencyDKK;

  /// No description provided for @currencyBRL.
  ///
  /// In en, this message translates to:
  /// **'Brazilian Real'**
  String get currencyBRL;

  /// No description provided for @currencyMXN.
  ///
  /// In en, this message translates to:
  /// **'Mexican Peso'**
  String get currencyMXN;

  /// No description provided for @currencyTRY.
  ///
  /// In en, this message translates to:
  /// **'Turkish Lira'**
  String get currencyTRY;

  /// No description provided for @currencyZAR.
  ///
  /// In en, this message translates to:
  /// **'South African Rand'**
  String get currencyZAR;

  /// No description provided for @currencyAED.
  ///
  /// In en, this message translates to:
  /// **'UAE Dirham'**
  String get currencyAED;

  /// No description provided for @currencySAR.
  ///
  /// In en, this message translates to:
  /// **'Saudi Riyal'**
  String get currencySAR;

  /// No description provided for @currencyPLN.
  ///
  /// In en, this message translates to:
  /// **'Polish Zloty'**
  String get currencyPLN;

  /// No description provided for @currencyCZK.
  ///
  /// In en, this message translates to:
  /// **'Czech Koruna'**
  String get currencyCZK;

  /// No description provided for @currencyHUF.
  ///
  /// In en, this message translates to:
  /// **'Hungarian Forint'**
  String get currencyHUF;

  /// No description provided for @currencyARS.
  ///
  /// In en, this message translates to:
  /// **'Argentine Peso'**
  String get currencyARS;

  /// No description provided for @currencyCLP.
  ///
  /// In en, this message translates to:
  /// **'Chilean Peso'**
  String get currencyCLP;

  /// No description provided for @currencyCOP.
  ///
  /// In en, this message translates to:
  /// **'Colombian Peso'**
  String get currencyCOP;

  /// No description provided for @currencyPEN.
  ///
  /// In en, this message translates to:
  /// **'Peruvian Sol'**
  String get currencyPEN;

  /// No description provided for @currencyEGP.
  ///
  /// In en, this message translates to:
  /// **'Egyptian Pound'**
  String get currencyEGP;

  /// No description provided for @currencyNGN.
  ///
  /// In en, this message translates to:
  /// **'Nigerian Naira'**
  String get currencyNGN;

  /// No description provided for @currencyKZT.
  ///
  /// In en, this message translates to:
  /// **'Kazakhstani Tenge'**
  String get currencyKZT;

  /// No description provided for @currencyUAH.
  ///
  /// In en, this message translates to:
  /// **'Ukrainian Hryvnia'**
  String get currencyUAH;

  /// No description provided for @currencyILS.
  ///
  /// In en, this message translates to:
  /// **'Israeli New Shekel'**
  String get currencyILS;

  /// No description provided for @currencyPKR.
  ///
  /// In en, this message translates to:
  /// **'Pakistani Rupee'**
  String get currencyPKR;

  /// No description provided for @currencyBDT.
  ///
  /// In en, this message translates to:
  /// **'Bangladeshi Taka'**
  String get currencyBDT;

  /// No description provided for @currencyLKR.
  ///
  /// In en, this message translates to:
  /// **'Sri Lankan Rupee'**
  String get currencyLKR;

  /// No description provided for @currencyMMK.
  ///
  /// In en, this message translates to:
  /// **'Myanmar Kyat'**
  String get currencyMMK;

  /// No description provided for @webdavConfiguredTitle.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Cloud Service Configured'**
  String get webdavConfiguredTitle;

  /// No description provided for @webdavConfiguredMessage.
  ///
  /// In en, this message translates to:
  /// **'WebDAV cloud service uses the credentials provided during configuration, no additional login required.'**
  String get webdavConfiguredMessage;

  /// No description provided for @recurringTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Recurring Bills'**
  String get recurringTransactionTitle;

  /// No description provided for @recurringTransactionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Recurring Bill'**
  String get recurringTransactionAdd;

  /// No description provided for @recurringTransactionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Recurring Bill'**
  String get recurringTransactionEdit;

  /// No description provided for @recurringTransactionFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get recurringTransactionFrequency;

  /// No description provided for @recurringTransactionDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get recurringTransactionDaily;

  /// No description provided for @recurringTransactionWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get recurringTransactionWeekly;

  /// No description provided for @recurringTransactionMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get recurringTransactionMonthly;

  /// No description provided for @recurringTransactionYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get recurringTransactionYearly;

  /// No description provided for @recurringTransactionInterval.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get recurringTransactionInterval;

  /// No description provided for @recurringTransactionDayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'Day of Month'**
  String get recurringTransactionDayOfMonth;

  /// No description provided for @recurringTransactionStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get recurringTransactionStartDate;

  /// No description provided for @recurringTransactionEndDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get recurringTransactionEndDate;

  /// No description provided for @recurringTransactionNoEndDate.
  ///
  /// In en, this message translates to:
  /// **'Perpetual'**
  String get recurringTransactionNoEndDate;

  /// No description provided for @recurringTransactionDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this recurring bill?'**
  String get recurringTransactionDeleteConfirm;

  /// No description provided for @recurringTransactionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No Recurring Bills'**
  String get recurringTransactionEmpty;

  /// No description provided for @recurringTransactionEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button in the top right corner to add'**
  String get recurringTransactionEmptyHint;

  /// No description provided for @recurringTransactionAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Amount must be greater than 0'**
  String get recurringTransactionAmountInvalid;

  /// No description provided for @recurringTransactionEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'End date cannot be earlier than start date'**
  String get recurringTransactionEndBeforeStart;

  /// No description provided for @recurringTransactionEveryNDays.
  ///
  /// In en, this message translates to:
  /// **'Every {n} day(s)'**
  String recurringTransactionEveryNDays(int n);

  /// No description provided for @recurringTransactionEveryNWeeks.
  ///
  /// In en, this message translates to:
  /// **'Every {n} week(s)'**
  String recurringTransactionEveryNWeeks(int n);

  /// No description provided for @recurringTransactionEveryNMonths.
  ///
  /// In en, this message translates to:
  /// **'Every {n} month(s)'**
  String recurringTransactionEveryNMonths(int n);

  /// No description provided for @recurringTransactionEveryNYears.
  ///
  /// In en, this message translates to:
  /// **'Every {n} year(s)'**
  String recurringTransactionEveryNYears(int n);

  /// No description provided for @recurringTransactionUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage Guide'**
  String get recurringTransactionUsageTitle;

  /// No description provided for @recurringTransactionUsageContent.
  ///
  /// In en, this message translates to:
  /// **'Recurring transactions are automatically scanned and generated when the app cold starts. After setting a date, the system will create corresponding bills on the first startup after that date. For example: if set to Nov 27, bills will be auto-recorded on the first launch after Nov 27.'**
  String get recurringTransactionUsageContent;

  /// No description provided for @ledgerSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Ledger'**
  String get ledgerSelectTitle;

  /// No description provided for @ledgerSelect.
  ///
  /// In en, this message translates to:
  /// **'Select Ledger'**
  String get ledgerSelect;

  /// No description provided for @syncNotConfiguredMessage.
  ///
  /// In en, this message translates to:
  /// **'Cloud not configured'**
  String get syncNotConfiguredMessage;

  /// No description provided for @syncNotLoggedInMessage.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get syncNotLoggedInMessage;

  /// No description provided for @syncCloudBackupCorruptedMessage.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup content is corrupted, possibly due to encoding issues from earlier versions. Please click \'Upload Current Ledger to Cloud\' to overwrite and fix.'**
  String get syncCloudBackupCorruptedMessage;

  /// No description provided for @syncNoCloudBackupMessage.
  ///
  /// In en, this message translates to:
  /// **'No cloud backup'**
  String get syncNoCloudBackupMessage;

  /// No description provided for @syncAccessDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'403 Access denied (check storage RLS policy and path)'**
  String get syncAccessDeniedMessage;

  /// No description provided for @cloudTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get cloudTestConnection;

  /// No description provided for @cloudLastTestTime.
  ///
  /// In en, this message translates to:
  /// **'Last test time: {time}'**
  String cloudLastTestTime(String time);

  /// No description provided for @cloudLocalStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Local Storage'**
  String get cloudLocalStorageTitle;

  /// No description provided for @cloudLocalStorageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Data is only saved on local device'**
  String get cloudLocalStorageSubtitle;

  /// No description provided for @localBackupPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Local Storage'**
  String get localBackupPageTitle;

  /// No description provided for @localBackupAutoTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto Local Backup'**
  String get localBackupAutoTitle;

  /// No description provided for @localBackupAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically back up a database snapshot on first launch each day'**
  String get localBackupAutoSubtitle;

  /// No description provided for @storagePermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage Permission Required'**
  String get storagePermissionTitle;

  /// No description provided for @storagePermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Android 11+ requires \"All files access\" to save files to the public Download folder (visible in file managers, kept after uninstall).\n\nChoosing \"Continue Anyway\" saves to the app\'s private folder instead — invisible in file managers and deleted on uninstall.'**
  String get storagePermissionMessage;

  /// No description provided for @storagePermissionGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant Access'**
  String get storagePermissionGrant;

  /// No description provided for @storagePermissionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue Anyway'**
  String get storagePermissionContinue;

  /// No description provided for @exportStorageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'External storage is unavailable. Check device storage status'**
  String get exportStorageUnavailable;

  /// No description provided for @localBackupNowTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get localBackupNowTooltip;

  /// No description provided for @localBackupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup completed'**
  String get localBackupSuccess;

  /// No description provided for @localBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed. Check storage space and permissions'**
  String get localBackupFailed;

  /// No description provided for @localBackupListHint.
  ///
  /// In en, this message translates to:
  /// **'Select a backup to restore:'**
  String get localBackupListHint;

  /// No description provided for @localBackupImportFromFile.
  ///
  /// In en, this message translates to:
  /// **'Import from file'**
  String get localBackupImportFromFile;

  /// No description provided for @localBackupImportInvalidFile.
  ///
  /// In en, this message translates to:
  /// **'Please select a .sqlite backup file'**
  String get localBackupImportInvalidFile;

  /// No description provided for @localBackupListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No backups yet'**
  String get localBackupListEmpty;

  /// No description provided for @localBackupRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore Backup'**
  String get localBackupRestoreTitle;

  /// No description provided for @localBackupRestoreMessage.
  ///
  /// In en, this message translates to:
  /// **'Restoring will overwrite all current data and cannot be undone. Continue?'**
  String get localBackupRestoreMessage;

  /// No description provided for @localBackupRestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Restore completed'**
  String get localBackupRestoreSuccess;

  /// No description provided for @localBackupRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed'**
  String get localBackupRestoreFailed;

  /// No description provided for @localBackupEmergencyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create a safety copy of current data. Restore cancelled'**
  String get localBackupEmergencyFailed;

  /// No description provided for @localBackupIntegrityFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup file is corrupted and cannot be restored'**
  String get localBackupIntegrityFailed;

  /// No description provided for @localBackupVersionTooNew.
  ///
  /// In en, this message translates to:
  /// **'This backup was created by a newer version of the app. Please update the app first'**
  String get localBackupVersionTooNew;

  /// No description provided for @localBackupRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring…'**
  String get localBackupRestoring;

  /// No description provided for @localBackupOldLink.
  ///
  /// In en, this message translates to:
  /// **'Can\'t see older backups?'**
  String get localBackupOldLink;

  /// No description provided for @localBackupOldDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Find Older Backups'**
  String get localBackupOldDialogTitle;

  /// No description provided for @localBackupOldReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Why can\'t I see them?'**
  String get localBackupOldReasonTitle;

  /// No description provided for @localBackupOldReasonBody.
  ///
  /// In en, this message translates to:
  /// **'After an app update or reinstall, Android hides old backups. The files are still in Download/Spitout/backups, but the app can\'t read them yet.'**
  String get localBackupOldReasonBody;

  /// No description provided for @localBackupOldHowTitle.
  ///
  /// In en, this message translates to:
  /// **'How to find them?'**
  String get localBackupOldHowTitle;

  /// No description provided for @localBackupOldHowBody.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Grant access\" to open system settings and enable \"All files access\". When you return, this page refreshes automatically and older backups reappear.'**
  String get localBackupOldHowBody;

  /// No description provided for @localBackupOldHowBodyGranted.
  ///
  /// In en, this message translates to:
  /// **'All files access is already enabled, so older backups should be visible now. If they still don\'t appear, use \"Import from file\" to pick one manually.'**
  String get localBackupOldHowBodyGranted;

  /// No description provided for @localBackupOldSafeTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy note'**
  String get localBackupOldSafeTitle;

  /// No description provided for @localBackupOldSafeBody.
  ///
  /// In en, this message translates to:
  /// **'This permission is only used to read your own backup files, and you can turn it off anytime in system settings. If you\'d rather not, use \"Import from file\" to pick a backup manually.'**
  String get localBackupOldSafeBody;

  /// No description provided for @localBackupOldGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant access'**
  String get localBackupOldGrant;

  /// No description provided for @localBackupOldGranted.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get localBackupOldGranted;

  /// No description provided for @localBackupOldLater.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get localBackupOldLater;

  /// No description provided for @localBackupOldGrantFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open system settings. Please enable \"All files access\" manually'**
  String get localBackupOldGrantFailed;

  /// No description provided for @cloudCustomSupabaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Supabase'**
  String get cloudCustomSupabaseTitle;

  /// No description provided for @cloudCustomSupabaseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Click to configure self-hosted Supabase'**
  String get cloudCustomSupabaseSubtitle;

  /// No description provided for @cloudCustomWebdavTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom WebDAV'**
  String get cloudCustomWebdavTitle;

  /// No description provided for @cloudCustomWebdavSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Click to configure Nutstore/Nextcloud etc.'**
  String get cloudCustomWebdavSubtitle;

  /// No description provided for @cloudCustomS3Title.
  ///
  /// In en, this message translates to:
  /// **'S3 Protocol Storage'**
  String get cloudCustomS3Title;

  /// No description provided for @cloudCustomS3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'AWS S3 / Cloudflare R2 / MinIO'**
  String get cloudCustomS3Subtitle;

  /// No description provided for @cloudSpitoutCloudTitle.
  ///
  /// In en, this message translates to:
  /// **'Spitout Cloud'**
  String get cloudSpitoutCloudTitle;

  /// No description provided for @cloudSpitoutCloudSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Self-hosted · Incremental sync · Multi-device'**
  String get cloudSpitoutCloudSubtitle;

  /// No description provided for @cloudConfigureSpitoutCloudTitle.
  ///
  /// In en, this message translates to:
  /// **'Configure Spitout Cloud'**
  String get cloudConfigureSpitoutCloudTitle;

  /// No description provided for @cloudSpitoutCloudUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get cloudSpitoutCloudUrlLabel;

  /// No description provided for @cloudSpitoutCloudUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://your-server.com'**
  String get cloudSpitoutCloudUrlHint;

  /// No description provided for @cloudSpitoutCloudAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get cloudSpitoutCloudAccountLabel;

  /// No description provided for @cloudSpitoutCloudAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get cloudSpitoutCloudAccountHint;

  /// No description provided for @cloudSpitoutCloudPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get cloudSpitoutCloudPasswordLabel;

  /// No description provided for @cloudSpitoutCloudPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get cloudSpitoutCloudPasswordHint;

  /// No description provided for @cloudSpitoutCloudPasswordNotSavedHint.
  ///
  /// In en, this message translates to:
  /// **'Password is only used for this sign-in and is not saved on this device'**
  String get cloudSpitoutCloudPasswordNotSavedHint;

  /// No description provided for @cloudSpitoutCloudLoginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Login successful'**
  String get cloudSpitoutCloudLoginSuccess;

  /// No description provided for @cloudSpitoutCloudLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get cloudSpitoutCloudLoginFailed;

  /// No description provided for @cloudTabOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get cloudTabOffline;

  /// No description provided for @cloudTabBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get cloudTabBackup;

  /// No description provided for @cloudTabBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap a card to switch backup methods. The first setup requires configuration.'**
  String get cloudTabBackupSubtitle;

  /// No description provided for @cloudTabCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get cloudTabCloudSync;

  /// No description provided for @cloudSupabaseHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Supabase Setup Guide'**
  String get cloudSupabaseHelpTitle;

  /// No description provided for @cloudSupabaseHelpIntro.
  ///
  /// In en, this message translates to:
  /// **'What is Supabase'**
  String get cloudSupabaseHelpIntro;

  /// No description provided for @cloudSupabaseHelpIntro1.
  ///
  /// In en, this message translates to:
  /// **'Supabase is an open-source backend-as-a-service platform'**
  String get cloudSupabaseHelpIntro1;

  /// No description provided for @cloudSupabaseHelpIntro2.
  ///
  /// In en, this message translates to:
  /// **'Offers a free tier, sufficient for personal use'**
  String get cloudSupabaseHelpIntro2;

  /// No description provided for @cloudSupabaseHelpIntro3.
  ///
  /// In en, this message translates to:
  /// **'You have full control over your data'**
  String get cloudSupabaseHelpIntro3;

  /// No description provided for @cloudSupabaseHelpSteps.
  ///
  /// In en, this message translates to:
  /// **'Setup Steps'**
  String get cloudSupabaseHelpSteps;

  /// No description provided for @cloudSupabaseHelpStep1.
  ///
  /// In en, this message translates to:
  /// **'1. Visit supabase.com to create an account'**
  String get cloudSupabaseHelpStep1;

  /// No description provided for @cloudSupabaseHelpStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Create a new project (select free tier)'**
  String get cloudSupabaseHelpStep2;

  /// No description provided for @cloudSupabaseHelpStep3.
  ///
  /// In en, this message translates to:
  /// **'3. Go to Project Settings > API'**
  String get cloudSupabaseHelpStep3;

  /// No description provided for @cloudSupabaseHelpStep4.
  ///
  /// In en, this message translates to:
  /// **'4. Copy Project URL and anon key'**
  String get cloudSupabaseHelpStep4;

  /// No description provided for @cloudSupabaseHelpStep5.
  ///
  /// In en, this message translates to:
  /// **'5. Paste them into the app configuration'**
  String get cloudSupabaseHelpStep5;

  /// No description provided for @cloudSupabaseHelpFaq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get cloudSupabaseHelpFaq;

  /// No description provided for @cloudSupabaseHelpFaq1.
  ///
  /// In en, this message translates to:
  /// **'Free tier includes 500MB storage'**
  String get cloudSupabaseHelpFaq1;

  /// No description provided for @cloudSupabaseHelpFaq2.
  ///
  /// In en, this message translates to:
  /// **'Data is encrypted and secure'**
  String get cloudSupabaseHelpFaq2;

  /// No description provided for @cloudSupabaseHelpFaq3.
  ///
  /// In en, this message translates to:
  /// **'Supports multi-device sync'**
  String get cloudSupabaseHelpFaq3;

  /// No description provided for @cloudSupabaseHelpNote.
  ///
  /// In en, this message translates to:
  /// **'After configuration, you need to register/login to use sync'**
  String get cloudSupabaseHelpNote;

  /// No description provided for @cloudWebdavHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Setup Guide'**
  String get cloudWebdavHelpTitle;

  /// No description provided for @cloudWebdavHelpIntro.
  ///
  /// In en, this message translates to:
  /// **'What is WebDAV'**
  String get cloudWebdavHelpIntro;

  /// No description provided for @cloudWebdavHelpIntro1.
  ///
  /// In en, this message translates to:
  /// **'WebDAV is a network file protocol'**
  String get cloudWebdavHelpIntro1;

  /// No description provided for @cloudWebdavHelpIntro2.
  ///
  /// In en, this message translates to:
  /// **'Supported by many cloud storage and NAS devices'**
  String get cloudWebdavHelpIntro2;

  /// No description provided for @cloudWebdavHelpIntro3.
  ///
  /// In en, this message translates to:
  /// **'Data is stored on your own server'**
  String get cloudWebdavHelpIntro3;

  /// No description provided for @cloudWebdavHelpProviders.
  ///
  /// In en, this message translates to:
  /// **'Supported Providers'**
  String get cloudWebdavHelpProviders;

  /// No description provided for @cloudWebdavHelpProvider1.
  ///
  /// In en, this message translates to:
  /// **'- Nutstore (recommended for China users)'**
  String get cloudWebdavHelpProvider1;

  /// No description provided for @cloudWebdavHelpProvider2.
  ///
  /// In en, this message translates to:
  /// **'- Nextcloud / ownCloud'**
  String get cloudWebdavHelpProvider2;

  /// No description provided for @cloudWebdavHelpProvider3.
  ///
  /// In en, this message translates to:
  /// **'- Synology / QNAP NAS'**
  String get cloudWebdavHelpProvider3;

  /// No description provided for @cloudWebdavHelpProvider4.
  ///
  /// In en, this message translates to:
  /// **'- Other WebDAV-compatible services'**
  String get cloudWebdavHelpProvider4;

  /// No description provided for @cloudWebdavHelpSteps.
  ///
  /// In en, this message translates to:
  /// **'Setup Steps (Nutstore example)'**
  String get cloudWebdavHelpSteps;

  /// No description provided for @cloudWebdavHelpStep1.
  ///
  /// In en, this message translates to:
  /// **'1. Login to Nutstore web version'**
  String get cloudWebdavHelpStep1;

  /// No description provided for @cloudWebdavHelpStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Click account name > Account Info'**
  String get cloudWebdavHelpStep2;

  /// No description provided for @cloudWebdavHelpStep3.
  ///
  /// In en, this message translates to:
  /// **'3. Select Security Options tab'**
  String get cloudWebdavHelpStep3;

  /// No description provided for @cloudWebdavHelpStep4.
  ///
  /// In en, this message translates to:
  /// **'4. Add application password (for third-party apps)'**
  String get cloudWebdavHelpStep4;

  /// No description provided for @cloudWebdavHelpStep5.
  ///
  /// In en, this message translates to:
  /// **'5. Copy server address, account, and app password'**
  String get cloudWebdavHelpStep5;

  /// No description provided for @cloudWebdavHelpNote.
  ///
  /// In en, this message translates to:
  /// **'Use an app-specific password instead of your account password'**
  String get cloudWebdavHelpNote;

  /// No description provided for @cloudS3HelpTitle.
  ///
  /// In en, this message translates to:
  /// **'S3 Storage Setup Guide'**
  String get cloudS3HelpTitle;

  /// No description provided for @cloudS3HelpIntro.
  ///
  /// In en, this message translates to:
  /// **'What is S3'**
  String get cloudS3HelpIntro;

  /// No description provided for @cloudS3HelpIntro1.
  ///
  /// In en, this message translates to:
  /// **'S3 is a standard object storage protocol'**
  String get cloudS3HelpIntro1;

  /// No description provided for @cloudS3HelpIntro2.
  ///
  /// In en, this message translates to:
  /// **'Supported by many cloud providers'**
  String get cloudS3HelpIntro2;

  /// No description provided for @cloudS3HelpIntro3.
  ///
  /// In en, this message translates to:
  /// **'Data is stored on your chosen cloud service'**
  String get cloudS3HelpIntro3;

  /// No description provided for @cloudS3HelpProviders.
  ///
  /// In en, this message translates to:
  /// **'Supported Providers'**
  String get cloudS3HelpProviders;

  /// No description provided for @cloudS3HelpProvider1.
  ///
  /// In en, this message translates to:
  /// **'- AWS S3 (Amazon Web Services)'**
  String get cloudS3HelpProvider1;

  /// No description provided for @cloudS3HelpProvider2.
  ///
  /// In en, this message translates to:
  /// **'- Cloudflare R2 (free 10GB/month)'**
  String get cloudS3HelpProvider2;

  /// No description provided for @cloudS3HelpProvider3.
  ///
  /// In en, this message translates to:
  /// **'- Backblaze B2 (free 10GB)'**
  String get cloudS3HelpProvider3;

  /// No description provided for @cloudS3HelpProvider4.
  ///
  /// In en, this message translates to:
  /// **'- MinIO (self-hosted)'**
  String get cloudS3HelpProvider4;

  /// No description provided for @cloudS3HelpProvider5.
  ///
  /// In en, this message translates to:
  /// **'- Alibaba Cloud OSS'**
  String get cloudS3HelpProvider5;

  /// No description provided for @cloudS3HelpProvider6.
  ///
  /// In en, this message translates to:
  /// **'- Tencent Cloud COS'**
  String get cloudS3HelpProvider6;

  /// No description provided for @cloudS3HelpProvider7.
  ///
  /// In en, this message translates to:
  /// **'- Qiniu Kodo'**
  String get cloudS3HelpProvider7;

  /// No description provided for @cloudS3HelpSteps.
  ///
  /// In en, this message translates to:
  /// **'Setup Steps (Cloudflare R2 example)'**
  String get cloudS3HelpSteps;

  /// No description provided for @cloudS3HelpStep1.
  ///
  /// In en, this message translates to:
  /// **'1. Login to Cloudflare Dashboard'**
  String get cloudS3HelpStep1;

  /// No description provided for @cloudS3HelpStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Go to R2 > Create Bucket'**
  String get cloudS3HelpStep2;

  /// No description provided for @cloudS3HelpStep3.
  ///
  /// In en, this message translates to:
  /// **'3. Go to R2 > Manage R2 API Tokens'**
  String get cloudS3HelpStep3;

  /// No description provided for @cloudS3HelpStep4.
  ///
  /// In en, this message translates to:
  /// **'4. Create API Token and copy credentials'**
  String get cloudS3HelpStep4;

  /// No description provided for @cloudS3HelpStep5.
  ///
  /// In en, this message translates to:
  /// **'5. Paste endpoint, access key, secret key, and bucket name'**
  String get cloudS3HelpStep5;

  /// No description provided for @cloudS3HelpNote.
  ///
  /// In en, this message translates to:
  /// **'Recommended: Cloudflare R2 offers 10GB free storage without egress fees'**
  String get cloudS3HelpNote;

  /// No description provided for @cloudStatusNotTested.
  ///
  /// In en, this message translates to:
  /// **'Not tested'**
  String get cloudStatusNotTested;

  /// No description provided for @cloudStatusNormal.
  ///
  /// In en, this message translates to:
  /// **'Connection normal'**
  String get cloudStatusNormal;

  /// No description provided for @cloudStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get cloudStatusFailed;

  /// No description provided for @cloudErrorAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed: Invalid API Key'**
  String get cloudErrorAuthFailed;

  /// No description provided for @cloudErrorServerStatus.
  ///
  /// In en, this message translates to:
  /// **'Server returned status code {code}'**
  String cloudErrorServerStatus(String code);

  /// No description provided for @cloudErrorWebdavNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Server does not support WebDAV protocol'**
  String get cloudErrorWebdavNotSupported;

  /// No description provided for @cloudErrorAuthFailedCredentials.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed: Incorrect username or password'**
  String get cloudErrorAuthFailedCredentials;

  /// No description provided for @cloudErrorAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access denied: Please check permissions'**
  String get cloudErrorAccessDenied;

  /// No description provided for @cloudErrorPathNotFound.
  ///
  /// In en, this message translates to:
  /// **'Server path not found: {path}'**
  String cloudErrorPathNotFound(String path);

  /// No description provided for @cloudErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error: {message}'**
  String cloudErrorNetwork(String message);

  /// No description provided for @cloudTestSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Connection normal, configuration valid'**
  String get cloudTestSuccessMessage;

  /// No description provided for @cloudTestFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get cloudTestFailedMessage;

  /// No description provided for @cloudSwitchConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch Cloud Service'**
  String get cloudSwitchConfirmTitle;

  /// No description provided for @cloudSwitchConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Switching cloud service will log out current account. Confirm switch?'**
  String get cloudSwitchConfirmMessage;

  /// No description provided for @cloudSwitchFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch Failed'**
  String get cloudSwitchFailedTitle;

  /// No description provided for @cloudSwitchFailedConfigMissing.
  ///
  /// In en, this message translates to:
  /// **'Please configure this cloud service first'**
  String get cloudSwitchFailedConfigMissing;

  /// No description provided for @cloudConfigInvalidMessage.
  ///
  /// In en, this message translates to:
  /// **'Please fill in complete information'**
  String get cloudConfigInvalidMessage;

  /// No description provided for @cloudSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save Failed'**
  String get cloudSaveFailed;

  /// No description provided for @cloudSwitchedTo.
  ///
  /// In en, this message translates to:
  /// **'Switched to {type}'**
  String cloudSwitchedTo(String type);

  /// No description provided for @cloudConfigureSupabaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Configure Supabase'**
  String get cloudConfigureSupabaseTitle;

  /// No description provided for @cloudConfigureWebdavTitle.
  ///
  /// In en, this message translates to:
  /// **'Configure WebDAV'**
  String get cloudConfigureWebdavTitle;

  /// No description provided for @cloudConfigureS3Title.
  ///
  /// In en, this message translates to:
  /// **'Configure S3'**
  String get cloudConfigureS3Title;

  /// No description provided for @cloudSupabaseAnonKeyHintLong.
  ///
  /// In en, this message translates to:
  /// **'Paste complete anon key'**
  String get cloudSupabaseAnonKeyHintLong;

  /// No description provided for @cloudWebdavRemotePathLabel.
  ///
  /// In en, this message translates to:
  /// **'Remote Path'**
  String get cloudWebdavRemotePathLabel;

  /// No description provided for @cloudWebdavRemotePathHelperText.
  ///
  /// In en, this message translates to:
  /// **'Remote directory path for data storage'**
  String get cloudWebdavRemotePathHelperText;

  /// No description provided for @welcomeSelectCurrencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Accounting Currency'**
  String get welcomeSelectCurrencyTitle;

  /// No description provided for @welcomeCurrencyDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred currency, you can change it anytime in settings'**
  String get welcomeCurrencyDescription;

  /// No description provided for @aiOcrNoLedger.
  ///
  /// In en, this message translates to:
  /// **'Ledger not found'**
  String get aiOcrNoLedger;

  /// No description provided for @cloudTutorialTitle.
  ///
  /// In en, this message translates to:
  /// **'Getting Started'**
  String get cloudTutorialTitle;

  /// No description provided for @cloudTutorialIntro.
  ///
  /// In en, this message translates to:
  /// **'Spitout Cloud is a self-hosted sync server that supports real-time multi-device collaboration. The flow is simple:'**
  String get cloudTutorialIntro;

  /// No description provided for @cloudTutorialStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Step 1: Deploy or join a server'**
  String get cloudTutorialStep1Title;

  /// No description provided for @cloudTutorialStep1Desc.
  ///
  /// In en, this message translates to:
  /// **'Self-host with one Docker command (see the Docker guide in GitHub README). Or join an existing Spitout Cloud server run by a friend / team.'**
  String get cloudTutorialStep1Desc;

  /// No description provided for @cloudTutorialStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Get an account'**
  String get cloudTutorialStep2Title;

  /// No description provided for @cloudTutorialStep2Desc.
  ///
  /// In en, this message translates to:
  /// **'Spitout Cloud does NOT offer self-registration (to prevent abuse on public servers). If you self-host: the first Docker boot prints a random admin account + password to the logs — use that. Joining someone else\'s server: ask the admin to create an account for you in Web → Users.'**
  String get cloudTutorialStep2Desc;

  /// No description provided for @cloudTutorialStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Step 3: Login + enable sync'**
  String get cloudTutorialStep3Title;

  /// No description provided for @cloudTutorialStep3Desc.
  ///
  /// In en, this message translates to:
  /// **'In the app, pick Spitout Cloud, enter the server URL and the account you got in step 2. First login uploads your entire local ledger; every subsequent edit is pushed in real time.'**
  String get cloudTutorialStep3Desc;

  /// No description provided for @cloudTutorialStep4Title.
  ///
  /// In en, this message translates to:
  /// **'Step 4: Login from other devices'**
  String get cloudTutorialStep4Title;

  /// No description provided for @cloudTutorialStep4Desc.
  ///
  /// In en, this message translates to:
  /// **'Phone / tablet / Web — same account, instant shared state. Edits propagate within seconds.'**
  String get cloudTutorialStep4Desc;

  /// No description provided for @cloudTutorialTipTitle.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get cloudTutorialTipTitle;

  /// No description provided for @cloudTutorialTipDesc.
  ///
  /// In en, this message translates to:
  /// **'The Web UI lives at the server URL. Open it in a browser to manage ledgers, members, and view logs.'**
  String get cloudTutorialTipDesc;

  /// No description provided for @cloudTutorialFeaturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get cloudTutorialFeaturesTitle;

  /// No description provided for @cloudTutorialFeature1.
  ///
  /// In en, this message translates to:
  /// **'📱 Real-time multi-device: phone A + phone B + Web on one account, sub-second sync'**
  String get cloudTutorialFeature1;

  /// No description provided for @cloudTutorialFeature2.
  ///
  /// In en, this message translates to:
  /// **'🌐 Web UI included: one Docker image ships server + Web, browser ready'**
  String get cloudTutorialFeature2;

  /// No description provided for @cloudTutorialFeature3.
  ///
  /// In en, this message translates to:
  /// **'👥 Multi-user isolation: multiple users on one server, data fully separated'**
  String get cloudTutorialFeature3;

  /// No description provided for @cloudTutorialFeature4.
  ///
  /// In en, this message translates to:
  /// **'🤝 Shared ledgers: invite family / team into one book with seconds-level sync'**
  String get cloudTutorialFeature4;

  /// No description provided for @cloudTutorialGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get cloudTutorialGotIt;

  /// No description provided for @cloudSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Downloads automatically compare differences for selective preview. Not real-time — avoid editing the same ledger on multiple devices simultaneously. Sync scope covers ledger data (including associated accounts and categories).'**
  String get cloudSyncHint;

  /// No description provided for @appearanceSettings.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get appearanceSettings;

  /// No description provided for @appearanceSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Theme, font, language, app lock, etc.'**
  String get appearanceSettingsDesc;

  /// No description provided for @appearanceSettingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get appearanceSettingsPageTitle;

  /// No description provided for @appearanceSettingsPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance, display, security and other app preferences'**
  String get appearanceSettingsPageSubtitle;

  /// No description provided for @logCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Center'**
  String get logCenterTitle;

  /// No description provided for @logCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View app runtime logs'**
  String get logCenterSubtitle;

  /// No description provided for @logCenterSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search log content or tags...'**
  String get logCenterSearchHint;

  /// No description provided for @logCenterFilterLevel.
  ///
  /// In en, this message translates to:
  /// **'Log Level'**
  String get logCenterFilterLevel;

  /// No description provided for @logCenterFilterPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get logCenterFilterPlatform;

  /// No description provided for @logCenterTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get logCenterTotal;

  /// No description provided for @logCenterFiltered.
  ///
  /// In en, this message translates to:
  /// **'Filtered'**
  String get logCenterFiltered;

  /// No description provided for @logCenterEmpty.
  ///
  /// In en, this message translates to:
  /// **'No logs'**
  String get logCenterEmpty;

  /// No description provided for @logCenterExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get logCenterExport;

  /// No description provided for @logCenterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get logCenterClear;

  /// No description provided for @logCenterExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get logCenterExportFailed;

  /// No description provided for @logCenterClearConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Logs'**
  String get logCenterClearConfirmTitle;

  /// No description provided for @logCenterClearConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all logs? This action cannot be undone.'**
  String get logCenterClearConfirmMessage;

  /// No description provided for @logCenterCleared.
  ///
  /// In en, this message translates to:
  /// **'Logs cleared'**
  String get logCenterCleared;

  /// No description provided for @logCenterCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get logCenterCopied;

  /// No description provided for @logCenterDetailTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get logCenterDetailTime;

  /// No description provided for @logCenterDetailLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get logCenterDetailLevel;

  /// No description provided for @logCenterDetailPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get logCenterDetailPlatform;

  /// No description provided for @logCenterDetailError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get logCenterDetailError;

  /// No description provided for @logCenterDetailStackTrace.
  ///
  /// In en, this message translates to:
  /// **'Stack Trace'**
  String get logCenterDetailStackTrace;

  /// No description provided for @logCenterCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get logCenterCopy;

  /// No description provided for @logCenterClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get logCenterClose;

  /// No description provided for @logCenterExportSubject.
  ///
  /// In en, this message translates to:
  /// **'Spitout Log Export'**
  String get logCenterExportSubject;

  /// No description provided for @configImportExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Config Import/Export'**
  String get configImportExportTitle;

  /// No description provided for @configImportExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Backup and restore app configurations'**
  String get configImportExportSubtitle;

  /// No description provided for @configImportExportInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Feature Description'**
  String get configImportExportInfoTitle;

  /// No description provided for @configImportExportInfoMessage.
  ///
  /// In en, this message translates to:
  /// **'Back up and restore app configurations for cross-device migration or settings recovery. Exports as YAML format, viewable and editable.\n\nOnly includes app configurations, not transaction records (use Detail Import/Export for transaction data).'**
  String get configImportExportInfoMessage;

  /// No description provided for @configImportExportWarning.
  ///
  /// In en, this message translates to:
  /// **'The config file contains sensitive information such as cloud service keys and passwords. Keep it safe. Importing overwrites existing configurations with the same name—back up first.'**
  String get configImportExportWarning;

  /// No description provided for @configExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Config'**
  String get configExportTitle;

  /// No description provided for @configExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export current config to YAML file'**
  String get configExportSubtitle;

  /// No description provided for @configExportShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Spitout Config File'**
  String get configExportShareSubject;

  /// No description provided for @configExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Config exported successfully'**
  String get configExportSuccess;

  /// No description provided for @configExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Config export failed'**
  String get configExportFailed;

  /// No description provided for @configImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Config'**
  String get configImportTitle;

  /// No description provided for @configImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore config from YAML file'**
  String get configImportSubtitle;

  /// No description provided for @configImportNoFilePath.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get configImportNoFilePath;

  /// No description provided for @configImportConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Import'**
  String get configImportConfirmTitle;

  /// No description provided for @configImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Config imported successfully'**
  String get configImportSuccess;

  /// No description provided for @configImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Config import failed'**
  String get configImportFailed;

  /// No description provided for @configImportRestartTitle.
  ///
  /// In en, this message translates to:
  /// **'Restart Required'**
  String get configImportRestartTitle;

  /// No description provided for @configImportRestartMessage.
  ///
  /// In en, this message translates to:
  /// **'Config has been imported. Some settings will take effect after restarting the app.'**
  String get configImportRestartMessage;

  /// No description provided for @configImportOverwriteWarning.
  ///
  /// In en, this message translates to:
  /// **'Importing will overwrite existing configurations. It is recommended to back up your current config first.'**
  String get configImportOverwriteWarning;

  /// No description provided for @configImportExportIncludesTitle.
  ///
  /// In en, this message translates to:
  /// **'Included Configurations'**
  String get configImportExportIncludesTitle;

  /// No description provided for @configExportSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to: {path}'**
  String configExportSavedTo(String path);

  /// No description provided for @configExportViewContent.
  ///
  /// In en, this message translates to:
  /// **'View Content'**
  String get configExportViewContent;

  /// No description provided for @configExportCopyContent.
  ///
  /// In en, this message translates to:
  /// **'Copy Content'**
  String get configExportCopyContent;

  /// No description provided for @configExportContentCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get configExportContentCopied;

  /// No description provided for @configExportReadFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read file'**
  String get configExportReadFileFailed;

  /// No description provided for @configIncludeLedgers.
  ///
  /// In en, this message translates to:
  /// **'Ledgers'**
  String get configIncludeLedgers;

  /// No description provided for @configIncludeSupabase.
  ///
  /// In en, this message translates to:
  /// **'Supabase cloud service config'**
  String get configIncludeSupabase;

  /// No description provided for @configIncludeWebdav.
  ///
  /// In en, this message translates to:
  /// **'WebDAV cloud service config'**
  String get configIncludeWebdav;

  /// No description provided for @configIncludeS3.
  ///
  /// In en, this message translates to:
  /// **'S3 cloud service config'**
  String get configIncludeS3;

  /// No description provided for @configIncludeSpitoutCloud.
  ///
  /// In en, this message translates to:
  /// **'Spitout Cloud service config'**
  String get configIncludeSpitoutCloud;

  /// No description provided for @configIncludeAppSettings.
  ///
  /// In en, this message translates to:
  /// **'App settings (reminder, language, appearance, font, sync, etc.)'**
  String get configIncludeAppSettings;

  /// No description provided for @configIncludeRecurringTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recurring transactions'**
  String get configIncludeRecurringTransactions;

  /// No description provided for @configIncludeCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get configIncludeCategories;

  /// No description provided for @configIncludeOtherSettings.
  ///
  /// In en, this message translates to:
  /// **'Other Settings'**
  String get configIncludeOtherSettings;

  /// No description provided for @configIncludeOtherSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Including cloud service configs and app settings'**
  String get configIncludeOtherSettingsSubtitle;

  /// No description provided for @configIncludeCredentials.
  ///
  /// In en, this message translates to:
  /// **'Include credentials'**
  String get configIncludeCredentials;

  /// No description provided for @configIncludeCredentialsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Passwords and secret keys will be written in plain text'**
  String get configIncludeCredentialsSubtitle;

  /// No description provided for @configExportSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Export Content'**
  String get configExportSelectTitle;

  /// No description provided for @configExportPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Preview'**
  String get configExportPreviewTitle;

  /// No description provided for @configExportConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Export'**
  String get configExportConfirmTitle;

  /// No description provided for @configExportContainsSecretsWarning.
  ///
  /// In en, this message translates to:
  /// **'This file contains passwords/secret keys. Do not share it or commit it to version control!'**
  String get configExportContainsSecretsWarning;

  /// No description provided for @configImportSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Import Content'**
  String get configImportSelectTitle;

  /// No description provided for @configImportPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Preview'**
  String get configImportPreviewTitle;

  /// No description provided for @ledgersConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Conflict'**
  String get ledgersConflictTitle;

  /// No description provided for @ledgersConflictMessage.
  ///
  /// In en, this message translates to:
  /// **'Local and cloud ledger data are inconsistent, please choose an action:'**
  String get ledgersConflictMessage;

  /// No description provided for @ledgersConflictLocalInfo.
  ///
  /// In en, this message translates to:
  /// **'Local: {count} transactions'**
  String ledgersConflictLocalInfo(int count);

  /// No description provided for @ledgersConflictRemoteInfo.
  ///
  /// In en, this message translates to:
  /// **'Cloud: {count} transactions'**
  String ledgersConflictRemoteInfo(int count);

  /// No description provided for @ledgersConflictRemoteUpdated.
  ///
  /// In en, this message translates to:
  /// **'Cloud updated: {time}'**
  String ledgersConflictRemoteUpdated(String time);

  /// No description provided for @ledgersConflictLocalFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Local fingerprint: {fp}'**
  String ledgersConflictLocalFingerprint(String fp);

  /// No description provided for @ledgersConflictRemoteFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Cloud fingerprint: {fp}'**
  String ledgersConflictRemoteFingerprint(String fp);

  /// No description provided for @ledgersConflictUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload to Cloud'**
  String get ledgersConflictUpload;

  /// No description provided for @ledgersConflictDownload.
  ///
  /// In en, this message translates to:
  /// **'Download to Local'**
  String get ledgersConflictDownload;

  /// No description provided for @ledgersConflictUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get ledgersConflictUploading;

  /// No description provided for @ledgersConflictDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get ledgersConflictDownloading;

  /// No description provided for @ledgersConflictUploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Upload successful'**
  String get ledgersConflictUploadSuccess;

  /// No description provided for @ledgersConflictDownloadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Download successful, merged {inserted} transactions'**
  String ledgersConflictDownloadSuccess(int inserted);

  /// No description provided for @welcomeExistingUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Existing User?'**
  String get welcomeExistingUserTitle;

  /// No description provided for @welcomeExistingUserButton.
  ///
  /// In en, this message translates to:
  /// **'Import Config'**
  String get welcomeExistingUserButton;

  /// No description provided for @welcomeImportingConfig.
  ///
  /// In en, this message translates to:
  /// **'Importing configuration...'**
  String get welcomeImportingConfig;

  /// No description provided for @welcomeImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Configuration imported successfully'**
  String get welcomeImportSuccess;

  /// No description provided for @welcomeImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String welcomeImportFailed(String error);

  /// No description provided for @welcomeImportNoFile.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get welcomeImportNoFile;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// No description provided for @calendarToday.
  ///
  /// In en, this message translates to:
  /// **'Back to Today'**
  String get calendarToday;

  /// No description provided for @calendarNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get calendarNoTransactions;

  /// No description provided for @calendarViewAllTransactions.
  ///
  /// In en, this message translates to:
  /// **'View all {count} transactions'**
  String calendarViewAllTransactions(int count);

  /// No description provided for @calendarAddTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add entry on this day'**
  String get calendarAddTransaction;

  /// No description provided for @commonUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get commonUncategorized;

  /// No description provided for @syncPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Preview'**
  String get syncPreviewTitle;

  /// No description provided for @syncPreviewSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get syncPreviewSelectAll;

  /// No description provided for @syncPreviewDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get syncPreviewDeselectAll;

  /// No description provided for @syncPreviewAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get syncPreviewAdded;

  /// No description provided for @syncPreviewModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get syncPreviewModified;

  /// No description provided for @syncPreviewDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get syncPreviewDeleted;

  /// No description provided for @syncPreviewAddedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} added'**
  String syncPreviewAddedCount(int count);

  /// No description provided for @syncPreviewModifiedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} modified'**
  String syncPreviewModifiedCount(int count);

  /// No description provided for @syncPreviewDeletedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} deleted'**
  String syncPreviewDeletedCount(int count);

  /// No description provided for @syncPreviewApply.
  ///
  /// In en, this message translates to:
  /// **'Apply {count} items'**
  String syncPreviewApply(int count);

  /// No description provided for @syncPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cloud data matches local, no sync needed'**
  String get syncPreviewEmpty;

  /// No description provided for @syncPreviewOldFormat.
  ///
  /// In en, this message translates to:
  /// **'Old cloud format, full replace required'**
  String get syncPreviewOldFormat;

  /// No description provided for @syncPreviewOldFormatMessage.
  ///
  /// In en, this message translates to:
  /// **'Cloud data does not contain sync IDs. Local data will be cleared and re-imported from cloud.'**
  String get syncPreviewOldFormatMessage;

  /// No description provided for @syncPreviewApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied {count} changes'**
  String syncPreviewApplied(int count);

  /// No description provided for @cloudSyncGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync Guide'**
  String get cloudSyncGuideTitle;

  /// No description provided for @cloudSyncGuideGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get cloudSyncGuideGotIt;

  /// No description provided for @cloudSyncGuideHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get cloudSyncGuideHowItWorks;

  /// No description provided for @cloudSyncGuideHowItem1.
  ///
  /// In en, this message translates to:
  /// **'Upload: packages all current ledger data and uploads to cloud, replacing old cloud data'**
  String get cloudSyncGuideHowItem1;

  /// No description provided for @cloudSyncGuideHowItem2.
  ///
  /// In en, this message translates to:
  /// **'Download: fetches cloud data and compares with local records one by one — you choose which changes to apply'**
  String get cloudSyncGuideHowItem2;

  /// No description provided for @cloudSyncGuideHowItem3.
  ///
  /// In en, this message translates to:
  /// **'The cloud always stores only the last uploaded snapshot, no version history'**
  String get cloudSyncGuideHowItem3;

  /// No description provided for @cloudSyncGuideCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct usage'**
  String get cloudSyncGuideCorrect;

  /// No description provided for @cloudSyncGuideCorrectItem1.
  ///
  /// In en, this message translates to:
  /// **'Edit on one device at a time, upload when done'**
  String get cloudSyncGuideCorrectItem1;

  /// No description provided for @cloudSyncGuideCorrectItem2.
  ///
  /// In en, this message translates to:
  /// **'Download on the new device before starting to edit'**
  String get cloudSyncGuideCorrectItem2;

  /// No description provided for @cloudSyncGuideCorrectItem3.
  ///
  /// In en, this message translates to:
  /// **'Review the preview carefully before applying changes'**
  String get cloudSyncGuideCorrectItem3;

  /// No description provided for @cloudSyncGuideCorrectItem4.
  ///
  /// In en, this message translates to:
  /// **'Follow the pattern: edit → upload → switch device → download → edit'**
  String get cloudSyncGuideCorrectItem4;

  /// No description provided for @cloudSyncGuideWrong.
  ///
  /// In en, this message translates to:
  /// **'What to avoid'**
  String get cloudSyncGuideWrong;

  /// No description provided for @cloudSyncGuideWrongItem1.
  ///
  /// In en, this message translates to:
  /// **'Editing the same ledger on two devices simultaneously — the later upload overwrites the earlier one'**
  String get cloudSyncGuideWrongItem1;

  /// No description provided for @cloudSyncGuideWrongItem2.
  ///
  /// In en, this message translates to:
  /// **'Downloading immediately after upload — cloud services may have seconds to minutes of sync delay, wait a moment'**
  String get cloudSyncGuideWrongItem2;

  /// No description provided for @cloudSyncGuideWrongItem3.
  ///
  /// In en, this message translates to:
  /// **'Going long periods without syncing then downloading many changes at once — easy to miss important differences'**
  String get cloudSyncGuideWrongItem3;

  /// No description provided for @cloudSyncGuideLimitations.
  ///
  /// In en, this message translates to:
  /// **'Known limitations'**
  String get cloudSyncGuideLimitations;

  /// No description provided for @cloudSyncGuideLimitItem1.
  ///
  /// In en, this message translates to:
  /// **'Not real-time: requires manually tapping upload and download'**
  String get cloudSyncGuideLimitItem1;

  /// No description provided for @cloudSyncGuideLimitItem2.
  ///
  /// In en, this message translates to:
  /// **'No conflict merging: does not auto-merge edits from both sides — last upload wins'**
  String get cloudSyncGuideLimitItem2;

  /// No description provided for @cloudSyncGuideLimitItem3.
  ///
  /// In en, this message translates to:
  /// **'Cloud service delay: uploaded files may take seconds to minutes before other devices can read them, depending on your cloud provider'**
  String get cloudSyncGuideLimitItem3;

  /// No description provided for @appLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Lock App'**
  String get appLockTitle;

  /// No description provided for @appLockDesc.
  ///
  /// In en, this message translates to:
  /// **'PIN & biometric to protect privacy'**
  String get appLockDesc;

  /// No description provided for @appLockEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable App Lock'**
  String get appLockEnable;

  /// No description provided for @appLockEnableDesc.
  ///
  /// In en, this message translates to:
  /// **'Require authentication on launch and resume'**
  String get appLockEnableDesc;

  /// No description provided for @appLockSetPin.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get appLockSetPin;

  /// No description provided for @appLockChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get appLockChangePin;

  /// No description provided for @appLockVerifyPin.
  ///
  /// In en, this message translates to:
  /// **'Verify PIN'**
  String get appLockVerifyPin;

  /// No description provided for @appLockVerifyCurrentPin.
  ///
  /// In en, this message translates to:
  /// **'Enter current PIN'**
  String get appLockVerifyCurrentPin;

  /// No description provided for @appLockSetNewPin.
  ///
  /// In en, this message translates to:
  /// **'Set new PIN'**
  String get appLockSetNewPin;

  /// No description provided for @appLockConfirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get appLockConfirmPin;

  /// No description provided for @appLockEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get appLockEnterPin;

  /// No description provided for @appLockPinSetSuccess.
  ///
  /// In en, this message translates to:
  /// **'PIN set successfully'**
  String get appLockPinSetSuccess;

  /// No description provided for @appLockDisabled.
  ///
  /// In en, this message translates to:
  /// **'App Lock disabled'**
  String get appLockDisabled;

  /// No description provided for @appLockBiometric.
  ///
  /// In en, this message translates to:
  /// **'Biometric Unlock'**
  String get appLockBiometric;

  /// No description provided for @appLockBiometricDesc.
  ///
  /// In en, this message translates to:
  /// **'Use Face ID or fingerprint to unlock'**
  String get appLockBiometricDesc;

  /// No description provided for @appLockBiometricReason.
  ///
  /// In en, this message translates to:
  /// **'Verify identity to unlock Spitout'**
  String get appLockBiometricReason;

  /// No description provided for @appLockTimeout.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock Timeout'**
  String get appLockTimeout;

  /// No description provided for @appLockTimeoutImmediate.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get appLockTimeoutImmediate;

  /// No description provided for @appLockTimeout1Min.
  ///
  /// In en, this message translates to:
  /// **'After 1 minute'**
  String get appLockTimeout1Min;

  /// No description provided for @appLockTimeout5Min.
  ///
  /// In en, this message translates to:
  /// **'After 5 minutes'**
  String get appLockTimeout5Min;

  /// No description provided for @appLockTimeout15Min.
  ///
  /// In en, this message translates to:
  /// **'After 15 minutes'**
  String get appLockTimeout15Min;

  /// No description provided for @dayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'{day}th of each month'**
  String dayOfMonth(int day);

  /// No description provided for @syncHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync status'**
  String get syncHealthTitle;

  /// No description provided for @cloudSyncHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'How sync works · Why it sometimes stalls'**
  String get cloudSyncHelpTitle;

  /// No description provided for @cloudSyncHelpModesTitle.
  ///
  /// In en, this message translates to:
  /// **'Three sync modes'**
  String get cloudSyncHelpModesTitle;

  /// No description provided for @cloudSyncHelpModesBody.
  ///
  /// In en, this message translates to:
  /// **'• Incremental (automatic, everyday): after you add or edit an entry, only that change is uploaded/downloaded automatically — fast, no manual action. This is what runs all the time.\n• Full upload: the first time you enable cloud sync, or when the cloud has no data for this ledger yet, all local data is pushed to the cloud at once.\n• Full download: on a new device, after a reinstall, or when local is empty, all data is pulled down from the cloud.'**
  String get cloudSyncHelpModesBody;

  /// No description provided for @cloudSyncHelpWhenFullTitle.
  ///
  /// In en, this message translates to:
  /// **'When does a full sync happen?'**
  String get cloudSyncHelpWhenFullTitle;

  /// No description provided for @cloudSyncHelpWhenFullBody.
  ///
  /// In en, this message translates to:
  /// **'A full sync only triggers automatically when one side is empty (first enabling cloud sync / new device / reinstall / after clearing local or cloud data). As long as both sides have data, sync stays incremental and never restarts on its own. To force a full re-sync, you must first clear the data on the corresponding side.'**
  String get cloudSyncHelpWhenFullBody;

  /// No description provided for @cloudSyncHelpStuckTitle.
  ///
  /// In en, this message translates to:
  /// **'Why sync sometimes stalls'**
  String get cloudSyncHelpStuckTitle;

  /// No description provided for @cloudSyncHelpStuckBody.
  ///
  /// In en, this message translates to:
  /// **'• Full upload/download does NOT support resume: if the network drops or the app is killed in the background, it starts over from scratch instead of continuing. For large data, use a stable network (Wi-Fi recommended) and let it finish without switching away.\n• Incremental sync is resume-safe and unaffected in everyday use.'**
  String get cloudSyncHelpStuckBody;

  /// No description provided for @cloudSyncHelpTroubleshootTitle.
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting'**
  String get cloudSyncHelpTroubleshootTitle;

  /// No description provided for @cloudSyncHelpTroubleshootBody.
  ///
  /// In en, this message translates to:
  /// **'• First, pull down on this page to run a Deep Check and compare local vs cloud.\n• Still stuck? Open the Log Center to view sync logs (including failure reasons) for reporting.'**
  String get cloudSyncHelpTroubleshootBody;

  /// No description provided for @cloudSyncHelpOpenLogCenter.
  ///
  /// In en, this message translates to:
  /// **'Open Log Center'**
  String get cloudSyncHelpOpenLogCenter;

  /// No description provided for @syncHealthCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Check failed: {msg}'**
  String syncHealthCheckFailed(String msg);

  /// Shown while cloud sign-in is silently recovering after a session loss; auto-retries after cooldown
  ///
  /// In en, this message translates to:
  /// **'Restoring sign-in status…'**
  String get syncHealthRecovering;

  /// Shown when silent recovery failed and the user must manually sign in to cloud sync
  ///
  /// In en, this message translates to:
  /// **'Not signed in or session expired. Please sign in to cloud sync again.'**
  String get syncHealthNeedsLogin;

  /// No description provided for @syncHealthHasDiff.
  ///
  /// In en, this message translates to:
  /// **'Diff detected; auto-synced'**
  String get syncHealthHasDiff;

  /// Shown when the self-heal circuit breaker is open and the missing cloud data could not be restored automatically
  ///
  /// In en, this message translates to:
  /// **'Auto-restore failed; please restore from cloud manually'**
  String get cloudSyncHealFailed;

  /// No description provided for @syncHealthInSync.
  ///
  /// In en, this message translates to:
  /// **'Local matches cloud'**
  String get syncHealthInSync;

  /// No description provided for @syncHealthGroupCurrentLedger.
  ///
  /// In en, this message translates to:
  /// **'Current ledger'**
  String get syncHealthGroupCurrentLedger;

  /// No description provided for @syncHealthGroupAll.
  ///
  /// In en, this message translates to:
  /// **'All ledgers'**
  String get syncHealthGroupAll;

  /// No description provided for @syncHealthRowTx.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get syncHealthRowTx;

  /// No description provided for @syncHealthRowCategory.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get syncHealthRowCategory;

  /// No description provided for @syncHealthRowUnpushed.
  ///
  /// In en, this message translates to:
  /// **'Unpushed changes'**
  String get syncHealthRowUnpushed;

  /// Per-item sync counts in the sync-status detail panel, local vs remote
  ///
  /// In en, this message translates to:
  /// **'Local {local} · Remote {remote}'**
  String syncHealthValue(int local, int remote);

  /// Per-item sync count when the remote count cannot be fetched
  ///
  /// In en, this message translates to:
  /// **'Local {local} · Remote —'**
  String syncHealthValueRemoteMissing(int local);

  /// No description provided for @twofaChallengeTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get twofaChallengeTitle;

  /// No description provided for @twofaMethodTotp.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get twofaMethodTotp;

  /// No description provided for @twofaMethodRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery code'**
  String get twofaMethodRecovery;

  /// No description provided for @twofaTotpInputPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get twofaTotpInputPlaceholder;

  /// No description provided for @twofaRecoveryInputPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Recovery code'**
  String get twofaRecoveryInputPlaceholder;

  /// No description provided for @twofaVerifyButton.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get twofaVerifyButton;

  /// No description provided for @twofaStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get twofaStatusTitle;

  /// No description provided for @twofaStatusEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled ✓'**
  String get twofaStatusEnabled;

  /// No description provided for @twofaStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Not enabled'**
  String get twofaStatusDisabled;

  /// No description provided for @twofaStatusEnabledAt.
  ///
  /// In en, this message translates to:
  /// **'Enabled on {date}'**
  String twofaStatusEnabledAt(String date);

  /// No description provided for @sharedRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get sharedRoleOwner;

  /// No description provided for @sharedRoleEditor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get sharedRoleEditor;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get commonCopied;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @sharedJoinPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Join shared ledger'**
  String get sharedJoinPageTitle;

  /// No description provided for @sharedJoinPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter an invite code or tap a shared link'**
  String get sharedJoinPageSubtitle;

  /// No description provided for @sharedJoinEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter invite code'**
  String get sharedJoinEnterCode;

  /// No description provided for @sharedJoinEnterCodeHint.
  ///
  /// In en, this message translates to:
  /// **'6 uppercase letters / digits. You can also tap a share link to skip this step.'**
  String get sharedJoinEnterCodeHint;

  /// No description provided for @sharedJoinPreviewButton.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get sharedJoinPreviewButton;

  /// No description provided for @sharedJoinAcceptButton.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get sharedJoinAcceptButton;

  /// No description provided for @sharedJoinInvitedBy.
  ///
  /// In en, this message translates to:
  /// **'{name} invited you to join'**
  String sharedJoinInvitedBy(String name);

  /// No description provided for @sharedJoinRoleLine.
  ///
  /// In en, this message translates to:
  /// **'Role: {role}'**
  String sharedJoinRoleLine(String role);

  /// No description provided for @sharedJoinExpiresInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Expires in {n} min'**
  String sharedJoinExpiresInMinutes(int n);

  /// No description provided for @sharedJoinExpiresInHours.
  ///
  /// In en, this message translates to:
  /// **'Expires in {n}h'**
  String sharedJoinExpiresInHours(int n);

  /// No description provided for @sharedJoinExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'Expires in {n}d'**
  String sharedJoinExpiresInDays(int n);

  /// No description provided for @sharedJoinSuccess.
  ///
  /// In en, this message translates to:
  /// **'Joined \"{name}\"'**
  String sharedJoinSuccess(String name);

  /// No description provided for @sharedJoinCodeFormatError.
  ///
  /// In en, this message translates to:
  /// **'Invite code must be 6 letters/digits.'**
  String get sharedJoinCodeFormatError;

  /// No description provided for @sharedJoinInvalidOrExpired.
  ///
  /// In en, this message translates to:
  /// **'Invite code is invalid or expired. Ask the inviter for a new one.'**
  String get sharedJoinInvalidOrExpired;

  /// No description provided for @sharedJoinAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'You are already a member of this ledger.'**
  String get sharedJoinAlreadyMember;

  /// No description provided for @sharedJoinMemberLimit.
  ///
  /// In en, this message translates to:
  /// **'This ledger has reached its member limit. Ask the owner.'**
  String get sharedJoinMemberLimit;

  /// No description provided for @sharedInviteFormRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get sharedInviteFormRole;

  /// No description provided for @sharedInviteFormExpiry.
  ///
  /// In en, this message translates to:
  /// **'Valid for'**
  String get sharedInviteFormExpiry;

  /// No description provided for @sharedInviteExpiryHours.
  ///
  /// In en, this message translates to:
  /// **'{n} h'**
  String sharedInviteExpiryHours(int n);

  /// No description provided for @sharedInviteExpiryDays.
  ///
  /// In en, this message translates to:
  /// **'{n} day'**
  String sharedInviteExpiryDays(int n);

  /// No description provided for @sharedInviteGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate invite code'**
  String get sharedInviteGenerate;

  /// No description provided for @sharedInviteGenerateAnother.
  ///
  /// In en, this message translates to:
  /// **'Generate another code'**
  String get sharedInviteGenerateAnother;

  /// No description provided for @sharedInviteCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get sharedInviteCopyCode;

  /// No description provided for @sharedInviteCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get sharedInviteCopyLink;

  /// No description provided for @sharedInviteShareLink.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get sharedInviteShareLink;

  /// No description provided for @sharedInviteExpiresAt.
  ///
  /// In en, this message translates to:
  /// **'Expires at {dt}'**
  String sharedInviteExpiresAt(String dt);

  /// No description provided for @sharedInviteWarning.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Don\'t post invite codes to public groups / social. Anyone with the code can join. Revoke and regenerate from Members if leaked.'**
  String get sharedInviteWarning;

  /// No description provided for @sharedInviteInstruction.
  ///
  /// In en, this message translates to:
  /// **'Send the code or short link to the other person. After they install Spitout, they can tap the link or enter the code from \"Me → Join shared ledger\".'**
  String get sharedInviteInstruction;

  /// No description provided for @sharedInviteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Invite is unavailable. Please generate a new one.'**
  String get sharedInviteUnavailable;

  /// No description provided for @sharedInviteShareText.
  ///
  /// In en, this message translates to:
  /// **'I\'m inviting you to Spitout shared ledger \"{ledger}\".\n\nCode: {code}\nLink: {url}\n\nTap the link, or open Spitout → Me → Join shared ledger and enter this code.'**
  String sharedInviteShareText(String ledger, String code, String url);

  /// No description provided for @sharedMembersPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get sharedMembersPageTitle;

  /// No description provided for @sharedMembersInviteCta.
  ///
  /// In en, this message translates to:
  /// **'Invite new member'**
  String get sharedMembersInviteCta;

  /// No description provided for @ledgersLeaveAndDelete.
  ///
  /// In en, this message translates to:
  /// **'Leave and Delete'**
  String get ledgersLeaveAndDelete;

  /// No description provided for @ledgersLeaveAndDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave and Delete Ledger'**
  String get ledgersLeaveAndDeleteConfirm;

  /// No description provided for @ledgersLeaveAndDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Leave and delete the shared ledger \"{name}\"?\\nAfter leaving, the cloud removes your membership and all local data is cleared. You won\'t be able to access its transactions anymore.'**
  String ledgersLeaveAndDeleteMessage(String name);

  /// No description provided for @ledgersLeaveAndDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Left and deleted the ledger'**
  String get ledgersLeaveAndDeleteSuccess;

  /// No description provided for @ledgersDeleteShared.
  ///
  /// In en, this message translates to:
  /// **'Delete Shared Ledger'**
  String get ledgersDeleteShared;

  /// No description provided for @ledgersDeleteSharedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete Shared Ledger'**
  String get ledgersDeleteSharedConfirm;

  /// No description provided for @ledgersDeleteSharedMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete the shared ledger \"{name}\"?\\nThis also removes all collaborators and clears their local data. This cannot be undone.'**
  String ledgersDeleteSharedMessage(String name);

  /// No description provided for @ledgersDeleteSharedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Shared ledger deleted'**
  String get ledgersDeleteSharedSuccess;

  /// No description provided for @sharedMembersRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove member'**
  String get sharedMembersRemoveTitle;

  /// No description provided for @sharedMembersRemoveCta.
  ///
  /// In en, this message translates to:
  /// **'Remove this member'**
  String get sharedMembersRemoveCta;

  /// No description provided for @sharedMembersRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}? They will immediately lose access to this ledger.'**
  String sharedMembersRemoveConfirm(String name);

  /// No description provided for @sharedMembersRemoved.
  ///
  /// In en, this message translates to:
  /// **'Member removed'**
  String get sharedMembersRemoved;

  /// No description provided for @sharedMembersRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove member. Please try again later.'**
  String get sharedMembersRemoveFailed;

  /// No description provided for @sharedMembersSyncPending.
  ///
  /// In en, this message translates to:
  /// **'For a newly created ledger, select it on the ledger management page first, then re-enter this page to invite members.'**
  String get sharedMembersSyncPending;

  /// No description provided for @sharedMembersSaveFirst.
  ///
  /// In en, this message translates to:
  /// **'Please save the ledger first'**
  String get sharedMembersSaveFirst;

  /// No description provided for @sharedMembersInviteSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync not finished yet. Please try again later.'**
  String get sharedMembersInviteSyncFailed;

  /// No description provided for @sharedMembersLoadingHint.
  ///
  /// In en, this message translates to:
  /// **'Cloud ledger is not ready, syncing…'**
  String get sharedMembersLoadingHint;

  /// No description provided for @sharedMembersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load members'**
  String get sharedMembersLoadFailed;

  /// No description provided for @sharedMembersRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get sharedMembersRetry;

  /// No description provided for @sharedTxCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Created by {name}'**
  String sharedTxCreatedBy(String name);

  /// No description provided for @sharedTxEditedBy.
  ///
  /// In en, this message translates to:
  /// **'Last edited by {name}'**
  String sharedTxEditedBy(String name);

  /// No description provided for @sharedTxCreatedAndEditedBy.
  ///
  /// In en, this message translates to:
  /// **'Created and edited by {name}'**
  String sharedTxCreatedAndEditedBy(String name);

  /// No description provided for @sharedRequiresCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Please enable cloud sync first'**
  String get sharedRequiresCloudSync;

  /// No description provided for @sharedMembersStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Member expenses'**
  String get sharedMembersStatsTitle;

  /// No description provided for @sharedMembersStatsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get sharedMembersStatsEmpty;

  /// No description provided for @sharedMembersStatsTxCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tx'**
  String sharedMembersStatsTxCount(int count);

  /// No description provided for @maintenanceOrphanCleanupTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Cleanup'**
  String get maintenanceOrphanCleanupTitle;

  /// No description provided for @maintenanceOrphanCleanupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Detect and clean local orphan data'**
  String get maintenanceOrphanCleanupSubtitle;

  /// No description provided for @maintenanceOrphanRescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get maintenanceOrphanRescan;

  /// No description provided for @maintenanceOrphanEmpty.
  ///
  /// In en, this message translates to:
  /// **'Local data is clean, no orphan data found'**
  String get maintenanceOrphanEmpty;

  /// No description provided for @maintenanceOrphanGroupDb.
  ///
  /// In en, this message translates to:
  /// **'Database orphans'**
  String get maintenanceOrphanGroupDb;

  /// No description provided for @maintenanceOrphanGroupSync.
  ///
  /// In en, this message translates to:
  /// **'Sync state orphans'**
  String get maintenanceOrphanGroupSync;

  /// No description provided for @maintenanceOrphanSummary.
  ///
  /// In en, this message translates to:
  /// **'Found {count} issue(s)'**
  String maintenanceOrphanSummary(int count);

  /// No description provided for @maintenanceOrphanSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get maintenanceOrphanSelectAll;

  /// No description provided for @maintenanceOrphanDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get maintenanceOrphanDeselectAll;

  /// No description provided for @maintenanceOrphanDeleteOne.
  ///
  /// In en, this message translates to:
  /// **'Delete this'**
  String get maintenanceOrphanDeleteOne;

  /// No description provided for @maintenanceOrphanSelectedHint.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String maintenanceOrphanSelectedHint(int count);

  /// No description provided for @maintenanceOrphanCleanSelected.
  ///
  /// In en, this message translates to:
  /// **'Clean selected'**
  String get maintenanceOrphanCleanSelected;

  /// No description provided for @maintenanceOrphanConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm cleanup'**
  String get maintenanceOrphanConfirmTitle;

  /// No description provided for @maintenanceOrphanConfirmDeleteOne.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"? This cannot be undone.'**
  String maintenanceOrphanConfirmDeleteOne(String title);

  /// No description provided for @maintenanceOrphanConfirmDeleteBatch.
  ///
  /// In en, this message translates to:
  /// **'Delete the {count} selected item(s)? This cannot be undone.'**
  String maintenanceOrphanConfirmDeleteBatch(int count);

  /// No description provided for @maintenanceOrphanCleanSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cleaned {count} item(s)'**
  String maintenanceOrphanCleanSuccess(int count);

  /// No description provided for @maintenanceOrphanCleanPartial.
  ///
  /// In en, this message translates to:
  /// **'Cleaned {ok} item(s), {fail} failed'**
  String maintenanceOrphanCleanPartial(int ok, int fail);

  /// No description provided for @maintenanceOrphanDeletedLedgerGroup.
  ///
  /// In en, this message translates to:
  /// **'Deleted ledger #{ledgerId} ({count} items)'**
  String maintenanceOrphanDeletedLedgerGroup(int ledgerId, int count);

  /// No description provided for @maintenanceOrphanMoveSingle.
  ///
  /// In en, this message translates to:
  /// **'Move to ledger'**
  String get maintenanceOrphanMoveSingle;

  /// No description provided for @maintenanceOrphanMoveToLedger.
  ///
  /// In en, this message translates to:
  /// **'Move to ledger'**
  String get maintenanceOrphanMoveToLedger;

  /// No description provided for @maintenanceOrphanMoveToLedgerSuccess.
  ///
  /// In en, this message translates to:
  /// **'Moved {count} item(s) to ledger'**
  String maintenanceOrphanMoveToLedgerSuccess(int count);

  /// No description provided for @exchangeRatePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Exchange Rates'**
  String get exchangeRatePageTitle;

  /// No description provided for @exchangeRateEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-fetched rates with manual override'**
  String get exchangeRateEntrySubtitle;

  /// No description provided for @rateSourceAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get rateSourceAuto;

  /// No description provided for @rateSourceManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get rateSourceManual;

  /// No description provided for @rateUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String rateUpdatedAt(String date);

  /// No description provided for @rateNotFetched.
  ///
  /// In en, this message translates to:
  /// **'Not fetched'**
  String get rateNotFetched;

  /// No description provided for @rateEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Rate'**
  String get rateEditTitle;

  /// No description provided for @rateInverseHint.
  ///
  /// In en, this message translates to:
  /// **'Inverse: 1 {base} ≈ {rate} {quote}'**
  String rateInverseHint(String base, String rate, String quote);

  /// No description provided for @rateResetToAuto.
  ///
  /// In en, this message translates to:
  /// **'Reset to auto'**
  String get rateResetToAuto;

  /// No description provided for @rateRefreshSuccess.
  ///
  /// In en, this message translates to:
  /// **'Rates updated'**
  String get rateRefreshSuccess;

  /// No description provided for @rateRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Fetch failed, you can set rates manually'**
  String get rateRefreshFailed;

  /// No description provided for @rateDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Source: open exchange-rate data, updated daily. Conversion is for reference only and may differ from bank rates.'**
  String get rateDisclaimer;

  /// No description provided for @txFlagExcludedTag.
  ///
  /// In en, this message translates to:
  /// **'Excluded'**
  String get txFlagExcludedTag;

  /// No description provided for @txRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get txRateLabel;

  /// No description provided for @txRateMissingHint.
  ///
  /// In en, this message translates to:
  /// **'Please enter the rate for this entry before saving'**
  String get txRateMissingHint;

  /// No description provided for @ledgerBaseCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary currency'**
  String get ledgerBaseCurrencyLabel;

  /// No description provided for @statsConvertedFootnote.
  ///
  /// In en, this message translates to:
  /// **'Includes foreign currency, converted to {currency} at entry-time rates'**
  String statsConvertedFootnote(Object currency);

  /// No description provided for @ledgerCurrencyChangeRecalcHint.
  ///
  /// In en, this message translates to:
  /// **'Changing the base currency will reconvert all history at current rates'**
  String get ledgerCurrencyChangeRecalcHint;

  /// No description provided for @ledgerCurrencyChangeRecalcWarning.
  ///
  /// In en, this message translates to:
  /// **'Converted amounts of all transactions in this ledger will be recalculated at the latest rates and overwritten; switching away and back cannot restore the original values'**
  String get ledgerCurrencyChangeRecalcWarning;

  /// No description provided for @recalcForeignTxBanner.
  ///
  /// In en, this message translates to:
  /// **'Unconverted foreign-currency transactions detected in this ledger'**
  String get recalcForeignTxBanner;

  /// No description provided for @recalcForeignTxAction.
  ///
  /// In en, this message translates to:
  /// **'Reconvert at current rates'**
  String get recalcForeignTxAction;

  /// No description provided for @recalcForeignTxDone.
  ///
  /// In en, this message translates to:
  /// **'Reconverted {count} foreign-currency transactions'**
  String recalcForeignTxDone(Object count);

  /// No description provided for @txCurrencyPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select currency'**
  String get txCurrencyPickerTitle;

  /// No description provided for @txAddEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'New Entry'**
  String get txAddEntryTitle;

  /// No description provided for @txDeleteLongPress.
  ///
  /// In en, this message translates to:
  /// **'Long press to clear'**
  String get txDeleteLongPress;

  /// No description provided for @txSelectDateTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Select date & time'**
  String get txSelectDateTimeTitle;

  /// No description provided for @txSelectDateTimeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe up or down to pick a value'**
  String get txSelectDateTimeHint;

  /// No description provided for @txEditCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit categories'**
  String get txEditCategory;

  /// No description provided for @txEditCategoryReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Edit categories (read-only in shared ledger)'**
  String get txEditCategoryReadOnly;

  /// No description provided for @txLedgerBaseCurrency.
  ///
  /// In en, this message translates to:
  /// **'Ledger base currency'**
  String get txLedgerBaseCurrency;

  /// No description provided for @recalcSyncCountHint.
  ///
  /// In en, this message translates to:
  /// **'{count} transactions will be reconverted and synced'**
  String recalcSyncCountHint(Object count);

  /// No description provided for @analyticsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data. Please check your network.'**
  String get analyticsLoadFailed;

  /// No description provided for @analyticsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get analyticsRetry;

  /// No description provided for @exportCsvHeaderCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get exportCsvHeaderCurrency;

  /// No description provided for @importFieldCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get importFieldCurrency;

  /// No description provided for @currencyMOP.
  ///
  /// In en, this message translates to:
  /// **'Macau Pataca'**
  String get currencyMOP;

  /// No description provided for @currencyMNT.
  ///
  /// In en, this message translates to:
  /// **'Mongolian Tughrik'**
  String get currencyMNT;

  /// No description provided for @currencyKPW.
  ///
  /// In en, this message translates to:
  /// **'North Korean Won'**
  String get currencyKPW;

  /// No description provided for @currencyKHR.
  ///
  /// In en, this message translates to:
  /// **'Cambodian Riel'**
  String get currencyKHR;

  /// No description provided for @currencyLAK.
  ///
  /// In en, this message translates to:
  /// **'Lao Kip'**
  String get currencyLAK;

  /// No description provided for @currencyBND.
  ///
  /// In en, this message translates to:
  /// **'Bruneian Dollar'**
  String get currencyBND;

  /// No description provided for @currencyNPR.
  ///
  /// In en, this message translates to:
  /// **'Nepalese Rupee'**
  String get currencyNPR;

  /// No description provided for @currencyBTN.
  ///
  /// In en, this message translates to:
  /// **'Bhutanese Ngultrum'**
  String get currencyBTN;

  /// No description provided for @currencyMVR.
  ///
  /// In en, this message translates to:
  /// **'Maldivian Rufiyaa'**
  String get currencyMVR;

  /// No description provided for @currencyAFN.
  ///
  /// In en, this message translates to:
  /// **'Afghan Afghani'**
  String get currencyAFN;

  /// No description provided for @currencyUZS.
  ///
  /// In en, this message translates to:
  /// **'Uzbekistani Som'**
  String get currencyUZS;

  /// No description provided for @currencyTJS.
  ///
  /// In en, this message translates to:
  /// **'Tajikistani Somoni'**
  String get currencyTJS;

  /// No description provided for @currencyTMT.
  ///
  /// In en, this message translates to:
  /// **'Turkmenistani Manat'**
  String get currencyTMT;

  /// No description provided for @currencyKGS.
  ///
  /// In en, this message translates to:
  /// **'Kyrgyzstani Som'**
  String get currencyKGS;

  /// No description provided for @currencyQAR.
  ///
  /// In en, this message translates to:
  /// **'Qatari Riyal'**
  String get currencyQAR;

  /// No description provided for @currencyKWD.
  ///
  /// In en, this message translates to:
  /// **'Kuwaiti Dinar'**
  String get currencyKWD;

  /// No description provided for @currencyBHD.
  ///
  /// In en, this message translates to:
  /// **'Bahraini Dinar'**
  String get currencyBHD;

  /// No description provided for @currencyOMR.
  ///
  /// In en, this message translates to:
  /// **'Omani Rial'**
  String get currencyOMR;

  /// No description provided for @currencyJOD.
  ///
  /// In en, this message translates to:
  /// **'Jordanian Dinar'**
  String get currencyJOD;

  /// No description provided for @currencyLBP.
  ///
  /// In en, this message translates to:
  /// **'Lebanese Pound'**
  String get currencyLBP;

  /// No description provided for @currencyIQD.
  ///
  /// In en, this message translates to:
  /// **'Iraqi Dinar'**
  String get currencyIQD;

  /// No description provided for @currencyIRR.
  ///
  /// In en, this message translates to:
  /// **'Iranian Rial'**
  String get currencyIRR;

  /// No description provided for @currencyYER.
  ///
  /// In en, this message translates to:
  /// **'Yemeni Rial'**
  String get currencyYER;

  /// No description provided for @currencySYP.
  ///
  /// In en, this message translates to:
  /// **'Syrian Pound'**
  String get currencySYP;

  /// No description provided for @currencyGEL.
  ///
  /// In en, this message translates to:
  /// **'Georgian Lari'**
  String get currencyGEL;

  /// No description provided for @currencyAMD.
  ///
  /// In en, this message translates to:
  /// **'Armenian Dram'**
  String get currencyAMD;

  /// No description provided for @currencyAZN.
  ///
  /// In en, this message translates to:
  /// **'Azerbaijan Manat'**
  String get currencyAZN;

  /// No description provided for @currencyRON.
  ///
  /// In en, this message translates to:
  /// **'Romanian Leu'**
  String get currencyRON;

  /// No description provided for @currencyBGN.
  ///
  /// In en, this message translates to:
  /// **'Bulgarian Lev'**
  String get currencyBGN;

  /// No description provided for @currencyRSD.
  ///
  /// In en, this message translates to:
  /// **'Serbian Dinar'**
  String get currencyRSD;

  /// No description provided for @currencyISK.
  ///
  /// In en, this message translates to:
  /// **'Icelandic Krona'**
  String get currencyISK;

  /// No description provided for @currencyMDL.
  ///
  /// In en, this message translates to:
  /// **'Moldovan Leu'**
  String get currencyMDL;

  /// No description provided for @currencyALL.
  ///
  /// In en, this message translates to:
  /// **'Albanian Lek'**
  String get currencyALL;

  /// No description provided for @currencyMKD.
  ///
  /// In en, this message translates to:
  /// **'Macedonian Denar'**
  String get currencyMKD;

  /// No description provided for @currencyBAM.
  ///
  /// In en, this message translates to:
  /// **'Bosnian Convertible Mark'**
  String get currencyBAM;

  /// No description provided for @currencyGIP.
  ///
  /// In en, this message translates to:
  /// **'Gibraltar Pound'**
  String get currencyGIP;

  /// No description provided for @currencyGTQ.
  ///
  /// In en, this message translates to:
  /// **'Guatemalan Quetzal'**
  String get currencyGTQ;

  /// No description provided for @currencyHNL.
  ///
  /// In en, this message translates to:
  /// **'Honduran Lempira'**
  String get currencyHNL;

  /// No description provided for @currencyNIO.
  ///
  /// In en, this message translates to:
  /// **'Nicaraguan Cordoba'**
  String get currencyNIO;

  /// No description provided for @currencyCRC.
  ///
  /// In en, this message translates to:
  /// **'Costa Rican Colon'**
  String get currencyCRC;

  /// No description provided for @currencyPAB.
  ///
  /// In en, this message translates to:
  /// **'Panamanian Balboa'**
  String get currencyPAB;

  /// No description provided for @currencyDOP.
  ///
  /// In en, this message translates to:
  /// **'Dominican Peso'**
  String get currencyDOP;

  /// No description provided for @currencyCUP.
  ///
  /// In en, this message translates to:
  /// **'Cuban Peso'**
  String get currencyCUP;

  /// No description provided for @currencyJMD.
  ///
  /// In en, this message translates to:
  /// **'Jamaican Dollar'**
  String get currencyJMD;

  /// No description provided for @currencyTTD.
  ///
  /// In en, this message translates to:
  /// **'Trinidadian Dollar'**
  String get currencyTTD;

  /// No description provided for @currencyBSD.
  ///
  /// In en, this message translates to:
  /// **'Bahamian Dollar'**
  String get currencyBSD;

  /// No description provided for @currencyBBD.
  ///
  /// In en, this message translates to:
  /// **'Barbadian or Bajan Dollar'**
  String get currencyBBD;

  /// No description provided for @currencyBZD.
  ///
  /// In en, this message translates to:
  /// **'Belizean Dollar'**
  String get currencyBZD;

  /// No description provided for @currencyHTG.
  ///
  /// In en, this message translates to:
  /// **'Haitian Gourde'**
  String get currencyHTG;

  /// No description provided for @currencyKYD.
  ///
  /// In en, this message translates to:
  /// **'Caymanian Dollar'**
  String get currencyKYD;

  /// No description provided for @currencyAWG.
  ///
  /// In en, this message translates to:
  /// **'Aruban or Dutch Guilder'**
  String get currencyAWG;

  /// No description provided for @currencyBMD.
  ///
  /// In en, this message translates to:
  /// **'Bermudian Dollar'**
  String get currencyBMD;

  /// No description provided for @currencyUYU.
  ///
  /// In en, this message translates to:
  /// **'Uruguayan Peso'**
  String get currencyUYU;

  /// No description provided for @currencyPYG.
  ///
  /// In en, this message translates to:
  /// **'Paraguayan Guarani'**
  String get currencyPYG;

  /// No description provided for @currencyBOB.
  ///
  /// In en, this message translates to:
  /// **'Bolivian Bolíviano'**
  String get currencyBOB;

  /// No description provided for @currencyVES.
  ///
  /// In en, this message translates to:
  /// **'Venezuelan Bolívar'**
  String get currencyVES;

  /// No description provided for @currencyGYD.
  ///
  /// In en, this message translates to:
  /// **'Guyanese Dollar'**
  String get currencyGYD;

  /// No description provided for @currencySRD.
  ///
  /// In en, this message translates to:
  /// **'Surinamese Dollar'**
  String get currencySRD;

  /// No description provided for @currencyFJD.
  ///
  /// In en, this message translates to:
  /// **'Fijian Dollar'**
  String get currencyFJD;

  /// No description provided for @currencyPGK.
  ///
  /// In en, this message translates to:
  /// **'Papua New Guinean Kina'**
  String get currencyPGK;

  /// No description provided for @currencySBD.
  ///
  /// In en, this message translates to:
  /// **'Solomon Islander Dollar'**
  String get currencySBD;

  /// No description provided for @currencyTOP.
  ///
  /// In en, this message translates to:
  /// **'Tongan Pa\'anga'**
  String get currencyTOP;

  /// No description provided for @currencyVUV.
  ///
  /// In en, this message translates to:
  /// **'Ni-Vanuatu Vatu'**
  String get currencyVUV;

  /// No description provided for @currencyWST.
  ///
  /// In en, this message translates to:
  /// **'Samoan Tala'**
  String get currencyWST;

  /// No description provided for @currencyKES.
  ///
  /// In en, this message translates to:
  /// **'Kenyan Shilling'**
  String get currencyKES;

  /// No description provided for @currencyGHS.
  ///
  /// In en, this message translates to:
  /// **'Ghanaian Cedi'**
  String get currencyGHS;

  /// No description provided for @currencyMAD.
  ///
  /// In en, this message translates to:
  /// **'Moroccan Dirham'**
  String get currencyMAD;

  /// No description provided for @currencyDZD.
  ///
  /// In en, this message translates to:
  /// **'Algerian Dinar'**
  String get currencyDZD;

  /// No description provided for @currencyTND.
  ///
  /// In en, this message translates to:
  /// **'Tunisian Dinar'**
  String get currencyTND;

  /// No description provided for @currencyLYD.
  ///
  /// In en, this message translates to:
  /// **'Libyan Dinar'**
  String get currencyLYD;

  /// No description provided for @currencyETB.
  ///
  /// In en, this message translates to:
  /// **'Ethiopian Birr'**
  String get currencyETB;

  /// No description provided for @currencyUGX.
  ///
  /// In en, this message translates to:
  /// **'Ugandan Shilling'**
  String get currencyUGX;

  /// No description provided for @currencyTZS.
  ///
  /// In en, this message translates to:
  /// **'Tanzanian Shilling'**
  String get currencyTZS;

  /// No description provided for @currencyRWF.
  ///
  /// In en, this message translates to:
  /// **'Rwandan Franc'**
  String get currencyRWF;

  /// No description provided for @currencyMUR.
  ///
  /// In en, this message translates to:
  /// **'Mauritian Rupee'**
  String get currencyMUR;

  /// No description provided for @currencyBWP.
  ///
  /// In en, this message translates to:
  /// **'Botswana Pula'**
  String get currencyBWP;

  /// No description provided for @currencyNAD.
  ///
  /// In en, this message translates to:
  /// **'Namibian Dollar'**
  String get currencyNAD;

  /// No description provided for @currencyZMW.
  ///
  /// In en, this message translates to:
  /// **'Zambian Kwacha'**
  String get currencyZMW;

  /// No description provided for @currencyMWK.
  ///
  /// In en, this message translates to:
  /// **'Malawian Kwacha'**
  String get currencyMWK;

  /// No description provided for @currencyMZN.
  ///
  /// In en, this message translates to:
  /// **'Mozambican Metical'**
  String get currencyMZN;

  /// No description provided for @currencyAOA.
  ///
  /// In en, this message translates to:
  /// **'Angolan Kwanza'**
  String get currencyAOA;

  /// No description provided for @currencyCDF.
  ///
  /// In en, this message translates to:
  /// **'Congolese Franc'**
  String get currencyCDF;

  /// No description provided for @currencyGMD.
  ///
  /// In en, this message translates to:
  /// **'Gambian Dalasi'**
  String get currencyGMD;

  /// No description provided for @currencyGNF.
  ///
  /// In en, this message translates to:
  /// **'Guinean Franc'**
  String get currencyGNF;

  /// No description provided for @currencyLRD.
  ///
  /// In en, this message translates to:
  /// **'Liberian Dollar'**
  String get currencyLRD;

  /// No description provided for @currencySLE.
  ///
  /// In en, this message translates to:
  /// **'Sierra Leonean Leone'**
  String get currencySLE;

  /// No description provided for @currencySDG.
  ///
  /// In en, this message translates to:
  /// **'Sudanese Pound'**
  String get currencySDG;

  /// No description provided for @currencySSP.
  ///
  /// In en, this message translates to:
  /// **'South Sudanese Pound'**
  String get currencySSP;

  /// No description provided for @currencySOS.
  ///
  /// In en, this message translates to:
  /// **'Somali Shilling'**
  String get currencySOS;

  /// No description provided for @currencyDJF.
  ///
  /// In en, this message translates to:
  /// **'Djiboutian Franc'**
  String get currencyDJF;

  /// No description provided for @currencyERN.
  ///
  /// In en, this message translates to:
  /// **'Eritrean Nakfa'**
  String get currencyERN;

  /// No description provided for @currencyBIF.
  ///
  /// In en, this message translates to:
  /// **'Burundian Franc'**
  String get currencyBIF;

  /// No description provided for @currencyCVE.
  ///
  /// In en, this message translates to:
  /// **'Cape Verdean Escudo'**
  String get currencyCVE;

  /// No description provided for @currencySTN.
  ///
  /// In en, this message translates to:
  /// **'Sao Tomean Dobra'**
  String get currencySTN;

  /// No description provided for @currencySCR.
  ///
  /// In en, this message translates to:
  /// **'Seychellois Rupee'**
  String get currencySCR;

  /// No description provided for @currencyKMF.
  ///
  /// In en, this message translates to:
  /// **'Comorian Franc'**
  String get currencyKMF;

  /// No description provided for @currencyLSL.
  ///
  /// In en, this message translates to:
  /// **'Basotho Loti'**
  String get currencyLSL;

  /// No description provided for @currencySZL.
  ///
  /// In en, this message translates to:
  /// **'Swazi Lilangeni'**
  String get currencySZL;

  /// No description provided for @currencyMGA.
  ///
  /// In en, this message translates to:
  /// **'Malagasy Ariary'**
  String get currencyMGA;

  /// No description provided for @currencyMRU.
  ///
  /// In en, this message translates to:
  /// **'Mauritanian Ouguiya'**
  String get currencyMRU;

  /// No description provided for @detailImportExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Detail Import/Export'**
  String get detailImportExportTitle;

  /// No description provided for @detailImportExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Expense CSV file'**
  String get detailImportExportSubtitle;

  /// No description provided for @detailImportExportImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Details'**
  String get detailImportExportImportTitle;

  /// No description provided for @detailImportExportImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Supports CSV/TSV/XLSX and Alipay/WeChat bills'**
  String get detailImportExportImportSubtitle;

  /// No description provided for @detailImportExportExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Details'**
  String get detailImportExportExportTitle;

  /// No description provided for @detailImportExportExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export ledger details to a CSV file'**
  String get detailImportExportExportSubtitle;

  /// No description provided for @detailImportExportImportPoint1.
  ///
  /// In en, this message translates to:
  /// **'Supports generic CSV, Alipay and WeChat bills in CSV/TSV/XLSX format'**
  String get detailImportExportImportPoint1;

  /// No description provided for @detailImportExportImportPoint2.
  ///
  /// In en, this message translates to:
  /// **'The difference lies only in file structure: generic CSV has a clean header row, while Alipay/WeChat bills contain descriptive preamble lines that the app skips automatically to locate the header'**
  String get detailImportExportImportPoint2;

  /// No description provided for @detailImportExportImportPoint3.
  ///
  /// In en, this message translates to:
  /// **'All three are recognized via the same column mapping (date, type, amount, currency, category, subcategory, note), with an identical import flow'**
  String get detailImportExportImportPoint3;

  /// No description provided for @detailImportExportExportPoint1.
  ///
  /// In en, this message translates to:
  /// **'Exports the selected ledger\'s transactions to a CSV file with UTF-8 BOM encoding, which Excel can open directly'**
  String get detailImportExportExportPoint1;

  /// No description provided for @detailImportExportExportPoint2.
  ///
  /// In en, this message translates to:
  /// **'Named spitout_timestamp.csv and saved to the Download/Spitout directory by default'**
  String get detailImportExportExportPoint2;

  /// No description provided for @detailImportExportExportPoint3.
  ///
  /// In en, this message translates to:
  /// **'Fields included:'**
  String get detailImportExportExportPoint3;

  /// No description provided for @detailExportLedgerLabel.
  ///
  /// In en, this message translates to:
  /// **'Export Ledger'**
  String get detailExportLedgerLabel;

  /// No description provided for @detailExportSelectAllLabel.
  ///
  /// In en, this message translates to:
  /// **'All Data'**
  String get detailExportSelectAllLabel;

  /// No description provided for @detailExportSelectAllSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export all data under the selected ledger'**
  String get detailExportSelectAllSubtitle;

  /// No description provided for @detailExportStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get detailExportStartDate;

  /// No description provided for @detailExportEndDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get detailExportEndDate;

  /// No description provided for @detailExportDateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Start date cannot be later than end date'**
  String get detailExportDateInvalid;

  /// No description provided for @detailExportAction.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get detailExportAction;

  /// No description provided for @exchangeRateCurrentLedger.
  ///
  /// In en, this message translates to:
  /// **'Current ledger: {name}'**
  String exchangeRateCurrentLedger(Object name);

  /// No description provided for @exchangeRateInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'About Primary Currency'**
  String get exchangeRateInfoTitle;

  /// No description provided for @exchangeRateInfoMessage.
  ///
  /// In en, this message translates to:
  /// **'The primary currency is the base currency of the current ledger: foreign-currency transactions in this ledger are converted into it at exchange rates, so totals can be compared directly in statistics and asset overviews. Each ledger has its own primary currency and you can switch it at any time; switching recalculates converted amounts for all transactions in this ledger at the latest rates.\n\nRates are fetched automatically from public data sources on a daily basis. You can also tap \"Edit\" for any currency in the list below to set a manual rate — it overrides the automatic data and takes effect immediately.'**
  String get exchangeRateInfoMessage;

  /// No description provided for @rateEditLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get rateEditLabel;

  /// No description provided for @rateInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid rate (a number greater than 0)'**
  String get rateInvalidInput;

  /// No description provided for @currencyManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Displayed Currencies'**
  String get currencyManageTitle;

  /// No description provided for @currencyManageEntry.
  ///
  /// In en, this message translates to:
  /// **'Currency Management'**
  String get currencyManageEntry;

  /// No description provided for @currencyManageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} currencies selected'**
  String currencyManageCount(Object count);

  /// No description provided for @currencyManageBaseLocked.
  ///
  /// In en, this message translates to:
  /// **'Ledger base currency (cannot be hidden)'**
  String get currencyManageBaseLocked;

  /// No description provided for @currencyManageHint.
  ///
  /// In en, this message translates to:
  /// **'Hiding a currency does not affect existing transactions; you can re-enable it here at any time.'**
  String get currencyManageHint;

  /// No description provided for @detailImportExportMigrateTitle.
  ///
  /// In en, this message translates to:
  /// **'Ledger Data Migration'**
  String get detailImportExportMigrateTitle;

  /// No description provided for @detailImportExportMigrateTip.
  ///
  /// In en, this message translates to:
  /// **'Export the current ledger\'s data to a CSV file, then switch to the target ledger and import that file to migrate your data between ledgers seamlessly.'**
  String get detailImportExportMigrateTip;

  /// No description provided for @mineCheckUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get mineCheckUpdate;

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get updateChecking;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get updateAvailableTitle;

  /// No description provided for @updateLatestVersion.
  ///
  /// In en, this message translates to:
  /// **'Latest: v{version}'**
  String updateLatestVersion(String version);

  /// No description provided for @updateAlreadyLatestTitle.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get updateAlreadyLatestTitle;

  /// No description provided for @updateAlreadyLatest.
  ///
  /// In en, this message translates to:
  /// **'You are on the latest version v{version}'**
  String updateAlreadyLatest(String version);

  /// No description provided for @updateGotoDownload.
  ///
  /// In en, this message translates to:
  /// **'Go to download'**
  String get updateGotoDownload;

  /// No description provided for @updateCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version v{version}'**
  String updateCurrentVersion(String version);

  /// No description provided for @updateNewVersionHint.
  ///
  /// In en, this message translates to:
  /// **'New version v{version} available'**
  String updateNewVersionHint(String version);

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get updateOk;

  /// No description provided for @updateCantAutoCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t check for updates automatically'**
  String get updateCantAutoCheckTitle;

  /// No description provided for @updateCantAutoCheck.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t fetch version info. View the latest release on GitHub.'**
  String get updateCantAutoCheck;

  /// No description provided for @updateGoToGithub.
  ///
  /// In en, this message translates to:
  /// **'View on GitHub'**
  String get updateGoToGithub;

  /// No description provided for @mineUpdateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get mineUpdateNow;

  /// No description provided for @ledgerMetaReadOnlyToast.
  ///
  /// In en, this message translates to:
  /// **'Collaborators cannot modify ledger settings.'**
  String get ledgerMetaReadOnlyToast;

  /// No description provided for @aaStatisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'AA Statistics'**
  String get aaStatisticsTitle;

  /// No description provided for @aaStatisticsOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get aaStatisticsOverview;

  /// No description provided for @aaStatisticsTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total shared'**
  String get aaStatisticsTotalAmount;

  /// No description provided for @aaStatisticsTxCount.
  ///
  /// In en, this message translates to:
  /// **'{count} shared transactions'**
  String aaStatisticsTxCount(int count);

  /// No description provided for @aaStatisticsPerPerson.
  ///
  /// In en, this message translates to:
  /// **'Split details'**
  String get aaStatisticsPerPerson;

  /// No description provided for @aaStatisticsPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get aaStatisticsPaid;

  /// No description provided for @aaStatisticsShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get aaStatisticsShare;

  /// No description provided for @aaStatisticsNet.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get aaStatisticsNet;

  /// No description provided for @aaStatisticsNetReceive.
  ///
  /// In en, this message translates to:
  /// **'to receive'**
  String get aaStatisticsNetReceive;

  /// No description provided for @aaStatisticsNetPay.
  ///
  /// In en, this message translates to:
  /// **'to pay'**
  String get aaStatisticsNetPay;

  /// No description provided for @aaStatisticsTransferPlan.
  ///
  /// In en, this message translates to:
  /// **'Settlement plan'**
  String get aaStatisticsTransferPlan;

  /// No description provided for @aaStatisticsTransferSeparator.
  ///
  /// In en, this message translates to:
  /// **'pays'**
  String get aaStatisticsTransferSeparator;

  /// No description provided for @aaStatisticsNoTransfers.
  ///
  /// In en, this message translates to:
  /// **'All settled up'**
  String get aaStatisticsNoTransfers;

  /// No description provided for @aaStatisticsExcluded.
  ///
  /// In en, this message translates to:
  /// **'Excluded from split'**
  String get aaStatisticsExcluded;

  /// No description provided for @aaStatisticsParticipantCount.
  ///
  /// In en, this message translates to:
  /// **'{count} participants'**
  String aaStatisticsParticipantCount(int count);

  /// No description provided for @aaStatisticsExcludedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions excluded from split'**
  String get aaStatisticsExcludedEmpty;

  /// No description provided for @aaStatisticsViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get aaStatisticsViewDetails;

  /// No description provided for @aaStatisticsBillSummary.
  ///
  /// In en, this message translates to:
  /// **'Bill summary'**
  String get aaStatisticsBillSummary;

  /// No description provided for @aaStatisticsTotalCount.
  ///
  /// In en, this message translates to:
  /// **'Total bills'**
  String get aaStatisticsTotalCount;

  /// No description provided for @aaStatisticsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total amount'**
  String get aaStatisticsTotal;

  /// No description provided for @aaStatisticsNetReceiveAmount.
  ///
  /// In en, this message translates to:
  /// **'To receive'**
  String get aaStatisticsNetReceiveAmount;

  /// No description provided for @aaStatisticsNetPayAmount.
  ///
  /// In en, this message translates to:
  /// **'To pay'**
  String get aaStatisticsNetPayAmount;

  /// No description provided for @aaStatisticsSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get aaStatisticsSettled;

  /// No description provided for @aaStatisticsModePerPerson.
  ///
  /// In en, this message translates to:
  /// **'Split equally'**
  String get aaStatisticsModePerPerson;

  /// No description provided for @aaStatisticsModeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom amount'**
  String get aaStatisticsModeCustom;

  /// No description provided for @aaStatisticsSplitDetail.
  ///
  /// In en, this message translates to:
  /// **'Split details'**
  String get aaStatisticsSplitDetail;

  /// No description provided for @aaStatisticsPayerPrefix.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get aaStatisticsPayerPrefix;

  /// No description provided for @aaStatisticsMemberTxEmpty.
  ///
  /// In en, this message translates to:
  /// **'No bills for this member'**
  String get aaStatisticsMemberTxEmpty;

  /// No description provided for @aaEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit split'**
  String get aaEditTitle;

  /// No description provided for @aaEditSplitButton.
  ///
  /// In en, this message translates to:
  /// **'Edit split'**
  String get aaEditSplitButton;

  /// No description provided for @aaPayer.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get aaPayer;

  /// No description provided for @aaSplitMode.
  ///
  /// In en, this message translates to:
  /// **'Split method'**
  String get aaSplitMode;

  /// No description provided for @aaParticipants.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get aaParticipants;

  /// No description provided for @aaModePerPerson.
  ///
  /// In en, this message translates to:
  /// **'Split equally'**
  String get aaModePerPerson;

  /// No description provided for @aaModeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom split'**
  String get aaModeCustom;

  /// No description provided for @aaModeNoSplit.
  ///
  /// In en, this message translates to:
  /// **'No split'**
  String get aaModeNoSplit;

  /// No description provided for @aaParticipantsAll.
  ///
  /// In en, this message translates to:
  /// **'All members'**
  String get aaParticipantsAll;

  /// No description provided for @aaParticipantsAllCount.
  ///
  /// In en, this message translates to:
  /// **'All members ({count})'**
  String aaParticipantsAllCount(int count);

  /// No description provided for @aaParticipantsUnit.
  ///
  /// In en, this message translates to:
  /// **''**
  String get aaParticipantsUnit;

  /// No description provided for @aaVirtualUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Virtual members'**
  String get aaVirtualUserTitle;

  /// No description provided for @aaVirtualUserAdd.
  ///
  /// In en, this message translates to:
  /// **'Add virtual member'**
  String get aaVirtualUserAdd;

  /// No description provided for @aaVirtualUserNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a nickname'**
  String get aaVirtualUserNameHint;

  /// No description provided for @aaVirtualUserRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get aaVirtualUserRename;

  /// No description provided for @aaVirtualUserEmpty.
  ///
  /// In en, this message translates to:
  /// **'No virtual members yet'**
  String get aaVirtualUserEmpty;

  /// No description provided for @aaVirtualUserDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String aaVirtualUserDeleteConfirm(String name);

  /// No description provided for @aaVirtualUserInUse.
  ///
  /// In en, this message translates to:
  /// **'Has related transactions and cannot be deleted'**
  String get aaVirtualUserInUse;

  /// No description provided for @aaVirtualUserDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Virtual User {index}'**
  String aaVirtualUserDefaultName(int index);

  /// No description provided for @aaAddVirtualUser.
  ///
  /// In en, this message translates to:
  /// **'Add virtual user'**
  String get aaAddVirtualUser;

  /// No description provided for @aaUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get aaUnknownUser;

  /// No description provided for @aaMe.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get aaMe;

  /// No description provided for @ledgerAaEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'Split expenses with members when enabled'**
  String get ledgerAaEnabledHint;

  /// No description provided for @ledgerAaStatisticsEntry.
  ///
  /// In en, this message translates to:
  /// **'AA Statistics'**
  String get ledgerAaStatisticsEntry;

  /// No description provided for @ledgerAaVirtualUsersEntry.
  ///
  /// In en, this message translates to:
  /// **'Manage virtual members'**
  String get ledgerAaVirtualUsersEntry;

  /// No description provided for @aaSwitchOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Turn on AA Split'**
  String get aaSwitchOnLabel;

  /// No description provided for @aaSwitchOffLabel.
  ///
  /// In en, this message translates to:
  /// **'Turn off AA Split'**
  String get aaSwitchOffLabel;

  /// No description provided for @aaNoParticipants.
  ///
  /// In en, this message translates to:
  /// **'Add participants first'**
  String get aaNoParticipants;

  /// No description provided for @aaSplitAmountIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount for every participant'**
  String get aaSplitAmountIncomplete;
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
      <String>['en', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
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
