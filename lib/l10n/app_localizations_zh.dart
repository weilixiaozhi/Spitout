import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Spitout';

  @override
  String get tabHome => '明细';

  @override
  String get tabAnalytics => '统计';

  @override
  String get tabCalendar => '日历';

  @override
  String get tabMine => '我的';

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '确定';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get commonAdd => '添加';

  @override
  String get commonOk => '确定';

  @override
  String get commonDone => '完成';

  @override
  String get homeSelectBillMonth => '选择账单月份';

  @override
  String get homePickerHint => '上下滑动数字以选择时间';

  @override
  String get homeBackToCurrentMonth => '回到当月';

  @override
  String get homeTodayExpense => '今日';

  @override
  String get homeWeekExpense => '本周';

  @override
  String get homeMonthExpense => '本月支出';

  @override
  String get homeDetailCategory => '分类';

  @override
  String get homeDetailDate => '记账日期';

  @override
  String get homeDetailAmount => '记账金额';

  @override
  String get homeDetailCurrency => '货币';

  @override
  String get homeDetailNativeAmount => '折合主货币';

  @override
  String get homeDetailMembers => '协作成员';

  @override
  String get homeDetailCreator => '创建者';

  @override
  String get homeDetailLastEditor => '最后编辑';

  @override
  String get homeDetailEditHistory => '编辑记录';

  @override
  String get homeDetailEditHistoryHint => '仅供查看';

  @override
  String get homeDetailEditButton => '编辑记账';

  @override
  String get homeDetailNoHistory => '暂无编辑历史';

  @override
  String get homeDeleteDetailTitle => '删除这条明细?';

  @override
  String homeDeleteDetailMessage(Object name) {
    return '将删除\"$name\"记录,此操作不可撤销。';
  }

  @override
  String get commonEmpty => '暂无数据';

  @override
  String get commonError => '错误';

  @override
  String get commonFailed => '失败';

  @override
  String get commonBack => '返回';

  @override
  String get commonNext => '下一步';

  @override
  String get commonFinish => '完成';

  @override
  String get commonOther => '其他';

  @override
  String get commonSearch => '搜索';

  @override
  String get commonNoteHint => '备注…';

  @override
  String get commonSettings => '设置';

  @override
  String get commonCurrent => '当前';

  @override
  String get commonTutorial => '教程';

  @override
  String get commonConfigure => '配置';

  @override
  String get commonPressAgainToExit => '再按一次退出应用';

  @override
  String get commonWeekdayMonday => '星期一';

  @override
  String get commonWeekdayTuesday => '星期二';

  @override
  String get commonWeekdayWednesday => '星期三';

  @override
  String get commonWeekdayThursday => '星期四';

  @override
  String get commonWeekdayFriday => '星期五';

  @override
  String get commonWeekdaySaturday => '星期六';

  @override
  String get commonWeekdaySunday => '星期日';

  @override
  String get homeExpense => '支出';

  @override
  String get homeNoRecords => '还没有记账';

  @override
  String get homeSelectDate => '选择日期';

  @override
  String homeYear(int year) {
    return '$year年';
  }

  @override
  String homeMonth(String month) {
    return '$month月';
  }

  @override
  String homeMonthExpenseOf(String month) {
    return '$month月支出';
  }

  @override
  String get homeNoRecordsSubtext => '点击底部加号，马上记一笔';

  @override
  String get homeBaseCurrencyNeedLedger => '请先创建账本';

  @override
  String homeBaseCurrencySwitched(String code) {
    return '已切换主币种为 $code';
  }

  @override
  String get homePullCloudSuccess => '已同步云端账本数据';

  @override
  String get homePullCloudFailed => '刷新失败，请稍后重试';

  @override
  String get homePullLocalSuccess => '已刷新本地账本数据与配置';

  @override
  String get homePullCloudFailedButLocalOk => '云端同步失败，已刷新本地数据（汇率/配置）';

  @override
  String homePullCloudHealed(int count) {
    return '已自动修复并同步 $count 条云端数据';
  }

  @override
  String get homePullCloudGap => '云端有历史数据未能自动恢复，请到云同步页执行「从云端恢复」';

  @override
  String get homeSyncing => '正在同步账本数据';

  @override
  String get homeSwitchMonthHint => '左右滑动列表切换月份';

  @override
  String get analyticsMonth => '月';

  @override
  String get analyticsYear => '年';

  @override
  String get analyticsAll => '全部';

  @override
  String get analyticsWeek => '周';

  @override
  String analyticsSwipePeriodHint(Object period) {
    return '左右滑动列表切换$period';
  }

  @override
  String get analyticsTrend => '支出趋势';

  @override
  String get analyticsTotalExpenseLabel => '总支出';

  @override
  String get analyticsDailyExpense => '日均支出';

  @override
  String get analyticsMoMLastWeek => '环比上周';

  @override
  String get analyticsMoMLastMonth => '环比上月';

  @override
  String get analyticsMoMLastYear => '环比上年';

  @override
  String get analyticsCategoryLabel => '分类统计';

  @override
  String get analyticsExpenseRatio => '支出占比';

  @override
  String get analyticsThisWeek => '本周';

  @override
  String get analyticsBackToThisWeek => '回到本周';

  @override
  String get analyticsBackToThisMonth => '回到本月';

  @override
  String get analyticsBackToThisYear => '回到今年';

  @override
  String analyticsWeekN(int week) {
    return '第$week周';
  }

  @override
  String get analyticsSelectWeek => '选择周';

  @override
  String get ledgersTitle => '账本管理';

  @override
  String get ledgersNew => '新建账本';

  @override
  String get ledgersClear => '清空账本';

  @override
  String ledgersClearMessage(Object name) {
    return '确定要清空账本\"$name\"的所有账单吗？此操作不可恢复。\\n账本本身会保留，仅删除账单数据。';
  }

  @override
  String get ledgerDefaultName => '默认账本';

  @override
  String get ledgersEdit => '编辑账本';

  @override
  String get ledgersDelete => '删除账本';

  @override
  String get ledgersDeleteConfirm => '删除账本';

  @override
  String get ledgersDeleteMessage => '确定要删除该账本及其全部记录吗？此操作不可恢复。\\n若云端存在备份，也会一并删除。';

  @override
  String get ledgersDeleted => '已删除';

  @override
  String get ledgersDeleteFailed => '删除失败';

  @override
  String get ledgersClearTitle => '清空账本';

  @override
  String get ledgersClearSuccess => '账本已清空';

  @override
  String get ledgersCreateSuccess => '账本创建成功';

  @override
  String get ledgerNameLabel => '账本名称';

  @override
  String get ledgerNameHint => '请输入账本名称';

  @override
  String get ledgersDefaultLedgerName => '默认账本';

  @override
  String get ledgersCurrency => '币种';

  @override
  String get ledgersMonthStartDay => '每月起始日';

  @override
  String get ledgersMonthStartDayHint => '统计与预算按该日作为每月周期起点（1-28）';

  @override
  String get ledgersMonthStartDayNatural => '1日（自然月）';

  @override
  String ledgersMonthStartDayValue(int day) {
    return '每月$day日';
  }

  @override
  String get ledgersSearchCurrency => '搜索：中文或代码';

  @override
  String get ledgersCreate => '创建';

  @override
  String ledgersRecords(String count) {
    return '笔数：$count';
  }

  @override
  String ledgersExpense(String expense) {
    return '支出：$expense';
  }

  @override
  String get ledgersEmpty => '暂无账本';

  @override
  String get ledgersSectionLocal => '本地账本';

  @override
  String get ledgersSectionCloud => 'Spitout Cloud 账本';

  @override
  String get ledgersSectionLocalEmpty => '暂无本地账本，本地账本只保存在这台设备上';

  @override
  String get ledgersSectionCloudEmpty => '暂无云端账本，云端账本会在各设备间同步';

  @override
  String get ledgersSectionCloudSignInHint => '登录 Spitout Cloud 后即可使用云端账本';

  @override
  String get ledgersStorageLocation => '存储位置';

  @override
  String get ledgersStorageLocalHint => '只保存在这台设备上，不会上传到云端';

  @override
  String get ledgersStorageCloudHint => '数据会上传到 Spitout Cloud，并在各设备间同步';

  @override
  String get ledgersActionMoveToCloud => '移动到 Spitout Cloud';

  @override
  String get ledgersActionMoveToLocal => '移动到本地';

  @override
  String get ledgersActionCopyToLocal => '复制到本地';

  @override
  String ledgersMoveToCloudMessage(String name) {
    return '账本\"$name\"的数据将上传到 Spitout Cloud，并在各设备间同步。';
  }

  @override
  String ledgersMoveToLocalMessage(String name) {
    return '账本\"$name\"将从 Spitout Cloud 删除，仅保留在这台设备上，其他设备将不再能看到它。';
  }

  @override
  String ledgersCopyToLocalMessage(String name) {
    return '将账本\"$name\"复制一份到本地，云端原账本保持不变。';
  }

  @override
  String get ledgersMoveToCloudSuccess => '已移动到 Spitout Cloud';

  @override
  String get ledgersMoveToLocalSuccess => '已移动到本地';

  @override
  String get ledgersCopyToLocalSuccess => '已复制到本地';

  @override
  String ledgersSwitched(String name) {
    return '已切换到账本\"$name\"';
  }

  @override
  String get categoryTitle => '分类管理';

  @override
  String get categoryExpense => '支出';

  @override
  String get categoryEmpty => '暂无分类';

  @override
  String categoryLoadFailed(String error) {
    return '加载失败: $error';
  }

  @override
  String get importReading => '读取文件中…';

  @override
  String get importPreparing => '准备中…';

  @override
  String importColumnNumber(Object number) {
    return '第 $number 列';
  }

  @override
  String get importConfirmMapping => '确认映射';

  @override
  String get importCategoryMapping => '分类映射';

  @override
  String get importNoDataParsed => '未解析到任何数据，请返回上一页检查 CSV 内容或分隔符。';

  @override
  String get importFieldDate => '日期';

  @override
  String get importFieldType => '类型';

  @override
  String get importFieldAmount => '金额';

  @override
  String get importFieldCategory => '分类';

  @override
  String get importFieldNote => '备注';

  @override
  String get importPreview => '预览：';

  @override
  String importPreviewLimit(Object shown, Object total) {
    return '仅预览前 $shown 行，共 $total 行';
  }

  @override
  String get importCategoryNotSelected => '未选择\"分类\"列，请点击\"上一步\"返回并设置\"分类\"的列，再继续。';

  @override
  String get importCategoryMappingDescription => '请将左侧\"源分类名\"映射到系统内已有分类（或保持原名自动创建/合并）';

  @override
  String get importKeepOriginalName => '保持原名（自动创建/合并）';

  @override
  String importProgress(Object fail, Object ok) {
    return '导入中… 成功 $ok，失败 $fail';
  }

  @override
  String get importCancelImport => '取消导入';

  @override
  String get importCompleteTitle => '导入完成';

  @override
  String get importSelectCategoryFirst => '请先选择\"分类\"列再继续';

  @override
  String get importNextStep => '下一步';

  @override
  String get importPreviousStep => '上一步';

  @override
  String get importStartImport => '开始导入';

  @override
  String get importAutoDetect => '自动';

  @override
  String get importInProgress => '正在导入…';

  @override
  String importProgressDetail(Object done, Object fail, Object ok, Object total) {
    return '已完成：$done/$total，成功 $ok，失败 $fail';
  }

  @override
  String get importBackgroundImport => '后台导入';

  @override
  String get importCancelled => '（已取消）';

  @override
  String importCompleted(Object cancelled, Object fail, Object ok) {
    return '导入完成$cancelled：成功 $ok 条，失败 $fail 条';
  }

  @override
  String importSkippedNonTransactionTypes(Object count) {
    return '跳过 $count 条非支出记录（债务等）';
  }

  @override
  String importTransactionFailed(Object error) {
    return '导入失败，已回滚所有更改：$error';
  }

  @override
  String importFileOpenError(String error) {
    return '无法打开文件选择器：$error';
  }

  @override
  String get mineTitle => '我的';

  @override
  String get mineLanguageSettings => '应用语言';

  @override
  String get languageTitle => '语言设置';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystemDefault => '跟随系统';

  @override
  String get mineSlogan => '设置昵称';

  @override
  String get mineDisplayNameEditTitle => '设置昵称';

  @override
  String get mineDisplayNameHint => '输入昵称';

  @override
  String get mineDisplayNameSaved => '昵称已更新';

  @override
  String get mineGreetingMorning => '早上好';

  @override
  String get mineGreetingNoon => '中午好';

  @override
  String get mineGreetingAfternoon => '下午好';

  @override
  String get mineGreetingEvening => '晚上好';

  @override
  String get mineGreetingNight => '夜深了';

  @override
  String mineGreetingNamed(String greeting, String name) {
    return '$greeting，$name';
  }

  @override
  String get mineAvatarDelete => '删除头像';

  @override
  String get mineAvatarUploadNew => '上传新头像';

  @override
  String get mineCloudService => '备份与云同步配置';

  @override
  String get mineCloudServiceLoading => '加载中…';

  @override
  String get mineSyncTitle => '同步';

  @override
  String get mineSyncNotLoggedIn => '未登录';

  @override
  String get mineSyncNotConfigured => '未配置云端';

  @override
  String get mineSyncNoRemote => '云端暂无数据';

  @override
  String mineSyncInSync(Object count) {
    return '已同步 (本地$count条)';
  }

  @override
  String mineSyncLocalNewer(Object count) {
    return '本地有更新 (本地$count条, 建议上传)';
  }

  @override
  String get mineSyncCloudNewer => '云端有更新 (建议下载同步)';

  @override
  String get mineSyncDifferent => '本地与云端有差异，建议下载对比';

  @override
  String get mineSyncError => '状态获取失败';

  @override
  String get mineSyncDetailTitle => '同步状态详情';

  @override
  String mineSyncLocalRecords(Object count) {
    return '本地记录数: $count';
  }

  @override
  String mineSyncCloudRecords(Object count) {
    return '云端记录数: $count';
  }

  @override
  String mineSyncCloudLatest(Object time) {
    return '云端最新记账时间: $time';
  }

  @override
  String mineSyncLocalFingerprint(Object fingerprint) {
    return '本地指纹: $fingerprint';
  }

  @override
  String mineSyncCloudFingerprint(Object fingerprint) {
    return '云端指纹: $fingerprint';
  }

  @override
  String mineSyncMessage(Object message) {
    return '说明: $message';
  }

  @override
  String get mineUploadTitle => '上传';

  @override
  String get mineUploadNeedLogin => '需登录';

  @override
  String get mineUploadNeedCloudService => '仅限云服务模式可用';

  @override
  String get mineUploadInProgress => '正在上传中…';

  @override
  String get mineUploadRefreshing => '刷新中…';

  @override
  String get mineUploadSynced => '已同步';

  @override
  String get mineUploadSuccess => '已上传';

  @override
  String get mineUploadSuccessMessage => '当前账本已同步到云端';

  @override
  String get mineDownloadTitle => '下载同步';

  @override
  String get mineDownloadNeedCloudService => '仅限云服务模式可用';

  @override
  String get mineDownloadComplete => '同步完成';

  @override
  String mineDownloadResult(Object inserted) {
    return '导入：$inserted 条';
  }

  @override
  String get mineLoginTitle => '登录';

  @override
  String get mineLoginSubtitle => '仅在同步时需要';

  @override
  String get cloudReloginTitle => '重新登录';

  @override
  String get cloudReloginSuccess => '已重新登录';

  @override
  String get mineLoggedInEmail => '已登录';

  @override
  String get mineLogoutSubtitle => '点击可退出登录';

  @override
  String get mineLogoutConfirmTitle => '退出登录';

  @override
  String get mineLogoutConfirmMessage => '确定要退出当前账号登录吗？\n退出后将无法使用云同步功能。';

  @override
  String get mineLogoutButton => '退出';

  @override
  String get mineAutoSyncTitle => '自动同步账本';

  @override
  String get mineAutoSyncSubtitle => '记账后自动上传到云端';

  @override
  String get mineAutoSyncNeedLogin => '需登录后可开启';

  @override
  String get mineCategoryManagement => '分类管理';

  @override
  String get mineCategoryManagementSubtitle => '编辑自定义分类';

  @override
  String get mineRecurringTransactions => '周期账单';

  @override
  String get mineRecurringTransactionsSubtitle => '管理周期性账单';

  @override
  String get mineReminderSettings => '记账提醒';

  @override
  String get mineReminderSettingsSubtitle => '设置每日记账提醒';

  @override
  String get categoryEditTitle => '编辑分类';

  @override
  String get categoryNewTitle => '新建分类';

  @override
  String get categoryDetailTooltip => '分类汇总';

  @override
  String get categoryDefaultTitle => '默认分类';

  @override
  String get categoryNameLabel => '分类名称';

  @override
  String get categoryNameHint => '请输入分类名称';

  @override
  String get categoryNameRequired => '请输入分类名称';

  @override
  String get categoryNameTooLong => '分类名称不能超过4个字';

  @override
  String get categoryNameDuplicate => '分类名称已存在';

  @override
  String get categoryIconLabel => '分类图标';

  @override
  String get categoryCurrentIcon => '当前图标';

  @override
  String get categorySaveError => '保存失败';

  @override
  String categoryUpdated(Object name) {
    return '分类\"$name\"已更新';
  }

  @override
  String categoryCreated(Object name) {
    return '分类\"$name\"已创建';
  }

  @override
  String get categoryCannotDelete => '无法删除';

  @override
  String get categoryClearUnused => '清空未使用分类';

  @override
  String get categoryClearUnusedTitle => '清空未使用分类';

  @override
  String categoryClearUnusedMessage(Object count) {
    return '确定要删除 $count 个未使用的分类吗？此操作无法撤销。';
  }

  @override
  String get categoryClearUnusedListTitle => '将被删除的分类：';

  @override
  String get categoryClearUnusedEmpty => '没有未使用的分类';

  @override
  String categoryClearUnusedSuccess(Object count) {
    return '已删除 $count 个分类';
  }

  @override
  String get categoryClearUnusedFailed => '清空失败';

  @override
  String get categoryDeleteError => '删除失败';

  @override
  String categorySubCategoryCreated(Object name) {
    return '已添加二级分类：$name';
  }

  @override
  String get categoryParentCategoryTitle => '所属分类';

  @override
  String get categorySelectParentTitle => '选择所属分类';

  @override
  String get categoryHasSubCategories => '此分类包含二级分类，无法修改';

  @override
  String get categorySearchCategory => '搜索分类';

  @override
  String get categoryTopLevelLabel => '一级分类';

  @override
  String get categorySecondLevelLabel => '二级分类';

  @override
  String get categoryExpenseList => '餐饮-交通-购物-娱乐-居家-家庭-通讯-水电-住房-医疗-教育-宠物-运动-数码-旅行-烟酒-母婴-美容-维修-社交-学习-汽车-打车-地铁-外卖-物业-停车-捐赠-送礼-纳税-饮料-服装-零食-发红包-水果-游戏-书籍-爱人-装修-日用品-彩票-股票-社保-快递-工作-转账-其他';

  @override
  String get categoryExpenseDining => '餐饮-早餐-午餐-晚餐-美团外卖-饿了么外卖-京东外卖-餐厅-美食';

  @override
  String get categoryExpenseSnacks => '零食-饼干-薯片-糖果-巧克力-坚果';

  @override
  String get categoryExpenseFruit => '水果-苹果-香蕉-橙子-葡萄-西瓜-其他水果';

  @override
  String get categoryExpenseBeverage => '饮料-奶茶-咖啡-果汁-汽水-矿泉水';

  @override
  String get categoryExpensePastry => '糕点-蛋糕-面包-甜点-曲奇';

  @override
  String get categoryExpenseCooking => '做饭食材-蔬菜-肉类-水产-调料-粮油';

  @override
  String get categoryExpenseShopping => '购物-超市-日用百货-服装-鞋子-包包';

  @override
  String get categoryExpensePets => '宠物-宠物食品-宠物用品-宠物医疗-宠物美容';

  @override
  String get categoryExpenseTransport => '交通-交通卡充值-打车-停车费-加油';

  @override
  String get categoryExpenseCar => '汽车-汽车保养-汽车维修-汽车保险-洗车-违章罚款';

  @override
  String get categoryExpenseClothing => '服装-上衣-裤子-裙子-鞋子-服饰配件';

  @override
  String get categoryExpenseDailyGoods => '日用品-洗护用品-纸品-清洁用品-厨房用品';

  @override
  String get categoryExpenseEducation => '教育-学费-培训费-书籍-文具-办公用品-学习';

  @override
  String get categoryExpenseInvestLoss => '投资亏损-股票亏损-基金亏损-其他投资亏损';

  @override
  String get categoryExpenseEntertainment => '娱乐-电影-KTV-游乐场-酒吧-其他娱乐';

  @override
  String get categoryExpenseGame => '游戏-游戏充值-游戏装备-游戏会员';

  @override
  String get categoryExpenseHealthProducts => '保健品-维生素-保健食品-营养品';

  @override
  String get categoryExpenseSubscription => '订阅服务-视频会员-音乐会员-云存储-其他订阅';

  @override
  String get categoryExpenseSports => '运动-健身房-运动装备-运动课程-户外活动';

  @override
  String get categoryExpenseHousing => '住房-水电煤-物业费-房租-房贷-装修-宽带';

  @override
  String get categoryExpenseHome => '居家-家具-家电-装饰品-床上用品';

  @override
  String get categoryExpenseBeauty => '美容-护肤品-化妆品-剪发-美甲';

  @override
  String get categoryExpenseTransfer => '转账-生活费-家庭-父母-恋人-借钱';

  @override
  String get appearanceThemeMode => '深色模式';

  @override
  String get appearanceThemeModeSystem => '跟随系统';

  @override
  String get appearanceThemeModeLight => '亮色模式';

  @override
  String get appearanceThemeModeDark => '暗黑模式';

  @override
  String get appearanceExpenseColorScheme => '支出颜色';

  @override
  String get appearanceExpenseColorRed => '红色表示支出';

  @override
  String get appearanceExpenseColorGreen => '绿色表示支出';

  @override
  String get appearanceExpenseColorApplied => '已更换';

  @override
  String get reminderTitle => '记账提醒';

  @override
  String get reminderSubtitle => '设置每日记账提醒时间';

  @override
  String get reminderDailyTitle => '每日记账提醒';

  @override
  String get reminderDailySubtitle => '开启后将在指定时间提醒您记账';

  @override
  String get reminderTimeTitle => '提醒时间';

  @override
  String get commonSelectTime => '选择时间';

  @override
  String get reminderTestNotification => '发送测试通知';

  @override
  String get reminderTestSent => '测试通知已发送';

  @override
  String get reminderTestTitle => '测试通知';

  @override
  String get reminderTestBody => '这是一条测试通知，点击查看效果';

  @override
  String get reminderCheckBattery => '检查电池优化状态';

  @override
  String get reminderBatteryStatus => '电池优化状态';

  @override
  String reminderManufacturer(Object value) {
    return '设备制造商: $value';
  }

  @override
  String reminderModel(Object value) {
    return '设备型号: $value';
  }

  @override
  String reminderAndroidVersion(Object value) {
    return 'Android版本: $value';
  }

  @override
  String get reminderBatteryIgnored => '电池优化状态: 已忽略 ✅';

  @override
  String get reminderBatteryNotIgnored => '电池优化状态: 未忽略 ⚠️';

  @override
  String get reminderBatteryAdvice => '建议关闭电池优化以确保通知正常工作';

  @override
  String get reminderCheckChannel => '检查通知渠道设置';

  @override
  String get reminderChannelStatus => '通知渠道状态';

  @override
  String get reminderChannelEnabled => '渠道启用: 是 ✅';

  @override
  String get reminderChannelDisabled => '渠道启用: 否 ❌';

  @override
  String reminderChannelImportance(Object value) {
    return '重要性: $value';
  }

  @override
  String get reminderChannelSoundOn => '声音: 开启 🔊';

  @override
  String get reminderChannelSoundOff => '声音: 关闭 🔇';

  @override
  String get reminderChannelVibrationOn => '震动: 开启 📳';

  @override
  String get reminderChannelVibrationOff => '震动: 关闭';

  @override
  String get reminderChannelDndBypass => '勿扰模式: 可绕过';

  @override
  String get reminderChannelDndNoBypass => '勿扰模式: 不可绕过';

  @override
  String get reminderChannelAdvice => '⚠️ 建议设置：';

  @override
  String get reminderChannelAdviceImportance => '• 重要性：紧急或高';

  @override
  String get reminderChannelAdviceSound => '• 开启声音和震动';

  @override
  String get reminderChannelAdviceBanner => '• 允许横幅通知';

  @override
  String get reminderChannelAdviceXiaomi => '• 小米手机需单独设置每个渠道';

  @override
  String get reminderChannelGood => '✅ 通知渠道配置良好';

  @override
  String get reminderOpenAppSettings => '打开应用设置';

  @override
  String get reminderAppSettingsMessage => '请在设置中允许通知、关闭电池优化';

  @override
  String get reminderDescription => '提示：开启记账提醒后，系统会在每天指定时间发送通知提醒您记录支出。';

  @override
  String get reminderAndroidInstructions => '如果通知无法正常工作，请检查：\n• 已允许应用发送通知\n• 关闭应用的电池优化/省电模式\n• 允许应用在后台运行和自启动\n• Android 12+需要精确闹钟权限\n\n📱 小米手机特殊设置：\n• 设置 > 应用管理 > Spitout > 通知管理\n• 点击\"记账提醒\"渠道\n• 设置重要性为\"紧急\"或\"高\"\n• 开启\"横幅通知\"、\"声音\"、\"震动\"\n• 安全中心 > 应用管理 > 权限 > 自启动\n\n🔒 锁定后台方法：\n• 最近任务中找到Spitout\n• 向下拉动应用卡片显示锁定图标\n• 点击锁定图标防止被清理';

  @override
  String get categoryDetailLoadFailed => '加载失败';

  @override
  String get categoryDetailSummaryTitle => '分类汇总';

  @override
  String get categoryDetailTotalCount => '总笔数';

  @override
  String get categoryDetailTotalAmount => '总金额';

  @override
  String get categoryDetailAverageAmount => '平均金额';

  @override
  String get categoryDetailSortTitle => '排序';

  @override
  String get categoryDetailSortTimeDesc => '时间↓';

  @override
  String get categoryDetailSortTimeAsc => '时间↑';

  @override
  String get categoryDetailSortAmountDesc => '金额↓';

  @override
  String get categoryDetailSortAmountAsc => '金额↑';

  @override
  String get categoryDetailNoTransactions => '暂无交易记录';

  @override
  String get categoryDetailNoTransactionsSubtext => '该分类下还没有任何交易记录';

  @override
  String get categoryDetailDeleteFailed => '删除失败';

  @override
  String categoryMigrationTransactionLabel(int count) {
    return '$count笔';
  }

  @override
  String get categoryTemplateEntryFlat => '一级模板';

  @override
  String get categoryTemplateEntryHierarchical => '二级模板';

  @override
  String get categoryTemplateFlatTitle => '一级分类模板';

  @override
  String get categoryTemplateHierarchicalTitle => '二级分类模板';

  @override
  String categoryTemplateSelectedCount(int count) {
    return '本次已勾选 $count 项';
  }

  @override
  String get categoryTemplateSelectAll => '全选';

  @override
  String get categoryTemplateDeselectAll => '取消全选';

  @override
  String get categoryTemplateConfirmTitle => '确认添加';

  @override
  String categoryTemplateConfirmMessage(int count) {
    return '确定将勾选的 $count 个分类加入分类表吗？';
  }

  @override
  String categoryTemplateAddSuccess(int count) {
    return '已添加 $count 个分类';
  }

  @override
  String categoryTemplateAddFailed(String error) {
    return '添加失败：$error';
  }

  @override
  String get categoryManageAdd => '添加分类';

  @override
  String get categoryManageDelete => '删除分类';

  @override
  String get categoryManageConfirmDelete => '确认删除';

  @override
  String get categoryManageReorderHint => '长按调整分类顺序';

  @override
  String get categorySharedManageBannerOwner => '共享账本：分类的新增、修改、删除会同步给所有成员';

  @override
  String get categorySharedManageBannerEditor => '共享账本记账使用所有者的分类；此处的编辑仅影响你的个人分类';

  @override
  String get categorySyncFailedBeforeInvite => '分类同步失败，请检查网络后重试';

  @override
  String get categorySortSaveFailed => '排序保存失败，请重试';

  @override
  String get categoryDeleteOptionAll => '删除分类和分类下的所有数据（含二级）';

  @override
  String get categoryDeleteOptionMigrate => '删除分类并迁移分类下的所有数据到其他分类（含二级）';

  @override
  String get categoryDeleteOptionPromote => '删除分类和分类下的所有数据（不含二级分类，二级分类将变为一级分类）';

  @override
  String get categoryDeleteSelectedTitle => '删除选中的分类';

  @override
  String categoryDeleteSelectedSubtitleWithSub(int count) {
    return '确定要删除 $count 个选中分类并且清空分类下的数据吗？（包含二级分类和数据）此操作无法撤销。';
  }

  @override
  String categoryDeleteSelectedSubtitleWithoutSub(int count) {
    return '确定要删除 $count 个选中分类并且清空分类下的数据吗？（不含二级分类和数据）此操作无法撤销。';
  }

  @override
  String get categoryMigrateSelectTargetTitle => '选择数据迁移到的分类';

  @override
  String get categoryMigrateConfirmButton => '确定（迁移分类数据并删除分类）';

  @override
  String categoryMigrateChildLabel(Object parent) {
    return '二级 · $parent';
  }

  @override
  String get subcategoryEditParent => '编辑父分类';

  @override
  String get subcategoryAdd => '添加子分类';

  @override
  String get subcategoryDelete => '删除子分类';

  @override
  String get subcategoryDeleteOptionAll => '删除分类和分类下的所有数据';

  @override
  String get subcategoryDeleteOptionMigrate => '删除分类并迁移分类下的所有数据到其他分类';

  @override
  String subcategoryDeleteSelectedSubtitle(int count) {
    return '确定要删除 $count 个选中分类并且清空分类下的数据吗？此操作无法撤销。';
  }

  @override
  String get subcategoryEmpty => '暂无子分类';

  @override
  String get cloudSupabaseUrlLabel => 'Supabase URL';

  @override
  String get cloudSupabaseUrlHint => 'https://xxx.supabase.co';

  @override
  String get cloudAnonKeyLabel => 'Anon Key';

  @override
  String get cloudMultiDeviceWarningTitle => '多设备使用提醒';

  @override
  String get cloudMultiDeviceWarningMessage => '换设备前记得先上传，到新设备后先下载再记账。不要同时在两台设备上记同一个账本。点击查看详情 →';

  @override
  String get cloudWebdavUrlLabel => 'WebDAV 服务器地址';

  @override
  String get cloudWebdavUrlHint => 'https://dav.jianguoyun.com/dav/';

  @override
  String get cloudWebdavUsernameLabel => '用户名';

  @override
  String get cloudWebdavPasswordLabel => '密码';

  @override
  String get cloudWebdavPathHint => '/Spitout';

  @override
  String get cloudS3EndpointLabel => '端点地址';

  @override
  String get cloudS3EndpointHint => 's3.amazonaws.com 或自定义端点';

  @override
  String get cloudS3RegionLabel => '区域';

  @override
  String get cloudS3RegionHint => 'us-east-1（留空自动）';

  @override
  String get cloudS3AccessKeyLabel => 'Access Key';

  @override
  String get cloudS3AccessKeyHint => '您的 Access Key ID';

  @override
  String get cloudS3SecretKeyLabel => 'Secret Key';

  @override
  String get cloudS3SecretKeyHint => '您的 Secret Access Key';

  @override
  String get cloudS3BucketLabel => '存储桶名称';

  @override
  String get cloudS3BucketHint => 'spitout-data';

  @override
  String get cloudS3UseSSLLabel => '使用 HTTPS';

  @override
  String get cloudS3PortLabel => '端口（可选）';

  @override
  String get cloudS3PortHint => '留空使用默认端口';

  @override
  String get cloudSupabaseBucketLabel => 'Storage Bucket 名称';

  @override
  String get cloudSupabaseBucketHint => '留空使用默认值 spitout-backups';

  @override
  String get authRememberAccount => '记住账号密码';

  @override
  String get authRememberAccountHint => '下次登录时自动填充（仅Supabase）';

  @override
  String get cloudFirstSaveSwitchTitle => '配置已保存';

  @override
  String get cloudFirstSaveSwitchMessage => '是否立即切换到该云服务作为当前同步配置?';

  @override
  String get cloudSaveOnlyNoSwitch => '暂不切换';

  @override
  String get cloudSaveAndSwitch => '立即切换';

  @override
  String get cloudClearConfig => '清除配置';

  @override
  String get cloudClearConfigConfirmTitle => '清除云端配置';

  @override
  String get cloudClearConfigConfirmMessage => '确定要清除该云端服务的配置吗？\n云端已备份的数据不会被删除，你可以随时重新配置并恢复。';

  @override
  String get cloudClearConfigDone => '配置已清除';

  @override
  String get cloudPurgeFailed => '云端账本清理失败，请稍后重试';

  @override
  String get authLogin => '登录';

  @override
  String get authEmail => '邮箱';

  @override
  String get authPassword => '密码';

  @override
  String get authInvalidEmail => '请输入有效的邮箱地址';

  @override
  String get authErrorInvalidCredentials => '邮箱或密码不正确。';

  @override
  String get authErrorEmailNotConfirmed => '邮箱未验证，请先到邮箱完成验证再登录。';

  @override
  String get authErrorRateLimit => '操作过于频繁，请稍后再试。';

  @override
  String get authErrorNetworkIssue => '网络异常，请检查网络后重试。';

  @override
  String get authErrorLoginFailed => '登录失败，请稍后再试。';

  @override
  String get exportCsvHeaderType => '类型';

  @override
  String get exportCsvHeaderCategory => '分类';

  @override
  String get exportCsvHeaderSubCategory => '二级分类';

  @override
  String get exportCsvHeaderAmount => '金额';

  @override
  String get exportCsvHeaderNote => '备注';

  @override
  String get exportCsvHeaderTime => '时间';

  @override
  String get exportSuccessTitle => '导出成功';

  @override
  String exportSuccessMessageAndroid(String path) {
    return '已保存到：\n$path';
  }

  @override
  String get exportFailedTitle => '导出失败';

  @override
  String get exportTypeExpense => '支出';

  @override
  String get currencyCNY => '人民币';

  @override
  String get currencyUSD => '美元';

  @override
  String get currencyEUR => '欧元';

  @override
  String get currencyJPY => '日元';

  @override
  String get currencyHKD => '港币';

  @override
  String get currencyTWD => '新台币';

  @override
  String get currencyGBP => '英镑';

  @override
  String get currencyAUD => '澳元';

  @override
  String get currencyCAD => '加元';

  @override
  String get currencyKRW => '韩元';

  @override
  String get currencySGD => '新加坡元';

  @override
  String get currencyMYR => '马来西亚林吉特';

  @override
  String get currencyTHB => '泰铢';

  @override
  String get currencyIDR => '印尼卢比';

  @override
  String get currencyPHP => '菲律宾比索';

  @override
  String get currencyVND => '越南盾';

  @override
  String get currencyINR => '印度卢比';

  @override
  String get currencyRUB => '俄罗斯卢布';

  @override
  String get currencyBYN => '白俄罗斯卢布';

  @override
  String get currencyNZD => '新西兰元';

  @override
  String get currencyCHF => '瑞士法郎';

  @override
  String get currencySEK => '瑞典克朗';

  @override
  String get currencyNOK => '挪威克朗';

  @override
  String get currencyDKK => '丹麦克朗';

  @override
  String get currencyBRL => '巴西雷亚尔';

  @override
  String get currencyMXN => '墨西哥比索';

  @override
  String get currencyTRY => '土耳其里拉';

  @override
  String get currencyZAR => '南非兰特';

  @override
  String get currencyAED => '阿联酋迪拉姆';

  @override
  String get currencySAR => '沙特里亚尔';

  @override
  String get currencyPLN => '波兰兹罗提';

  @override
  String get currencyCZK => '捷克克朗';

  @override
  String get currencyHUF => '匈牙利福林';

  @override
  String get currencyARS => '阿根廷比索';

  @override
  String get currencyCLP => '智利比索';

  @override
  String get currencyCOP => '哥伦比亚比索';

  @override
  String get currencyPEN => '秘鲁索尔';

  @override
  String get currencyEGP => '埃及镑';

  @override
  String get currencyNGN => '尼日利亚奈拉';

  @override
  String get currencyKZT => '哈萨克斯坦坚戈';

  @override
  String get currencyUAH => '乌克兰格里夫纳';

  @override
  String get currencyILS => '以色列新谢克尔';

  @override
  String get currencyPKR => '巴基斯坦卢比';

  @override
  String get currencyBDT => '孟加拉塔卡';

  @override
  String get currencyLKR => '斯里兰卡卢比';

  @override
  String get currencyMMK => '缅甸元';

  @override
  String get webdavConfiguredTitle => 'WebDAV 云服务已配置';

  @override
  String get webdavConfiguredMessage => 'WebDAV 云服务使用配置时提供的凭据，无需额外登录。';

  @override
  String get recurringTransactionTitle => '周期账单';

  @override
  String get recurringTransactionAdd => '添加周期账单';

  @override
  String get recurringTransactionEdit => '编辑周期账单';

  @override
  String get recurringTransactionFrequency => '周期频率';

  @override
  String get recurringTransactionDaily => '每天';

  @override
  String get recurringTransactionWeekly => '每周';

  @override
  String get recurringTransactionMonthly => '每月';

  @override
  String get recurringTransactionYearly => '每年';

  @override
  String get recurringTransactionInterval => '间隔';

  @override
  String get recurringTransactionDayOfMonth => '每月第几天';

  @override
  String get recurringTransactionStartDate => '开始日期';

  @override
  String get recurringTransactionEndDate => '结束日期';

  @override
  String get recurringTransactionNoEndDate => '永久周期';

  @override
  String get recurringTransactionDeleteConfirm => '确定要删除这个周期账单吗？';

  @override
  String get recurringTransactionEmpty => '暂无周期账单';

  @override
  String get recurringTransactionEmptyHint => '点击右上角 + 按钮添加';

  @override
  String recurringTransactionEveryNDays(int n) {
    return '每 $n 天';
  }

  @override
  String recurringTransactionEveryNWeeks(int n) {
    return '每 $n 周';
  }

  @override
  String recurringTransactionEveryNMonths(int n) {
    return '每 $n 个月';
  }

  @override
  String recurringTransactionEveryNYears(int n) {
    return '每 $n 年';
  }

  @override
  String get recurringTransactionUsageTitle => '使用说明';

  @override
  String get recurringTransactionUsageContent => '周期记账会在每次冷启动进入App时自动扫描并生成账单。设置日期后，系统会在该日期之后的冷启动时创建对应账单。例如：设置11月27日，则会在11月27日之后的首次启动时自动记账。';

  @override
  String get ledgerSelectTitle => '选择账本';

  @override
  String get ledgerSelect => '选择账本';

  @override
  String get syncNotConfiguredMessage => '未配置云端';

  @override
  String get syncNotLoggedInMessage => '未登录';

  @override
  String get syncCloudBackupCorruptedMessage => '云端备份内容无法解析，可能是早期版本编码问题造成的损坏。请点击\\\"上传当前账本到云端\\\"覆盖修复。';

  @override
  String get syncNoCloudBackupMessage => '云端暂无备份';

  @override
  String get syncAccessDeniedMessage => '403 拒绝访问（检查 storage RLS 策略与路径）';

  @override
  String get cloudTestConnection => '测试连接';

  @override
  String cloudLastTestTime(String time) {
    return '上次测试时间：$time';
  }

  @override
  String get cloudLocalStorageTitle => '本地存储';

  @override
  String get cloudLocalStorageSubtitle => '数据仅保存在本地设备';

  @override
  String get localBackupPageTitle => '本地存储';

  @override
  String get localBackupAutoTitle => '自动本地备份';

  @override
  String get localBackupAutoSubtitle => '每天首次打开应用时自动备份数据库快照';

  @override
  String get storagePermissionTitle => '需要存储权限';

  @override
  String get storagePermissionMessage => 'Android 11 及以上版本需授予「所有文件访问」权限，才能将文件保存到公共 Download 目录（文件管理器可见、卸载应用不丢失）。\n\n选择「仍要继续」将保存到应用私有目录，文件管理器不可见，且卸载应用后会被删除。';

  @override
  String get storagePermissionGrant => '去授权';

  @override
  String get storagePermissionContinue => '仍要继续';

  @override
  String get exportStorageUnavailable => '外部存储不可用，请检查设备存储状态';

  @override
  String get localBackupNowTooltip => '立即备份';

  @override
  String get localBackupSuccess => '备份成功';

  @override
  String get localBackupFailed => '备份失败，请检查存储空间与权限';

  @override
  String get localBackupListHint => '选择一个数据进行恢复：';

  @override
  String get localBackupImportFromFile => '导入文件恢复';

  @override
  String get localBackupImportInvalidFile => '请选择 .sqlite 格式的备份文件';

  @override
  String get localBackupListEmpty => '暂无备份';

  @override
  String get localBackupRestoreTitle => '恢复备份';

  @override
  String get localBackupRestoreMessage => '恢复将覆盖当前全部数据且不可逆，是否继续？';

  @override
  String get localBackupRestoreSuccess => '恢复成功';

  @override
  String get localBackupRestoreFailed => '恢复失败';

  @override
  String get localBackupEmergencyFailed => '无法为当前数据创建安全副本，已取消恢复';

  @override
  String get localBackupIntegrityFailed => '备份文件已损坏，无法恢复';

  @override
  String get localBackupVersionTooNew => '该备份由更新版本的应用创建，请升级应用后再恢复';

  @override
  String get localBackupRestoring => '正在恢复…';

  @override
  String get cloudCustomSupabaseTitle => '自定义 Supabase';

  @override
  String get cloudCustomSupabaseSubtitle => '点击配置自建Supabase服务';

  @override
  String get cloudCustomWebdavTitle => '自定义 WebDAV';

  @override
  String get cloudCustomWebdavSubtitle => '点击配置坚果云/Nextcloud等';

  @override
  String get cloudCustomS3Title => 'S3 协议存储';

  @override
  String get cloudCustomS3Subtitle => 'AWS S3 / Cloudflare R2 / MinIO';

  @override
  String get cloudSpitoutCloudTitle => 'Spitout Cloud';

  @override
  String get cloudSpitoutCloudSubtitle => '自建云服务 · 增量同步 · 多设备协同';

  @override
  String get cloudConfigureSpitoutCloudTitle => '配置 Spitout Cloud';

  @override
  String get cloudSpitoutCloudUrlLabel => '服务器地址';

  @override
  String get cloudSpitoutCloudUrlHint => 'https://your-server.com';

  @override
  String get cloudSpitoutCloudEmailLabel => '邮箱';

  @override
  String get cloudSpitoutCloudEmailHint => 'your@email.com';

  @override
  String get cloudSpitoutCloudPasswordLabel => '密码';

  @override
  String get cloudSpitoutCloudPasswordHint => '输入密码';

  @override
  String get cloudSpitoutCloudLoginSuccess => '登录成功';

  @override
  String get cloudSpitoutCloudLoginFailed => '登录失败';

  @override
  String get cloudTabOffline => '离线模式';

  @override
  String get cloudTabBackup => '备份同步';

  @override
  String get cloudTabBackupSubtitle => '点击卡片切换备份方式，首次需要配置信息';

  @override
  String get cloudTabCloudSync => '云端协同';

  @override
  String get cloudSupabaseHelpTitle => 'Supabase 配置说明';

  @override
  String get cloudSupabaseHelpIntro => '什么是 Supabase';

  @override
  String get cloudSupabaseHelpIntro1 => 'Supabase 是一个开源的后端即服务平台';

  @override
  String get cloudSupabaseHelpIntro2 => '提供免费套餐，足够个人使用';

  @override
  String get cloudSupabaseHelpIntro3 => '数据完全由您掌控';

  @override
  String get cloudSupabaseHelpSteps => '配置步骤';

  @override
  String get cloudSupabaseHelpStep1 => '1. 访问 supabase.com 注册账号';

  @override
  String get cloudSupabaseHelpStep2 => '2. 创建新项目（选择免费套餐）';

  @override
  String get cloudSupabaseHelpStep3 => '3. 进入项目设置 > API';

  @override
  String get cloudSupabaseHelpStep4 => '4. 复制 Project URL 和 anon key';

  @override
  String get cloudSupabaseHelpStep5 => '5. 粘贴到应用的配置中';

  @override
  String get cloudSupabaseHelpFaq => '常见问题';

  @override
  String get cloudSupabaseHelpFaq1 => '免费套餐有 500MB 存储空间';

  @override
  String get cloudSupabaseHelpFaq2 => '数据加密存储，安全可靠';

  @override
  String get cloudSupabaseHelpFaq3 => '支持多设备同步';

  @override
  String get cloudSupabaseHelpNote => '配置完成后需要注册/登录账号才能使用同步功能';

  @override
  String get cloudWebdavHelpTitle => 'WebDAV 配置说明';

  @override
  String get cloudWebdavHelpIntro => '什么是 WebDAV';

  @override
  String get cloudWebdavHelpIntro1 => 'WebDAV 是一种网络文件协议';

  @override
  String get cloudWebdavHelpIntro2 => '支持多种云盘和NAS设备';

  @override
  String get cloudWebdavHelpIntro3 => '数据存储在您自己的服务器上';

  @override
  String get cloudWebdavHelpProviders => '支持的服务商';

  @override
  String get cloudWebdavHelpProvider1 => '• 坚果云（推荐国内用户）';

  @override
  String get cloudWebdavHelpProvider2 => '• Nextcloud / ownCloud';

  @override
  String get cloudWebdavHelpProvider3 => '• 群晖 / 威联通 NAS';

  @override
  String get cloudWebdavHelpProvider4 => '• 其他支持 WebDAV 的服务';

  @override
  String get cloudWebdavHelpSteps => '配置步骤（以坚果云为例）';

  @override
  String get cloudWebdavHelpStep1 => '1. 登录坚果云网页版';

  @override
  String get cloudWebdavHelpStep2 => '2. 点击右上角账户名 > 账户信息';

  @override
  String get cloudWebdavHelpStep3 => '3. 选择「安全选项」标签';

  @override
  String get cloudWebdavHelpStep4 => '4. 添加应用密码（用于第三方应用）';

  @override
  String get cloudWebdavHelpStep5 => '5. 复制服务器地址、账号、应用密码';

  @override
  String get cloudWebdavHelpNote => '建议使用应用专用密码，而非账号密码';

  @override
  String get cloudS3HelpTitle => 'S3 存储配置说明';

  @override
  String get cloudS3HelpIntro => '什么是 S3';

  @override
  String get cloudS3HelpIntro1 => 'S3 是一种标准的对象存储协议';

  @override
  String get cloudS3HelpIntro2 => '支持多家云服务商';

  @override
  String get cloudS3HelpIntro3 => '数据存储在您选择的云服务中';

  @override
  String get cloudS3HelpProviders => '支持的服务商';

  @override
  String get cloudS3HelpProvider1 => '• AWS S3（Amazon Web Services）';

  @override
  String get cloudS3HelpProvider2 => '• Cloudflare R2（免费 10GB/月）';

  @override
  String get cloudS3HelpProvider3 => '• Backblaze B2（免费 10GB）';

  @override
  String get cloudS3HelpProvider4 => '• MinIO（自建服务）';

  @override
  String get cloudS3HelpProvider5 => '• 阿里云 OSS';

  @override
  String get cloudS3HelpProvider6 => '• 腾讯云 COS';

  @override
  String get cloudS3HelpProvider7 => '• 七牛云 Kodo';

  @override
  String get cloudS3HelpSteps => '配置步骤（以 Cloudflare R2 为例）';

  @override
  String get cloudS3HelpStep1 => '1. 登录 Cloudflare 控制台';

  @override
  String get cloudS3HelpStep2 => '2. 进入 R2 > 创建存储桶';

  @override
  String get cloudS3HelpStep3 => '3. 进入 R2 > 管理 R2 API 令牌';

  @override
  String get cloudS3HelpStep4 => '4. 创建 API 令牌并复制凭据';

  @override
  String get cloudS3HelpStep5 => '5. 粘贴端点、访问密钥、私密密钥和存储桶名称';

  @override
  String get cloudS3HelpNote => '推荐使用 Cloudflare R2，提供 10GB 免费存储且无流量费';

  @override
  String get cloudStatusNotTested => '未测试';

  @override
  String get cloudStatusNormal => '连接正常';

  @override
  String get cloudStatusFailed => '连接失败';

  @override
  String get cloudErrorAuthFailed => '认证失败: API Key 无效';

  @override
  String cloudErrorServerStatus(String code) {
    return '服务器返回状态码 $code';
  }

  @override
  String get cloudErrorWebdavNotSupported => '服务器不支持 WebDAV 协议';

  @override
  String get cloudErrorAuthFailedCredentials => '认证失败: 用户名或密码错误';

  @override
  String get cloudErrorAccessDenied => '访问被拒绝: 请检查权限';

  @override
  String cloudErrorPathNotFound(String path) {
    return '服务器路径不存在: $path';
  }

  @override
  String cloudErrorNetwork(String message) {
    return '网络错误: $message';
  }

  @override
  String get cloudTestSuccessMessage => '连接正常,配置有效';

  @override
  String get cloudTestFailedMessage => '连接失败';

  @override
  String get cloudSwitchConfirmTitle => '切换云服务';

  @override
  String get cloudSwitchConfirmMessage => '切换云服务将登出当前账号,确认切换?';

  @override
  String get cloudSwitchFailedTitle => '切换失败';

  @override
  String get cloudSwitchFailedConfigMissing => '请先配置该云服务';

  @override
  String get cloudConfigInvalidMessage => '请填写完整信息';

  @override
  String get cloudSaveFailed => '保存失败';

  @override
  String cloudSwitchedTo(String type) {
    return '已切换到$type';
  }

  @override
  String get cloudConfigureSupabaseTitle => '配置 Supabase';

  @override
  String get cloudConfigureWebdavTitle => '配置 WebDAV';

  @override
  String get cloudConfigureS3Title => '配置 S3';

  @override
  String get cloudSupabaseAnonKeyHintLong => '粘贴完整的 anon key';

  @override
  String get cloudWebdavRemotePathLabel => '远程路径';

  @override
  String get cloudWebdavRemotePathHelperText => '数据存储的远程目录路径';

  @override
  String get welcomeSelectCurrencyTitle => '选择记账货币';

  @override
  String get welcomeCurrencyDescription => '选择您常用的货币，之后可以随时在设置中更改';

  @override
  String get aiOcrNoLedger => '未找到账本';

  @override
  String get cloudTutorialTitle => '使用教程';

  @override
  String get cloudTutorialIntro => 'Spitout Cloud 是可以自建的云同步服务端,支持多设备实时协同。流程很简单:';

  @override
  String get cloudTutorialStep1Title => '第一步:部署或选择服务器';

  @override
  String get cloudTutorialStep1Desc => '自己部署:Docker 一行命令拉起(见 GitHub README 的 Docker 指南)。或直接使用朋友/团队已有的 Spitout Cloud 服务器。';

  @override
  String get cloudTutorialStep2Title => '第二步:获取账号';

  @override
  String get cloudTutorialStep2Desc => 'Spitout Cloud 不支持自助注册(避免公网服务被滥用)。自己部署的同学:首次启动 Docker 日志里会打印随机管理员账号密码,直接用。加入他人服务器的同学:让管理员在 Web 后台 →「用户」里帮你添加账号。';

  @override
  String get cloudTutorialStep3Title => '第三步:登录并开启同步';

  @override
  String get cloudTutorialStep3Desc => 'App 里选「Spitout Cloud」,填服务器地址 + 管理员给你的账号,登录。首次会全量上传你本地所有账本数据,之后每次编辑实时推送。';

  @override
  String get cloudTutorialStep4Title => '第四步:其他设备登录';

  @override
  String get cloudTutorialStep4Desc => '手机、平板、Web 三端用同一账号登录,数据即刻互通。修改几秒内互相感知。';

  @override
  String get cloudTutorialTipTitle => '小贴士';

  @override
  String get cloudTutorialTipDesc => 'Web 端地址 = 服务器地址,浏览器直接访问即可。登录后可以管理账本、成员、查看日志。';

  @override
  String get cloudTutorialFeaturesTitle => '特色功能';

  @override
  String get cloudTutorialFeature1 => '📱 多设备实时协同:手机 A + 手机 B + Web 三端同账号,数据秒级同步';

  @override
  String get cloudTutorialFeature2 => '🌐 自带 Web 管理端:一个 Docker 镜像包含 server + web,浏览器即可使用';

  @override
  String get cloudTutorialFeature3 => '👥 多用户独立:一个服务器可以多人注册,各自数据完全隔离';

  @override
  String get cloudTutorialFeature4 => '🤝 共享账本:邀请家人 / 团队一起记同一本,实时秒级同步';

  @override
  String get cloudTutorialGotIt => '我知道了';

  @override
  String get cloudSyncHint => '下载时可自动对比差异并逐条预览。非实时同步，请避免多设备同时编辑同一账本。同步范围为账本数据（含关联的账户、分类）。';

  @override
  String get appearanceSettings => '偏好调节';

  @override
  String get appearanceSettingsDesc => '主题、字体、语言、应用锁等';

  @override
  String get appearanceSettingsPageTitle => '偏好调节';

  @override
  String get appearanceSettingsPageSubtitle => '外观、显示、安全等应用偏好';

  @override
  String get logCenterTitle => '日志中心';

  @override
  String get logCenterSubtitle => '查看应用运行日志';

  @override
  String get logCenterSearchHint => '搜索日志内容或标签...';

  @override
  String get logCenterFilterLevel => '日志级别';

  @override
  String get logCenterFilterPlatform => '平台';

  @override
  String get logCenterTotal => '全部';

  @override
  String get logCenterFiltered => '已过滤';

  @override
  String get logCenterEmpty => '暂无日志';

  @override
  String get logCenterExport => '导出';

  @override
  String get logCenterClear => '清空';

  @override
  String get logCenterExportFailed => '导出失败';

  @override
  String get logCenterClearConfirmTitle => '清空日志';

  @override
  String get logCenterClearConfirmMessage => '确定要清空所有日志吗？此操作不可恢复。';

  @override
  String get logCenterCleared => '日志已清空';

  @override
  String get logCenterCopied => '已复制到剪贴板';

  @override
  String get configImportExportTitle => '配置导入导出';

  @override
  String get configImportExportSubtitle => '备份和恢复应用配置';

  @override
  String get configImportExportInfoTitle => '功能说明';

  @override
  String get configImportExportInfoMessage => '备份和恢复应用配置，用于跨设备迁移或恢复设置。导出为 YAML 格式，可查看和编辑。\n\n仅包含应用配置，不包含交易记录（交易数据请使用明细导入导出功能）。';

  @override
  String get configImportExportWarning => '配置文件包含云服务密钥、密码等敏感信息，请妥善保管。导入会覆盖现有同名配置，建议先导出备份。';

  @override
  String get configExportTitle => '导出配置';

  @override
  String get configExportSubtitle => '将当前配置导出为YAML文件';

  @override
  String get configExportShareSubject => 'Spitout 配置文件';

  @override
  String get configExportSuccess => '配置导出成功';

  @override
  String get configExportFailed => '配置导出失败';

  @override
  String get configImportTitle => '导入配置';

  @override
  String get configImportSubtitle => '从YAML文件恢复配置';

  @override
  String get configImportNoFilePath => '未选择文件';

  @override
  String get configImportConfirmTitle => '确认导入';

  @override
  String get configImportSuccess => '配置导入成功';

  @override
  String get configImportFailed => '配置导入失败';

  @override
  String get configImportRestartTitle => '需要重启';

  @override
  String get configImportRestartMessage => '配置已导入，部分配置需要重启应用后生效。';

  @override
  String get configImportOverwriteWarning => '导入将覆盖现有配置，建议先备份当前配置。';

  @override
  String get configImportExportIncludesTitle => '包含的配置项';

  @override
  String configExportSavedTo(String path) {
    return '已保存至: $path';
  }

  @override
  String get configExportViewContent => '查看内容';

  @override
  String get configExportCopyContent => '复制内容';

  @override
  String get configExportContentCopied => '已复制到剪贴板';

  @override
  String get configExportReadFileFailed => '读取文件失败';

  @override
  String get configIncludeLedgers => '账本';

  @override
  String get configIncludeSupabase => 'Supabase 云服务配置';

  @override
  String get configIncludeWebdav => 'WebDAV 云服务配置';

  @override
  String get configIncludeS3 => 'S3 云服务配置';

  @override
  String get configIncludeSpitoutCloud => 'Spitout Cloud 云服务配置';

  @override
  String get configIncludeAppSettings => '应用设置（提醒、语言、外观、字体、同步等）';

  @override
  String get configIncludeRecurringTransactions => '周期账单';

  @override
  String get configIncludeCategories => '分类';

  @override
  String get configIncludeOtherSettings => '其他设置';

  @override
  String get configIncludeOtherSettingsSubtitle => '包含云服务配置和应用设置';

  @override
  String get configExportSelectTitle => '选择导出内容';

  @override
  String get configExportPreviewTitle => '导出预览';

  @override
  String get configExportConfirmTitle => '确认导出';

  @override
  String get configImportSelectTitle => '选择导入内容';

  @override
  String get configImportPreviewTitle => '导入预览';

  @override
  String get ledgersConflictTitle => '同步冲突';

  @override
  String get ledgersConflictMessage => '本地和云端账本数据不一致，请选择操作：';

  @override
  String ledgersConflictLocalInfo(int count) {
    return '本地：$count 笔账单';
  }

  @override
  String ledgersConflictRemoteInfo(int count) {
    return '云端：$count 笔账单';
  }

  @override
  String ledgersConflictRemoteUpdated(String time) {
    return '云端更新：$time';
  }

  @override
  String ledgersConflictLocalFingerprint(String fp) {
    return '本地指纹：$fp';
  }

  @override
  String ledgersConflictRemoteFingerprint(String fp) {
    return '云端指纹：$fp';
  }

  @override
  String get ledgersConflictUpload => '上传到云端';

  @override
  String get ledgersConflictDownload => '下载到本地';

  @override
  String get ledgersConflictUploading => '正在上传...';

  @override
  String get ledgersConflictDownloading => '正在下载...';

  @override
  String get ledgersConflictUploadSuccess => '上传成功';

  @override
  String ledgersConflictDownloadSuccess(int inserted) {
    return '下载成功，已合并 $inserted 笔账单';
  }

  @override
  String get welcomeExistingUserTitle => '老用户？';

  @override
  String get welcomeExistingUserButton => '导入配置';

  @override
  String get welcomeImportingConfig => '正在导入配置...';

  @override
  String get welcomeImportSuccess => '配置导入成功';

  @override
  String welcomeImportFailed(String error) {
    return '配置导入失败: $error';
  }

  @override
  String get welcomeImportNoFile => '未选择文件';

  @override
  String get calendarTitle => '日历';

  @override
  String get calendarToday => '回到今天';

  @override
  String get calendarNoTransactions => '当天无交易';

  @override
  String get calendarAddTransaction => '在该日记账';

  @override
  String get commonUncategorized => '未分类';

  @override
  String get syncPreviewTitle => '同步预览';

  @override
  String get syncPreviewSelectAll => '全选';

  @override
  String get syncPreviewDeselectAll => '取消全选';

  @override
  String get syncPreviewAdded => '新增';

  @override
  String get syncPreviewModified => '修改';

  @override
  String get syncPreviewDeleted => '删除';

  @override
  String syncPreviewAddedCount(int count) {
    return '新增 $count 条';
  }

  @override
  String syncPreviewModifiedCount(int count) {
    return '修改 $count 条';
  }

  @override
  String syncPreviewDeletedCount(int count) {
    return '删除 $count 条';
  }

  @override
  String syncPreviewApply(int count) {
    return '应用 $count 项';
  }

  @override
  String get syncPreviewEmpty => '云端数据与本地一致，无需同步';

  @override
  String get syncPreviewOldFormat => '云端数据格式较旧，将执行全量替换';

  @override
  String get syncPreviewOldFormatMessage => '云端数据不包含同步标识，无法逐条对比。将清空当前账本数据并从云端重新导入。';

  @override
  String syncPreviewApplied(int count) {
    return '已应用 $count 项变更';
  }

  @override
  String get cloudSyncGuideTitle => '云同步使用指南';

  @override
  String get cloudSyncGuideGotIt => '我知道了';

  @override
  String get cloudSyncGuideHowItWorks => '工作原理';

  @override
  String get cloudSyncGuideHowItem1 => '上传：将当前账本的全部数据打包上传到云端，覆盖云端旧数据';

  @override
  String get cloudSyncGuideHowItem2 => '下载：从云端拉取数据，与本地逐条对比差异，你可以选择要同步哪些变更';

  @override
  String get cloudSyncGuideHowItem3 => '云端始终只保存最后一次上传的完整快照，不保留历史版本';

  @override
  String get cloudSyncGuideCorrect => '正确的使用方式';

  @override
  String get cloudSyncGuideCorrectItem1 => '同一时间只在一台设备上记账，完成后上传';

  @override
  String get cloudSyncGuideCorrectItem2 => '切换设备前，先在新设备上下载同步';

  @override
  String get cloudSyncGuideCorrectItem3 => '下载时仔细查看预览，确认每条变更再应用';

  @override
  String get cloudSyncGuideCorrectItem4 => '养成「编辑→上传→切换设备→下载→编辑」的习惯';

  @override
  String get cloudSyncGuideWrong => '应避免的用法';

  @override
  String get cloudSyncGuideWrongItem1 => '两台设备同时编辑同一个账本，后上传的会覆盖先上传的改动';

  @override
  String get cloudSyncGuideWrongItem2 => '上传后立刻在另一台设备下载，文件服务可能有几秒到几分钟的同步延迟，等一会再试';

  @override
  String get cloudSyncGuideWrongItem3 => '长时间不同步后一次性下载大量变更，容易遗漏需要处理的差异';

  @override
  String get cloudSyncGuideLimitations => '已知限制';

  @override
  String get cloudSyncGuideLimitItem1 => '非实时同步：需要手动点击上传和下载';

  @override
  String get cloudSyncGuideLimitItem2 => '无冲突合并：不会自动合并两端的修改，以最后上传的为准';

  @override
  String get cloudSyncGuideLimitItem3 => '文件服务延迟：上传后云端文件可能需要几秒到几分钟才能被其他设备读取，取决于你使用的云服务';

  @override
  String get appLockTitle => '应用上锁';

  @override
  String get appLockDesc => 'PIN码与生物识别保护隐私';

  @override
  String get appLockEnable => '启用应用锁';

  @override
  String get appLockEnableDesc => '启动和切回应用时需要验证身份';

  @override
  String get appLockSetPin => '设置密码';

  @override
  String get appLockChangePin => '修改密码';

  @override
  String get appLockVerifyPin => '验证密码';

  @override
  String get appLockVerifyCurrentPin => '请输入当前密码';

  @override
  String get appLockSetNewPin => '请设置新密码';

  @override
  String get appLockConfirmPin => '请再次输入密码';

  @override
  String get appLockEnterPin => '请输入密码';

  @override
  String get appLockPinSetSuccess => '密码设置成功';

  @override
  String get appLockDisabled => '应用锁已关闭';

  @override
  String get appLockBiometric => '生物识别解锁';

  @override
  String get appLockBiometricDesc => '使用Face ID或指纹快速解锁';

  @override
  String get appLockBiometricReason => '请验证身份以解锁Spitout';

  @override
  String get appLockTimeout => '自动锁定时间';

  @override
  String get appLockTimeoutImmediate => '立即';

  @override
  String get appLockTimeout1Min => '1分钟后';

  @override
  String get appLockTimeout5Min => '5分钟后';

  @override
  String get appLockTimeout15Min => '15分钟后';

  @override
  String dayOfMonth(int day) {
    return '每月$day日';
  }

  @override
  String get syncHealthTitle => '同步状态';

  @override
  String get cloudSyncHelpTitle => '同步说明 · 为什么有时同步不动？';

  @override
  String get cloudSyncHelpModesTitle => '三种同步方式';

  @override
  String get cloudSyncHelpModesBody => '• 增量同步（日常自动）：记一笔 / 改一笔后，只把这条变化自动上传下载，快、无需手动操作 —— 平时一直在跑的就是它。\n• 全量上传：首次开启云同步、或云端还没有这个账本的数据时，把本地全部数据一次性推上云。\n• 全量下载：换新设备、重装、或本地为空时，从云端把全部数据拉下来。';

  @override
  String get cloudSyncHelpWhenFullTitle => '什么时候才会走全量？';

  @override
  String get cloudSyncHelpWhenFullBody => '全量只在某一端数据为空时才会自动触发（首次开启云同步 / 换新设备 / 重装 / 清空了本地或云端数据）。只要两端都有数据，之后一直走增量，不会无故重来。想强制重新全量同步，得先清空对应端的数据。';

  @override
  String get cloudSyncHelpStuckTitle => '为什么有时同步不动 / 卡住';

  @override
  String get cloudSyncHelpStuckBody => '• 全量上传 / 下载不支持断点续传：中途断网、或 App 被切到后台被系统杀掉，会从头重来，不会接着传。数据多时请用稳定网络（建议 Wi-Fi）耐心等它跑完，别中途切走。\n• 增量同步是断点安全的，日常同步不受影响。';

  @override
  String get cloudSyncHelpTroubleshootTitle => '排查办法';

  @override
  String get cloudSyncHelpTroubleshootBody => '• 先在本页下拉做一次「深度检测」，对比本地与云端差异。\n• 仍有问题，去「日志中心」查看同步日志（含失败原因），方便反馈。';

  @override
  String get cloudSyncHelpOpenLogCenter => '打开日志中心';

  @override
  String syncHealthCheckFailed(String msg) {
    return '检测失败：$msg';
  }

  @override
  String get syncHealthRecovering => '登录状态恢复中…';

  @override
  String get syncHealthNeedsLogin => '未登录或登录已失效，请重新登录云同步';

  @override
  String get syncHealthHasDiff => '检测到差异，已自动同步';

  @override
  String get cloudSyncHealFailed => '自动恢复失败，请从云端恢复';

  @override
  String get syncHealthInSync => '本地与云端一致';

  @override
  String get syncHealthGroupCurrentLedger => '当前账本';

  @override
  String get syncHealthGroupAll => '全部账本';

  @override
  String get syncHealthRowTx => '交易';

  @override
  String get syncHealthRowCategory => '分类';

  @override
  String get syncHealthRowUnpushed => '未推送变更';

  @override
  String syncHealthValue(int local, int remote) {
    return '本地 $local · 云端 $remote';
  }

  @override
  String syncHealthValueRemoteMissing(int local) {
    return '本地 $local · 云端 —';
  }

  @override
  String get twofaChallengeTitle => '二次验证';

  @override
  String get twofaMethodTotp => '动态码';

  @override
  String get twofaMethodRecovery => '恢复码';

  @override
  String get twofaTotpInputPlaceholder => '输入 6 位动态码';

  @override
  String get twofaRecoveryInputPlaceholder => '输入恢复码';

  @override
  String get twofaVerifyButton => '验证';

  @override
  String get twofaStatusTitle => '二次验证';

  @override
  String get twofaStatusEnabled => '已启用 ✓';

  @override
  String get twofaStatusDisabled => '未启用';

  @override
  String twofaStatusEnabledAt(String date) {
    return '启用于 $date';
  }

  @override
  String get sharedRoleOwner => '所有者';

  @override
  String get sharedRoleEditor => '编辑者';

  @override
  String get commonCopied => '已复制';

  @override
  String get commonRemove => '移除';

  @override
  String get sharedJoinPageTitle => '加入共享账本';

  @override
  String get sharedJoinPageSubtitle => '输入邀请码或点击对方分享的链接';

  @override
  String get sharedJoinEnterCode => '输入邀请码';

  @override
  String get sharedJoinEnterCodeHint => '邀请码 6 位,全大写字母数字。也可直接点击邀请方分享的短链跳过此步。';

  @override
  String get sharedJoinPreviewButton => '验证邀请码';

  @override
  String get sharedJoinAcceptButton => '加入账本';

  @override
  String sharedJoinInvitedBy(String name) {
    return '$name 邀请你加入';
  }

  @override
  String sharedJoinRoleLine(String role) {
    return '角色:$role';
  }

  @override
  String sharedJoinExpiresInMinutes(int n) {
    return '有效期还剩 $n 分钟';
  }

  @override
  String sharedJoinExpiresInHours(int n) {
    return '有效期还剩 $n 小时';
  }

  @override
  String sharedJoinExpiresInDays(int n) {
    return '有效期还剩 $n 天';
  }

  @override
  String sharedJoinSuccess(String name) {
    return '已加入「$name」';
  }

  @override
  String get sharedJoinCodeFormatError => '邀请码格式不对,请输入 6 位字母数字';

  @override
  String get sharedJoinInvalidOrExpired => '邀请码无效或已过期,请向邀请人索取新码';

  @override
  String get sharedJoinAlreadyMember => '你已经是该账本成员';

  @override
  String get sharedJoinMemberLimit => '该账本成员已满,请联系账本所有者';

  @override
  String get sharedInviteFormRole => '角色';

  @override
  String get sharedInviteFormExpiry => '有效期';

  @override
  String sharedInviteExpiryHours(int n) {
    return '$n 小时';
  }

  @override
  String sharedInviteExpiryDays(int n) {
    return '$n 天';
  }

  @override
  String get sharedInviteGenerate => '生成邀请码';

  @override
  String get sharedInviteGenerateAnother => '生成另一个邀请码';

  @override
  String get sharedInviteCopyCode => '复制邀请码';

  @override
  String get sharedInviteCopyLink => '复制链接';

  @override
  String get sharedInviteShareLink => '分享给好友';

  @override
  String sharedInviteExpiresAt(String dt) {
    return '邀请将在 $dt 失效';
  }

  @override
  String get sharedInviteWarning => '⚠️ 不要把邀请码发到公开群 / 朋友圈。拿到码的任何人都可加入账本;泄露后请到成员管理页撤销并重新生成。';

  @override
  String get sharedInviteInstruction => '把邀请码或短链发给对方。对方装上 Spitout 后,点击链接或在「我的 → 加入共享账本」输入码即可加入。';

  @override
  String sharedInviteShareText(String ledger, String code, String url) {
    return '邀请你加入 Spitout 共享账本「$ledger」\n\n邀请码:$code\n链接:$url\n\n点击链接或在 Spitout → 我的 → 加入共享账本输入此码即可。';
  }

  @override
  String get sharedMembersPageTitle => '成员管理';

  @override
  String get sharedMembersYou => '你';

  @override
  String get sharedMembersInviteCta => '邀请新成员';

  @override
  String get ledgersLeaveAndDelete => '退出并删除';

  @override
  String get ledgersLeaveAndDeleteConfirm => '退出并删除账本';

  @override
  String ledgersLeaveAndDeleteMessage(String name) {
    return '确定要退出并删除共享账本「$name」吗？\\n退出后云端将移除你的成员身份，本地数据全部清空，且无法再访问其中的交易。';
  }

  @override
  String get ledgersLeaveAndDeleteSuccess => '已退出并删除账本';

  @override
  String get ledgersDeleteShared => '删除共享账本';

  @override
  String get ledgersDeleteSharedConfirm => '删除共享账本';

  @override
  String ledgersDeleteSharedMessage(String name) {
    return '确定要删除共享账本「$name」吗？\\n此操作会一并移除所有协作者并清空他们的本地数据，不可恢复。';
  }

  @override
  String get ledgersDeleteSharedSuccess => '已删除共享账本';

  @override
  String get sharedMembersRemoveTitle => '移除成员';

  @override
  String get sharedMembersRemoveCta => '移除该成员';

  @override
  String sharedMembersRemoveConfirm(String name) {
    return '确定移除 $name?ta 将立即失去对该账本的访问。';
  }

  @override
  String get sharedMembersRemoved => '已移除成员';

  @override
  String get sharedMembersSyncPending => '首次创建账本需要先在账本管理页面选中本账本，重新进入页面才可邀请成员';

  @override
  String get sharedMembersSaveFirst => '请先保存账本';

  @override
  String sharedTxCreatedBy(String name) {
    return '$name 创建';
  }

  @override
  String sharedTxEditedBy(String name) {
    return '$name 最后编辑';
  }

  @override
  String sharedTxCreatedAndEditedBy(String name) {
    return '$name 创建并编辑';
  }

  @override
  String get sharedRequiresCloudSync => '请先启用云同步';

  @override
  String get sharedMembersStatsTitle => '成员支出';

  @override
  String get sharedMembersStatsEmpty => '暂无记账';

  @override
  String sharedMembersStatsTxCount(int count) {
    return '$count笔';
  }

  @override
  String get maintenanceOrphanCleanupTitle => '数据清理';

  @override
  String get maintenanceOrphanCleanupSubtitle => '检查并清理本地孤儿数据';

  @override
  String get maintenanceOrphanRescan => '重新扫描';

  @override
  String get maintenanceOrphanEmpty => '本地数据干净,未发现孤儿数据';

  @override
  String get maintenanceOrphanGroupDb => '数据库孤儿';

  @override
  String get maintenanceOrphanGroupSync => '同步状态孤儿';

  @override
  String maintenanceOrphanSummary(int count) {
    return '发现 $count 项异常';
  }

  @override
  String get maintenanceOrphanSelectAll => '全选';

  @override
  String get maintenanceOrphanDeselectAll => '取消全选';

  @override
  String get maintenanceOrphanDeleteOne => '删除此项';

  @override
  String maintenanceOrphanSelectedHint(int count) {
    return '已选 $count 项';
  }

  @override
  String get maintenanceOrphanCleanSelected => '清理已选';

  @override
  String get maintenanceOrphanConfirmTitle => '确认清理';

  @override
  String maintenanceOrphanConfirmDeleteOne(String title) {
    return '确定清理「$title」吗？操作不可撤销。';
  }

  @override
  String maintenanceOrphanConfirmDeleteBatch(int count) {
    return '确定清理选中的 $count 项吗？操作不可撤销。';
  }

  @override
  String maintenanceOrphanCleanSuccess(int count) {
    return '已清理 $count 项';
  }

  @override
  String maintenanceOrphanCleanPartial(int ok, int fail) {
    return '成功 $ok 项,失败 $fail 项';
  }

  @override
  String maintenanceOrphanDeletedLedgerGroup(int ledgerId, int count) {
    return '已删账本 #$ledgerId（$count 笔）';
  }

  @override
  String get maintenanceOrphanMoveSingle => '移动到账本';

  @override
  String get maintenanceOrphanMoveToLedger => '移动到账本';

  @override
  String maintenanceOrphanMoveToLedgerSuccess(int count) {
    return '已将 $count 笔移动到账本';
  }

  @override
  String get exchangeRatePageTitle => '汇率管理';

  @override
  String get exchangeRateEntrySubtitle => '自动获取汇率，支持手动修正';

  @override
  String get rateSourceAuto => '自动';

  @override
  String get rateSourceManual => '手动';

  @override
  String rateUpdatedAt(String date) {
    return '$date 更新';
  }

  @override
  String get rateNotFetched => '未获取';

  @override
  String get rateEditTitle => '编辑汇率';

  @override
  String rateInverseHint(String base, String rate, String quote) {
    return '反向参考:1 $base ≈ $rate $quote';
  }

  @override
  String get rateResetToAuto => '恢复自动';

  @override
  String get rateRefreshSuccess => '汇率已更新';

  @override
  String get rateRefreshFailed => '获取失败,可手动设置汇率';

  @override
  String get rateDisclaimer => '数据来源:开源汇率数据,每日更新;折算仅供参考,可能与银行实际牌价有差异。';

  @override
  String get txFlagExcludedTag => '不计收支';

  @override
  String get txRateLabel => '汇率';

  @override
  String get txRateMissingHint => '请手动填写本笔汇率后保存';

  @override
  String get ledgerBaseCurrencyLabel => '主币种';

  @override
  String statsConvertedFootnote(Object currency) {
    return '含外币,已按各笔记账时汇率折算为 $currency';
  }

  @override
  String get ledgerCurrencyChangeRecalcHint => '修改本位币将按当前汇率重算全部历史交易的折算值';

  @override
  String get ledgerCurrencyChangeRecalcWarning => '历史折算值将按最新汇率重算并覆盖，往返切换（切走再切回）也无法还原原始折算值';

  @override
  String get recalcForeignTxBanner => '检测到该账本有未折算的外币交易';

  @override
  String get recalcForeignTxAction => '按当前汇率重算折算';

  @override
  String recalcForeignTxDone(Object count) {
    return '已重算 $count 笔外币交易的折算值';
  }

  @override
  String get txCurrencyPickerTitle => '选择币种';

  @override
  String get txAddEntryTitle => '记一笔';

  @override
  String get txDeleteLongPress => '长按清空';

  @override
  String get txSelectDateTimeTitle => '选择交易时间';

  @override
  String get txSelectDateTimeHint => '上下滑动数字以选择时间';

  @override
  String get txEditCategory => '编辑分类';

  @override
  String get txEditCategoryReadOnly => '编辑分类（共享账本只读）';

  @override
  String get txLedgerBaseCurrency => '账本主币种';

  @override
  String recalcSyncCountHint(Object count) {
    return '将重算并同步 $count 笔交易';
  }

  @override
  String get analyticsLoadFailed => '数据加载失败，请检查网络';

  @override
  String get analyticsRetry => '重试';

  @override
  String get exportCsvHeaderCurrency => '币种';

  @override
  String get importFieldCurrency => '币种';

  @override
  String get currencyMOP => '澳门元';

  @override
  String get currencyMNT => '蒙古图格里克';

  @override
  String get currencyKPW => '朝鲜元';

  @override
  String get currencyKHR => '柬埔寨瑞尔';

  @override
  String get currencyLAK => '老挝基普';

  @override
  String get currencyBND => '文莱元';

  @override
  String get currencyNPR => '尼泊尔卢比';

  @override
  String get currencyBTN => '不丹努尔特鲁姆';

  @override
  String get currencyMVR => '马尔代夫拉菲亚';

  @override
  String get currencyAFN => '阿富汗尼';

  @override
  String get currencyUZS => '乌兹别克斯坦索姆';

  @override
  String get currencyTJS => '塔吉克斯坦索莫尼';

  @override
  String get currencyTMT => '土库曼斯坦马纳特';

  @override
  String get currencyKGS => '吉尔吉斯斯坦索姆';

  @override
  String get currencyQAR => '卡塔尔里亚尔';

  @override
  String get currencyKWD => '科威特第纳尔';

  @override
  String get currencyBHD => '巴林第纳尔';

  @override
  String get currencyOMR => '阿曼里亚尔';

  @override
  String get currencyJOD => '约旦第纳尔';

  @override
  String get currencyLBP => '黎巴嫩镑';

  @override
  String get currencyIQD => '伊拉克第纳尔';

  @override
  String get currencyIRR => '伊朗里亚尔';

  @override
  String get currencyYER => '也门里亚尔';

  @override
  String get currencySYP => '叙利亚镑';

  @override
  String get currencyGEL => '格鲁吉亚拉里';

  @override
  String get currencyAMD => '亚美尼亚德拉姆';

  @override
  String get currencyAZN => '阿塞拜疆马纳特';

  @override
  String get currencyRON => '罗马尼亚列伊';

  @override
  String get currencyBGN => '保加利亚列弗';

  @override
  String get currencyRSD => '塞尔维亚第纳尔';

  @override
  String get currencyISK => '冰岛克朗';

  @override
  String get currencyMDL => '摩尔多瓦列伊';

  @override
  String get currencyALL => '阿尔巴尼亚列克';

  @override
  String get currencyMKD => '北马其顿第纳尔';

  @override
  String get currencyBAM => '波黑可兑换马克';

  @override
  String get currencyGIP => '直布罗陀镑';

  @override
  String get currencyGTQ => '危地马拉格查尔';

  @override
  String get currencyHNL => '洪都拉斯伦皮拉';

  @override
  String get currencyNIO => '尼加拉瓜科多巴';

  @override
  String get currencyCRC => '哥斯达黎加科朗';

  @override
  String get currencyPAB => '巴拿马巴波亚';

  @override
  String get currencyDOP => '多米尼加比索';

  @override
  String get currencyCUP => '古巴比索';

  @override
  String get currencyJMD => '牙买加元';

  @override
  String get currencyTTD => '特立尼达和多巴哥元';

  @override
  String get currencyBSD => '巴哈马元';

  @override
  String get currencyBBD => '巴巴多斯元';

  @override
  String get currencyBZD => '伯利兹元';

  @override
  String get currencyHTG => '海地古德';

  @override
  String get currencyKYD => '开曼群岛元';

  @override
  String get currencyAWG => '阿鲁巴弗罗林';

  @override
  String get currencyBMD => '百慕大元';

  @override
  String get currencyUYU => '乌拉圭比索';

  @override
  String get currencyPYG => '巴拉圭瓜拉尼';

  @override
  String get currencyBOB => '玻利维亚诺';

  @override
  String get currencyVES => '委内瑞拉玻利瓦尔';

  @override
  String get currencyGYD => '圭亚那元';

  @override
  String get currencySRD => '苏里南元';

  @override
  String get currencyFJD => '斐济元';

  @override
  String get currencyPGK => '巴布亚新几内亚基那';

  @override
  String get currencySBD => '所罗门群岛元';

  @override
  String get currencyTOP => '汤加潘加';

  @override
  String get currencyVUV => '瓦努阿图瓦图';

  @override
  String get currencyWST => '萨摩亚塔拉';

  @override
  String get currencyKES => '肯尼亚先令';

  @override
  String get currencyGHS => '加纳塞地';

  @override
  String get currencyMAD => '摩洛哥迪拉姆';

  @override
  String get currencyDZD => '阿尔及利亚第纳尔';

  @override
  String get currencyTND => '突尼斯第纳尔';

  @override
  String get currencyLYD => '利比亚第纳尔';

  @override
  String get currencyETB => '埃塞俄比亚比尔';

  @override
  String get currencyUGX => '乌干达先令';

  @override
  String get currencyTZS => '坦桑尼亚先令';

  @override
  String get currencyRWF => '卢旺达法郎';

  @override
  String get currencyMUR => '毛里求斯卢比';

  @override
  String get currencyBWP => '博茨瓦纳普拉';

  @override
  String get currencyNAD => '纳米比亚元';

  @override
  String get currencyZMW => '赞比亚克瓦查';

  @override
  String get currencyMWK => '马拉维克瓦查';

  @override
  String get currencyMZN => '莫桑比克梅蒂卡尔';

  @override
  String get currencyAOA => '安哥拉宽扎';

  @override
  String get currencyCDF => '刚果法郎';

  @override
  String get currencyGMD => '冈比亚达拉西';

  @override
  String get currencyGNF => '几内亚法郎';

  @override
  String get currencyLRD => '利比里亚元';

  @override
  String get currencySLE => '塞拉利昂利昂';

  @override
  String get currencySDG => '苏丹镑';

  @override
  String get currencySSP => '南苏丹镑';

  @override
  String get currencySOS => '索马里先令';

  @override
  String get currencyDJF => '吉布提法郎';

  @override
  String get currencyERN => '厄立特里亚纳克法';

  @override
  String get currencyBIF => '布隆迪法郎';

  @override
  String get currencyCVE => '佛得角埃斯库多';

  @override
  String get currencySTN => '圣多美多布拉';

  @override
  String get currencySCR => '塞舌尔卢比';

  @override
  String get currencyKMF => '科摩罗法郎';

  @override
  String get currencyLSL => '莱索托洛蒂';

  @override
  String get currencySZL => '斯威士兰里兰吉尼';

  @override
  String get currencyMGA => '马达加斯加阿里亚里';

  @override
  String get currencyMRU => '毛里塔尼亚乌吉亚';

  @override
  String get detailImportExportTitle => '明细导入导出';

  @override
  String get detailImportExportSubtitle => '支出明细csv格式文件';

  @override
  String get detailImportExportImportTitle => '导入明细';

  @override
  String get detailImportExportImportSubtitle => '支持 CSV/TSV/XLSX，兼容支付宝、微信账单';

  @override
  String get detailImportExportExportTitle => '导出明细';

  @override
  String get detailImportExportExportSubtitle => '将账本明细导出为 CSV 文件';

  @override
  String get detailImportExportImportPoint1 => '支持通用 CSV、支付宝、微信三类账单，文件格式可为 CSV/TSV/XLSX';

  @override
  String get detailImportExportImportPoint2 => '差异仅在文件结构：通用 CSV 为纯净表头；支付宝、微信账单含描述性前言，应用自动跳过并定位表头';

  @override
  String get detailImportExportImportPoint3 => '三类账单统一通过列映射识别（日期、类型、金额、币种、分类、二级分类、备注），导入流程一致';

  @override
  String get detailImportExportExportPoint1 => '将所选账本交易明细导出为 CSV 文件，UTF-8 BOM 编码，Excel 可直接打开';

  @override
  String get detailImportExportExportPoint2 => '文件名为 spitout_时间戳.csv，默认保存至系统 Download/Spitout 目录';

  @override
  String get detailImportExportExportPoint3 => '包含字段如下：';

  @override
  String get detailExportLedgerLabel => '导出账本';

  @override
  String get detailExportSelectAllLabel => '全选数据';

  @override
  String get detailExportSelectAllSubtitle => '导出所选账本下的全部数据';

  @override
  String get detailExportStartDate => '开始日期';

  @override
  String get detailExportEndDate => '结束日期';

  @override
  String get detailExportDateInvalid => '开始日期不能晚于结束日期';

  @override
  String get detailExportAction => '导出';

  @override
  String exchangeRateCurrentLedger(Object name) {
    return '当前账本：$name';
  }

  @override
  String get exchangeRateInfoTitle => '关于主币种';

  @override
  String get exchangeRateInfoMessage => '主币种是当前账本的本位币：账本内的外币交易会按汇率折算成主币种，在统计页和资产总览中统一汇总比较。每个账本各有自己的主币种，你可以随时切换；切换后将按最新汇率重算本账本全部交易的折算值。\n\n汇率默认从公开数据源每日自动拉取，也支持你点击下方列表中的「编辑」为任意币种手动设置汇率——手动汇率会覆盖自动数据并立即生效。';

  @override
  String get rateEditLabel => '编辑';

  @override
  String get rateInvalidInput => '请输入有效的汇率值（大于 0 的数字）';

  @override
  String get currencyManageTitle => '管理展示币种';

  @override
  String get currencyManageEntry => '币种管理';

  @override
  String currencyManageCount(Object count) {
    return '已选 $count 个币种';
  }

  @override
  String get currencyManageBaseLocked => '账本本位币，不可隐藏';

  @override
  String get currencyManageHint => '隐藏的币种不影响已有交易记录，可随时在此重新启用。';

  @override
  String get detailImportExportMigrateTitle => '账本数据迁移';

  @override
  String get detailImportExportMigrateTip => '你可以先将当前账本数据导出为 CSV 文件，再切换到目标账本导入该文件，即可实现账本间数据的平滑迁移。';

  @override
  String get mineCheckUpdate => '检查更新';

  @override
  String get updateChecking => '正在检查更新…';

  @override
  String get updateAvailableTitle => '发现新版本';

  @override
  String updateLatestVersion(String version) {
    return '最新版本 v$version';
  }

  @override
  String get updateAlreadyLatestTitle => '已是最新版本';

  @override
  String updateAlreadyLatest(String version) {
    return '当前已是最新版本 v$version';
  }

  @override
  String get updateGotoDownload => '前往下载';

  @override
  String updateCurrentVersion(String version) {
    return '当前版本 v$version';
  }

  @override
  String updateNewVersionHint(String version) {
    return '发现新版本 v$version';
  }

  @override
  String get updateLater => '稍后再说';

  @override
  String get updateOk => '好的';

  @override
  String get updateCantAutoCheckTitle => '无法自动检查更新';

  @override
  String get updateCantAutoCheck => '无法获取版本信息，可前往 GitHub 查看最新版本';

  @override
  String get updateGoToGithub => '前往 GitHub 查看';

  @override
  String get mineUpdateNow => '更新';

  @override
  String get ledgerMetaReadOnlyToast => '协作者无权修改账本信息';

  @override
  String get aaSettlementTitle => '分摊统计';

  @override
  String get aaSettlementOverview => '汇总';

  @override
  String get aaSettlementTotalAmount => '分摊总额';

  @override
  String aaSettlementTxCount(int count) {
    return '$count 笔分摊交易';
  }

  @override
  String get aaSettlementPerPerson => '分摊详情';

  @override
  String get aaSettlementPaid => '实付';

  @override
  String get aaSettlementShare => '应摊';

  @override
  String get aaSettlementNet => '差额';

  @override
  String get aaSettlementNetReceive => '应收';

  @override
  String get aaSettlementNetPay => '应付';

  @override
  String get aaSettlementTransferPlan => '转账方案';

  @override
  String aaSettlementTransferPayTo(String from, String to) {
    return '$from 付给 $to';
  }

  @override
  String get aaSettlementNoTransfers => '已结清，无需转账';

  @override
  String get aaSettlementExcluded => '不计入详单';

  @override
  String aaSettlementParticipantCount(int count) {
    return '分摊人数 $count 人';
  }

  @override
  String get aaSettlementExcludedEmpty => '暂无不计入详单的交易';

  @override
  String get aaEditTitle => '分摊明细';

  @override
  String get aaPayer => '支出人';

  @override
  String get aaSplitMode => '分摊方式';

  @override
  String get aaParticipants => '参与人';

  @override
  String get aaSplitAmounts => '指定金额';

  @override
  String get aaModePerPerson => '人均分摊';

  @override
  String get aaModeCustom => '指定分摊';

  @override
  String get aaModeNoSplit => '不分摊';

  @override
  String get aaSplitClearAll => '清空重填';

  @override
  String get aaParticipantsAll => '全部成员';

  @override
  String aaParticipantsSelected(int count) {
    return '已选 $count 人';
  }

  @override
  String get aaSplitTotal => '合计';

  @override
  String get aaSplitPayerAdjustHint => '差额由支出人兜底';

  @override
  String get aaVirtualUserTitle => '虚拟用户';

  @override
  String get aaVirtualUserAdd => '新建虚拟用户';

  @override
  String get aaVirtualUserNameHint => '输入昵称';

  @override
  String get aaVirtualUserRename => '重命名';

  @override
  String get aaVirtualUserEmpty => '暂无虚拟用户';

  @override
  String aaVirtualUserDeleteConfirm(String name) {
    return '确定删除虚拟用户「$name」吗？';
  }

  @override
  String get aaVirtualUserInUse => '该虚拟用户名下有账，不可删除';

  @override
  String aaVirtualUserDefaultName(int index) {
    return '虚拟用户$index';
  }

  @override
  String get aaAddVirtualUser => '添加虚拟用户';

  @override
  String get aaUnknownUser => '未知';

  @override
  String get aaMe => '我';

  @override
  String get aaPerPersonAllMembers => '人均分摊（全部成员）';

  @override
  String get ledgerAaEnabled => 'AA 分摊';

  @override
  String get ledgerAaEnabledHint => '开启后记账时可选择分摊方式';

  @override
  String get ledgerAaSettlementEntry => '查看分摊结算';

  @override
  String get ledgerAaVirtualUsersEntry => '管理虚拟用户';

  @override
  String get aaNoParticipants => '请先添加参与人';

  @override
  String get aaSplitAmountIncomplete => '请填写全部参与人的金额';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw(): super('zh_TW');

  @override
  String get appTitle => 'Spitout';

  @override
  String get tabHome => '明細';

  @override
  String get tabAnalytics => '統計';

  @override
  String get tabCalendar => '日曆';

  @override
  String get tabMine => '我的';

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '確定';

  @override
  String get commonSave => '儲存';

  @override
  String get commonDelete => '刪除';

  @override
  String get commonAdd => '新增';

  @override
  String get commonOk => '確定';

  @override
  String get commonDone => '完成';

  @override
  String get homeSelectBillMonth => '選擇帳單月份';

  @override
  String get homePickerHint => '上下滑動數字以選擇時間';

  @override
  String get homeBackToCurrentMonth => '回到當月';

  @override
  String get homeTodayExpense => '今日';

  @override
  String get homeWeekExpense => '本週';

  @override
  String get homeMonthExpense => '本月支出';

  @override
  String get homeDetailCategory => '分類';

  @override
  String get homeDetailDate => '記帳日期';

  @override
  String get homeDetailAmount => '記帳金額';

  @override
  String get homeDetailCurrency => '貨幣';

  @override
  String get homeDetailNativeAmount => '折合主貨幣';

  @override
  String get homeDetailMembers => '協作成員';

  @override
  String get homeDetailCreator => '建立者';

  @override
  String get homeDetailLastEditor => '最後編輯';

  @override
  String get homeDetailEditHistory => '編輯記錄';

  @override
  String get homeDetailEditHistoryHint => '僅供查看';

  @override
  String get homeDetailEditButton => '編輯記帳';

  @override
  String get homeDetailNoHistory => '暫無編輯歷史';

  @override
  String get homeDeleteDetailTitle => '刪除這條明細?';

  @override
  String homeDeleteDetailMessage(Object name) {
    return '將刪除\"$name\"記錄,此操作無法復原。';
  }

  @override
  String get commonEmpty => '暫無資料';

  @override
  String get commonError => '錯誤';

  @override
  String get commonFailed => '失敗';

  @override
  String get commonBack => '返回';

  @override
  String get commonNext => '下一步';

  @override
  String get commonFinish => '完成';

  @override
  String get commonOther => '其他';

  @override
  String get commonSearch => '搜尋';

  @override
  String get commonNoteHint => '備註…';

  @override
  String get commonSettings => '設定';

  @override
  String get commonCurrent => '當前';

  @override
  String get commonTutorial => '教學';

  @override
  String get commonConfigure => '配置';

  @override
  String get commonPressAgainToExit => '再按一次退出應用程式';

  @override
  String get commonWeekdayMonday => '星期一';

  @override
  String get commonWeekdayTuesday => '星期二';

  @override
  String get commonWeekdayWednesday => '星期三';

  @override
  String get commonWeekdayThursday => '星期四';

  @override
  String get commonWeekdayFriday => '星期五';

  @override
  String get commonWeekdaySaturday => '星期六';

  @override
  String get commonWeekdaySunday => '星期日';

  @override
  String get homeExpense => '支出';

  @override
  String get homeNoRecords => '還沒有記帳';

  @override
  String get homeSelectDate => '選擇日期';

  @override
  String homeYear(int year) {
    return '$year年';
  }

  @override
  String homeMonth(String month) {
    return '$month月';
  }

  @override
  String homeMonthExpenseOf(String month) {
    return '$month月支出';
  }

  @override
  String get homeNoRecordsSubtext => '點擊底部加號，馬上記一筆';

  @override
  String get homeBaseCurrencyNeedLedger => '請先建立帳本';

  @override
  String homeBaseCurrencySwitched(String code) {
    return '已切換主幣種為 $code';
  }

  @override
  String get homePullCloudSuccess => '已同步雲端帳本資料';

  @override
  String get homePullCloudFailed => '刷新失敗，請稍後重試';

  @override
  String get homePullLocalSuccess => '已刷新本地帳本資料與設定';

  @override
  String get homePullCloudFailedButLocalOk => '雲端同步失敗，已刷新本地資料（匯率/設定）';

  @override
  String homePullCloudHealed(int count) {
    return '已自動修復並同步 $count 條雲端資料';
  }

  @override
  String get homePullCloudGap => '雲端有歷史資料未能自動恢復，請到雲端同步頁執行「從雲端恢復」';

  @override
  String get homeSyncing => '正在同步帳本資料';

  @override
  String get homeSwitchMonthHint => '左右滑動列表切換月份';

  @override
  String get analyticsMonth => '月';

  @override
  String get analyticsYear => '年';

  @override
  String get analyticsAll => '全部';

  @override
  String get analyticsWeek => '週';

  @override
  String analyticsSwipePeriodHint(Object period) {
    return '左右滑動列表切換$period';
  }

  @override
  String get analyticsTrend => '支出趨勢';

  @override
  String get analyticsTotalExpenseLabel => '總支出';

  @override
  String get analyticsDailyExpense => '日均支出';

  @override
  String get analyticsMoMLastWeek => '環比上週';

  @override
  String get analyticsMoMLastMonth => '環比上月';

  @override
  String get analyticsMoMLastYear => '環比上年';

  @override
  String get analyticsCategoryLabel => '分類';

  @override
  String get analyticsExpenseRatio => '支出佔比';

  @override
  String get analyticsThisWeek => '本週';

  @override
  String get analyticsBackToThisWeek => '回到本週';

  @override
  String get analyticsBackToThisMonth => '回到本月';

  @override
  String get analyticsBackToThisYear => '回到今年';

  @override
  String analyticsWeekN(int week) {
    return '第$week週';
  }

  @override
  String get analyticsSelectWeek => '選擇週';

  @override
  String get ledgersTitle => '帳本管理';

  @override
  String get ledgersNew => '新建帳本';

  @override
  String get ledgersClear => '清空當前帳本';

  @override
  String ledgersClearMessage(Object name) {
    return '將刪除該帳本下所有交易記錄，且不可復原。';
  }

  @override
  String get ledgerDefaultName => '預設帳本';

  @override
  String get ledgersEdit => '編輯帳本';

  @override
  String get ledgersDelete => '刪除帳本';

  @override
  String get ledgersDeleteConfirm => '刪除帳本';

  @override
  String get ledgersDeleteMessage => '確定要刪除該帳本及其全部記錄嗎？此操作不可復原。\\n若雲端存在備份，也會一併刪除。';

  @override
  String get ledgersDeleted => '已刪除';

  @override
  String get ledgersDeleteFailed => '刪除失敗';

  @override
  String get ledgersClearTitle => '清空帳本';

  @override
  String get ledgersClearSuccess => '帳本已清空';

  @override
  String get ledgersCreateSuccess => '帳本建立成功';

  @override
  String get ledgerNameLabel => '帳本名稱';

  @override
  String get ledgerNameHint => '請輸入帳本名稱';

  @override
  String get ledgersDefaultLedgerName => '預設帳本';

  @override
  String get ledgersCurrency => '幣種';

  @override
  String get ledgersMonthStartDay => '每月起始日';

  @override
  String get ledgersMonthStartDayHint => '統計與預算按該日作為每月週期起點（1-28）';

  @override
  String get ledgersMonthStartDayNatural => '1日（自然月）';

  @override
  String ledgersMonthStartDayValue(int day) {
    return '每月$day日';
  }

  @override
  String get ledgersSearchCurrency => '搜尋：中文或代碼';

  @override
  String get ledgersCreate => '建立';

  @override
  String ledgersRecords(String count) {
    return '筆數：$count';
  }

  @override
  String ledgersExpense(String expense) {
    return '支出：$expense';
  }

  @override
  String get ledgersEmpty => '暫無帳本';

  @override
  String get ledgersSectionLocal => '本機帳本';

  @override
  String get ledgersSectionCloud => 'Spitout Cloud 帳本';

  @override
  String get ledgersSectionLocalEmpty => '暫無本機帳本，本機帳本只保存在這台裝置上';

  @override
  String get ledgersSectionCloudEmpty => '暫無雲端帳本，雲端帳本會在各裝置間同步';

  @override
  String get ledgersSectionCloudSignInHint => '登入 Spitout Cloud 後即可使用雲端帳本';

  @override
  String get ledgersStorageLocation => '儲存位置';

  @override
  String get ledgersStorageLocalHint => '只保存在這台裝置上，不會上傳到雲端';

  @override
  String get ledgersStorageCloudHint => '資料會上傳到 Spitout Cloud，並在各裝置間同步';

  @override
  String get ledgersActionMoveToCloud => '移動到 Spitout Cloud';

  @override
  String get ledgersActionMoveToLocal => '移動到本機';

  @override
  String get ledgersActionCopyToLocal => '複製到本機';

  @override
  String ledgersMoveToCloudMessage(String name) {
    return '帳本\"$name\"的資料將上傳到 Spitout Cloud，並在各裝置間同步。';
  }

  @override
  String ledgersMoveToLocalMessage(String name) {
    return '帳本\"$name\"將從 Spitout Cloud 刪除，僅保留在這台裝置上，其他裝置將不再看得到它。';
  }

  @override
  String ledgersCopyToLocalMessage(String name) {
    return '將帳本\"$name\"複製一份到本機，雲端原帳本保持不變。';
  }

  @override
  String get ledgersMoveToCloudSuccess => '已移動到 Spitout Cloud';

  @override
  String get ledgersMoveToLocalSuccess => '已移動到本機';

  @override
  String get ledgersCopyToLocalSuccess => '已複製到本機';

  @override
  String ledgersSwitched(String name) {
    return '已切換到帳本「$name」';
  }

  @override
  String get categoryTitle => '分類管理';

  @override
  String get categoryExpense => '支出分類';

  @override
  String get categoryEmpty => '暫無分類';

  @override
  String categoryLoadFailed(String error) {
    return '載入失敗: $error';
  }

  @override
  String get importReading => '讀取檔案中…';

  @override
  String get importPreparing => '準備中…';

  @override
  String importColumnNumber(Object number) {
    return '第$number列';
  }

  @override
  String get importConfirmMapping => '確認對應';

  @override
  String get importCategoryMapping => '分類對應';

  @override
  String get importNoDataParsed => '未解析到任何資料，請返回上一頁檢查 CSV 內容或分隔符。';

  @override
  String get importFieldDate => '日期';

  @override
  String get importFieldType => '類型';

  @override
  String get importFieldAmount => '金額';

  @override
  String get importFieldCategory => '分類';

  @override
  String get importFieldNote => '備註';

  @override
  String get importPreview => '資料預覽';

  @override
  String importPreviewLimit(Object shown, Object total) {
    return '僅預覽前 $shown 行，共 $total 行';
  }

  @override
  String get importCategoryNotSelected => '未選擇\"分類\"列，請點擊\"上一步\"返回並設定\"分類\"的列，再繼續。';

  @override
  String get importCategoryMappingDescription => '請將左側\"源分類名\"對應到系統內已有分類（或保持原名自動建立/合併）';

  @override
  String get importKeepOriginalName => '保持原名（自動建立/合併）';

  @override
  String importProgress(Object fail, Object ok) {
    return '匯入中… 成功 $ok，失敗 $fail';
  }

  @override
  String get importCancelImport => '取消匯入';

  @override
  String get importCompleteTitle => '匯入完成';

  @override
  String get importSelectCategoryFirst => '請先選擇\"分類\"列再繼續';

  @override
  String get importNextStep => '下一步';

  @override
  String get importPreviousStep => '上一步';

  @override
  String get importStartImport => '開始匯入';

  @override
  String get importAutoDetect => '自動檢測';

  @override
  String get importInProgress => '正在匯入…';

  @override
  String importProgressDetail(Object done, Object fail, Object ok, Object total) {
    return '已完成：$done/$total，成功 $ok，失敗 $fail';
  }

  @override
  String get importBackgroundImport => '背景匯入';

  @override
  String get importCancelled => '（已取消）';

  @override
  String importCompleted(Object cancelled, Object fail, Object ok) {
    return '匯入完成$cancelled：成功 $ok 條，失敗 $fail 條';
  }

  @override
  String importSkippedNonTransactionTypes(Object count) {
    return '跳過 $count 條非支出記錄（債務等）';
  }

  @override
  String importTransactionFailed(Object error) {
    return '匯入失敗，已回滾所有更改：$error';
  }

  @override
  String importFileOpenError(String error) {
    return '無法開啟檔案選擇器：$error';
  }

  @override
  String get mineTitle => '我的';

  @override
  String get mineLanguageSettings => '應用語言';

  @override
  String get languageTitle => '語言設定';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystemDefault => '跟隨系統';

  @override
  String get mineSlogan => '设置昵称';

  @override
  String get mineDisplayNameEditTitle => '設定暱稱';

  @override
  String get mineDisplayNameHint => '輸入暱稱';

  @override
  String get mineDisplayNameSaved => '暱稱已更新';

  @override
  String get mineGreetingMorning => '早安';

  @override
  String get mineGreetingNoon => '中午好';

  @override
  String get mineGreetingAfternoon => '午安';

  @override
  String get mineGreetingEvening => '晚安';

  @override
  String get mineGreetingNight => '夜深了';

  @override
  String mineGreetingNamed(String greeting, String name) {
    return '$greeting，$name';
  }

  @override
  String get mineAvatarDelete => '刪除頭像';

  @override
  String get mineAvatarUploadNew => '上傳新頭像';

  @override
  String get mineCloudService => '雲服務';

  @override
  String get mineCloudServiceLoading => '載入中…';

  @override
  String get mineSyncTitle => '同步';

  @override
  String get mineSyncNotLoggedIn => '未登入';

  @override
  String get mineSyncNotConfigured => '未設定雲端';

  @override
  String get mineSyncNoRemote => '雲端暫無資料';

  @override
  String mineSyncInSync(Object count) {
    return '已同步 (本地$count條)';
  }

  @override
  String mineSyncLocalNewer(Object count) {
    return '本機有更新 (本機$count條, 建議上傳)';
  }

  @override
  String get mineSyncCloudNewer => '雲端有更新 (建議下載同步)';

  @override
  String get mineSyncDifferent => '本機與雲端有差異，建議下載對比';

  @override
  String get mineSyncError => '狀態取得失敗';

  @override
  String get mineSyncDetailTitle => '同步狀態詳情';

  @override
  String mineSyncLocalRecords(Object count) {
    return '本地記錄數: $count';
  }

  @override
  String mineSyncCloudRecords(Object count) {
    return '雲端記錄數: $count';
  }

  @override
  String mineSyncCloudLatest(Object time) {
    return '雲端最新記帳時間: $time';
  }

  @override
  String mineSyncLocalFingerprint(Object fingerprint) {
    return '本地指紋: $fingerprint';
  }

  @override
  String mineSyncCloudFingerprint(Object fingerprint) {
    return '雲端指紋: $fingerprint';
  }

  @override
  String mineSyncMessage(Object message) {
    return '說明: $message';
  }

  @override
  String get mineUploadTitle => '上傳';

  @override
  String get mineUploadNeedLogin => '需登入';

  @override
  String get mineUploadNeedCloudService => '僅限雲端服務模式可用';

  @override
  String get mineUploadInProgress => '正在上傳中…';

  @override
  String get mineUploadRefreshing => '重新整理中…';

  @override
  String get mineUploadSynced => '已同步';

  @override
  String get mineUploadSuccess => '已上傳';

  @override
  String get mineUploadSuccessMessage => '當前帳本已同步到雲端';

  @override
  String get mineDownloadTitle => '下載同步';

  @override
  String get mineDownloadNeedCloudService => '僅限雲端服務模式可用';

  @override
  String get mineDownloadComplete => '同步完成';

  @override
  String mineDownloadResult(Object inserted) {
    return '匯入：$inserted 條';
  }

  @override
  String get mineLoginTitle => '登入';

  @override
  String get mineLoginSubtitle => '僅在同步時需要';

  @override
  String get cloudReloginTitle => '重新登入';

  @override
  String get cloudReloginSuccess => '已重新登入';

  @override
  String get mineLoggedInEmail => '已登入';

  @override
  String get mineLogoutSubtitle => '點擊可退出登入';

  @override
  String get mineLogoutConfirmTitle => '退出登入';

  @override
  String get mineLogoutConfirmMessage => '確定要退出當前帳號登入嗎？\n退出後將無法使用雲同步功能。';

  @override
  String get mineLogoutButton => '退出';

  @override
  String get mineAutoSyncTitle => '自動同步帳本';

  @override
  String get mineAutoSyncSubtitle => '記帳後自動上傳到雲端';

  @override
  String get mineAutoSyncNeedLogin => '需登入後可開啟';

  @override
  String get mineCategoryManagement => '分類管理';

  @override
  String get mineCategoryManagementSubtitle => '編輯自訂分類';

  @override
  String get mineRecurringTransactions => '週期帳單';

  @override
  String get mineRecurringTransactionsSubtitle => '管理週期性帳單';

  @override
  String get mineReminderSettings => '記帳提醒';

  @override
  String get mineReminderSettingsSubtitle => '設定每日記帳提醒';

  @override
  String get categoryEditTitle => '編輯分類';

  @override
  String get categoryNewTitle => '新建分類';

  @override
  String get categoryDetailTooltip => '分類匯總';

  @override
  String get categoryDefaultTitle => '預設分類';

  @override
  String get categoryNameLabel => '分類名稱';

  @override
  String get categoryNameHint => '請輸入分類名稱';

  @override
  String get categoryNameRequired => '請輸入分類名稱';

  @override
  String get categoryNameTooLong => '分類名稱不能超過4個字';

  @override
  String get categoryNameDuplicate => '分類名稱已存在';

  @override
  String get categoryIconLabel => '分類圖示';

  @override
  String get categoryCurrentIcon => '當前圖示';

  @override
  String get categorySaveError => '儲存失敗';

  @override
  String categoryUpdated(Object name) {
    return '分類\"$name\"已更新';
  }

  @override
  String categoryCreated(Object name) {
    return '分類\"$name\"已建立';
  }

  @override
  String get categoryCannotDelete => '無法刪除';

  @override
  String get categoryClearUnused => '清空未使用分類';

  @override
  String get categoryClearUnusedTitle => '清空未使用分類';

  @override
  String categoryClearUnusedMessage(Object count) {
    return '確定要刪除 $count 個未使用的分類嗎？此操作無法撤銷。';
  }

  @override
  String get categoryClearUnusedListTitle => '將被刪除的分類：';

  @override
  String get categoryClearUnusedEmpty => '沒有未使用的分類';

  @override
  String categoryClearUnusedSuccess(Object count) {
    return '已刪除 $count 個分類';
  }

  @override
  String get categoryClearUnusedFailed => '清空失敗';

  @override
  String get categoryDeleteError => '刪除失敗';

  @override
  String categorySubCategoryCreated(Object name) {
    return '已新增二級分類：$name';
  }

  @override
  String get categoryParentCategoryTitle => '所屬分類';

  @override
  String get categorySelectParentTitle => '選擇所屬分類';

  @override
  String get categoryHasSubCategories => '此分類包含二級分類，無法修改';

  @override
  String get categorySearchCategory => '搜尋分類';

  @override
  String get categoryTopLevelLabel => '一級分類';

  @override
  String get categorySecondLevelLabel => '二級分類';

  @override
  String get categoryExpenseList => '餐飲-交通-購物-娛樂-居家-家庭-通訊-水電-住房-醫療-教育-寵物-運動-數碼-旅行-煙酒-母嬰-美容-維修-社交-學習-汽車-打車-地鐵-外賣-物業-停車-捐贈-送禮-納稅-飲料-服裝-零食-發紅包-水果-遊戲-書籍-愛人-裝修-日用品-彩票-股票-社保-快遞-工作-轉帳-其他';

  @override
  String get categoryExpenseDining => '餐飲-早餐-午餐-晚餐-美團外賣-餓了麼外賣-京東外賣-餐廳-美食';

  @override
  String get categoryExpenseSnacks => '零食-餅乾-薯片-糖果-巧克力-堅果';

  @override
  String get categoryExpenseFruit => '水果-蘋果-香蕉-橙子-葡萄-西瓜-其他水果';

  @override
  String get categoryExpenseBeverage => '飲料-奶茶-咖啡-果汁-汽水-礦泉水';

  @override
  String get categoryExpensePastry => '糕點-蛋糕-麵包-甜點-曲奇';

  @override
  String get categoryExpenseCooking => '做飯食材-蔬菜-肉類-水產-調料-糧油';

  @override
  String get categoryExpenseShopping => '購物-超市-日用百貨-服裝-鞋子-包包';

  @override
  String get categoryExpensePets => '寵物-寵物食品-寵物用品-寵物醫療-寵物美容';

  @override
  String get categoryExpenseTransport => '交通-交通卡充值-打車-停車費-加油';

  @override
  String get categoryExpenseCar => '汽車-汽車保養-汽車維修-汽車保險-洗車-違章罰款';

  @override
  String get categoryExpenseClothing => '服裝-上衣-褲子-裙子-鞋子-服飾配件';

  @override
  String get categoryExpenseDailyGoods => '日用品-洗護用品-紙品-清潔用品-廚房用品';

  @override
  String get categoryExpenseEducation => '教育-學費-培訓費-書籍-文具-辦公用品-學習';

  @override
  String get categoryExpenseInvestLoss => '投資虧損-股票虧損-基金虧損-其他投資虧損';

  @override
  String get categoryExpenseEntertainment => '娛樂-電影-KTV-遊樂場-酒吧-其他娛樂';

  @override
  String get categoryExpenseGame => '遊戲-遊戲儲值-遊戲裝備-遊戲會員';

  @override
  String get categoryExpenseHealthProducts => '保健品-維生素-保健食品-營養品';

  @override
  String get categoryExpenseSubscription => '訂閱服務-視頻會員-音樂會員-雲端儲存-其他訂閱';

  @override
  String get categoryExpenseSports => '運動-健身房-運動裝備-運動課程-戶外活動';

  @override
  String get categoryExpenseHousing => '住房-水電煤-物業費-房租-房貸-裝修-寬頻';

  @override
  String get categoryExpenseHome => '居家-傢俱-家電-裝飾品-床上用品';

  @override
  String get categoryExpenseBeauty => '美容-護膚品-化妝品-剪髮-美甲';

  @override
  String get categoryExpenseTransfer => '轉帳-生活費-家庭-父母-戀人-借錢';

  @override
  String get appearanceThemeMode => '深色模式';

  @override
  String get appearanceThemeModeSystem => '跟隨系統';

  @override
  String get appearanceThemeModeLight => '亮色模式';

  @override
  String get appearanceThemeModeDark => '暗黑模式';

  @override
  String get appearanceExpenseColorScheme => '支出顏色';

  @override
  String get appearanceExpenseColorRed => '紅色表示支出';

  @override
  String get appearanceExpenseColorGreen => '綠色表示支出';

  @override
  String get appearanceExpenseColorApplied => '已更換';

  @override
  String get reminderTitle => '記帳提醒';

  @override
  String get reminderSubtitle => '設定每日記帳提醒時間';

  @override
  String get reminderDailyTitle => '每日記帳提醒';

  @override
  String get reminderDailySubtitle => '開啟後將在指定時間提醒您記帳';

  @override
  String get reminderTimeTitle => '提醒時間';

  @override
  String get commonSelectTime => '選擇時間';

  @override
  String get reminderTestNotification => '發送測試通知';

  @override
  String get reminderTestSent => '測試通知已發送';

  @override
  String get reminderTestTitle => '測試通知';

  @override
  String get reminderTestBody => '這是一條測試通知，點擊檢視效果';

  @override
  String get reminderCheckBattery => '檢查電池最佳化狀態';

  @override
  String get reminderBatteryStatus => '電池最佳化狀態';

  @override
  String reminderManufacturer(Object value) {
    return '裝置製造商: $value';
  }

  @override
  String reminderModel(Object value) {
    return '裝置型號: $value';
  }

  @override
  String reminderAndroidVersion(Object value) {
    return 'Android版本: $value';
  }

  @override
  String get reminderBatteryIgnored => '電池最佳化狀態: 已忽略 ✅';

  @override
  String get reminderBatteryNotIgnored => '電池最佳化狀態: 未忽略 ⚠️';

  @override
  String get reminderBatteryAdvice => '建議關閉電池最佳化以確保通知正常工作';

  @override
  String get reminderCheckChannel => '檢查通知頻道設定';

  @override
  String get reminderChannelStatus => '通知頻道狀態';

  @override
  String get reminderChannelEnabled => '頻道啟用: 是 ✅';

  @override
  String get reminderChannelDisabled => '頻道啟用: 否 ❌';

  @override
  String reminderChannelImportance(Object value) {
    return '重要性: $value';
  }

  @override
  String get reminderChannelSoundOn => '聲音: 開啟 🔊';

  @override
  String get reminderChannelSoundOff => '聲音: 關閉 🔇';

  @override
  String get reminderChannelVibrationOn => '震動: 開啟 📳';

  @override
  String get reminderChannelVibrationOff => '震動: 關閉';

  @override
  String get reminderChannelDndBypass => '勿擾模式: 可繞過';

  @override
  String get reminderChannelDndNoBypass => '勿擾模式: 不可繞過';

  @override
  String get reminderChannelAdvice => '⚠️ 建議設定：';

  @override
  String get reminderChannelAdviceImportance => '• 重要性：緊急或高';

  @override
  String get reminderChannelAdviceSound => '• 開啟聲音和震動';

  @override
  String get reminderChannelAdviceBanner => '• 允許橫幅通知';

  @override
  String get reminderChannelAdviceXiaomi => '• 小米手機需單獨設定每個頻道';

  @override
  String get reminderChannelGood => '✅ 通知頻道設定良好';

  @override
  String get reminderOpenAppSettings => '開啟應用程式設定';

  @override
  String get reminderAppSettingsMessage => '請在設定中允許通知、關閉電池最佳化';

  @override
  String get reminderDescription => '提示：開啟記帳提醒後，系統會在每天指定時間發送通知提醒您記錄支出。';

  @override
  String get reminderAndroidInstructions => '如果通知無法正常工作，請檢查：\n• 已允許應用程式發送通知\n• 關閉應用程式的電池最佳化/省電模式\n• 允許應用程式在背景執行和自啟動\n• Android 12+需要精確鬧鐘權限\n\n📱 小米手機特殊設定：\n• 設定 > 應用程式管理 > Spitout > 通知管理\n• 點擊\"記帳提醒\"頻道\n• 設定重要性為\"緊急\"或\"高\"\n• 開啟\"橫幅通知\"、\"聲音\"、\"震動\"\n• 安全中心 > 應用程式管理 > 權限 > 自啟動\n\n🔒 鎖定背景方法：\n• 最近任務中找到Spitout\n• 向下拉動應用程式卡片顯示鎖定圖示\n• 點擊鎖定圖示防止被清理';

  @override
  String get categoryDetailLoadFailed => '載入失敗';

  @override
  String get categoryDetailSummaryTitle => '分類匯總';

  @override
  String get categoryDetailTotalCount => '總筆數';

  @override
  String get categoryDetailTotalAmount => '總金額';

  @override
  String get categoryDetailAverageAmount => '平均金額';

  @override
  String get categoryDetailSortTitle => '排序';

  @override
  String get categoryDetailSortTimeDesc => '時間↓';

  @override
  String get categoryDetailSortTimeAsc => '時間↑';

  @override
  String get categoryDetailSortAmountDesc => '金額↓';

  @override
  String get categoryDetailSortAmountAsc => '金額↑';

  @override
  String get categoryDetailNoTransactions => '暫無交易記錄';

  @override
  String get categoryDetailNoTransactionsSubtext => '該分類下還沒有任何交易記錄';

  @override
  String get categoryDetailDeleteFailed => '刪除失敗';

  @override
  String categoryMigrationTransactionLabel(int count) {
    return '$count筆';
  }

  @override
  String get categoryTemplateEntryFlat => '一級模板';

  @override
  String get categoryTemplateEntryHierarchical => '二級模板';

  @override
  String get categoryTemplateFlatTitle => '一級分類模板';

  @override
  String get categoryTemplateHierarchicalTitle => '二級分類模板';

  @override
  String categoryTemplateSelectedCount(int count) {
    return '本次已勾選 $count 項';
  }

  @override
  String get categoryTemplateSelectAll => '全選';

  @override
  String get categoryTemplateDeselectAll => '取消全選';

  @override
  String get categoryTemplateConfirmTitle => '確認新增';

  @override
  String categoryTemplateConfirmMessage(int count) {
    return '確定將勾選的 $count 個分類加入分類表嗎？';
  }

  @override
  String categoryTemplateAddSuccess(int count) {
    return '已新增 $count 個分類';
  }

  @override
  String categoryTemplateAddFailed(String error) {
    return '新增失敗：$error';
  }

  @override
  String get categoryManageAdd => '新增分類';

  @override
  String get categoryManageDelete => '刪除分類';

  @override
  String get categoryManageConfirmDelete => '確認刪除';

  @override
  String get categoryManageReorderHint => '長按調整分類順序';

  @override
  String get categorySharedManageBannerOwner => '共享帳本：分類的新增、修改、刪除會同步給所有成員';

  @override
  String get categorySharedManageBannerEditor => '共享帳本記帳使用擁有者的分類；此處的編輯僅影響你的個人分類';

  @override
  String get categorySyncFailedBeforeInvite => '分類同步失敗，請檢查網路後重試';

  @override
  String get categorySortSaveFailed => '排序保存失敗，請重試';

  @override
  String get categoryDeleteOptionAll => '刪除分類和分類下的所有資料（含二級）';

  @override
  String get categoryDeleteOptionMigrate => '刪除分類並遷移分類下的所有資料到其他分類（含二級）';

  @override
  String get categoryDeleteOptionPromote => '刪除分類和分類下的所有資料（不含二級分類，二級分類將變為一級分類）';

  @override
  String get categoryDeleteSelectedTitle => '刪除選中的分類';

  @override
  String categoryDeleteSelectedSubtitleWithSub(int count) {
    return '確定要刪除 $count 個選中分類並且清空分類下的資料嗎？（包含二級分類和資料）此操作無法撤銷。';
  }

  @override
  String categoryDeleteSelectedSubtitleWithoutSub(int count) {
    return '確定要刪除 $count 個選中分類並且清空分類下的資料嗎？（不含二級分類和資料）此操作無法撤銷。';
  }

  @override
  String get categoryMigrateSelectTargetTitle => '選擇資料遷移到的分類';

  @override
  String get categoryMigrateConfirmButton => '確定（遷移分類資料並刪除分類）';

  @override
  String categoryMigrateChildLabel(Object parent) {
    return '二級 · $parent';
  }

  @override
  String get subcategoryEditParent => '編輯父分類';

  @override
  String get subcategoryAdd => '新增子分類';

  @override
  String get subcategoryDelete => '刪除子分類';

  @override
  String get subcategoryDeleteOptionAll => '刪除分類和分類下的所有資料';

  @override
  String get subcategoryDeleteOptionMigrate => '刪除分類並將分類下的所有資料遷移到其他分類';

  @override
  String subcategoryDeleteSelectedSubtitle(int count) {
    return '確定要刪除 $count 個選中分類並且清空分類下的資料嗎？此操作無法撤銷。';
  }

  @override
  String get subcategoryEmpty => '暫無子分類';

  @override
  String get cloudSupabaseUrlLabel => 'Supabase URL';

  @override
  String get cloudSupabaseUrlHint => 'https://xxx.supabase.co';

  @override
  String get cloudAnonKeyLabel => 'Anon Key';

  @override
  String get cloudMultiDeviceWarningTitle => '多裝置使用提醒';

  @override
  String get cloudMultiDeviceWarningMessage => '換裝置前記得先上傳，到新裝置後先下載再記帳。不要同時在兩台裝置上記同一個帳本。點擊查看詳情 →';

  @override
  String get cloudWebdavUrlLabel => 'WebDAV 伺服器地址';

  @override
  String get cloudWebdavUrlHint => 'https://dav.jianguoyun.com/dav/';

  @override
  String get cloudWebdavUsernameLabel => '使用者名稱';

  @override
  String get cloudWebdavPasswordLabel => '密碼';

  @override
  String get cloudWebdavPathHint => '/Spitout';

  @override
  String get cloudS3EndpointLabel => '端點地址';

  @override
  String get cloudS3EndpointHint => 's3.amazonaws.com 或自訂端點';

  @override
  String get cloudS3RegionLabel => '區域';

  @override
  String get cloudS3RegionHint => 'us-east-1（留空自動）';

  @override
  String get cloudS3AccessKeyLabel => 'Access Key';

  @override
  String get cloudS3AccessKeyHint => '您的 Access Key ID';

  @override
  String get cloudS3SecretKeyLabel => 'Secret Key';

  @override
  String get cloudS3SecretKeyHint => '您的 Secret Access Key';

  @override
  String get cloudS3BucketLabel => '儲存桶名稱';

  @override
  String get cloudS3BucketHint => 'spitout-data';

  @override
  String get cloudS3UseSSLLabel => '使用 HTTPS';

  @override
  String get cloudS3PortLabel => '連接埠（選填）';

  @override
  String get cloudS3PortHint => '留空使用預設連接埠';

  @override
  String get cloudSupabaseBucketLabel => 'Storage Bucket 名稱';

  @override
  String get cloudSupabaseBucketHint => '留空使用預設值 spitout-backups';

  @override
  String get authRememberAccount => '記住帳號密碼';

  @override
  String get authRememberAccountHint => '下次登入時自動填入（僅Supabase）';

  @override
  String get cloudFirstSaveSwitchTitle => '設定已儲存';

  @override
  String get cloudFirstSaveSwitchMessage => '是否立即切換到該雲端服務作為目前同步設定？';

  @override
  String get cloudSaveOnlyNoSwitch => '暫不切換';

  @override
  String get cloudSaveAndSwitch => '立即切換';

  @override
  String get cloudClearConfig => '清除設定';

  @override
  String get cloudClearConfigConfirmTitle => '清除雲端設定';

  @override
  String get cloudClearConfigConfirmMessage => '確定要清除該雲端服務的設定嗎？\n雲端已備份的資料不會被刪除，你可以隨時重新設定並恢復。';

  @override
  String get cloudClearConfigDone => '設定已清除';

  @override
  String get cloudPurgeFailed => '雲端帳本清理失敗，請稍後重試';

  @override
  String get authLogin => '登入';

  @override
  String get authEmail => '電子郵件';

  @override
  String get authPassword => '密碼';

  @override
  String get authInvalidEmail => '請輸入有效的電子郵件地址';

  @override
  String get authErrorInvalidCredentials => '電子郵件或密碼不正確。';

  @override
  String get authErrorEmailNotConfirmed => '電子郵件未驗證，請先到電子郵件完成驗證再登入。';

  @override
  String get authErrorRateLimit => '操作過於頻繁，請稍後再試。';

  @override
  String get authErrorNetworkIssue => '網路異常，請檢查網路後重試。';

  @override
  String get authErrorLoginFailed => '登入失敗，請稍後再試。';

  @override
  String get exportCsvHeaderType => '類型';

  @override
  String get exportCsvHeaderCategory => '分類';

  @override
  String get exportCsvHeaderSubCategory => '二級分類';

  @override
  String get exportCsvHeaderAmount => '金額';

  @override
  String get exportCsvHeaderNote => '備註';

  @override
  String get exportCsvHeaderTime => '時間';

  @override
  String get exportSuccessTitle => '匯出成功';

  @override
  String exportSuccessMessageAndroid(String path) {
    return '已儲存到：\n$path';
  }

  @override
  String get exportFailedTitle => '匯出失敗';

  @override
  String get exportTypeExpense => '支出';

  @override
  String get currencyCNY => '人民幣';

  @override
  String get currencyUSD => '美元';

  @override
  String get currencyEUR => '歐元';

  @override
  String get currencyJPY => '日元';

  @override
  String get currencyHKD => '港幣';

  @override
  String get currencyTWD => '新台幣';

  @override
  String get currencyGBP => '英鎊';

  @override
  String get currencyAUD => '澳元';

  @override
  String get currencyCAD => '加元';

  @override
  String get currencyKRW => '韓元';

  @override
  String get currencySGD => '新加坡元';

  @override
  String get currencyMYR => '馬來西亞令吉';

  @override
  String get currencyTHB => '泰銖';

  @override
  String get currencyIDR => '印尼盾';

  @override
  String get currencyPHP => '菲律賓披索';

  @override
  String get currencyVND => '越南盾';

  @override
  String get currencyINR => '印度盧比';

  @override
  String get currencyRUB => '俄羅斯盧布';

  @override
  String get currencyBYN => '白俄羅斯盧布';

  @override
  String get currencyNZD => '紐西蘭元';

  @override
  String get currencyCHF => '瑞士法郎';

  @override
  String get currencySEK => '瑞典克朗';

  @override
  String get currencyNOK => '挪威克朗';

  @override
  String get currencyDKK => '丹麥克朗';

  @override
  String get currencyBRL => '巴西雷亞爾';

  @override
  String get currencyMXN => '墨西哥披索';

  @override
  String get currencyTRY => '土耳其里拉';

  @override
  String get currencyZAR => '南非蘭特';

  @override
  String get currencyAED => '阿聯酋迪拉姆';

  @override
  String get currencySAR => '沙烏地里亞爾';

  @override
  String get currencyPLN => '波蘭茲羅提';

  @override
  String get currencyCZK => '捷克克朗';

  @override
  String get currencyHUF => '匈牙利福林';

  @override
  String get currencyARS => '阿根廷披索';

  @override
  String get currencyCLP => '智利披索';

  @override
  String get currencyCOP => '哥倫比亞披索';

  @override
  String get currencyPEN => '秘魯索爾';

  @override
  String get currencyEGP => '埃及鎊';

  @override
  String get currencyNGN => '奈及利亞奈拉';

  @override
  String get currencyKZT => '哈薩克坦吉';

  @override
  String get currencyUAH => '烏克蘭格里夫納';

  @override
  String get currencyILS => '以色列新謝克爾';

  @override
  String get currencyPKR => '巴基斯坦盧比';

  @override
  String get currencyBDT => '孟加拉塔卡';

  @override
  String get currencyLKR => '斯里蘭卡盧比';

  @override
  String get currencyMMK => '緬甸元';

  @override
  String get webdavConfiguredTitle => 'WebDAV 雲服務已設定';

  @override
  String get webdavConfiguredMessage => 'WebDAV 雲服務使用設定時提供的憑證，無需額外登入。';

  @override
  String get recurringTransactionTitle => '週期帳單';

  @override
  String get recurringTransactionAdd => '新增週期帳單';

  @override
  String get recurringTransactionEdit => '編輯週期帳單';

  @override
  String get recurringTransactionFrequency => '週期頻率';

  @override
  String get recurringTransactionDaily => '每天';

  @override
  String get recurringTransactionWeekly => '每週';

  @override
  String get recurringTransactionMonthly => '每月';

  @override
  String get recurringTransactionYearly => '每年';

  @override
  String get recurringTransactionInterval => '間隔';

  @override
  String get recurringTransactionDayOfMonth => '每月第幾天';

  @override
  String get recurringTransactionStartDate => '開始日期';

  @override
  String get recurringTransactionEndDate => '結束日期';

  @override
  String get recurringTransactionNoEndDate => '永久週期';

  @override
  String get recurringTransactionDeleteConfirm => '確定要刪除這個週期帳單嗎？';

  @override
  String get recurringTransactionEmpty => '暫無週期帳單';

  @override
  String get recurringTransactionEmptyHint => '點擊右上角 + 按鈕新增';

  @override
  String recurringTransactionEveryNDays(int n) {
    return '每 $n 天';
  }

  @override
  String recurringTransactionEveryNWeeks(int n) {
    return '每 $n 週';
  }

  @override
  String recurringTransactionEveryNMonths(int n) {
    return '每 $n 個月';
  }

  @override
  String recurringTransactionEveryNYears(int n) {
    return '每 $n 年';
  }

  @override
  String get recurringTransactionUsageTitle => '使用說明';

  @override
  String get recurringTransactionUsageContent => '週期記帳會在每次冷啟動進入 App 時自動掃描並產生帳單。設定日期後，系統會在該日期之後的冷啟動時建立對應帳單。例如：設定 11 月 27 日，則會在 11 月 27 日之後的首次啟動時自動記帳。';

  @override
  String get ledgerSelectTitle => '選擇帳本';

  @override
  String get ledgerSelect => '選擇帳本';

  @override
  String get syncNotConfiguredMessage => '未設定雲端';

  @override
  String get syncNotLoggedInMessage => '未登入';

  @override
  String get syncCloudBackupCorruptedMessage => '雲端備份內容無法解析，可能是早期版本編碼問題造成的損壞。請點擊\\\"上傳當前帳本到雲端\\\"覆蓋修復。';

  @override
  String get syncNoCloudBackupMessage => '雲端暫無備份';

  @override
  String get syncAccessDeniedMessage => '403 拒絕存取（檢查 storage RLS 策略與路徑）';

  @override
  String get cloudTestConnection => '測試連線';

  @override
  String cloudLastTestTime(String time) {
    return '上次測試時間：$time';
  }

  @override
  String get cloudLocalStorageTitle => '本機儲存';

  @override
  String get cloudLocalStorageSubtitle => '資料僅儲存在本機裝置';

  @override
  String get localBackupPageTitle => '本機儲存';

  @override
  String get localBackupAutoTitle => '自動本機備份';

  @override
  String get localBackupAutoSubtitle => '每天首次開啟應用程式時自動備份資料庫快照';

  @override
  String get storagePermissionTitle => '需要儲存權限';

  @override
  String get storagePermissionMessage => 'Android 11 及以上需授予「所有檔案存取」權限，才能將檔案儲存到公共 Download 目錄（檔案管理員可見、解除安裝不遺失）。\n\n選擇「仍要繼續」將儲存到應用程式私有目錄，檔案管理員不可見，且解除安裝後會被刪除。';

  @override
  String get storagePermissionGrant => '前往授權';

  @override
  String get storagePermissionContinue => '仍要繼續';

  @override
  String get exportStorageUnavailable => '外部儲存不可用，請檢查裝置儲存狀態';

  @override
  String get localBackupNowTooltip => '立即備份';

  @override
  String get localBackupSuccess => '備份成功';

  @override
  String get localBackupFailed => '備份失敗，請檢查儲存空間與權限';

  @override
  String get localBackupListHint => '選擇一個資料進行恢復：';

  @override
  String get localBackupImportFromFile => '匯入檔案恢復';

  @override
  String get localBackupImportInvalidFile => '請選擇 .sqlite 格式的備份檔案';

  @override
  String get localBackupListEmpty => '暫無備份';

  @override
  String get localBackupRestoreTitle => '恢復備份';

  @override
  String get localBackupRestoreMessage => '恢復將覆蓋目前全部資料且不可逆，是否繼續？';

  @override
  String get localBackupRestoreSuccess => '恢復成功';

  @override
  String get localBackupRestoreFailed => '恢復失敗';

  @override
  String get localBackupEmergencyFailed => '無法為目前資料建立安全副本，已取消恢復';

  @override
  String get localBackupIntegrityFailed => '備份檔案已損毀，無法恢復';

  @override
  String get localBackupVersionTooNew => '該備份由更新版本的應用程式建立，請升級應用程式後再恢復';

  @override
  String get localBackupRestoring => '正在恢復…';

  @override
  String get cloudCustomSupabaseTitle => '自訂 Supabase';

  @override
  String get cloudCustomSupabaseSubtitle => '點擊設定自建Supabase服務';

  @override
  String get cloudCustomWebdavTitle => '自訂 WebDAV';

  @override
  String get cloudCustomWebdavSubtitle => '點擊設定堅果雲/Nextcloud等';

  @override
  String get cloudCustomS3Title => 'S3 協議儲存';

  @override
  String get cloudCustomS3Subtitle => 'AWS S3 / Cloudflare R2 / MinIO';

  @override
  String get cloudSpitoutCloudTitle => 'Spitout Cloud';

  @override
  String get cloudSpitoutCloudSubtitle => '自建雲服務 · 增量同步 · 多裝置協同';

  @override
  String get cloudConfigureSpitoutCloudTitle => '設定 Spitout Cloud';

  @override
  String get cloudSpitoutCloudUrlLabel => '伺服器地址';

  @override
  String get cloudSpitoutCloudUrlHint => 'https://your-server.com';

  @override
  String get cloudSpitoutCloudEmailLabel => '電子郵件';

  @override
  String get cloudSpitoutCloudEmailHint => 'your@email.com';

  @override
  String get cloudSpitoutCloudPasswordLabel => '密碼';

  @override
  String get cloudSpitoutCloudPasswordHint => '輸入密碼';

  @override
  String get cloudSpitoutCloudLoginSuccess => '登入成功';

  @override
  String get cloudSpitoutCloudLoginFailed => '登入失敗';

  @override
  String get cloudTabOffline => '離線模式';

  @override
  String get cloudTabBackup => '備份同步';

  @override
  String get cloudTabBackupSubtitle => '點擊卡片切換備份方式，首次需要配置資訊';

  @override
  String get cloudTabCloudSync => '雲端協同';

  @override
  String get cloudSupabaseHelpTitle => 'Supabase 設定說明';

  @override
  String get cloudSupabaseHelpIntro => '什麼是 Supabase';

  @override
  String get cloudSupabaseHelpIntro1 => 'Supabase 是一個開源的後端即服務平台';

  @override
  String get cloudSupabaseHelpIntro2 => '提供免費方案，足夠個人使用';

  @override
  String get cloudSupabaseHelpIntro3 => '資料完全由您掌控';

  @override
  String get cloudSupabaseHelpSteps => '設定步驟';

  @override
  String get cloudSupabaseHelpStep1 => '1. 前往 supabase.com 註冊帳號';

  @override
  String get cloudSupabaseHelpStep2 => '2. 建立新專案（選擇免費方案）';

  @override
  String get cloudSupabaseHelpStep3 => '3. 進入專案設定 > API';

  @override
  String get cloudSupabaseHelpStep4 => '4. 複製 Project URL 和 anon key';

  @override
  String get cloudSupabaseHelpStep5 => '5. 貼到應用程式的設定中';

  @override
  String get cloudSupabaseHelpFaq => '常見問題';

  @override
  String get cloudSupabaseHelpFaq1 => '免費方案有 500MB 儲存空間';

  @override
  String get cloudSupabaseHelpFaq2 => '資料加密儲存，安全可靠';

  @override
  String get cloudSupabaseHelpFaq3 => '支援多裝置同步';

  @override
  String get cloudSupabaseHelpNote => '設定完成後需要註冊/登入帳號才能使用同步功能';

  @override
  String get cloudWebdavHelpTitle => 'WebDAV 設定說明';

  @override
  String get cloudWebdavHelpIntro => '什麼是 WebDAV';

  @override
  String get cloudWebdavHelpIntro1 => 'WebDAV 是一種網路檔案通訊協定';

  @override
  String get cloudWebdavHelpIntro2 => '支援多種雲端硬碟和 NAS 裝置';

  @override
  String get cloudWebdavHelpIntro3 => '資料儲存在您自己的伺服器上';

  @override
  String get cloudWebdavHelpProviders => '支援的服務商';

  @override
  String get cloudWebdavHelpProvider1 => '• 堅果雲（推薦國內用戶）';

  @override
  String get cloudWebdavHelpProvider2 => '• Nextcloud / ownCloud';

  @override
  String get cloudWebdavHelpProvider3 => '• 群暉 / 威聯通 NAS';

  @override
  String get cloudWebdavHelpProvider4 => '• 其他支援 WebDAV 的服務';

  @override
  String get cloudWebdavHelpSteps => '設定步驟（以堅果雲為例）';

  @override
  String get cloudWebdavHelpStep1 => '1. 登入堅果雲網頁版';

  @override
  String get cloudWebdavHelpStep2 => '2. 點擊右上角帳戶名 > 帳戶資訊';

  @override
  String get cloudWebdavHelpStep3 => '3. 選擇「安全選項」標籤';

  @override
  String get cloudWebdavHelpStep4 => '4. 新增應用程式密碼（用於第三方應用程式）';

  @override
  String get cloudWebdavHelpStep5 => '5. 複製伺服器地址、帳號、應用程式密碼';

  @override
  String get cloudWebdavHelpNote => '建議使用應用程式專用密碼，而非帳號密碼';

  @override
  String get cloudS3HelpTitle => 'S3 儲存設定說明';

  @override
  String get cloudS3HelpIntro => '什麼是 S3';

  @override
  String get cloudS3HelpIntro1 => 'S3 是一種標準的物件儲存通訊協定';

  @override
  String get cloudS3HelpIntro2 => '支援多家雲端服務商';

  @override
  String get cloudS3HelpIntro3 => '資料儲存在您選擇的雲端服務中';

  @override
  String get cloudS3HelpProviders => '支援的服務商';

  @override
  String get cloudS3HelpProvider1 => '• AWS S3（Amazon Web Services）';

  @override
  String get cloudS3HelpProvider2 => '• Cloudflare R2（免費 10GB/月）';

  @override
  String get cloudS3HelpProvider3 => '• Backblaze B2（免費 10GB）';

  @override
  String get cloudS3HelpProvider4 => '• MinIO（自建服務）';

  @override
  String get cloudS3HelpProvider5 => '• 阿里雲 OSS';

  @override
  String get cloudS3HelpProvider6 => '• 騰訊雲 COS';

  @override
  String get cloudS3HelpProvider7 => '• 七牛雲 Kodo';

  @override
  String get cloudS3HelpSteps => '設定步驟（以 Cloudflare R2 為例）';

  @override
  String get cloudS3HelpStep1 => '1. 登入 Cloudflare 控制台';

  @override
  String get cloudS3HelpStep2 => '2. 進入 R2 > 建立儲存桶';

  @override
  String get cloudS3HelpStep3 => '3. 進入 R2 > 管理 R2 API 令牌';

  @override
  String get cloudS3HelpStep4 => '4. 建立 API 令牌並複製憑據';

  @override
  String get cloudS3HelpStep5 => '5. 貼上端點、存取金鑰、私密金鑰和儲存桶名稱';

  @override
  String get cloudS3HelpNote => '推薦使用 Cloudflare R2，提供 10GB 免費儲存且無流量費';

  @override
  String get cloudStatusNotTested => '未測試';

  @override
  String get cloudStatusNormal => '連線正常';

  @override
  String get cloudStatusFailed => '連線失敗';

  @override
  String get cloudErrorAuthFailed => '認證失敗: API Key 無效';

  @override
  String cloudErrorServerStatus(String code) {
    return '伺服器返回狀態碼 $code';
  }

  @override
  String get cloudErrorWebdavNotSupported => '伺服器不支援 WebDAV 通訊協定';

  @override
  String get cloudErrorAuthFailedCredentials => '認證失敗: 使用者名稱或密碼錯誤';

  @override
  String get cloudErrorAccessDenied => '存取被拒絕: 請檢查權限';

  @override
  String cloudErrorPathNotFound(String path) {
    return '伺服器路徑不存在: $path';
  }

  @override
  String cloudErrorNetwork(String message) {
    return '網路錯誤: $message';
  }

  @override
  String get cloudTestSuccessMessage => '連線正常，設定有效';

  @override
  String get cloudTestFailedMessage => '連線失敗';

  @override
  String get cloudSwitchConfirmTitle => '切換雲端服務';

  @override
  String get cloudSwitchConfirmMessage => '切換雲端服務將登出目前帳號。確認切換？';

  @override
  String get cloudSwitchFailedTitle => '切換失敗';

  @override
  String get cloudSwitchFailedConfigMissing => '請先設定此雲端服務';

  @override
  String get cloudConfigInvalidMessage => '請填寫完整資訊';

  @override
  String get cloudSaveFailed => '儲存失敗';

  @override
  String cloudSwitchedTo(String type) {
    return '已切換至 $type';
  }

  @override
  String get cloudConfigureSupabaseTitle => '設定 Supabase';

  @override
  String get cloudConfigureWebdavTitle => '設定 WebDAV';

  @override
  String get cloudConfigureS3Title => '設定 S3';

  @override
  String get cloudSupabaseAnonKeyHintLong => '貼上完整的 anon key';

  @override
  String get cloudWebdavRemotePathLabel => '遠端路徑';

  @override
  String get cloudWebdavRemotePathHelperText => '資料儲存的遠端目錄路徑';

  @override
  String get welcomeSelectCurrencyTitle => '選擇記帳貨幣';

  @override
  String get welcomeCurrencyDescription => '選擇您常用的貨幣，之後可以隨時在設定中更改';

  @override
  String get aiOcrNoLedger => '未找到帳本';

  @override
  String get cloudTutorialTitle => '使用教程';

  @override
  String get cloudTutorialIntro => 'Spitout Cloud 是可自建的雲同步服務端,支援多裝置即時協同。流程很簡單:';

  @override
  String get cloudTutorialStep1Title => '第一步:部署或選擇伺服器';

  @override
  String get cloudTutorialStep1Desc => '自行部署:Docker 一行指令拉起(詳見 GitHub README 的 Docker 指南)。或直接使用朋友/團隊既有的 Spitout Cloud 伺服器。';

  @override
  String get cloudTutorialStep2Title => '第二步:取得帳號';

  @override
  String get cloudTutorialStep2Desc => 'Spitout Cloud 不支援自助註冊(避免公網服務被濫用)。自行部署:Docker 首次啟動日誌會印出隨機管理員帳密,直接用。加入他人伺服器:請管理員在 Web 後台 →「使用者」裡為你建立帳號。';

  @override
  String get cloudTutorialStep3Title => '第三步:登入並開啟同步';

  @override
  String get cloudTutorialStep3Desc => 'App 內選「Spitout Cloud」,填伺服器位址 + 管理員給你的帳號,登入。首次會全量上傳你本機所有帳本資料,之後每次編輯即時推送。';

  @override
  String get cloudTutorialStep4Title => '第四步:其他裝置登入';

  @override
  String get cloudTutorialStep4Desc => '手機、平板、Web 三端用同一帳號登入,資料即刻互通。修改數秒內互相感知。';

  @override
  String get cloudTutorialTipTitle => '小提示';

  @override
  String get cloudTutorialTipDesc => 'Web 端地址 = 伺服器位址,瀏覽器直接開啟即可。登入後可管理帳本、成員、查看紀錄。';

  @override
  String get cloudTutorialFeaturesTitle => '特色功能';

  @override
  String get cloudTutorialFeature1 => '📱 多裝置即時協同:手機 A + 手機 B + Web 三端同帳號,資料秒級同步';

  @override
  String get cloudTutorialFeature2 => '🌐 內建 Web 管理端:一個 Docker 映像檔含 server + web,瀏覽器即可使用';

  @override
  String get cloudTutorialFeature3 => '👥 多用戶獨立:一個伺服器可多人註冊,各自資料完全隔離';

  @override
  String get cloudTutorialFeature4 => '🤝 共享帳本:邀請家人 / 團隊一起記同一本,即時秒級同步';

  @override
  String get cloudTutorialGotIt => '我知道了';

  @override
  String get cloudSyncHint => '下載時可自動對比差異並逐條預覽。非即時同步，請避免多裝置同時編輯同一帳本。同步範圍為帳本資料（含關聯的帳戶、分類）。';

  @override
  String get appearanceSettings => '偏好調節';

  @override
  String get appearanceSettingsDesc => '主題、字體、語言、應用鎖等';

  @override
  String get appearanceSettingsPageTitle => '偏好調節';

  @override
  String get appearanceSettingsPageSubtitle => '外觀、顯示、安全等應用偏好';

  @override
  String get logCenterTitle => '日誌中心';

  @override
  String get logCenterSubtitle => '查看應用程式執行日誌';

  @override
  String get logCenterSearchHint => '搜尋日誌內容或標籤...';

  @override
  String get logCenterFilterLevel => '日誌級別';

  @override
  String get logCenterFilterPlatform => '平台';

  @override
  String get logCenterTotal => '全部';

  @override
  String get logCenterFiltered => '已過濾';

  @override
  String get logCenterEmpty => '暫無日誌';

  @override
  String get logCenterExport => '匯出';

  @override
  String get logCenterClear => '清空';

  @override
  String get logCenterExportFailed => '匯出失敗';

  @override
  String get logCenterClearConfirmTitle => '清空日誌';

  @override
  String get logCenterClearConfirmMessage => '確定要清空所有日誌嗎？此操作無法復原。';

  @override
  String get logCenterCleared => '日誌已清空';

  @override
  String get logCenterCopied => '已複製到剪貼簿';

  @override
  String get configImportExportTitle => '配置匯入匯出';

  @override
  String get configImportExportSubtitle => '備份和恢復應用配置';

  @override
  String get configImportExportInfoTitle => '功能說明';

  @override
  String get configImportExportInfoMessage => '備份和恢復應用配置，用於跨裝置遷移或恢復設定。匯出為 YAML 格式，可檢視和編輯。\n\n僅包含應用配置，不包含交易記錄（交易資料請使用明細匯入匯出功能）。';

  @override
  String get configImportExportWarning => '配置檔案包含雲端服務金鑰、密碼等敏感資訊，請妥善保管。匯入會覆蓋同名配置，建議先匯出備份。';

  @override
  String get configExportTitle => '匯出配置';

  @override
  String get configExportSubtitle => '將目前配置匯出為YAML檔案';

  @override
  String get configExportShareSubject => 'Spitout 配置檔案';

  @override
  String get configExportSuccess => '配置匯出成功';

  @override
  String get configExportFailed => '配置匯出失敗';

  @override
  String get configImportTitle => '匯入配置';

  @override
  String get configImportSubtitle => '從YAML檔案恢復配置';

  @override
  String get configImportNoFilePath => '未選擇檔案';

  @override
  String get configImportConfirmTitle => '確認匯入';

  @override
  String get configImportSuccess => '配置匯入成功';

  @override
  String get configImportFailed => '配置匯入失敗';

  @override
  String get configImportRestartTitle => '需要重新啟動';

  @override
  String get configImportRestartMessage => '配置已匯入，部分配置需要重新啟動應用程式後生效。';

  @override
  String get configImportOverwriteWarning => '匯入將覆蓋現有配置，建議先備份目前配置。';

  @override
  String get configImportExportIncludesTitle => '包含的配置項';

  @override
  String configExportSavedTo(String path) {
    return '已儲存至: $path';
  }

  @override
  String get configExportViewContent => '檢視內容';

  @override
  String get configExportCopyContent => '複製內容';

  @override
  String get configExportContentCopied => '已複製到剪貼簿';

  @override
  String get configExportReadFileFailed => '讀取檔案失敗';

  @override
  String get configIncludeLedgers => '帳本';

  @override
  String get configIncludeSupabase => 'Supabase 雲端服務配置';

  @override
  String get configIncludeWebdav => 'WebDAV 雲端服務配置';

  @override
  String get configIncludeS3 => 'S3 雲端服務配置';

  @override
  String get configIncludeSpitoutCloud => 'Spitout Cloud 雲端服務配置';

  @override
  String get configIncludeAppSettings => '應用程式設定（提醒、語言、外觀、字體、同步等）';

  @override
  String get configIncludeRecurringTransactions => '週期帳單';

  @override
  String get configIncludeCategories => '分類';

  @override
  String get configIncludeOtherSettings => '其他設定';

  @override
  String get configIncludeOtherSettingsSubtitle => '包含雲端服務配置和應用程式設定';

  @override
  String get configExportSelectTitle => '選擇匯出內容';

  @override
  String get configExportPreviewTitle => '匯出預覽';

  @override
  String get configExportConfirmTitle => '確認匯出';

  @override
  String get configImportSelectTitle => '選擇匯入內容';

  @override
  String get configImportPreviewTitle => '匯入預覽';

  @override
  String get ledgersConflictTitle => '同步衝突';

  @override
  String get ledgersConflictMessage => '本地和雲端帳本資料不一致，請選擇操作：';

  @override
  String ledgersConflictLocalInfo(int count) {
    return '本地：$count 筆帳單';
  }

  @override
  String ledgersConflictRemoteInfo(int count) {
    return '雲端：$count 筆帳單';
  }

  @override
  String ledgersConflictRemoteUpdated(String time) {
    return '雲端更新：$time';
  }

  @override
  String ledgersConflictLocalFingerprint(String fp) {
    return '本地指紋：$fp';
  }

  @override
  String ledgersConflictRemoteFingerprint(String fp) {
    return '雲端指紋：$fp';
  }

  @override
  String get ledgersConflictUpload => '上傳到雲端';

  @override
  String get ledgersConflictDownload => '下載到本地';

  @override
  String get ledgersConflictUploading => '正在上傳...';

  @override
  String get ledgersConflictDownloading => '正在下載...';

  @override
  String get ledgersConflictUploadSuccess => '上傳成功';

  @override
  String ledgersConflictDownloadSuccess(int inserted) {
    return '下載成功，已合併 $inserted 筆帳單';
  }

  @override
  String get welcomeExistingUserTitle => '老用戶？';

  @override
  String get welcomeExistingUserButton => '匯入配置';

  @override
  String get welcomeImportingConfig => '正在匯入配置...';

  @override
  String get welcomeImportSuccess => '配置匯入成功';

  @override
  String welcomeImportFailed(String error) {
    return '配置匯入失敗: $error';
  }

  @override
  String get welcomeImportNoFile => '未選擇檔案';

  @override
  String get calendarTitle => '日曆';

  @override
  String get calendarToday => '回到今天';

  @override
  String get calendarNoTransactions => '當天無交易';

  @override
  String get calendarAddTransaction => '在該日記帳';

  @override
  String get commonUncategorized => '未分類';

  @override
  String get syncPreviewTitle => '同步預覽';

  @override
  String get syncPreviewSelectAll => '全選';

  @override
  String get syncPreviewDeselectAll => '取消全選';

  @override
  String get syncPreviewAdded => '新增';

  @override
  String get syncPreviewModified => '修改';

  @override
  String get syncPreviewDeleted => '刪除';

  @override
  String syncPreviewAddedCount(int count) {
    return '新增 $count 條';
  }

  @override
  String syncPreviewModifiedCount(int count) {
    return '修改 $count 條';
  }

  @override
  String syncPreviewDeletedCount(int count) {
    return '刪除 $count 條';
  }

  @override
  String syncPreviewApply(int count) {
    return '套用 $count 項';
  }

  @override
  String get syncPreviewEmpty => '雲端資料與本機一致，無需同步';

  @override
  String get syncPreviewOldFormat => '雲端資料格式較舊，將執行全量替換';

  @override
  String get syncPreviewOldFormatMessage => '雲端資料不包含同步標識，無法逐條對比。將清空當前帳本資料並從雲端重新匯入。';

  @override
  String syncPreviewApplied(int count) {
    return '已套用 $count 項變更';
  }

  @override
  String get cloudSyncGuideTitle => '雲端同步使用指南';

  @override
  String get cloudSyncGuideGotIt => '我知道了';

  @override
  String get cloudSyncGuideHowItWorks => '運作原理';

  @override
  String get cloudSyncGuideHowItem1 => '上傳：將當前帳本的全部資料打包上傳至雲端，覆蓋雲端舊資料';

  @override
  String get cloudSyncGuideHowItem2 => '下載：從雲端拉取資料，與本機逐條比對差異，您可以選擇要同步哪些變更';

  @override
  String get cloudSyncGuideHowItem3 => '雲端始終只儲存最後一次上傳的完整快照，不保留歷史版本';

  @override
  String get cloudSyncGuideCorrect => '正確的使用方式';

  @override
  String get cloudSyncGuideCorrectItem1 => '同一時間只在一台裝置上記帳，完成後上傳';

  @override
  String get cloudSyncGuideCorrectItem2 => '切換裝置前，先在新裝置上下載同步';

  @override
  String get cloudSyncGuideCorrectItem3 => '下載時仔細查看預覽，確認每條變更再套用';

  @override
  String get cloudSyncGuideCorrectItem4 => '養成「編輯→上傳→切換裝置→下載→編輯」的習慣';

  @override
  String get cloudSyncGuideWrong => '應避免的用法';

  @override
  String get cloudSyncGuideWrongItem1 => '兩台裝置同時編輯同一帳本，後上傳的會覆蓋先上傳的改動';

  @override
  String get cloudSyncGuideWrongItem2 => '上傳後立刻在另一台裝置下載，檔案服務可能有數秒到數分鐘的同步延遲，請稍候再試';

  @override
  String get cloudSyncGuideWrongItem3 => '長時間不同步後一次性下載大量變更，容易遺漏需要處理的差異';

  @override
  String get cloudSyncGuideLimitations => '已知限制';

  @override
  String get cloudSyncGuideLimitItem1 => '非即時同步：需手動點擊上傳和下載';

  @override
  String get cloudSyncGuideLimitItem2 => '無衝突合併：不會自動合併兩端的修改，以最後上傳的為準';

  @override
  String get cloudSyncGuideLimitItem3 => '檔案服務延遲：上傳後雲端檔案可能需要數秒到數分鐘才能被其他裝置讀取，取決於您使用的雲端服務';

  @override
  String get appLockTitle => '應用上鎖';

  @override
  String get appLockDesc => 'PIN碼與生物辨識保護隱私';

  @override
  String get appLockEnable => '啟用應用鎖';

  @override
  String get appLockEnableDesc => '啟動和切回應用時需要驗證身份';

  @override
  String get appLockSetPin => '設定密碼';

  @override
  String get appLockChangePin => '修改密碼';

  @override
  String get appLockVerifyPin => '驗證密碼';

  @override
  String get appLockVerifyCurrentPin => '請輸入當前密碼';

  @override
  String get appLockSetNewPin => '請設定新密碼';

  @override
  String get appLockConfirmPin => '請再次輸入密碼';

  @override
  String get appLockEnterPin => '請輸入密碼';

  @override
  String get appLockPinSetSuccess => '密碼設定成功';

  @override
  String get appLockDisabled => '應用鎖已關閉';

  @override
  String get appLockBiometric => '生物辨識解鎖';

  @override
  String get appLockBiometricDesc => '使用Face ID或指紋快速解鎖';

  @override
  String get appLockBiometricReason => '請驗證身份以解鎖Spitout';

  @override
  String get appLockTimeout => '自動鎖定時間';

  @override
  String get appLockTimeoutImmediate => '立即';

  @override
  String get appLockTimeout1Min => '1分鐘後';

  @override
  String get appLockTimeout5Min => '5分鐘後';

  @override
  String get appLockTimeout15Min => '15分鐘後';

  @override
  String dayOfMonth(int day) {
    return '每月$day日';
  }

  @override
  String get syncHealthTitle => '同步狀態';

  @override
  String get cloudSyncHelpTitle => '同步說明 · 為什麼有時同步不動？';

  @override
  String get cloudSyncHelpModesTitle => '三種同步方式';

  @override
  String get cloudSyncHelpModesBody => '• 增量同步（日常自動）：記一筆 / 改一筆後，只把這條變化自動上傳下載，快、無需手動操作 —— 平時一直在跑的就是它。\n• 全量上傳：首次開啟雲同步、或雲端還沒有這個帳本的資料時，把本機全部資料一次性推上雲。\n• 全量下載：換新裝置、重裝、或本機為空時，從雲端把全部資料拉下來。';

  @override
  String get cloudSyncHelpWhenFullTitle => '什麼時候才會走全量？';

  @override
  String get cloudSyncHelpWhenFullBody => '全量只在某一端資料為空時才會自動觸發（首次開啟雲同步 / 換新裝置 / 重裝 / 清空了本機或雲端資料）。只要兩端都有資料，之後一直走增量，不會無故重來。想強制重新全量同步，得先清空對應端的資料。';

  @override
  String get cloudSyncHelpStuckTitle => '為什麼有時同步不動 / 卡住';

  @override
  String get cloudSyncHelpStuckBody => '• 全量上傳 / 下載不支援斷點續傳：中途斷網、或 App 被切到背景被系統清掉，會從頭重來，不會接著傳。資料多時請用穩定網路（建議 Wi-Fi）耐心等它跑完，別中途切走。\n• 增量同步是斷點安全的，日常同步不受影響。';

  @override
  String get cloudSyncHelpTroubleshootTitle => '排查辦法';

  @override
  String get cloudSyncHelpTroubleshootBody => '• 先在本頁下拉做一次「深度檢測」，對比本機與雲端差異。\n• 仍有問題，去「日誌中心」查看同步日誌（含失敗原因），方便回報。';

  @override
  String get cloudSyncHelpOpenLogCenter => '開啟日誌中心';

  @override
  String syncHealthCheckFailed(String msg) {
    return '檢測失敗：$msg';
  }

  @override
  String get syncHealthRecovering => '登入狀態恢復中…';

  @override
  String get syncHealthNeedsLogin => '未登入或登入已失效，請重新登入雲同步';

  @override
  String get syncHealthHasDiff => '偵測到差異，已自動同步';

  @override
  String get cloudSyncHealFailed => '自動恢復失敗，請從雲端恢復';

  @override
  String get syncHealthInSync => '本地與雲端一致';

  @override
  String get syncHealthGroupCurrentLedger => '目前帳本';

  @override
  String get syncHealthGroupAll => '全部帳本';

  @override
  String get syncHealthRowTx => '交易';

  @override
  String get syncHealthRowCategory => '分類';

  @override
  String get syncHealthRowUnpushed => '未推送變更';

  @override
  String syncHealthValue(int local, int remote) {
    return '本機 $local · 雲端 $remote';
  }

  @override
  String syncHealthValueRemoteMissing(int local) {
    return '本機 $local · 雲端 —';
  }

  @override
  String get twofaChallengeTitle => '二次驗證';

  @override
  String get twofaMethodTotp => '動態碼';

  @override
  String get twofaMethodRecovery => '恢復碼';

  @override
  String get twofaTotpInputPlaceholder => '輸入 6 位動態碼';

  @override
  String get twofaRecoveryInputPlaceholder => '輸入恢復碼';

  @override
  String get twofaVerifyButton => '驗證';

  @override
  String get twofaStatusTitle => '二次驗證';

  @override
  String get twofaStatusEnabled => '已啟用 ✓';

  @override
  String get twofaStatusDisabled => '未啟用';

  @override
  String twofaStatusEnabledAt(String date) {
    return '啟用於 $date';
  }

  @override
  String get sharedRoleOwner => '所有者';

  @override
  String get sharedRoleEditor => '編輯者';

  @override
  String get commonCopied => '已複製';

  @override
  String get commonRemove => '移除';

  @override
  String get sharedJoinPageTitle => '加入共享帳本';

  @override
  String get sharedJoinPageSubtitle => '輸入邀請碼或點擊對方分享的連結';

  @override
  String get sharedJoinEnterCode => '輸入邀請碼';

  @override
  String get sharedJoinEnterCodeHint => '邀請碼 6 位,全大寫字母數字。也可直接點擊邀請方分享的短連結跳過此步。';

  @override
  String get sharedJoinPreviewButton => '驗證邀請碼';

  @override
  String get sharedJoinAcceptButton => '加入帳本';

  @override
  String sharedJoinInvitedBy(String name) {
    return '$name 邀請你加入';
  }

  @override
  String sharedJoinRoleLine(String role) {
    return '角色:$role';
  }

  @override
  String sharedJoinExpiresInMinutes(int n) {
    return '有效期還剩 $n 分鐘';
  }

  @override
  String sharedJoinExpiresInHours(int n) {
    return '有效期還剩 $n 小時';
  }

  @override
  String sharedJoinExpiresInDays(int n) {
    return '有效期還剩 $n 天';
  }

  @override
  String sharedJoinSuccess(String name) {
    return '已加入「$name」';
  }

  @override
  String get sharedJoinCodeFormatError => '邀請碼格式不對,請輸入 6 位字母數字';

  @override
  String get sharedJoinInvalidOrExpired => '邀請碼無效或已過期,請向邀請人索取新碼';

  @override
  String get sharedJoinAlreadyMember => '你已經是該帳本成員';

  @override
  String get sharedJoinMemberLimit => '該帳本成員已滿,請聯絡帳本所有者';

  @override
  String get sharedInviteFormRole => '角色';

  @override
  String get sharedInviteFormExpiry => '有效期';

  @override
  String sharedInviteExpiryHours(int n) {
    return '$n 小時';
  }

  @override
  String sharedInviteExpiryDays(int n) {
    return '$n 天';
  }

  @override
  String get sharedInviteGenerate => '生成邀請碼';

  @override
  String get sharedInviteGenerateAnother => '生成另一個邀請碼';

  @override
  String get sharedInviteCopyCode => '複製邀請碼';

  @override
  String get sharedInviteCopyLink => '複製連結';

  @override
  String get sharedInviteShareLink => '分享給好友';

  @override
  String sharedInviteExpiresAt(String dt) {
    return '邀請將在 $dt 失效';
  }

  @override
  String get sharedInviteWarning => '⚠️ 不要把邀請碼發到公開群 / 朋友圈。拿到碼的任何人都可加入帳本;洩漏後請到成員管理頁撤銷並重新生成。';

  @override
  String get sharedInviteInstruction => '把邀請碼或短連結發給對方。對方裝上 Spitout 後,點擊連結或在「我的 → 加入共享帳本」輸入碼即可加入。';

  @override
  String sharedInviteShareText(String ledger, String code, String url) {
    return '邀請你加入 Spitout 共享帳本「$ledger」\n\n邀請碼:$code\n連結:$url\n\n點擊連結或在 Spitout → 我的 → 加入共享帳本輸入此碼即可。';
  }

  @override
  String get sharedMembersPageTitle => '成員管理';

  @override
  String get sharedMembersYou => '你';

  @override
  String get sharedMembersInviteCta => '邀請新成員';

  @override
  String get ledgersLeaveAndDelete => '退出並刪除';

  @override
  String get ledgersLeaveAndDeleteConfirm => '退出並刪除帳本';

  @override
  String ledgersLeaveAndDeleteMessage(String name) {
    return '確定要退出並刪除共享帳本「$name」嗎？\n退出後雲端將移除你的成員身分，本地資料全部清空，且無法再存取其中的交易。';
  }

  @override
  String get ledgersLeaveAndDeleteSuccess => '已退出並刪除帳本';

  @override
  String get ledgersDeleteShared => '刪除共享帳本';

  @override
  String get ledgersDeleteSharedConfirm => '刪除共享帳本';

  @override
  String ledgersDeleteSharedMessage(String name) {
    return '確定要刪除共享帳本「$name」嗎？\n此操作會一併移除所有協作者並清空他們的本地資料，不可恢復。';
  }

  @override
  String get ledgersDeleteSharedSuccess => '已刪除共享帳本';

  @override
  String get sharedMembersRemoveTitle => '移除成員';

  @override
  String get sharedMembersRemoveCta => '移除該成員';

  @override
  String sharedMembersRemoveConfirm(String name) {
    return '確定移除 $name?ta 將立即失去對該帳本的訪問。';
  }

  @override
  String get sharedMembersRemoved => '已移除成員';

  @override
  String get sharedMembersSyncPending => '首次建立帳本需要先在帳本管理頁面選中本帳本，重新進入頁面才可邀請成員';

  @override
  String get sharedMembersSaveFirst => '請先保存帳本';

  @override
  String sharedTxCreatedBy(String name) {
    return '$name 建立';
  }

  @override
  String sharedTxEditedBy(String name) {
    return '$name 最後編輯';
  }

  @override
  String sharedTxCreatedAndEditedBy(String name) {
    return '$name 建立並編輯';
  }

  @override
  String get sharedRequiresCloudSync => '請先啟用雲端同步';

  @override
  String get sharedMembersStatsTitle => '成員支出';

  @override
  String get sharedMembersStatsEmpty => '暫無記帳';

  @override
  String sharedMembersStatsTxCount(int count) {
    return '$count筆';
  }

  @override
  String get maintenanceOrphanCleanupTitle => '資料清理';

  @override
  String get maintenanceOrphanCleanupSubtitle => '檢查並清理本地孤兒資料';

  @override
  String get maintenanceOrphanRescan => '重新掃描';

  @override
  String get maintenanceOrphanEmpty => '本地資料乾淨,未發現孤兒資料';

  @override
  String get maintenanceOrphanGroupDb => '資料庫孤兒';

  @override
  String get maintenanceOrphanGroupSync => '同步狀態孤兒';

  @override
  String maintenanceOrphanSummary(int count) {
    return '發現 $count 項異常';
  }

  @override
  String get maintenanceOrphanSelectAll => '全選';

  @override
  String get maintenanceOrphanDeselectAll => '取消全選';

  @override
  String get maintenanceOrphanDeleteOne => '刪除此項';

  @override
  String maintenanceOrphanSelectedHint(int count) {
    return '已選 $count 項';
  }

  @override
  String get maintenanceOrphanCleanSelected => '清理已選';

  @override
  String get maintenanceOrphanConfirmTitle => '確認清理';

  @override
  String maintenanceOrphanConfirmDeleteOne(String title) {
    return '確定清理「$title」嗎？操作不可撤銷。';
  }

  @override
  String maintenanceOrphanConfirmDeleteBatch(int count) {
    return '確定清理選中的 $count 項嗎？操作不可撤銷。';
  }

  @override
  String maintenanceOrphanCleanSuccess(int count) {
    return '已清理 $count 項';
  }

  @override
  String maintenanceOrphanCleanPartial(int ok, int fail) {
    return '成功 $ok 項,失敗 $fail 項';
  }

  @override
  String maintenanceOrphanDeletedLedgerGroup(int ledgerId, int count) {
    return '已刪帳本 #$ledgerId（$count 筆）';
  }

  @override
  String get maintenanceOrphanMoveSingle => '移動到帳本';

  @override
  String get maintenanceOrphanMoveToLedger => '移動到帳本';

  @override
  String maintenanceOrphanMoveToLedgerSuccess(int count) {
    return '已將 $count 筆移動到帳本';
  }

  @override
  String get exchangeRatePageTitle => '匯率管理';

  @override
  String get exchangeRateEntrySubtitle => '自動取得匯率，支援手動修正';

  @override
  String get rateSourceAuto => '自動';

  @override
  String get rateSourceManual => '手動';

  @override
  String rateUpdatedAt(String date) {
    return '$date 更新';
  }

  @override
  String get rateNotFetched => '未取得';

  @override
  String get rateEditTitle => '編輯匯率';

  @override
  String rateInverseHint(String base, String rate, String quote) {
    return '反向參考:1 $base ≈ $rate $quote';
  }

  @override
  String get rateResetToAuto => '恢復自動';

  @override
  String get rateRefreshSuccess => '匯率已更新';

  @override
  String get rateRefreshFailed => '取得失敗,可手動設定匯率';

  @override
  String get rateDisclaimer => '資料來源:開源匯率資料,每日更新;折算僅供參考,可能與銀行實際牌價有差異。';

  @override
  String get txFlagExcludedTag => '不計收支';

  @override
  String get txRateLabel => '匯率';

  @override
  String get txRateMissingHint => '請手動填寫本筆匯率後儲存';

  @override
  String get ledgerBaseCurrencyLabel => '主幣種';

  @override
  String statsConvertedFootnote(Object currency) {
    return '含外幣,已按各筆記帳時匯率折算為 $currency';
  }

  @override
  String get ledgerCurrencyChangeRecalcHint => '修改本位幣將按當前匯率重算全部歷史交易的折算值';

  @override
  String get ledgerCurrencyChangeRecalcWarning => '歷史折算值將按最新匯率重算並覆蓋，往返切換（切走再切回）也無法還原原始折算值';

  @override
  String get recalcForeignTxBanner => '偵測到該帳本有未折算的外幣交易';

  @override
  String get recalcForeignTxAction => '按當前匯率重算折算';

  @override
  String recalcForeignTxDone(Object count) {
    return '已重算 $count 筆外幣交易的折算值';
  }

  @override
  String get txCurrencyPickerTitle => '選擇幣種';

  @override
  String get txAddEntryTitle => '記一筆';

  @override
  String get txDeleteLongPress => '長按清空';

  @override
  String get txSelectDateTimeTitle => '選擇交易時間';

  @override
  String get txSelectDateTimeHint => '上下滑動數字以選擇時間';

  @override
  String get txEditCategory => '編輯分類';

  @override
  String get txEditCategoryReadOnly => '編輯分類（共享帳本唯讀）';

  @override
  String get txLedgerBaseCurrency => '帳本主幣種';

  @override
  String recalcSyncCountHint(Object count) {
    return '將重算並同步 $count 筆交易';
  }

  @override
  String get analyticsLoadFailed => '資料載入失敗，請檢查網路';

  @override
  String get analyticsRetry => '重試';

  @override
  String get exportCsvHeaderCurrency => '幣種';

  @override
  String get importFieldCurrency => '幣種';

  @override
  String get currencyMOP => '澳門元';

  @override
  String get currencyMNT => '蒙古圖格里克';

  @override
  String get currencyKPW => '朝鲜元';

  @override
  String get currencyKHR => '柬埔寨瑞爾';

  @override
  String get currencyLAK => '老撾基普';

  @override
  String get currencyBND => '文萊元';

  @override
  String get currencyNPR => '尼泊爾盧比';

  @override
  String get currencyBTN => '不丹努爾特魯姆';

  @override
  String get currencyMVR => '马爾代夫拉菲亞';

  @override
  String get currencyAFN => '阿富汗尼';

  @override
  String get currencyUZS => '烏茲別克斯坦索姆';

  @override
  String get currencyTJS => '塔吉克斯坦索莫尼';

  @override
  String get currencyTMT => '土庫曼斯坦马納特';

  @override
  String get currencyKGS => '吉爾吉斯斯坦索姆';

  @override
  String get currencyQAR => '卡塔爾里亞爾';

  @override
  String get currencyKWD => '科威特第納爾';

  @override
  String get currencyBHD => '巴林第納爾';

  @override
  String get currencyOMR => '阿曼里亞爾';

  @override
  String get currencyJOD => '约旦第納爾';

  @override
  String get currencyLBP => '黎巴嫩鎊';

  @override
  String get currencyIQD => '伊拉克第納爾';

  @override
  String get currencyIRR => '伊朗里亞爾';

  @override
  String get currencyYER => '也門里亞爾';

  @override
  String get currencySYP => '敘利亞鎊';

  @override
  String get currencyGEL => '格魯吉亞拉里';

  @override
  String get currencyAMD => '亞美尼亞德拉姆';

  @override
  String get currencyAZN => '阿塞拜疆马納特';

  @override
  String get currencyRON => '羅马尼亞列伊';

  @override
  String get currencyBGN => '保加利亞列弗';

  @override
  String get currencyRSD => '塞爾維亞第納爾';

  @override
  String get currencyISK => '冰岛克朗';

  @override
  String get currencyMDL => '摩爾多瓦列伊';

  @override
  String get currencyALL => '阿爾巴尼亞列克';

  @override
  String get currencyMKD => '北马其顿第納爾';

  @override
  String get currencyBAM => '波黑可兑換马克';

  @override
  String get currencyGIP => '直布羅陀鎊';

  @override
  String get currencyGTQ => '危地马拉格查爾';

  @override
  String get currencyHNL => '洪都拉斯伦皮拉';

  @override
  String get currencyNIO => '尼加拉瓜科多巴';

  @override
  String get currencyCRC => '哥斯達黎加科朗';

  @override
  String get currencyPAB => '巴拿马巴波亞';

  @override
  String get currencyDOP => '多米尼加比索';

  @override
  String get currencyCUP => '古巴比索';

  @override
  String get currencyJMD => '牙買加元';

  @override
  String get currencyTTD => '特立尼達和多巴哥元';

  @override
  String get currencyBSD => '巴哈马元';

  @override
  String get currencyBBD => '巴巴多斯元';

  @override
  String get currencyBZD => '伯利茲元';

  @override
  String get currencyHTG => '海地古德';

  @override
  String get currencyKYD => '开曼群岛元';

  @override
  String get currencyAWG => '阿魯巴弗羅林';

  @override
  String get currencyBMD => '百慕大元';

  @override
  String get currencyUYU => '烏拉圭比索';

  @override
  String get currencyPYG => '巴拉圭瓜拉尼';

  @override
  String get currencyBOB => '玻利維亞诺';

  @override
  String get currencyVES => '委內瑞拉玻利瓦爾';

  @override
  String get currencyGYD => '圭亞那元';

  @override
  String get currencySRD => '蘇里南元';

  @override
  String get currencyFJD => '斐濟元';

  @override
  String get currencyPGK => '巴布亞新幾內亞基那';

  @override
  String get currencySBD => '所羅門群岛元';

  @override
  String get currencyTOP => '湯加潘加';

  @override
  String get currencyVUV => '瓦努阿圖瓦圖';

  @override
  String get currencyWST => '薩摩亞塔拉';

  @override
  String get currencyKES => '肯尼亞先令';

  @override
  String get currencyGHS => '加納塞地';

  @override
  String get currencyMAD => '摩洛哥迪拉姆';

  @override
  String get currencyDZD => '阿爾及利亞第納爾';

  @override
  String get currencyTND => '突尼斯第納爾';

  @override
  String get currencyLYD => '利比亞第納爾';

  @override
  String get currencyETB => '埃塞俄比亞比爾';

  @override
  String get currencyUGX => '烏干達先令';

  @override
  String get currencyTZS => '坦桑尼亞先令';

  @override
  String get currencyRWF => '盧旺達法郎';

  @override
  String get currencyMUR => '毛里求斯盧比';

  @override
  String get currencyBWP => '博茨瓦納普拉';

  @override
  String get currencyNAD => '納米比亞元';

  @override
  String get currencyZMW => '贊比亞克瓦查';

  @override
  String get currencyMWK => '马拉維克瓦查';

  @override
  String get currencyMZN => '莫桑比克梅蒂卡爾';

  @override
  String get currencyAOA => '安哥拉宽扎';

  @override
  String get currencyCDF => '剛果法郎';

  @override
  String get currencyGMD => '岡比亞達拉西';

  @override
  String get currencyGNF => '幾內亞法郎';

  @override
  String get currencyLRD => '利比里亞元';

  @override
  String get currencySLE => '塞拉利昂利昂';

  @override
  String get currencySDG => '蘇丹鎊';

  @override
  String get currencySSP => '南蘇丹鎊';

  @override
  String get currencySOS => '索马里先令';

  @override
  String get currencyDJF => '吉布提法郎';

  @override
  String get currencyERN => '厄立特里亞納克法';

  @override
  String get currencyBIF => '布隆迪法郎';

  @override
  String get currencyCVE => '佛得角埃斯庫多';

  @override
  String get currencySTN => '聖多美多布拉';

  @override
  String get currencySCR => '塞舌爾盧比';

  @override
  String get currencyKMF => '科摩羅法郎';

  @override
  String get currencyLSL => '萊索托洛蒂';

  @override
  String get currencySZL => '斯威士蘭里蘭吉尼';

  @override
  String get currencyMGA => '马達加斯加阿里亞里';

  @override
  String get currencyMRU => '毛里塔尼亞烏吉亞';

  @override
  String get detailImportExportTitle => '明細匯入匯出';

  @override
  String get detailImportExportSubtitle => '支出明細csv格式檔案';

  @override
  String get detailImportExportImportTitle => '匯入明細';

  @override
  String get detailImportExportImportSubtitle => '支援 CSV/TSV/XLSX，相容支付寶、微信帳單';

  @override
  String get detailImportExportExportTitle => '匯出明細';

  @override
  String get detailImportExportExportSubtitle => '將帳本明細匯出為 CSV 檔案';

  @override
  String get detailImportExportImportPoint1 => '支援通用 CSV、支付寶、微信三類帳單，檔案格式可為 CSV/TSV/XLSX';

  @override
  String get detailImportExportImportPoint2 => '差異僅在檔案結構：通用 CSV 為純淨表頭；支付寶、微信帳單含描述性前言，應用會自動跳過並定位表頭';

  @override
  String get detailImportExportImportPoint3 => '三類帳單統一透過列映射識別（日期、類型、金額、幣種、分類、二級分類、備註），匯入流程一致';

  @override
  String get detailImportExportExportPoint1 => '將所選帳本交易明細匯出為 CSV 檔案，UTF-8 BOM 編碼，Excel 可直接開啟';

  @override
  String get detailImportExportExportPoint2 => '檔案名為 spitout_時間戳.csv，預設儲存至系統 Download/Spitout 目錄';

  @override
  String get detailImportExportExportPoint3 => '包含欄位如下：';

  @override
  String get detailExportLedgerLabel => '匯出帳本';

  @override
  String get detailExportSelectAllLabel => '全選資料';

  @override
  String get detailExportSelectAllSubtitle => '匯出所選帳本下的全部資料';

  @override
  String get detailExportStartDate => '開始日期';

  @override
  String get detailExportEndDate => '結束日期';

  @override
  String get detailExportDateInvalid => '開始日期不能晚於結束日期';

  @override
  String get detailExportAction => '匯出';

  @override
  String exchangeRateCurrentLedger(Object name) {
    return '目前帳本：$name';
  }

  @override
  String get exchangeRateInfoTitle => '關於主幣種';

  @override
  String get exchangeRateInfoMessage => '主幣種是目前帳本的本位幣：帳本內的外幣交易會按匯率折算成主幣種，在統計頁和資產總覽中統一彙總比較。每個帳本各有自己的主幣種，可隨時切換；切換後將按最新匯率重算本帳本全部交易的折算值。\n\n匯率預設從公開資料來源每日自動拉取，也支援你點擊下方列表中的「編輯」為任意幣種手動設定匯率——手動匯率會覆蓋自動資料並立即生效。';

  @override
  String get rateEditLabel => '編輯';

  @override
  String get rateInvalidInput => '請輸入有效的匯率值（大於 0 的數字）';

  @override
  String get currencyManageTitle => '管理展示幣種';

  @override
  String get currencyManageEntry => '幣種管理';

  @override
  String currencyManageCount(Object count) {
    return '已選 $count 個幣種';
  }

  @override
  String get currencyManageBaseLocked => '帳本本位幣，不可隱藏';

  @override
  String get currencyManageHint => '隱藏的幣種不影響已有交易記錄，可隨時在此重新啟用。';

  @override
  String get detailImportExportMigrateTitle => '帳本資料遷移';

  @override
  String get detailImportExportMigrateTip => '你可以先將目前帳本的資料匯出為 CSV 檔案，再切換到目標帳本匯入該檔案，即可實現帳本間資料的平滑遷移。';

  @override
  String get mineCheckUpdate => '檢查更新';

  @override
  String get updateChecking => '檢查更新中…';

  @override
  String get updateAvailableTitle => '發現新版本';

  @override
  String updateLatestVersion(String version) {
    return '最新版本 v$version';
  }

  @override
  String get updateAlreadyLatestTitle => '已是最新版本';

  @override
  String updateAlreadyLatest(String version) {
    return '目前為最新版本 v$version';
  }

  @override
  String get updateGotoDownload => '前往下載';

  @override
  String updateCurrentVersion(String version) {
    return '目前版本 v$version';
  }

  @override
  String updateNewVersionHint(String version) {
    return '發現新版本 v$version';
  }

  @override
  String get updateLater => '稍後再說';

  @override
  String get updateOk => '好的';

  @override
  String get updateCantAutoCheckTitle => '無法自動檢查更新';

  @override
  String get updateCantAutoCheck => '無法取得版本資訊，可前往 GitHub 查看最新版本';

  @override
  String get updateGoToGithub => '前往 GitHub 查看';

  @override
  String get mineUpdateNow => '更新';

  @override
  String get ledgerMetaReadOnlyToast => '協作者無權修改帳本資訊';

  @override
  String get aaSettlementTitle => '分攤統計';

  @override
  String get aaSettlementOverview => '總覽';

  @override
  String get aaSettlementTotalAmount => '分攤總額';

  @override
  String aaSettlementTxCount(int count) {
    return '$count 筆分攤交易';
  }

  @override
  String get aaSettlementPerPerson => '分攤詳情';

  @override
  String get aaSettlementPaid => '實付';

  @override
  String get aaSettlementShare => '應攤';

  @override
  String get aaSettlementNet => '差額';

  @override
  String get aaSettlementNetReceive => '應收';

  @override
  String get aaSettlementNetPay => '應付';

  @override
  String get aaSettlementTransferPlan => '轉帳方案';

  @override
  String aaSettlementTransferPayTo(String from, String to) {
    return '$from 付給 $to';
  }

  @override
  String get aaSettlementNoTransfers => '已結清，無需轉帳';

  @override
  String get aaSettlementExcluded => '不計入詳單';

  @override
  String aaSettlementParticipantCount(int count) {
    return '分攤人數 $count 人';
  }

  @override
  String get aaSettlementExcludedEmpty => '暫無不計入詳單的交易';

  @override
  String get aaEditTitle => '分攤明細';

  @override
  String get aaPayer => '支出人';

  @override
  String get aaSplitMode => '分攤方式';

  @override
  String get aaParticipants => '參與人';

  @override
  String get aaSplitAmounts => '指定金額';

  @override
  String get aaModePerPerson => '人均分攤';

  @override
  String get aaModeCustom => '指定分攤';

  @override
  String get aaModeNoSplit => '不分攤';

  @override
  String get aaSplitClearAll => '清空重填';

  @override
  String get aaParticipantsAll => '全部成員';

  @override
  String aaParticipantsSelected(int count) {
    return '已選 $count 人';
  }

  @override
  String get aaSplitTotal => '合計';

  @override
  String get aaSplitPayerAdjustHint => '差額由支出人兜底';

  @override
  String get aaVirtualUserTitle => '虛擬用戶';

  @override
  String get aaVirtualUserAdd => '新增虛擬用戶';

  @override
  String get aaVirtualUserNameHint => '輸入暱稱';

  @override
  String get aaVirtualUserRename => '重新命名';

  @override
  String get aaVirtualUserEmpty => '暫無虛擬用戶';

  @override
  String aaVirtualUserDeleteConfirm(String name) {
    return '確定刪除虛擬用戶「$name」嗎？';
  }

  @override
  String get aaVirtualUserInUse => '該虛擬用戶名下有帳，不可刪除';

  @override
  String aaVirtualUserDefaultName(int index) {
    return '虛擬用戶$index';
  }

  @override
  String get aaAddVirtualUser => '新增虛擬用戶';

  @override
  String get aaUnknownUser => '未知';

  @override
  String get aaMe => '我';

  @override
  String get aaPerPersonAllMembers => '人均分攤（全部成員）';

  @override
  String get ledgerAaEnabled => 'AA 分攤';

  @override
  String get ledgerAaEnabledHint => '開啟後記帳時可選擇分攤方式';

  @override
  String get ledgerAaSettlementEntry => '查看分攤結算';

  @override
  String get ledgerAaVirtualUsersEntry => '管理虛擬用戶';

  @override
  String get aaNoParticipants => '請先新增參與人';

  @override
  String get aaSplitAmountIncomplete => '請填寫全部參與人的金額';
}
