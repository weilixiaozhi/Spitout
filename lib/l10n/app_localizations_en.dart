import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Spitout';

  @override
  String get tabHome => 'Home';

  @override
  String get tabAnalytics => 'Statistics';

  @override
  String get tabCalendar => 'Calendar';

  @override
  String get tabMine => 'Mine';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDone => 'Done';

  @override
  String get homeSelectBillMonth => 'Select month';

  @override
  String get homePickerHint => 'Swipe up or down to pick';

  @override
  String get homeBackToCurrentMonth => 'Back to current month';

  @override
  String get homeTodayExpense => 'Today';

  @override
  String get homeWeekExpense => 'This week';

  @override
  String get homeMonthExpense => 'This month';

  @override
  String get homeDetailCategory => 'Category';

  @override
  String get homeDetailDate => 'Date';

  @override
  String get homeDetailAmount => 'Amount';

  @override
  String get homeDetailCurrency => 'Currency';

  @override
  String get homeDetailNativeAmount => 'In base currency';

  @override
  String get homeDetailMembers => 'Members';

  @override
  String get homeDetailCreator => 'Created by';

  @override
  String get homeDetailLastEditor => 'Last edited by';

  @override
  String get homeDetailEditHistory => 'Edit history';

  @override
  String get homeDetailEditHistoryHint => 'View only';

  @override
  String get homeDetailEditButton => 'Edit';

  @override
  String get homeDetailNoHistory => 'No edit history';

  @override
  String get homeDeleteDetailTitle => 'Delete this entry?';

  @override
  String homeDeleteDetailMessage(Object name) {
    return 'This will delete the \"$name\" record. This action cannot be undone.';
  }

  @override
  String get commonEmpty => 'No data';

  @override
  String get commonError => 'Error';

  @override
  String get commonFailed => 'Failed';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonFinish => 'Finish';

  @override
  String get commonOther => 'Other';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonNoteHint => 'Note...';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonCurrent => 'Current';

  @override
  String get commonTutorial => 'Tutorial';

  @override
  String get commonConfigure => 'Configure';

  @override
  String get commonPressAgainToExit => 'Press again to exit';

  @override
  String get commonWeekdayMonday => 'Monday';

  @override
  String get commonWeekdayTuesday => 'Tuesday';

  @override
  String get commonWeekdayWednesday => 'Wednesday';

  @override
  String get commonWeekdayThursday => 'Thursday';

  @override
  String get commonWeekdayFriday => 'Friday';

  @override
  String get commonWeekdaySaturday => 'Saturday';

  @override
  String get commonWeekdaySunday => 'Sunday';

  @override
  String get homeExpense => 'Expense';

  @override
  String get homeNoRecords => 'No records yet';

  @override
  String get homeSelectDate => 'Select date';

  @override
  String homeYear(int year) {
    return '$year';
  }

  @override
  String homeMonth(String month) {
    return '${month}M';
  }

  @override
  String homeMonthExpenseOf(String month) {
    return 'Month $month';
  }

  @override
  String get homeNoRecordsSubtext => 'Tap the plus button at the bottom to add a record';

  @override
  String get homeBaseCurrencyNeedLedger => 'Please create a ledger first';

  @override
  String homeBaseCurrencySwitched(String code) {
    return 'Base currency switched to $code';
  }

  @override
  String get homePullCloudSuccess => 'Synced cloud ledger data';

  @override
  String get homePullCloudFailed => 'Refresh failed, please try again later';

  @override
  String get homePullLocalSuccess => 'Refreshed local ledger data & config';

  @override
  String get homePullCloudFailedButLocalOk => 'Cloud sync failed; refreshed local data (rates/config)';

  @override
  String homePullCloudHealed(int count) {
    return 'Auto-recovered and synced $count cloud records';
  }

  @override
  String get homePullCloudGap => 'Some cloud history could not be auto-restored. Please use \'Restore from cloud\' on the sync page';

  @override
  String get homeSyncing => 'Syncing ledger data';

  @override
  String get homeSwitchMonthHint => 'Swipe the list left/right to switch months';

  @override
  String get analyticsMonth => 'Month';

  @override
  String get analyticsYear => 'Year';

  @override
  String get analyticsAll => 'All';

  @override
  String get analyticsWeek => 'Week';

  @override
  String analyticsSwipePeriodHint(Object period) {
    return 'Swipe left/right on the list to switch $period';
  }

  @override
  String get analyticsTrend => 'Expense Trend';

  @override
  String get analyticsTotalExpenseLabel => 'Total Expense';

  @override
  String get analyticsDailyExpense => 'Daily Expense';

  @override
  String get analyticsMoMLastWeek => 'vs Last Week';

  @override
  String get analyticsMoMLastMonth => 'vs Last Month';

  @override
  String get analyticsMoMLastYear => 'vs Last Year';

  @override
  String get analyticsCategoryLabel => 'Category';

  @override
  String get analyticsExpenseRatio => 'Expense Ratio';

  @override
  String get analyticsThisWeek => 'This Week';

  @override
  String get analyticsBackToThisWeek => 'Back to This Week';

  @override
  String get analyticsBackToThisMonth => 'Back to This Month';

  @override
  String get analyticsBackToThisYear => 'Back to This Year';

  @override
  String analyticsWeekN(int week) {
    return 'Week $week';
  }

  @override
  String get analyticsSelectWeek => 'Select week';

  @override
  String get ledgersTitle => 'Ledger Management';

  @override
  String get ledgersNew => 'New Ledger';

  @override
  String get ledgersClear => 'Clear Ledger';

  @override
  String ledgersClearMessage(Object name) {
    return 'Are you sure to clear all transactions in ledger \"$name\"? This action cannot be undone.\\nThe ledger will be kept, only transaction data will be deleted.';
  }

  @override
  String get ledgerDefaultName => 'Default Ledger';

  @override
  String get ledgersEdit => 'Edit Ledger';

  @override
  String get ledgersDelete => 'Delete Ledger';

  @override
  String get ledgersDeleteConfirm => 'Delete Ledger';

  @override
  String get ledgersDeleteMessage => 'Are you sure you want to delete this ledger and all its records? This action cannot be undone.\\nIf there is a backup in the cloud, it will also be deleted.';

  @override
  String get ledgersDeleted => 'Deleted';

  @override
  String get ledgersDeleteFailed => 'Delete Failed';

  @override
  String get ledgersClearTitle => 'Clear Ledger';

  @override
  String get ledgersClearSuccess => 'Ledger cleared';

  @override
  String get ledgersCreateSuccess => 'Ledger created';

  @override
  String get ledgerNameLabel => 'Ledger Name';

  @override
  String get ledgerNameHint => 'Please enter the ledger name';

  @override
  String get ledgersDefaultLedgerName => 'Default Ledger';

  @override
  String get ledgersCurrency => 'Currency';

  @override
  String get ledgersMonthStartDay => 'Month start day';

  @override
  String get ledgersMonthStartDayHint => 'Statistics and budgets use this day (1-28) as the start of each monthly period';

  @override
  String get ledgersMonthStartDayNatural => '1st (calendar month)';

  @override
  String ledgersMonthStartDayValue(int day) {
    return 'Day $day of each month';
  }

  @override
  String get ledgersSearchCurrency => 'Search: Chinese or code';

  @override
  String get ledgersCreate => 'Create';

  @override
  String ledgersRecords(String count) {
    return 'Records: $count';
  }

  @override
  String ledgersExpense(String expense) {
    return 'Expense: $expense';
  }

  @override
  String get ledgersEmpty => 'No ledgers';

  @override
  String get ledgersSectionLocal => 'Local ledgers';

  @override
  String get ledgersSectionCloud => 'Spitout Cloud ledgers';

  @override
  String get ledgersSectionLocalEmpty => 'No local ledgers. Local ledgers stay on this device only.';

  @override
  String get ledgersSectionCloudEmpty => 'No cloud ledgers. Cloud ledgers sync across your devices.';

  @override
  String get ledgersSectionCloudSignInHint => 'Sign in to Spitout Cloud to use cloud ledgers';

  @override
  String get ledgersStorageLocation => 'Storage location';

  @override
  String get ledgersStorageLocalHint => 'Stored on this device only, never uploaded';

  @override
  String get ledgersStorageCloudHint => 'Uploaded to Spitout Cloud and synced across your devices';

  @override
  String get ledgersActionMoveToCloud => 'Move to Spitout Cloud';

  @override
  String get ledgersActionMoveToLocal => 'Move to local';

  @override
  String get ledgersActionCopyToLocal => 'Copy to local';

  @override
  String ledgersMoveToCloudMessage(String name) {
    return 'Ledger \"$name\" will be uploaded to Spitout Cloud and synced across your devices.';
  }

  @override
  String ledgersMoveToLocalMessage(String name) {
    return 'Ledger \"$name\" will be deleted from Spitout Cloud and kept on this device only. Other devices will no longer see it.';
  }

  @override
  String ledgersCopyToLocalMessage(String name) {
    return 'A local copy of ledger \"$name\" will be created. The cloud ledger stays unchanged.';
  }

  @override
  String get ledgersMoveToCloudSuccess => 'Moved to Spitout Cloud';

  @override
  String get ledgersMoveToLocalSuccess => 'Moved to local';

  @override
  String get ledgersCopyToLocalSuccess => 'Copied to local';

  @override
  String ledgersSwitched(String name) {
    return 'Switched to ledger \"$name\"';
  }

  @override
  String get categoryTitle => 'Category Management';

  @override
  String get categoryExpense => 'Expense';

  @override
  String get categoryEmpty => 'No categories';

  @override
  String categoryLoadFailed(String error) {
    return 'Load failed: $error';
  }

  @override
  String get importReading => 'Reading file…';

  @override
  String get importPreparing => 'Preparing…';

  @override
  String importColumnNumber(Object number) {
    return 'Column $number';
  }

  @override
  String get importConfirmMapping => 'Confirm Mapping';

  @override
  String get importCategoryMapping => 'Category Mapping';

  @override
  String get importNoDataParsed => 'No data parsed. Please return to previous page to check CSV content or separator.';

  @override
  String get importFieldDate => 'Date';

  @override
  String get importFieldType => 'Type';

  @override
  String get importFieldAmount => 'Amount';

  @override
  String get importFieldCategory => 'Category';

  @override
  String get importFieldNote => 'Note';

  @override
  String get importPreview => 'Data Preview';

  @override
  String importPreviewLimit(Object shown, Object total) {
    return 'Showing first $shown of $total records';
  }

  @override
  String get importCategoryNotSelected => 'Category not selected';

  @override
  String get importCategoryMappingDescription => 'Please select corresponding local categories for each category name:';

  @override
  String get importKeepOriginalName => 'Keep original name';

  @override
  String importProgress(Object fail, Object ok) {
    return 'Importing, success: $ok, failed: $fail';
  }

  @override
  String get importCancelImport => 'Cancel Import';

  @override
  String get importCompleteTitle => 'Import Complete';

  @override
  String get importSelectCategoryFirst => 'Please select category mapping first';

  @override
  String get importNextStep => 'Next Step';

  @override
  String get importPreviousStep => 'Previous Step';

  @override
  String get importStartImport => 'Start Import';

  @override
  String get importAutoDetect => 'Auto Detect';

  @override
  String get importInProgress => 'Import in Progress';

  @override
  String importProgressDetail(Object done, Object fail, Object ok, Object total) {
    return 'Imported $done / $total records, success $ok, failed $fail';
  }

  @override
  String get importBackgroundImport => 'Background Import';

  @override
  String get importCancelled => 'Import Cancelled';

  @override
  String importCompleted(Object cancelled, Object fail, Object ok) {
    return 'Import Completed$cancelled, success $ok, failed $fail';
  }

  @override
  String importSkippedNonTransactionTypes(Object count) {
    return 'Skipped $count non-transaction records (debts, etc.)';
  }

  @override
  String importTransactionFailed(Object error) {
    return 'Import failed, all changes have been rolled back: $error';
  }

  @override
  String importFileOpenError(String error) {
    return 'Unable to open file picker: $error';
  }

  @override
  String get mineTitle => 'Mine';

  @override
  String get mineLanguageSettings => 'App Language';

  @override
  String get languageTitle => 'Language Settings';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystemDefault => 'Follow System';

  @override
  String get mineSlogan => 'Set your nickname';

  @override
  String get mineDisplayNameEditTitle => 'Set nickname';

  @override
  String get mineDisplayNameHint => 'Enter a nickname';

  @override
  String get mineDisplayNameSaved => 'Nickname updated';

  @override
  String get mineGreetingMorning => 'Good morning';

  @override
  String get mineGreetingNoon => 'Good noon';

  @override
  String get mineGreetingAfternoon => 'Good afternoon';

  @override
  String get mineGreetingEvening => 'Good evening';

  @override
  String get mineGreetingNight => 'Good night';

  @override
  String mineGreetingNamed(String greeting, String name) {
    return '$greeting, $name';
  }

  @override
  String get mineAvatarDelete => 'Delete Avatar';

  @override
  String get mineAvatarUploadNew => 'Upload New Avatar';

  @override
  String get mineCloudService => 'Cloud Service';

  @override
  String get mineCloudServiceLoading => 'Loading...';

  @override
  String get mineSyncTitle => 'Sync';

  @override
  String get mineSyncNotLoggedIn => 'Not logged in';

  @override
  String get mineSyncNotConfigured => 'Cloud not configured';

  @override
  String get mineSyncNoRemote => 'No cloud data';

  @override
  String mineSyncInSync(Object count) {
    return 'Synced (local $count records)';
  }

  @override
  String mineSyncLocalNewer(Object count) {
    return 'Local updated ($count records, upload recommended)';
  }

  @override
  String get mineSyncCloudNewer => 'Cloud updated (download to sync)';

  @override
  String get mineSyncDifferent => 'Local and cloud differ, download to compare';

  @override
  String get mineSyncError => 'Failed to get status';

  @override
  String get mineSyncDetailTitle => 'Sync Status Details';

  @override
  String mineSyncLocalRecords(Object count) {
    return 'Local records: $count';
  }

  @override
  String mineSyncCloudRecords(Object count) {
    return 'Cloud records: $count';
  }

  @override
  String mineSyncCloudLatest(Object time) {
    return 'Cloud latest record time: $time';
  }

  @override
  String mineSyncLocalFingerprint(Object fingerprint) {
    return 'Local fingerprint: $fingerprint';
  }

  @override
  String mineSyncCloudFingerprint(Object fingerprint) {
    return 'Cloud fingerprint: $fingerprint';
  }

  @override
  String mineSyncMessage(Object message) {
    return 'Message: $message';
  }

  @override
  String get mineUploadTitle => 'Upload';

  @override
  String get mineUploadNeedLogin => 'Login required';

  @override
  String get mineUploadNeedCloudService => 'Available in cloud service mode only';

  @override
  String get mineUploadInProgress => 'Uploading...';

  @override
  String get mineUploadRefreshing => 'Refreshing...';

  @override
  String get mineUploadSynced => 'Synced';

  @override
  String get mineUploadSuccess => 'Uploaded';

  @override
  String get mineUploadSuccessMessage => 'Current ledger synced to cloud';

  @override
  String get mineDownloadTitle => 'Download & Sync';

  @override
  String get mineDownloadNeedCloudService => 'Available in cloud service mode only';

  @override
  String get mineDownloadComplete => 'Sync Complete';

  @override
  String mineDownloadResult(Object inserted) {
    return 'Imported: $inserted records';
  }

  @override
  String get mineLoginTitle => 'Login';

  @override
  String get mineLoginSubtitle => 'Only needed for sync';

  @override
  String get cloudReloginTitle => 'Re-login';

  @override
  String get cloudReloginSuccess => 'Re-logged in';

  @override
  String get mineLoggedInEmail => 'Logged in';

  @override
  String get mineLogoutSubtitle => 'Tap to logout';

  @override
  String get mineLogoutConfirmTitle => 'Logout';

  @override
  String get mineLogoutConfirmMessage => 'Are you sure you want to logout?\nYou won\'t be able to use cloud sync after logout.';

  @override
  String get mineLogoutButton => 'Logout';

  @override
  String get mineAutoSyncTitle => 'Auto sync ledger';

  @override
  String get mineAutoSyncSubtitle => 'Auto upload to cloud after recording';

  @override
  String get mineAutoSyncNeedLogin => 'Login required to enable';

  @override
  String get mineCategoryManagement => 'Category Management';

  @override
  String get mineCategoryManagementSubtitle => 'Edit custom categories';

  @override
  String get mineRecurringTransactions => 'Recurring Bills';

  @override
  String get mineRecurringTransactionsSubtitle => 'Manage recurring bills';

  @override
  String get mineReminderSettings => 'Reminder Settings';

  @override
  String get mineReminderSettingsSubtitle => 'Set daily recording reminders';

  @override
  String get categoryEditTitle => 'Edit Category';

  @override
  String get categoryNewTitle => 'New Category';

  @override
  String get categoryDetailTooltip => 'Category Summary';

  @override
  String get categoryDefaultTitle => 'Default Category';

  @override
  String get categoryNameLabel => 'Category Name';

  @override
  String get categoryNameHint => 'Enter category name';

  @override
  String get categoryNameRequired => 'Please enter category name';

  @override
  String get categoryNameTooLong => 'Category name cannot exceed 4 characters';

  @override
  String get categoryNameDuplicate => 'Category name already exists';

  @override
  String get categoryIconLabel => 'Category Icon';

  @override
  String get categoryCurrentIcon => 'Current Icon';

  @override
  String get categorySaveError => 'Save failed';

  @override
  String categoryUpdated(Object name) {
    return 'Category \"$name\" updated';
  }

  @override
  String categoryCreated(Object name) {
    return 'Category \"$name\" created';
  }

  @override
  String get categoryCannotDelete => 'Cannot delete';

  @override
  String get categoryClearUnused => 'Clear Unused Categories';

  @override
  String get categoryClearUnusedTitle => 'Clear Unused Categories';

  @override
  String categoryClearUnusedMessage(Object count) {
    return 'Are you sure you want to delete $count unused categories? This action cannot be undone.';
  }

  @override
  String get categoryClearUnusedListTitle => 'Categories to be deleted:';

  @override
  String get categoryClearUnusedEmpty => 'No unused categories';

  @override
  String categoryClearUnusedSuccess(Object count) {
    return 'Deleted $count categories';
  }

  @override
  String get categoryClearUnusedFailed => 'Clear failed';

  @override
  String get categoryDeleteError => 'Delete failed';

  @override
  String categorySubCategoryCreated(Object name) {
    return 'Subcategory added: $name';
  }

  @override
  String get categoryParentCategoryTitle => 'Belongs To';

  @override
  String get categorySelectParentTitle => 'Select Category';

  @override
  String get categoryHasSubCategories => 'This category has subcategories and cannot be modified';

  @override
  String get categorySearchCategory => 'Search categories';

  @override
  String get categoryTopLevelLabel => 'Top-level';

  @override
  String get categorySecondLevelLabel => 'Second-level';

  @override
  String get categoryExpenseList => 'Dining-Transport-Shopping-Entertainment-Home-Family-Communication-Utilities-Housing-Medical-Education-Pets-Sports-Digital-Travel-Alcohol & Tobacco-Baby Care-Beauty-Repair-Social-Learning-Car-Taxi-Subway-Delivery-Property-Parking-Donation-Give Gift-Tax-Beverage-Clothing-Snacks-Send Red Packet-Fruit-Game-Books-Lover-Decoration-Daily Goods-Lottery-Stock-Social Security-Express-Work-Transfer-Other';

  @override
  String get categoryExpenseDining => 'Dining-Breakfast-Lunch-Dinner-Meituan Delivery-Ele.me Delivery-JD Delivery-Restaurant-Food';

  @override
  String get categoryExpenseSnacks => 'Snacks-Cookies-Chips-Candy-Chocolate-Nuts';

  @override
  String get categoryExpenseFruit => 'Fruit-Apple-Banana-Orange-Grape-Watermelon-Other Fruits';

  @override
  String get categoryExpenseBeverage => 'Beverage-Milk Tea-Coffee-Juice-Soda-Mineral Water';

  @override
  String get categoryExpensePastry => 'Pastry-Cake-Bread-Dessert-Baked Goods';

  @override
  String get categoryExpenseCooking => 'Cooking Ingredients-Vegetables-Meat-Seafood-Seasoning-Grain & Oil';

  @override
  String get categoryExpenseShopping => 'Shopping-Supermarket-Daily Necessities-Clothing-Shoes-Bags';

  @override
  String get categoryExpensePets => 'Pets-Pet Food-Pet Supplies-Pet Medical-Pet Grooming';

  @override
  String get categoryExpenseTransport => 'Transport-Transit Card-Taxi-Parking Fee-Fuel';

  @override
  String get categoryExpenseCar => 'Car-Car Maintenance-Car Repair-Car Insurance-Car Wash-Traffic Fine';

  @override
  String get categoryExpenseClothing => 'Apparel-Top-Pants-Dress-Shoes-Apparel Accessories';

  @override
  String get categoryExpenseDailyGoods => 'Daily Goods-Personal Care-Paper Products-Cleaning Supplies-Kitchen Supplies';

  @override
  String get categoryExpenseEducation => 'Education-Tuition-Training Fee-Books-Stationery-Office Supplies-Learning';

  @override
  String get categoryExpenseInvestLoss => 'Investment Loss-Stock Loss-Fund Loss-Other Investment Loss';

  @override
  String get categoryExpenseEntertainment => 'Entertainment-Movie-KTV-Amusement Park-Bar-Other Entertainment';

  @override
  String get categoryExpenseGame => 'Game-Game Top up-Game Equipment-Game Membership';

  @override
  String get categoryExpenseHealthProducts => 'Health Products-Vitamins-Health Food-Nutritional Supplements';

  @override
  String get categoryExpenseSubscription => 'Subscription-Video Membership-Music Membership-Cloud Storage-Other Subscription';

  @override
  String get categoryExpenseSports => 'Sports-Gym-Sports Equipment-Sports Course-Outdoor Activity';

  @override
  String get categoryExpenseHousing => 'Housing-Utilities-Property Fee-Rent-Mortgage-Renovation-Broadband';

  @override
  String get categoryExpenseHome => 'Home-Furniture-Appliances-Decorations-Bedding';

  @override
  String get categoryExpenseBeauty => 'Beauty-Skincare-Cosmetics-Haircut-Nail Care';

  @override
  String get categoryExpenseTransfer => 'Transfer-Living Cost-Family-Parents-Lover-Borrow Money';

  @override
  String get appearanceThemeMode => 'Dark Mode';

  @override
  String get appearanceThemeModeSystem => 'Follow System';

  @override
  String get appearanceThemeModeLight => 'Light Mode';

  @override
  String get appearanceThemeModeDark => 'Dark Mode';

  @override
  String get appearanceExpenseColorScheme => 'Expense Color';

  @override
  String get appearanceExpenseColorRed => 'Red for expense';

  @override
  String get appearanceExpenseColorGreen => 'Green for expense';

  @override
  String get appearanceExpenseColorApplied => 'Color scheme updated';

  @override
  String get reminderTitle => 'Recording Reminder';

  @override
  String get reminderSubtitle => 'Set daily recording reminder time';

  @override
  String get reminderDailyTitle => 'Daily Recording Reminder';

  @override
  String get reminderDailySubtitle => 'When enabled, will remind you to record at specified time';

  @override
  String get reminderTimeTitle => 'Reminder Time';

  @override
  String get commonSelectTime => 'Select Time';

  @override
  String get reminderTestNotification => 'Send Test Notification';

  @override
  String get reminderTestSent => 'Test notification sent';

  @override
  String get reminderTestTitle => 'Test Notification';

  @override
  String get reminderTestBody => 'This is a test notification, tap to see the effect';

  @override
  String get reminderCheckBattery => 'Check Battery Optimization Status';

  @override
  String get reminderBatteryStatus => 'Battery Optimization Status';

  @override
  String reminderManufacturer(Object value) {
    return 'Manufacturer: $value';
  }

  @override
  String reminderModel(Object value) {
    return 'Model: $value';
  }

  @override
  String reminderAndroidVersion(Object value) {
    return 'Android Version: $value';
  }

  @override
  String get reminderBatteryIgnored => 'Battery optimization: Ignored ✅';

  @override
  String get reminderBatteryNotIgnored => 'Battery optimization: Not ignored ⚠️';

  @override
  String get reminderBatteryAdvice => 'Recommend disabling battery optimization for proper notifications';

  @override
  String get reminderCheckChannel => 'Check Notification Channel Settings';

  @override
  String get reminderChannelStatus => 'Notification Channel Status';

  @override
  String get reminderChannelEnabled => 'Channel enabled: Yes ✅';

  @override
  String get reminderChannelDisabled => 'Channel enabled: No ❌';

  @override
  String reminderChannelImportance(Object value) {
    return 'Importance: $value';
  }

  @override
  String get reminderChannelSoundOn => 'Sound: On 🔊';

  @override
  String get reminderChannelSoundOff => 'Sound: Off 🔇';

  @override
  String get reminderChannelVibrationOn => 'Vibration: On 📳';

  @override
  String get reminderChannelVibrationOff => 'Vibration: Off';

  @override
  String get reminderChannelDndBypass => 'Do Not Disturb: Can bypass';

  @override
  String get reminderChannelDndNoBypass => 'Do Not Disturb: Cannot bypass';

  @override
  String get reminderChannelAdvice => '⚠️ Recommended settings:';

  @override
  String get reminderChannelAdviceImportance => '• Importance: Urgent or High';

  @override
  String get reminderChannelAdviceSound => '• Enable sound and vibration';

  @override
  String get reminderChannelAdviceBanner => '• Allow banner notifications';

  @override
  String get reminderChannelAdviceXiaomi => '• Xiaomi phones need individual channel setup';

  @override
  String get reminderChannelGood => '✅ Notification channel well configured';

  @override
  String get reminderOpenAppSettings => 'Open App Settings';

  @override
  String get reminderAppSettingsMessage => 'Please allow notifications and disable battery optimization in settings';

  @override
  String get reminderDescription => 'Tip: When recording reminder is enabled, the system will send notifications at the specified time daily to remind you to record expenses.';

  @override
  String get reminderAndroidInstructions => 'If notifications don\'t work properly, check:\n• App is allowed to send notifications\n• Disable battery optimization/power saving for app\n• Allow app to run in background and auto-start\n• Android 12+ needs exact alarm permission\n\n📱 Xiaomi phone special settings:\n• Settings > App Management > Spitout > Notification Management\n• Tap \"Recording Reminder\" channel\n• Set importance to \"Urgent\" or \"High\"\n• Enable \"Banner notifications\", \"Sound\", \"Vibration\"\n• Security Center > App Management > Permissions > Auto-start\n\n🔒 Lock background methods:\n• Find Spitout in recent tasks\n• Pull down app card to show lock icon\n• Tap lock icon to prevent cleanup';

  @override
  String get categoryDetailLoadFailed => 'Load failed';

  @override
  String get categoryDetailSummaryTitle => 'Category Summary';

  @override
  String get categoryDetailTotalCount => 'Total Count';

  @override
  String get categoryDetailTotalAmount => 'Total Amount';

  @override
  String get categoryDetailAverageAmount => 'Average Amount';

  @override
  String get categoryDetailSortTitle => 'Sort';

  @override
  String get categoryDetailSortTimeDesc => 'Time ↓';

  @override
  String get categoryDetailSortTimeAsc => 'Time ↑';

  @override
  String get categoryDetailSortAmountDesc => 'Amount ↓';

  @override
  String get categoryDetailSortAmountAsc => 'Amount ↑';

  @override
  String get categoryDetailNoTransactions => 'No transactions';

  @override
  String get categoryDetailNoTransactionsSubtext => 'No transactions in this category yet';

  @override
  String get categoryDetailDeleteFailed => 'Delete failed';

  @override
  String categoryMigrationTransactionLabel(int count) {
    return '$count records';
  }

  @override
  String get categoryTemplateEntryFlat => 'Flat Template';

  @override
  String get categoryTemplateEntryHierarchical => 'Hierarchical Template';

  @override
  String get categoryTemplateFlatTitle => 'Flat Category Template';

  @override
  String get categoryTemplateHierarchicalTitle => 'Hierarchical Category Template';

  @override
  String categoryTemplateSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get categoryTemplateSelectAll => 'Select all';

  @override
  String get categoryTemplateDeselectAll => 'Deselect all';

  @override
  String get categoryTemplateConfirmTitle => 'Add Categories';

  @override
  String categoryTemplateConfirmMessage(int count) {
    return 'Add the selected $count categories to your category list?';
  }

  @override
  String categoryTemplateAddSuccess(int count) {
    return 'Added $count categories';
  }

  @override
  String categoryTemplateAddFailed(String error) {
    return 'Failed to add: $error';
  }

  @override
  String get categoryManageAdd => 'Add Category';

  @override
  String get categoryManageDelete => 'Delete Categories';

  @override
  String get categoryManageConfirmDelete => 'Confirm Delete';

  @override
  String get categoryManageReorderHint => 'Long press to reorder';

  @override
  String get categorySharedManageBannerOwner => 'Shared ledger: category changes here sync to all members';

  @override
  String get categorySharedManageBannerEditor => 'This shared ledger uses the owner\'s categories; edits here only affect your personal categories';

  @override
  String get categorySyncFailedBeforeInvite => 'Couldn\'t sync categories before creating the invite. Check your network and try again';

  @override
  String get categorySortSaveFailed => 'Failed to save order. Please try again';

  @override
  String get categoryDeleteOptionAll => 'Delete categories and all data (incl. subcategories)';

  @override
  String get categoryDeleteOptionMigrate => 'Delete and migrate all data to another category (incl. subcategories)';

  @override
  String get categoryDeleteOptionPromote => 'Delete categories and data (excl. subcategories, subcategories become top-level)';

  @override
  String get categoryDeleteSelectedTitle => 'Delete Selected Categories';

  @override
  String categoryDeleteSelectedSubtitleWithSub(int count) {
    return 'Are you sure you want to delete $count selected categories and clear their data? (including subcategories and data) This action cannot be undone.';
  }

  @override
  String categoryDeleteSelectedSubtitleWithoutSub(int count) {
    return 'Are you sure you want to delete $count selected categories and clear their data? (excluding subcategories and data) This action cannot be undone.';
  }

  @override
  String get categoryMigrateSelectTargetTitle => 'Select Target Category';

  @override
  String get categoryMigrateConfirmButton => 'Confirm (Migrate data and delete categories)';

  @override
  String categoryMigrateChildLabel(Object parent) {
    return 'Sub · $parent';
  }

  @override
  String get subcategoryEditParent => 'Edit Parent Category';

  @override
  String get subcategoryAdd => 'Add Subcategory';

  @override
  String get subcategoryDelete => 'Delete Subcategories';

  @override
  String get subcategoryDeleteOptionAll => 'Delete categories and all data under them';

  @override
  String get subcategoryDeleteOptionMigrate => 'Delete categories and migrate all data to another category';

  @override
  String subcategoryDeleteSelectedSubtitle(int count) {
    return 'Are you sure you want to delete $count selected categories and clear their data? This action cannot be undone.';
  }

  @override
  String get subcategoryEmpty => 'No subcategories yet';

  @override
  String get cloudSupabaseUrlLabel => 'Supabase URL';

  @override
  String get cloudSupabaseUrlHint => 'https://xxx.supabase.co';

  @override
  String get cloudAnonKeyLabel => 'Anon Key';

  @override
  String get cloudMultiDeviceWarningTitle => 'Multi-Device Tips';

  @override
  String get cloudMultiDeviceWarningMessage => 'Upload before switching devices, download on the new device before editing. Don\'t edit the same ledger on two devices at once. Tap for details →';

  @override
  String get cloudWebdavUrlLabel => 'WebDAV Server URL';

  @override
  String get cloudWebdavUrlHint => 'https://dav.jianguoyun.com/dav/';

  @override
  String get cloudWebdavUsernameLabel => 'Username';

  @override
  String get cloudWebdavPasswordLabel => 'Password';

  @override
  String get cloudWebdavPathHint => '/Spitout';

  @override
  String get cloudS3EndpointLabel => 'Endpoint';

  @override
  String get cloudS3EndpointHint => 's3.amazonaws.com or custom endpoint';

  @override
  String get cloudS3RegionLabel => 'Region';

  @override
  String get cloudS3RegionHint => 'us-east-1 (leave blank for auto)';

  @override
  String get cloudS3AccessKeyLabel => 'Access Key';

  @override
  String get cloudS3AccessKeyHint => 'Your Access Key ID';

  @override
  String get cloudS3SecretKeyLabel => 'Secret Key';

  @override
  String get cloudS3SecretKeyHint => 'Your Secret Access Key';

  @override
  String get cloudS3BucketLabel => 'Bucket Name';

  @override
  String get cloudS3BucketHint => 'spitout-data';

  @override
  String get cloudS3UseSSLLabel => 'Use HTTPS';

  @override
  String get cloudS3PortLabel => 'Port (optional)';

  @override
  String get cloudS3PortHint => 'Leave blank for default';

  @override
  String get cloudSupabaseBucketLabel => 'Storage Bucket Name';

  @override
  String get cloudSupabaseBucketHint => 'Leave blank for default: spitout-backups';

  @override
  String get authRememberAccount => 'Remember account';

  @override
  String get authRememberAccountHint => 'Auto-fill on next login (Supabase only)';

  @override
  String get cloudFirstSaveSwitchTitle => 'Configuration Saved';

  @override
  String get cloudFirstSaveSwitchMessage => 'Switch to this cloud service as the active sync configuration now?';

  @override
  String get cloudSaveOnlyNoSwitch => 'Not Now';

  @override
  String get cloudSaveAndSwitch => 'Switch Now';

  @override
  String get cloudClearConfig => 'Clear configuration';

  @override
  String get cloudClearConfigConfirmTitle => 'Clear cloud configuration';

  @override
  String get cloudClearConfigConfirmMessage => 'Clear this cloud service configuration?\nBacked-up data on the cloud will not be deleted. You can reconfigure and restore anytime.';

  @override
  String get cloudClearConfigDone => 'Configuration cleared';

  @override
  String get cloudPurgeFailed => 'Failed to clear cloud ledgers, please try again later';

  @override
  String get authLogin => 'Login';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authInvalidEmail => 'Please enter a valid email address';

  @override
  String get authErrorInvalidCredentials => 'Email or password is incorrect.';

  @override
  String get authErrorEmailNotConfirmed => 'Email not verified, please complete verification in your email before logging in.';

  @override
  String get authErrorRateLimit => 'Too many attempts, please try again later.';

  @override
  String get authErrorNetworkIssue => 'Network error, please check your connection and try again.';

  @override
  String get authErrorLoginFailed => 'Login failed, please try again later.';

  @override
  String get exportCsvHeaderType => 'Type';

  @override
  String get exportCsvHeaderCategory => 'Category';

  @override
  String get exportCsvHeaderSubCategory => 'Subcategory';

  @override
  String get exportCsvHeaderAmount => 'Amount';

  @override
  String get exportCsvHeaderNote => 'Note';

  @override
  String get exportCsvHeaderTime => 'Time';

  @override
  String get exportSuccessTitle => 'Export Successful';

  @override
  String exportSuccessMessageAndroid(String path) {
    return 'Saved to:\n$path';
  }

  @override
  String get exportFailedTitle => 'Export Failed';

  @override
  String get exportTypeExpense => 'Expense';

  @override
  String get currencyCNY => 'Chinese Yuan';

  @override
  String get currencyUSD => 'US Dollar';

  @override
  String get currencyEUR => 'Euro';

  @override
  String get currencyJPY => 'Japanese Yen';

  @override
  String get currencyHKD => 'Hong Kong Dollar';

  @override
  String get currencyTWD => 'New Taiwan Dollar';

  @override
  String get currencyGBP => 'British Pound';

  @override
  String get currencyAUD => 'Australian Dollar';

  @override
  String get currencyCAD => 'Canadian Dollar';

  @override
  String get currencyKRW => 'South Korean Won';

  @override
  String get currencySGD => 'Singapore Dollar';

  @override
  String get currencyMYR => 'Malaysian Ringgit';

  @override
  String get currencyTHB => 'Thai Baht';

  @override
  String get currencyIDR => 'Indonesian Rupiah';

  @override
  String get currencyPHP => 'Philippine Peso';

  @override
  String get currencyVND => 'Vietnamese Dong';

  @override
  String get currencyINR => 'Indian Rupee';

  @override
  String get currencyRUB => 'Russian Ruble';

  @override
  String get currencyBYN => 'Belarusian Ruble';

  @override
  String get currencyNZD => 'New Zealand Dollar';

  @override
  String get currencyCHF => 'Swiss Franc';

  @override
  String get currencySEK => 'Swedish Krona';

  @override
  String get currencyNOK => 'Norwegian Krone';

  @override
  String get currencyDKK => 'Danish Krone';

  @override
  String get currencyBRL => 'Brazilian Real';

  @override
  String get currencyMXN => 'Mexican Peso';

  @override
  String get currencyTRY => 'Turkish Lira';

  @override
  String get currencyZAR => 'South African Rand';

  @override
  String get currencyAED => 'UAE Dirham';

  @override
  String get currencySAR => 'Saudi Riyal';

  @override
  String get currencyPLN => 'Polish Zloty';

  @override
  String get currencyCZK => 'Czech Koruna';

  @override
  String get currencyHUF => 'Hungarian Forint';

  @override
  String get currencyARS => 'Argentine Peso';

  @override
  String get currencyCLP => 'Chilean Peso';

  @override
  String get currencyCOP => 'Colombian Peso';

  @override
  String get currencyPEN => 'Peruvian Sol';

  @override
  String get currencyEGP => 'Egyptian Pound';

  @override
  String get currencyNGN => 'Nigerian Naira';

  @override
  String get currencyKZT => 'Kazakhstani Tenge';

  @override
  String get currencyUAH => 'Ukrainian Hryvnia';

  @override
  String get currencyILS => 'Israeli New Shekel';

  @override
  String get currencyPKR => 'Pakistani Rupee';

  @override
  String get currencyBDT => 'Bangladeshi Taka';

  @override
  String get currencyLKR => 'Sri Lankan Rupee';

  @override
  String get currencyMMK => 'Myanmar Kyat';

  @override
  String get webdavConfiguredTitle => 'WebDAV Cloud Service Configured';

  @override
  String get webdavConfiguredMessage => 'WebDAV cloud service uses the credentials provided during configuration, no additional login required.';

  @override
  String get recurringTransactionTitle => 'Recurring Bills';

  @override
  String get recurringTransactionAdd => 'Add Recurring Bill';

  @override
  String get recurringTransactionEdit => 'Edit Recurring Bill';

  @override
  String get recurringTransactionFrequency => 'Frequency';

  @override
  String get recurringTransactionDaily => 'Daily';

  @override
  String get recurringTransactionWeekly => 'Weekly';

  @override
  String get recurringTransactionMonthly => 'Monthly';

  @override
  String get recurringTransactionYearly => 'Yearly';

  @override
  String get recurringTransactionInterval => 'Interval';

  @override
  String get recurringTransactionDayOfMonth => 'Day of Month';

  @override
  String get recurringTransactionStartDate => 'Start Date';

  @override
  String get recurringTransactionEndDate => 'End Date';

  @override
  String get recurringTransactionNoEndDate => 'Perpetual';

  @override
  String get recurringTransactionDeleteConfirm => 'Are you sure you want to delete this recurring bill?';

  @override
  String get recurringTransactionEmpty => 'No Recurring Bills';

  @override
  String get recurringTransactionEmptyHint => 'Tap the + button in the top right corner to add';

  @override
  String recurringTransactionEveryNDays(int n) {
    return 'Every $n day(s)';
  }

  @override
  String recurringTransactionEveryNWeeks(int n) {
    return 'Every $n week(s)';
  }

  @override
  String recurringTransactionEveryNMonths(int n) {
    return 'Every $n month(s)';
  }

  @override
  String recurringTransactionEveryNYears(int n) {
    return 'Every $n year(s)';
  }

  @override
  String get recurringTransactionUsageTitle => 'Usage Guide';

  @override
  String get recurringTransactionUsageContent => 'Recurring transactions are automatically scanned and generated when the app cold starts. After setting a date, the system will create corresponding bills on the first startup after that date. For example: if set to Nov 27, bills will be auto-recorded on the first launch after Nov 27.';

  @override
  String get ledgerSelectTitle => 'Select Ledger';

  @override
  String get ledgerSelect => 'Select Ledger';

  @override
  String get syncNotConfiguredMessage => 'Cloud not configured';

  @override
  String get syncNotLoggedInMessage => 'Not logged in';

  @override
  String get syncCloudBackupCorruptedMessage => 'Cloud backup content is corrupted, possibly due to encoding issues from earlier versions. Please click \'Upload Current Ledger to Cloud\' to overwrite and fix.';

  @override
  String get syncNoCloudBackupMessage => 'No cloud backup';

  @override
  String get syncAccessDeniedMessage => '403 Access denied (check storage RLS policy and path)';

  @override
  String get cloudTestConnection => 'Test Connection';

  @override
  String cloudLastTestTime(String time) {
    return 'Last test time: $time';
  }

  @override
  String get cloudLocalStorageTitle => 'Local Storage';

  @override
  String get cloudLocalStorageSubtitle => 'Data is only saved on local device';

  @override
  String get localBackupPageTitle => 'Local Storage';

  @override
  String get localBackupAutoTitle => 'Auto Local Backup';

  @override
  String get localBackupAutoSubtitle => 'Automatically back up a database snapshot on first launch each day';

  @override
  String get storagePermissionTitle => 'Storage Permission Required';

  @override
  String get storagePermissionMessage => 'Android 11+ requires \"All files access\" to save files to the public Download folder (visible in file managers, kept after uninstall).\n\nChoosing \"Continue Anyway\" saves to the app\'s private folder instead — invisible in file managers and deleted on uninstall.';

  @override
  String get storagePermissionGrant => 'Grant Access';

  @override
  String get storagePermissionContinue => 'Continue Anyway';

  @override
  String get exportStorageUnavailable => 'External storage is unavailable. Check device storage status';

  @override
  String get localBackupNowTooltip => 'Back up now';

  @override
  String get localBackupSuccess => 'Backup completed';

  @override
  String get localBackupFailed => 'Backup failed. Check storage space and permissions';

  @override
  String get localBackupListHint => 'Select a backup to restore:';

  @override
  String get localBackupImportFromFile => 'Import from file';

  @override
  String get localBackupImportInvalidFile => 'Please select a .sqlite backup file';

  @override
  String get localBackupListEmpty => 'No backups yet';

  @override
  String get localBackupRestoreTitle => 'Restore Backup';

  @override
  String get localBackupRestoreMessage => 'Restoring will overwrite all current data and cannot be undone. Continue?';

  @override
  String get localBackupRestoreSuccess => 'Restore completed';

  @override
  String get localBackupRestoreFailed => 'Restore failed';

  @override
  String get localBackupEmergencyFailed => 'Could not create a safety copy of current data. Restore cancelled';

  @override
  String get localBackupIntegrityFailed => 'Backup file is corrupted and cannot be restored';

  @override
  String get localBackupVersionTooNew => 'This backup was created by a newer version of the app. Please update the app first';

  @override
  String get localBackupRestoring => 'Restoring…';

  @override
  String get cloudCustomSupabaseTitle => 'Custom Supabase';

  @override
  String get cloudCustomSupabaseSubtitle => 'Click to configure self-hosted Supabase';

  @override
  String get cloudCustomWebdavTitle => 'Custom WebDAV';

  @override
  String get cloudCustomWebdavSubtitle => 'Click to configure Nutstore/Nextcloud etc.';

  @override
  String get cloudCustomS3Title => 'S3 Protocol Storage';

  @override
  String get cloudCustomS3Subtitle => 'AWS S3 / Cloudflare R2 / MinIO';

  @override
  String get cloudSpitoutCloudTitle => 'Spitout Cloud';

  @override
  String get cloudSpitoutCloudSubtitle => 'Self-hosted · Incremental sync · Multi-device';

  @override
  String get cloudConfigureSpitoutCloudTitle => 'Configure Spitout Cloud';

  @override
  String get cloudSpitoutCloudUrlLabel => 'Server URL';

  @override
  String get cloudSpitoutCloudUrlHint => 'https://your-server.com';

  @override
  String get cloudSpitoutCloudEmailLabel => 'Email';

  @override
  String get cloudSpitoutCloudEmailHint => 'your@email.com';

  @override
  String get cloudSpitoutCloudPasswordLabel => 'Password';

  @override
  String get cloudSpitoutCloudPasswordHint => 'Enter password';

  @override
  String get cloudSpitoutCloudLoginSuccess => 'Login successful';

  @override
  String get cloudSpitoutCloudLoginFailed => 'Login failed';

  @override
  String get cloudTabOffline => 'Offline';

  @override
  String get cloudTabBackup => 'Backup';

  @override
  String get cloudTabBackupSubtitle => 'Tap a card to switch backup methods. The first setup requires configuration.';

  @override
  String get cloudTabCloudSync => 'Cloud Sync';

  @override
  String get cloudSupabaseHelpTitle => 'Supabase Setup Guide';

  @override
  String get cloudSupabaseHelpIntro => 'What is Supabase';

  @override
  String get cloudSupabaseHelpIntro1 => 'Supabase is an open-source backend-as-a-service platform';

  @override
  String get cloudSupabaseHelpIntro2 => 'Offers a free tier, sufficient for personal use';

  @override
  String get cloudSupabaseHelpIntro3 => 'You have full control over your data';

  @override
  String get cloudSupabaseHelpSteps => 'Setup Steps';

  @override
  String get cloudSupabaseHelpStep1 => '1. Visit supabase.com to create an account';

  @override
  String get cloudSupabaseHelpStep2 => '2. Create a new project (select free tier)';

  @override
  String get cloudSupabaseHelpStep3 => '3. Go to Project Settings > API';

  @override
  String get cloudSupabaseHelpStep4 => '4. Copy Project URL and anon key';

  @override
  String get cloudSupabaseHelpStep5 => '5. Paste them into the app configuration';

  @override
  String get cloudSupabaseHelpFaq => 'FAQ';

  @override
  String get cloudSupabaseHelpFaq1 => 'Free tier includes 500MB storage';

  @override
  String get cloudSupabaseHelpFaq2 => 'Data is encrypted and secure';

  @override
  String get cloudSupabaseHelpFaq3 => 'Supports multi-device sync';

  @override
  String get cloudSupabaseHelpNote => 'After configuration, you need to register/login to use sync';

  @override
  String get cloudWebdavHelpTitle => 'WebDAV Setup Guide';

  @override
  String get cloudWebdavHelpIntro => 'What is WebDAV';

  @override
  String get cloudWebdavHelpIntro1 => 'WebDAV is a network file protocol';

  @override
  String get cloudWebdavHelpIntro2 => 'Supported by many cloud storage and NAS devices';

  @override
  String get cloudWebdavHelpIntro3 => 'Data is stored on your own server';

  @override
  String get cloudWebdavHelpProviders => 'Supported Providers';

  @override
  String get cloudWebdavHelpProvider1 => '- Nutstore (recommended for China users)';

  @override
  String get cloudWebdavHelpProvider2 => '- Nextcloud / ownCloud';

  @override
  String get cloudWebdavHelpProvider3 => '- Synology / QNAP NAS';

  @override
  String get cloudWebdavHelpProvider4 => '- Other WebDAV-compatible services';

  @override
  String get cloudWebdavHelpSteps => 'Setup Steps (Nutstore example)';

  @override
  String get cloudWebdavHelpStep1 => '1. Login to Nutstore web version';

  @override
  String get cloudWebdavHelpStep2 => '2. Click account name > Account Info';

  @override
  String get cloudWebdavHelpStep3 => '3. Select Security Options tab';

  @override
  String get cloudWebdavHelpStep4 => '4. Add application password (for third-party apps)';

  @override
  String get cloudWebdavHelpStep5 => '5. Copy server address, account, and app password';

  @override
  String get cloudWebdavHelpNote => 'Use an app-specific password instead of your account password';

  @override
  String get cloudS3HelpTitle => 'S3 Storage Setup Guide';

  @override
  String get cloudS3HelpIntro => 'What is S3';

  @override
  String get cloudS3HelpIntro1 => 'S3 is a standard object storage protocol';

  @override
  String get cloudS3HelpIntro2 => 'Supported by many cloud providers';

  @override
  String get cloudS3HelpIntro3 => 'Data is stored on your chosen cloud service';

  @override
  String get cloudS3HelpProviders => 'Supported Providers';

  @override
  String get cloudS3HelpProvider1 => '- AWS S3 (Amazon Web Services)';

  @override
  String get cloudS3HelpProvider2 => '- Cloudflare R2 (free 10GB/month)';

  @override
  String get cloudS3HelpProvider3 => '- Backblaze B2 (free 10GB)';

  @override
  String get cloudS3HelpProvider4 => '- MinIO (self-hosted)';

  @override
  String get cloudS3HelpProvider5 => '- Alibaba Cloud OSS';

  @override
  String get cloudS3HelpProvider6 => '- Tencent Cloud COS';

  @override
  String get cloudS3HelpProvider7 => '- Qiniu Kodo';

  @override
  String get cloudS3HelpSteps => 'Setup Steps (Cloudflare R2 example)';

  @override
  String get cloudS3HelpStep1 => '1. Login to Cloudflare Dashboard';

  @override
  String get cloudS3HelpStep2 => '2. Go to R2 > Create Bucket';

  @override
  String get cloudS3HelpStep3 => '3. Go to R2 > Manage R2 API Tokens';

  @override
  String get cloudS3HelpStep4 => '4. Create API Token and copy credentials';

  @override
  String get cloudS3HelpStep5 => '5. Paste endpoint, access key, secret key, and bucket name';

  @override
  String get cloudS3HelpNote => 'Recommended: Cloudflare R2 offers 10GB free storage without egress fees';

  @override
  String get cloudStatusNotTested => 'Not tested';

  @override
  String get cloudStatusNormal => 'Connection normal';

  @override
  String get cloudStatusFailed => 'Connection failed';

  @override
  String get cloudErrorAuthFailed => 'Authentication failed: Invalid API Key';

  @override
  String cloudErrorServerStatus(String code) {
    return 'Server returned status code $code';
  }

  @override
  String get cloudErrorWebdavNotSupported => 'Server does not support WebDAV protocol';

  @override
  String get cloudErrorAuthFailedCredentials => 'Authentication failed: Incorrect username or password';

  @override
  String get cloudErrorAccessDenied => 'Access denied: Please check permissions';

  @override
  String cloudErrorPathNotFound(String path) {
    return 'Server path not found: $path';
  }

  @override
  String cloudErrorNetwork(String message) {
    return 'Network error: $message';
  }

  @override
  String get cloudTestSuccessMessage => 'Connection normal, configuration valid';

  @override
  String get cloudTestFailedMessage => 'Connection failed';

  @override
  String get cloudSwitchConfirmTitle => 'Switch Cloud Service';

  @override
  String get cloudSwitchConfirmMessage => 'Switching cloud service will log out current account. Confirm switch?';

  @override
  String get cloudSwitchFailedTitle => 'Switch Failed';

  @override
  String get cloudSwitchFailedConfigMissing => 'Please configure this cloud service first';

  @override
  String get cloudConfigInvalidMessage => 'Please fill in complete information';

  @override
  String get cloudSaveFailed => 'Save Failed';

  @override
  String cloudSwitchedTo(String type) {
    return 'Switched to $type';
  }

  @override
  String get cloudConfigureSupabaseTitle => 'Configure Supabase';

  @override
  String get cloudConfigureWebdavTitle => 'Configure WebDAV';

  @override
  String get cloudConfigureS3Title => 'Configure S3';

  @override
  String get cloudSupabaseAnonKeyHintLong => 'Paste complete anon key';

  @override
  String get cloudWebdavRemotePathLabel => 'Remote Path';

  @override
  String get cloudWebdavRemotePathHelperText => 'Remote directory path for data storage';

  @override
  String get welcomeSelectCurrencyTitle => 'Select Accounting Currency';

  @override
  String get welcomeCurrencyDescription => 'Choose your preferred currency, you can change it anytime in settings';

  @override
  String get aiOcrNoLedger => 'Ledger not found';

  @override
  String get cloudTutorialTitle => 'Getting Started';

  @override
  String get cloudTutorialIntro => 'Spitout Cloud is a self-hosted sync server that supports real-time multi-device collaboration. The flow is simple:';

  @override
  String get cloudTutorialStep1Title => 'Step 1: Deploy or join a server';

  @override
  String get cloudTutorialStep1Desc => 'Self-host with one Docker command (see the Docker guide in GitHub README). Or join an existing Spitout Cloud server run by a friend / team.';

  @override
  String get cloudTutorialStep2Title => 'Step 2: Get an account';

  @override
  String get cloudTutorialStep2Desc => 'Spitout Cloud does NOT offer self-registration (to prevent abuse on public servers). If you self-host: the first Docker boot prints a random admin email + password to the logs — use that. Joining someone else\'s server: ask the admin to create an account for you in Web → Users.';

  @override
  String get cloudTutorialStep3Title => 'Step 3: Login + enable sync';

  @override
  String get cloudTutorialStep3Desc => 'In the app, pick Spitout Cloud, enter the server URL and the account you got in step 2. First login uploads your entire local ledger; every subsequent edit is pushed in real time.';

  @override
  String get cloudTutorialStep4Title => 'Step 4: Login from other devices';

  @override
  String get cloudTutorialStep4Desc => 'Phone / tablet / Web — same account, instant shared state. Edits propagate within seconds.';

  @override
  String get cloudTutorialTipTitle => 'Tip';

  @override
  String get cloudTutorialTipDesc => 'The Web UI lives at the server URL. Open it in a browser to manage ledgers, members, and view logs.';

  @override
  String get cloudTutorialFeaturesTitle => 'Features';

  @override
  String get cloudTutorialFeature1 => '📱 Real-time multi-device: phone A + phone B + Web on one account, sub-second sync';

  @override
  String get cloudTutorialFeature2 => '🌐 Web UI included: one Docker image ships server + Web, browser ready';

  @override
  String get cloudTutorialFeature3 => '👥 Multi-user isolation: multiple users on one server, data fully separated';

  @override
  String get cloudTutorialFeature4 => '🤝 Shared ledgers: invite family / team into one book with seconds-level sync';

  @override
  String get cloudTutorialGotIt => 'Got it';

  @override
  String get cloudSyncHint => 'Downloads automatically compare differences for selective preview. Not real-time — avoid editing the same ledger on multiple devices simultaneously. Sync scope covers ledger data (including associated accounts and categories).';

  @override
  String get appearanceSettings => 'Preferences';

  @override
  String get appearanceSettingsDesc => 'Theme, font, language, app lock, etc.';

  @override
  String get appearanceSettingsPageTitle => 'Preferences';

  @override
  String get appearanceSettingsPageSubtitle => 'Appearance, display, security and other app preferences';

  @override
  String get logCenterTitle => 'Log Center';

  @override
  String get logCenterSubtitle => 'View app runtime logs';

  @override
  String get logCenterSearchHint => 'Search log content or tags...';

  @override
  String get logCenterFilterLevel => 'Log Level';

  @override
  String get logCenterFilterPlatform => 'Platform';

  @override
  String get logCenterTotal => 'Total';

  @override
  String get logCenterFiltered => 'Filtered';

  @override
  String get logCenterEmpty => 'No logs';

  @override
  String get logCenterExport => 'Export';

  @override
  String get logCenterClear => 'Clear';

  @override
  String get logCenterExportFailed => 'Export failed';

  @override
  String get logCenterClearConfirmTitle => 'Clear Logs';

  @override
  String get logCenterClearConfirmMessage => 'Are you sure you want to clear all logs? This action cannot be undone.';

  @override
  String get logCenterCleared => 'Logs cleared';

  @override
  String get logCenterCopied => 'Copied to clipboard';

  @override
  String get configImportExportTitle => 'Config Import/Export';

  @override
  String get configImportExportSubtitle => 'Backup and restore app configurations';

  @override
  String get configImportExportInfoTitle => 'Feature Description';

  @override
  String get configImportExportInfoMessage => 'Back up and restore app configurations for cross-device migration or settings recovery. Exports as YAML format, viewable and editable.\n\nOnly includes app configurations, not transaction records (use Detail Import/Export for transaction data).';

  @override
  String get configImportExportWarning => 'The config file contains sensitive information such as cloud service keys and passwords. Keep it safe. Importing overwrites existing configurations with the same name—back up first.';

  @override
  String get configExportTitle => 'Export Config';

  @override
  String get configExportSubtitle => 'Export current config to YAML file';

  @override
  String get configExportShareSubject => 'Spitout Config File';

  @override
  String get configExportSuccess => 'Config exported successfully';

  @override
  String get configExportFailed => 'Config export failed';

  @override
  String get configImportTitle => 'Import Config';

  @override
  String get configImportSubtitle => 'Restore config from YAML file';

  @override
  String get configImportNoFilePath => 'No file selected';

  @override
  String get configImportConfirmTitle => 'Confirm Import';

  @override
  String get configImportSuccess => 'Config imported successfully';

  @override
  String get configImportFailed => 'Config import failed';

  @override
  String get configImportRestartTitle => 'Restart Required';

  @override
  String get configImportRestartMessage => 'Config has been imported. Some settings will take effect after restarting the app.';

  @override
  String get configImportOverwriteWarning => 'Importing will overwrite existing configurations. It is recommended to back up your current config first.';

  @override
  String get configImportExportIncludesTitle => 'Included Configurations';

  @override
  String configExportSavedTo(String path) {
    return 'Saved to: $path';
  }

  @override
  String get configExportViewContent => 'View Content';

  @override
  String get configExportCopyContent => 'Copy Content';

  @override
  String get configExportContentCopied => 'Copied to clipboard';

  @override
  String get configExportReadFileFailed => 'Failed to read file';

  @override
  String get configIncludeLedgers => 'Ledgers';

  @override
  String get configIncludeSupabase => 'Supabase cloud service config';

  @override
  String get configIncludeWebdav => 'WebDAV cloud service config';

  @override
  String get configIncludeS3 => 'S3 cloud service config';

  @override
  String get configIncludeSpitoutCloud => 'Spitout Cloud service config';

  @override
  String get configIncludeAppSettings => 'App settings (reminder, language, appearance, font, sync, etc.)';

  @override
  String get configIncludeRecurringTransactions => 'Recurring transactions';

  @override
  String get configIncludeCategories => 'Categories';

  @override
  String get configIncludeOtherSettings => 'Other Settings';

  @override
  String get configIncludeOtherSettingsSubtitle => 'Including cloud service configs and app settings';

  @override
  String get configExportSelectTitle => 'Select Export Content';

  @override
  String get configExportPreviewTitle => 'Export Preview';

  @override
  String get configExportConfirmTitle => 'Confirm Export';

  @override
  String get configImportSelectTitle => 'Select Import Content';

  @override
  String get configImportPreviewTitle => 'Import Preview';

  @override
  String get ledgersConflictTitle => 'Sync Conflict';

  @override
  String get ledgersConflictMessage => 'Local and cloud ledger data are inconsistent, please choose an action:';

  @override
  String ledgersConflictLocalInfo(int count) {
    return 'Local: $count transactions';
  }

  @override
  String ledgersConflictRemoteInfo(int count) {
    return 'Cloud: $count transactions';
  }

  @override
  String ledgersConflictRemoteUpdated(String time) {
    return 'Cloud updated: $time';
  }

  @override
  String ledgersConflictLocalFingerprint(String fp) {
    return 'Local fingerprint: $fp';
  }

  @override
  String ledgersConflictRemoteFingerprint(String fp) {
    return 'Cloud fingerprint: $fp';
  }

  @override
  String get ledgersConflictUpload => 'Upload to Cloud';

  @override
  String get ledgersConflictDownload => 'Download to Local';

  @override
  String get ledgersConflictUploading => 'Uploading...';

  @override
  String get ledgersConflictDownloading => 'Downloading...';

  @override
  String get ledgersConflictUploadSuccess => 'Upload successful';

  @override
  String ledgersConflictDownloadSuccess(int inserted) {
    return 'Download successful, merged $inserted transactions';
  }

  @override
  String get welcomeExistingUserTitle => 'Existing User?';

  @override
  String get welcomeExistingUserButton => 'Import Config';

  @override
  String get welcomeImportingConfig => 'Importing configuration...';

  @override
  String get welcomeImportSuccess => 'Configuration imported successfully';

  @override
  String welcomeImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get welcomeImportNoFile => 'No file selected';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get calendarToday => 'Back to Today';

  @override
  String get calendarNoTransactions => 'No transactions';

  @override
  String get calendarAddTransaction => 'Add entry on this day';

  @override
  String get commonUncategorized => 'Uncategorized';

  @override
  String get syncPreviewTitle => 'Sync Preview';

  @override
  String get syncPreviewSelectAll => 'Select All';

  @override
  String get syncPreviewDeselectAll => 'Deselect All';

  @override
  String get syncPreviewAdded => 'Added';

  @override
  String get syncPreviewModified => 'Modified';

  @override
  String get syncPreviewDeleted => 'Deleted';

  @override
  String syncPreviewAddedCount(int count) {
    return '$count added';
  }

  @override
  String syncPreviewModifiedCount(int count) {
    return '$count modified';
  }

  @override
  String syncPreviewDeletedCount(int count) {
    return '$count deleted';
  }

  @override
  String syncPreviewApply(int count) {
    return 'Apply $count items';
  }

  @override
  String get syncPreviewEmpty => 'Cloud data matches local, no sync needed';

  @override
  String get syncPreviewOldFormat => 'Old cloud format, full replace required';

  @override
  String get syncPreviewOldFormatMessage => 'Cloud data does not contain sync IDs. Local data will be cleared and re-imported from cloud.';

  @override
  String syncPreviewApplied(int count) {
    return 'Applied $count changes';
  }

  @override
  String get cloudSyncGuideTitle => 'Cloud Sync Guide';

  @override
  String get cloudSyncGuideGotIt => 'Got it';

  @override
  String get cloudSyncGuideHowItWorks => 'How it works';

  @override
  String get cloudSyncGuideHowItem1 => 'Upload: packages all current ledger data and uploads to cloud, replacing old cloud data';

  @override
  String get cloudSyncGuideHowItem2 => 'Download: fetches cloud data and compares with local records one by one — you choose which changes to apply';

  @override
  String get cloudSyncGuideHowItem3 => 'The cloud always stores only the last uploaded snapshot, no version history';

  @override
  String get cloudSyncGuideCorrect => 'Correct usage';

  @override
  String get cloudSyncGuideCorrectItem1 => 'Edit on one device at a time, upload when done';

  @override
  String get cloudSyncGuideCorrectItem2 => 'Download on the new device before starting to edit';

  @override
  String get cloudSyncGuideCorrectItem3 => 'Review the preview carefully before applying changes';

  @override
  String get cloudSyncGuideCorrectItem4 => 'Follow the pattern: edit → upload → switch device → download → edit';

  @override
  String get cloudSyncGuideWrong => 'What to avoid';

  @override
  String get cloudSyncGuideWrongItem1 => 'Editing the same ledger on two devices simultaneously — the later upload overwrites the earlier one';

  @override
  String get cloudSyncGuideWrongItem2 => 'Downloading immediately after upload — cloud services may have seconds to minutes of sync delay, wait a moment';

  @override
  String get cloudSyncGuideWrongItem3 => 'Going long periods without syncing then downloading many changes at once — easy to miss important differences';

  @override
  String get cloudSyncGuideLimitations => 'Known limitations';

  @override
  String get cloudSyncGuideLimitItem1 => 'Not real-time: requires manually tapping upload and download';

  @override
  String get cloudSyncGuideLimitItem2 => 'No conflict merging: does not auto-merge edits from both sides — last upload wins';

  @override
  String get cloudSyncGuideLimitItem3 => 'Cloud service delay: uploaded files may take seconds to minutes before other devices can read them, depending on your cloud provider';

  @override
  String get appLockTitle => 'Lock App';

  @override
  String get appLockDesc => 'PIN & biometric to protect privacy';

  @override
  String get appLockEnable => 'Enable App Lock';

  @override
  String get appLockEnableDesc => 'Require authentication on launch and resume';

  @override
  String get appLockSetPin => 'Set PIN';

  @override
  String get appLockChangePin => 'Change PIN';

  @override
  String get appLockVerifyPin => 'Verify PIN';

  @override
  String get appLockVerifyCurrentPin => 'Enter current PIN';

  @override
  String get appLockSetNewPin => 'Set new PIN';

  @override
  String get appLockConfirmPin => 'Confirm PIN';

  @override
  String get appLockEnterPin => 'Enter PIN';

  @override
  String get appLockPinSetSuccess => 'PIN set successfully';

  @override
  String get appLockDisabled => 'App Lock disabled';

  @override
  String get appLockBiometric => 'Biometric Unlock';

  @override
  String get appLockBiometricDesc => 'Use Face ID or fingerprint to unlock';

  @override
  String get appLockBiometricReason => 'Verify identity to unlock Spitout';

  @override
  String get appLockTimeout => 'Auto-lock Timeout';

  @override
  String get appLockTimeoutImmediate => 'Immediately';

  @override
  String get appLockTimeout1Min => 'After 1 minute';

  @override
  String get appLockTimeout5Min => 'After 5 minutes';

  @override
  String get appLockTimeout15Min => 'After 15 minutes';

  @override
  String dayOfMonth(int day) {
    return '${day}th of each month';
  }

  @override
  String get syncHealthTitle => 'Sync status';

  @override
  String get cloudSyncHelpTitle => 'How sync works · Why it sometimes stalls';

  @override
  String get cloudSyncHelpModesTitle => 'Three sync modes';

  @override
  String get cloudSyncHelpModesBody => '• Incremental (automatic, everyday): after you add or edit an entry, only that change is uploaded/downloaded automatically — fast, no manual action. This is what runs all the time.\n• Full upload: the first time you enable cloud sync, or when the cloud has no data for this ledger yet, all local data is pushed to the cloud at once.\n• Full download: on a new device, after a reinstall, or when local is empty, all data is pulled down from the cloud.';

  @override
  String get cloudSyncHelpWhenFullTitle => 'When does a full sync happen?';

  @override
  String get cloudSyncHelpWhenFullBody => 'A full sync only triggers automatically when one side is empty (first enabling cloud sync / new device / reinstall / after clearing local or cloud data). As long as both sides have data, sync stays incremental and never restarts on its own. To force a full re-sync, you must first clear the data on the corresponding side.';

  @override
  String get cloudSyncHelpStuckTitle => 'Why sync sometimes stalls';

  @override
  String get cloudSyncHelpStuckBody => '• Full upload/download does NOT support resume: if the network drops or the app is killed in the background, it starts over from scratch instead of continuing. For large data, use a stable network (Wi-Fi recommended) and let it finish without switching away.\n• Incremental sync is resume-safe and unaffected in everyday use.';

  @override
  String get cloudSyncHelpTroubleshootTitle => 'Troubleshooting';

  @override
  String get cloudSyncHelpTroubleshootBody => '• First, pull down on this page to run a Deep Check and compare local vs cloud.\n• Still stuck? Open the Log Center to view sync logs (including failure reasons) for reporting.';

  @override
  String get cloudSyncHelpOpenLogCenter => 'Open Log Center';

  @override
  String syncHealthCheckFailed(String msg) {
    return 'Check failed: $msg';
  }

  @override
  String get syncHealthRecovering => 'Restoring sign-in status…';

  @override
  String get syncHealthNeedsLogin => 'Not signed in or session expired. Please sign in to cloud sync again.';

  @override
  String get syncHealthHasDiff => 'Diff detected; auto-synced';

  @override
  String get cloudSyncHealFailed => 'Auto-restore failed; please restore from cloud manually';

  @override
  String get syncHealthInSync => 'Local matches cloud';

  @override
  String get syncHealthGroupCurrentLedger => 'Current ledger';

  @override
  String get syncHealthGroupAll => 'All ledgers';

  @override
  String get syncHealthRowTx => 'Transactions';

  @override
  String get syncHealthRowCategory => 'Categories';

  @override
  String get syncHealthRowUnpushed => 'Unpushed changes';

  @override
  String syncHealthValue(int local, int remote) {
    return 'Local $local · Remote $remote';
  }

  @override
  String syncHealthValueRemoteMissing(int local) {
    return 'Local $local · Remote —';
  }

  @override
  String get twofaChallengeTitle => 'Two-factor authentication';

  @override
  String get twofaMethodTotp => 'Code';

  @override
  String get twofaMethodRecovery => 'Recovery code';

  @override
  String get twofaTotpInputPlaceholder => '6-digit code';

  @override
  String get twofaRecoveryInputPlaceholder => 'Recovery code';

  @override
  String get twofaVerifyButton => 'Verify';

  @override
  String get twofaStatusTitle => 'Two-factor authentication';

  @override
  String get twofaStatusEnabled => 'Enabled ✓';

  @override
  String get twofaStatusDisabled => 'Not enabled';

  @override
  String twofaStatusEnabledAt(String date) {
    return 'Enabled on $date';
  }

  @override
  String get sharedRoleOwner => 'Owner';

  @override
  String get sharedRoleEditor => 'Editor';

  @override
  String get commonCopied => 'Copied';

  @override
  String get commonRemove => 'Remove';

  @override
  String get sharedJoinPageTitle => 'Join shared ledger';

  @override
  String get sharedJoinPageSubtitle => 'Enter an invite code or tap a shared link';

  @override
  String get sharedJoinEnterCode => 'Enter invite code';

  @override
  String get sharedJoinEnterCodeHint => '6 uppercase letters / digits. You can also tap a share link to skip this step.';

  @override
  String get sharedJoinPreviewButton => 'Verify code';

  @override
  String get sharedJoinAcceptButton => 'Join';

  @override
  String sharedJoinInvitedBy(String name) {
    return '$name invited you to join';
  }

  @override
  String sharedJoinRoleLine(String role) {
    return 'Role: $role';
  }

  @override
  String sharedJoinExpiresInMinutes(int n) {
    return 'Expires in $n min';
  }

  @override
  String sharedJoinExpiresInHours(int n) {
    return 'Expires in ${n}h';
  }

  @override
  String sharedJoinExpiresInDays(int n) {
    return 'Expires in ${n}d';
  }

  @override
  String sharedJoinSuccess(String name) {
    return 'Joined \"$name\"';
  }

  @override
  String get sharedJoinCodeFormatError => 'Invite code must be 6 letters/digits.';

  @override
  String get sharedJoinInvalidOrExpired => 'Invite code is invalid or expired. Ask the inviter for a new one.';

  @override
  String get sharedJoinAlreadyMember => 'You are already a member of this ledger.';

  @override
  String get sharedJoinMemberLimit => 'This ledger has reached its member limit. Ask the owner.';

  @override
  String get sharedInviteFormRole => 'Role';

  @override
  String get sharedInviteFormExpiry => 'Valid for';

  @override
  String sharedInviteExpiryHours(int n) {
    return '$n h';
  }

  @override
  String sharedInviteExpiryDays(int n) {
    return '$n day';
  }

  @override
  String get sharedInviteGenerate => 'Generate invite code';

  @override
  String get sharedInviteGenerateAnother => 'Generate another code';

  @override
  String get sharedInviteCopyCode => 'Copy code';

  @override
  String get sharedInviteCopyLink => 'Copy link';

  @override
  String get sharedInviteShareLink => 'Share link';

  @override
  String sharedInviteExpiresAt(String dt) {
    return 'Expires at $dt';
  }

  @override
  String get sharedInviteWarning => '⚠️ Don\'t post invite codes to public groups / social. Anyone with the code can join. Revoke and regenerate from Members if leaked.';

  @override
  String get sharedInviteInstruction => 'Send the code or short link to the other person. After they install Spitout, they can tap the link or enter the code from \"Me → Join shared ledger\".';

  @override
  String sharedInviteShareText(String ledger, String code, String url) {
    return 'I\'m inviting you to Spitout shared ledger \"$ledger\".\n\nCode: $code\nLink: $url\n\nTap the link, or open Spitout → Me → Join shared ledger and enter this code.';
  }

  @override
  String get sharedMembersPageTitle => 'Members';

  @override
  String get sharedMembersYou => 'you';

  @override
  String get sharedMembersInviteCta => 'Invite new member';

  @override
  String get ledgersLeaveAndDelete => 'Leave and Delete';

  @override
  String get ledgersLeaveAndDeleteConfirm => 'Leave and Delete Ledger';

  @override
  String ledgersLeaveAndDeleteMessage(String name) {
    return 'Leave and delete the shared ledger \"$name\"?\\nAfter leaving, the cloud removes your membership and all local data is cleared. You won\'t be able to access its transactions anymore.';
  }

  @override
  String get ledgersLeaveAndDeleteSuccess => 'Left and deleted the ledger';

  @override
  String get ledgersDeleteShared => 'Delete Shared Ledger';

  @override
  String get ledgersDeleteSharedConfirm => 'Delete Shared Ledger';

  @override
  String ledgersDeleteSharedMessage(String name) {
    return 'Delete the shared ledger \"$name\"?\\nThis also removes all collaborators and clears their local data. This cannot be undone.';
  }

  @override
  String get ledgersDeleteSharedSuccess => 'Shared ledger deleted';

  @override
  String get sharedMembersRemoveTitle => 'Remove member';

  @override
  String get sharedMembersRemoveCta => 'Remove this member';

  @override
  String sharedMembersRemoveConfirm(String name) {
    return 'Remove $name? They will immediately lose access to this ledger.';
  }

  @override
  String get sharedMembersRemoved => 'Member removed';

  @override
  String get sharedMembersSyncPending => 'For a newly created ledger, select it on the ledger management page first, then re-enter this page to invite members.';

  @override
  String sharedTxCreatedBy(String name) {
    return 'Created by $name';
  }

  @override
  String sharedTxEditedBy(String name) {
    return 'Last edited by $name';
  }

  @override
  String sharedTxCreatedAndEditedBy(String name) {
    return 'Created and edited by $name';
  }

  @override
  String get sharedRequiresCloudSync => 'Please enable cloud sync first';

  @override
  String get sharedMembersStatsTitle => 'Member expenses';

  @override
  String get sharedMembersStatsEmpty => 'No transactions yet';

  @override
  String sharedMembersStatsTxCount(int count) {
    return '$count tx';
  }

  @override
  String get maintenanceOrphanCleanupTitle => 'Data Cleanup';

  @override
  String get maintenanceOrphanCleanupSubtitle => 'Detect and clean local orphan data';

  @override
  String get maintenanceOrphanRescan => 'Rescan';

  @override
  String get maintenanceOrphanEmpty => 'Local data is clean, no orphan data found';

  @override
  String get maintenanceOrphanGroupDb => 'Database orphans';

  @override
  String get maintenanceOrphanGroupSync => 'Sync state orphans';

  @override
  String maintenanceOrphanSummary(int count) {
    return 'Found $count issue(s)';
  }

  @override
  String get maintenanceOrphanSelectAll => 'Select all';

  @override
  String get maintenanceOrphanDeselectAll => 'Deselect all';

  @override
  String get maintenanceOrphanDeleteOne => 'Delete this';

  @override
  String maintenanceOrphanSelectedHint(int count) {
    return '$count selected';
  }

  @override
  String get maintenanceOrphanCleanSelected => 'Clean selected';

  @override
  String get maintenanceOrphanConfirmTitle => 'Confirm cleanup';

  @override
  String maintenanceOrphanConfirmDeleteOne(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String maintenanceOrphanConfirmDeleteBatch(int count) {
    return 'Delete the $count selected item(s)? This cannot be undone.';
  }

  @override
  String maintenanceOrphanCleanSuccess(int count) {
    return 'Cleaned $count item(s)';
  }

  @override
  String maintenanceOrphanCleanPartial(int ok, int fail) {
    return 'Cleaned $ok item(s), $fail failed';
  }

  @override
  String maintenanceOrphanDeletedLedgerGroup(int ledgerId, int count) {
    return 'Deleted ledger #$ledgerId ($count items)';
  }

  @override
  String get maintenanceOrphanMoveSingle => 'Move to ledger';

  @override
  String get maintenanceOrphanMoveToLedger => 'Move to ledger';

  @override
  String maintenanceOrphanMoveToLedgerSuccess(int count) {
    return 'Moved $count item(s) to ledger';
  }

  @override
  String get exchangeRatePageTitle => 'Exchange Rates';

  @override
  String get exchangeRateEntrySubtitle => 'Auto-fetched rates with manual override';

  @override
  String get rateSourceAuto => 'Auto';

  @override
  String get rateSourceManual => 'Manual';

  @override
  String rateUpdatedAt(String date) {
    return 'Updated $date';
  }

  @override
  String get rateNotFetched => 'Not fetched';

  @override
  String get rateEditTitle => 'Edit Rate';

  @override
  String rateInverseHint(String base, String rate, String quote) {
    return 'Inverse: 1 $base ≈ $rate $quote';
  }

  @override
  String get rateResetToAuto => 'Reset to auto';

  @override
  String get rateRefreshSuccess => 'Rates updated';

  @override
  String get rateRefreshFailed => 'Fetch failed, you can set rates manually';

  @override
  String get rateDisclaimer => 'Source: open exchange-rate data, updated daily. Conversion is for reference only and may differ from bank rates.';

  @override
  String get txFlagExcludedTag => 'Excluded';

  @override
  String get txRateLabel => 'Rate';

  @override
  String get txRateMissingHint => 'Please enter the rate for this entry before saving';

  @override
  String get ledgerBaseCurrencyLabel => 'Primary currency';

  @override
  String statsConvertedFootnote(Object currency) {
    return 'Includes foreign currency, converted to $currency at entry-time rates';
  }

  @override
  String get ledgerCurrencyChangeRecalcHint => 'Changing the base currency will reconvert all history at current rates';

  @override
  String get ledgerCurrencyChangeRecalcWarning => 'Converted amounts of all transactions in this ledger will be recalculated at the latest rates and overwritten; switching away and back cannot restore the original values';

  @override
  String get recalcForeignTxBanner => 'Unconverted foreign-currency transactions detected in this ledger';

  @override
  String get recalcForeignTxAction => 'Reconvert at current rates';

  @override
  String recalcForeignTxDone(Object count) {
    return 'Reconverted $count foreign-currency transactions';
  }

  @override
  String get txCurrencyPickerTitle => 'Select currency';

  @override
  String get txAddEntryTitle => 'New Entry';

  @override
  String get txDeleteLongPress => 'Long press to clear';

  @override
  String get txSelectDateTimeTitle => 'Select date & time';

  @override
  String get txSelectDateTimeHint => 'Swipe up or down to pick a value';

  @override
  String get txEditCategory => 'Edit categories';

  @override
  String get txEditCategoryReadOnly => 'Edit categories (read-only in shared ledger)';

  @override
  String get txLedgerBaseCurrency => 'Ledger base currency';

  @override
  String recalcSyncCountHint(Object count) {
    return '$count transactions will be reconverted and synced';
  }

  @override
  String get analyticsLoadFailed => 'Failed to load data. Please check your network.';

  @override
  String get analyticsRetry => 'Retry';

  @override
  String get exportCsvHeaderCurrency => 'Currency';

  @override
  String get importFieldCurrency => 'Currency';

  @override
  String get currencyMOP => 'Macau Pataca';

  @override
  String get currencyMNT => 'Mongolian Tughrik';

  @override
  String get currencyKPW => 'North Korean Won';

  @override
  String get currencyKHR => 'Cambodian Riel';

  @override
  String get currencyLAK => 'Lao Kip';

  @override
  String get currencyBND => 'Bruneian Dollar';

  @override
  String get currencyNPR => 'Nepalese Rupee';

  @override
  String get currencyBTN => 'Bhutanese Ngultrum';

  @override
  String get currencyMVR => 'Maldivian Rufiyaa';

  @override
  String get currencyAFN => 'Afghan Afghani';

  @override
  String get currencyUZS => 'Uzbekistani Som';

  @override
  String get currencyTJS => 'Tajikistani Somoni';

  @override
  String get currencyTMT => 'Turkmenistani Manat';

  @override
  String get currencyKGS => 'Kyrgyzstani Som';

  @override
  String get currencyQAR => 'Qatari Riyal';

  @override
  String get currencyKWD => 'Kuwaiti Dinar';

  @override
  String get currencyBHD => 'Bahraini Dinar';

  @override
  String get currencyOMR => 'Omani Rial';

  @override
  String get currencyJOD => 'Jordanian Dinar';

  @override
  String get currencyLBP => 'Lebanese Pound';

  @override
  String get currencyIQD => 'Iraqi Dinar';

  @override
  String get currencyIRR => 'Iranian Rial';

  @override
  String get currencyYER => 'Yemeni Rial';

  @override
  String get currencySYP => 'Syrian Pound';

  @override
  String get currencyGEL => 'Georgian Lari';

  @override
  String get currencyAMD => 'Armenian Dram';

  @override
  String get currencyAZN => 'Azerbaijan Manat';

  @override
  String get currencyRON => 'Romanian Leu';

  @override
  String get currencyBGN => 'Bulgarian Lev';

  @override
  String get currencyRSD => 'Serbian Dinar';

  @override
  String get currencyISK => 'Icelandic Krona';

  @override
  String get currencyMDL => 'Moldovan Leu';

  @override
  String get currencyALL => 'Albanian Lek';

  @override
  String get currencyMKD => 'Macedonian Denar';

  @override
  String get currencyBAM => 'Bosnian Convertible Mark';

  @override
  String get currencyGIP => 'Gibraltar Pound';

  @override
  String get currencyGTQ => 'Guatemalan Quetzal';

  @override
  String get currencyHNL => 'Honduran Lempira';

  @override
  String get currencyNIO => 'Nicaraguan Cordoba';

  @override
  String get currencyCRC => 'Costa Rican Colon';

  @override
  String get currencyPAB => 'Panamanian Balboa';

  @override
  String get currencyDOP => 'Dominican Peso';

  @override
  String get currencyCUP => 'Cuban Peso';

  @override
  String get currencyJMD => 'Jamaican Dollar';

  @override
  String get currencyTTD => 'Trinidadian Dollar';

  @override
  String get currencyBSD => 'Bahamian Dollar';

  @override
  String get currencyBBD => 'Barbadian or Bajan Dollar';

  @override
  String get currencyBZD => 'Belizean Dollar';

  @override
  String get currencyHTG => 'Haitian Gourde';

  @override
  String get currencyKYD => 'Caymanian Dollar';

  @override
  String get currencyAWG => 'Aruban or Dutch Guilder';

  @override
  String get currencyBMD => 'Bermudian Dollar';

  @override
  String get currencyUYU => 'Uruguayan Peso';

  @override
  String get currencyPYG => 'Paraguayan Guarani';

  @override
  String get currencyBOB => 'Bolivian Bolíviano';

  @override
  String get currencyVES => 'Venezuelan Bolívar';

  @override
  String get currencyGYD => 'Guyanese Dollar';

  @override
  String get currencySRD => 'Surinamese Dollar';

  @override
  String get currencyFJD => 'Fijian Dollar';

  @override
  String get currencyPGK => 'Papua New Guinean Kina';

  @override
  String get currencySBD => 'Solomon Islander Dollar';

  @override
  String get currencyTOP => 'Tongan Pa\'anga';

  @override
  String get currencyVUV => 'Ni-Vanuatu Vatu';

  @override
  String get currencyWST => 'Samoan Tala';

  @override
  String get currencyKES => 'Kenyan Shilling';

  @override
  String get currencyGHS => 'Ghanaian Cedi';

  @override
  String get currencyMAD => 'Moroccan Dirham';

  @override
  String get currencyDZD => 'Algerian Dinar';

  @override
  String get currencyTND => 'Tunisian Dinar';

  @override
  String get currencyLYD => 'Libyan Dinar';

  @override
  String get currencyETB => 'Ethiopian Birr';

  @override
  String get currencyUGX => 'Ugandan Shilling';

  @override
  String get currencyTZS => 'Tanzanian Shilling';

  @override
  String get currencyRWF => 'Rwandan Franc';

  @override
  String get currencyMUR => 'Mauritian Rupee';

  @override
  String get currencyBWP => 'Botswana Pula';

  @override
  String get currencyNAD => 'Namibian Dollar';

  @override
  String get currencyZMW => 'Zambian Kwacha';

  @override
  String get currencyMWK => 'Malawian Kwacha';

  @override
  String get currencyMZN => 'Mozambican Metical';

  @override
  String get currencyAOA => 'Angolan Kwanza';

  @override
  String get currencyCDF => 'Congolese Franc';

  @override
  String get currencyGMD => 'Gambian Dalasi';

  @override
  String get currencyGNF => 'Guinean Franc';

  @override
  String get currencyLRD => 'Liberian Dollar';

  @override
  String get currencySLE => 'Sierra Leonean Leone';

  @override
  String get currencySDG => 'Sudanese Pound';

  @override
  String get currencySSP => 'South Sudanese Pound';

  @override
  String get currencySOS => 'Somali Shilling';

  @override
  String get currencyDJF => 'Djiboutian Franc';

  @override
  String get currencyERN => 'Eritrean Nakfa';

  @override
  String get currencyBIF => 'Burundian Franc';

  @override
  String get currencyCVE => 'Cape Verdean Escudo';

  @override
  String get currencySTN => 'Sao Tomean Dobra';

  @override
  String get currencySCR => 'Seychellois Rupee';

  @override
  String get currencyKMF => 'Comorian Franc';

  @override
  String get currencyLSL => 'Basotho Loti';

  @override
  String get currencySZL => 'Swazi Lilangeni';

  @override
  String get currencyMGA => 'Malagasy Ariary';

  @override
  String get currencyMRU => 'Mauritanian Ouguiya';

  @override
  String get detailImportExportTitle => 'Detail Import/Export';

  @override
  String get detailImportExportSubtitle => 'Expense CSV file';

  @override
  String get detailImportExportImportTitle => 'Import Details';

  @override
  String get detailImportExportImportSubtitle => 'Supports CSV/TSV/XLSX and Alipay/WeChat bills';

  @override
  String get detailImportExportExportTitle => 'Export Details';

  @override
  String get detailImportExportExportSubtitle => 'Export ledger details to a CSV file';

  @override
  String get detailImportExportImportPoint1 => 'Supports generic CSV, Alipay and WeChat bills in CSV/TSV/XLSX format';

  @override
  String get detailImportExportImportPoint2 => 'The difference lies only in file structure: generic CSV has a clean header row, while Alipay/WeChat bills contain descriptive preamble lines that the app skips automatically to locate the header';

  @override
  String get detailImportExportImportPoint3 => 'All three are recognized via the same column mapping (date, type, amount, currency, category, subcategory, note), with an identical import flow';

  @override
  String get detailImportExportExportPoint1 => 'Exports the selected ledger\'s transactions to a CSV file with UTF-8 BOM encoding, which Excel can open directly';

  @override
  String get detailImportExportExportPoint2 => 'Named spitout_timestamp.csv and saved to the Download/Spitout directory by default';

  @override
  String get detailImportExportExportPoint3 => 'Fields included:';

  @override
  String get detailExportLedgerLabel => 'Export Ledger';

  @override
  String get detailExportSelectAllLabel => 'All Data';

  @override
  String get detailExportSelectAllSubtitle => 'Export all data under the selected ledger';

  @override
  String get detailExportStartDate => 'Start Date';

  @override
  String get detailExportEndDate => 'End Date';

  @override
  String get detailExportDateInvalid => 'Start date cannot be later than end date';

  @override
  String get detailExportAction => 'Export';

  @override
  String exchangeRateCurrentLedger(Object name) {
    return 'Current ledger: $name';
  }

  @override
  String get exchangeRateInfoTitle => 'About Primary Currency';

  @override
  String get exchangeRateInfoMessage => 'The primary currency is the base currency of the current ledger: foreign-currency transactions in this ledger are converted into it at exchange rates, so totals can be compared directly in statistics and asset overviews. Each ledger has its own primary currency and you can switch it at any time; switching recalculates converted amounts for all transactions in this ledger at the latest rates.\n\nRates are fetched automatically from public data sources on a daily basis. You can also tap \"Edit\" for any currency in the list below to set a manual rate — it overrides the automatic data and takes effect immediately.';

  @override
  String get rateEditLabel => 'Edit';

  @override
  String get rateInvalidInput => 'Please enter a valid rate (a number greater than 0)';

  @override
  String get currencyManageTitle => 'Manage Displayed Currencies';

  @override
  String get currencyManageEntry => 'Currency Management';

  @override
  String currencyManageCount(Object count) {
    return '$count currencies selected';
  }

  @override
  String get currencyManageBaseLocked => 'Ledger base currency (cannot be hidden)';

  @override
  String get currencyManageHint => 'Hiding a currency does not affect existing transactions; you can re-enable it here at any time.';

  @override
  String get detailImportExportMigrateTitle => 'Ledger Data Migration';

  @override
  String get detailImportExportMigrateTip => 'Export the current ledger\'s data to a CSV file, then switch to the target ledger and import that file to migrate your data between ledgers seamlessly.';

  @override
  String get mineCheckUpdate => 'Check for Updates';

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String get updateAvailableTitle => 'New version available';

  @override
  String updateLatestVersion(String version) {
    return 'Latest: v$version';
  }

  @override
  String get updateAlreadyLatestTitle => 'Up to date';

  @override
  String updateAlreadyLatest(String version) {
    return 'You are on the latest version v$version';
  }

  @override
  String get updateGotoDownload => 'Go to download';

  @override
  String updateCurrentVersion(String version) {
    return 'Current version v$version';
  }

  @override
  String updateNewVersionHint(String version) {
    return 'New version v$version available';
  }

  @override
  String get updateLater => 'Later';

  @override
  String get updateOk => 'OK';

  @override
  String get updateCantAutoCheckTitle => 'Can\'t check for updates automatically';

  @override
  String get updateCantAutoCheck => 'Couldn\'t fetch version info. View the latest release on GitHub.';

  @override
  String get updateGoToGithub => 'View on GitHub';

  @override
  String get mineUpdateNow => 'Update';

  @override
  String get ledgerMetaReadOnlyToast => 'Collaborators cannot modify ledger settings.';

  @override
  String get aaSettlementTitle => 'AA Settlement';

  @override
  String get aaSettlementOverview => 'Overview';

  @override
  String get aaSettlementTotalAmount => 'Total shared';

  @override
  String aaSettlementTxCount(int count) {
    return '$count shared transactions';
  }

  @override
  String get aaSettlementPerPerson => 'Per person';

  @override
  String get aaSettlementPaid => 'Paid';

  @override
  String get aaSettlementShare => 'Share';

  @override
  String get aaSettlementNet => 'Balance';

  @override
  String get aaSettlementNetReceive => 'to receive';

  @override
  String get aaSettlementNetPay => 'to pay';

  @override
  String get aaSettlementTransferPlan => 'Settlement plan';

  @override
  String aaSettlementTransferPayTo(String from, String to) {
    return '$from pays $to';
  }

  @override
  String get aaSettlementNoTransfers => 'All settled up';

  @override
  String get aaSettlementEmpty => 'No shared transactions yet';

  @override
  String get aaSettlementExcluded => 'Not included in split';

  @override
  String get aaEditTitle => 'Split details';

  @override
  String get aaPayer => 'Paid by';

  @override
  String get aaSplitMode => 'Split method';

  @override
  String get aaParticipants => 'Participants';

  @override
  String get aaSplitAmounts => 'Custom amounts';

  @override
  String get aaModePerPerson => 'Split equally';

  @override
  String get aaModeCustom => 'Custom split';

  @override
  String get aaParticipantsAll => 'All members';

  @override
  String aaParticipantsSelected(int count) {
    return '$count selected';
  }

  @override
  String get aaSplitTotal => 'Total';

  @override
  String get aaSplitPayerAdjustHint => 'Any difference is adjusted to the payer';

  @override
  String get aaVirtualUserTitle => 'Virtual members';

  @override
  String get aaVirtualUserAdd => 'Add virtual member';

  @override
  String get aaVirtualUserNameHint => 'Enter a nickname';

  @override
  String get aaVirtualUserRename => 'Rename';

  @override
  String get aaVirtualUserEmpty => 'No virtual members yet';

  @override
  String aaVirtualUserDeleteConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get aaVirtualUserInUse => 'Has related transactions and cannot be deleted';

  @override
  String get aaUnknownUser => 'Unknown';

  @override
  String get aaPerPersonAllMembers => 'Split equally among all members';

  @override
  String get ledgerAaEnabled => 'AA Split';

  @override
  String get ledgerAaEnabledHint => 'Split expenses with members when enabled';

  @override
  String get ledgerAaSettlementEntry => 'View settlement';

  @override
  String get ledgerAaVirtualUsersEntry => 'Manage virtual members';

  @override
  String get aaNoParticipants => 'Add participants first';

  @override
  String get aaSplitAmountIncomplete => 'Enter an amount for every participant';
}
