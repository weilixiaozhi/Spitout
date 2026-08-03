import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Spitout';

  @override
  String get tabHome => '홈';

  @override
  String get tabAnalytics => '통계';

  @override
  String get tabCalendar => '캘린더';

  @override
  String get tabMine => '내 정보';

  @override
  String get commonCancel => '취소';

  @override
  String get commonConfirm => '확인';

  @override
  String get commonSave => '저장';

  @override
  String get commonDelete => '삭제';

  @override
  String get commonAdd => '추가';

  @override
  String get commonOk => '확인';

  @override
  String get commonDone => '완료';

  @override
  String get homeSelectBillMonth => '월 선택';

  @override
  String get homePickerHint => '숫자를 위아래로 슬라이드하여 선택';

  @override
  String get homeBackToCurrentMonth => '이번 달로 돌아가기';

  @override
  String get homeTodayExpense => '오늘';

  @override
  String get homeWeekExpense => '이번 주';

  @override
  String get homeMonthExpense => '이번 달 지출';

  @override
  String get homeDetailCategory => '분류';

  @override
  String get homeDetailDate => '기록 날짜';

  @override
  String get homeDetailAmount => '기록 금액';

  @override
  String get homeDetailCurrency => '통화';

  @override
  String get homeDetailNativeAmount => '기준 통화 환산';

  @override
  String get homeDetailMembers => '협업 멤버';

  @override
  String get homeDetailCreator => '작성자';

  @override
  String get homeDetailLastEditor => '최종 편집자';

  @override
  String get homeDetailEditHistory => '편집 기록';

  @override
  String get homeDetailEditHistoryHint => '보기 전용';

  @override
  String get homeDetailEditButton => '편집하기';

  @override
  String get homeDetailNoHistory => '편집 기록 없음';

  @override
  String get homeDeleteDetailTitle => '이 내역을 삭제하시겠습니까?';

  @override
  String homeDeleteDetailMessage(Object name) {
    return '\"$name\" 기록을 삭제합니다. 이 작업은 취소할 수 없습니다.';
  }

  @override
  String get commonEmpty => '데이터 없음';

  @override
  String get commonError => '오류';

  @override
  String get commonFailed => '실패';

  @override
  String get commonBack => '뒤로';

  @override
  String get commonNext => '다음';

  @override
  String get commonFinish => '완료';

  @override
  String get commonOther => '기타';

  @override
  String get commonSearch => '검색';

  @override
  String get commonNoteHint => '메모...';

  @override
  String get commonSettings => '설정';

  @override
  String get commonCurrent => '현재';

  @override
  String get commonTutorial => '튜토리얼';

  @override
  String get commonConfigure => '설정';

  @override
  String get commonPressAgainToExit => '한 번 더 누르면 종료됩니다';

  @override
  String get commonWeekdayMonday => '월요일';

  @override
  String get commonWeekdayTuesday => '화요일';

  @override
  String get commonWeekdayWednesday => '수요일';

  @override
  String get commonWeekdayThursday => '목요일';

  @override
  String get commonWeekdayFriday => '금요일';

  @override
  String get commonWeekdaySaturday => '토요일';

  @override
  String get commonWeekdaySunday => '일요일';

  @override
  String get homeExpense => '지출';

  @override
  String get homeNoRecords => '아직 기록이 없습니다';

  @override
  String get homeSelectDate => '날짜 선택';

  @override
  String homeYear(int year) {
    return '$year';
  }

  @override
  String homeMonth(String month) {
    return '$month월';
  }

  @override
  String homeMonthExpenseOf(String month) {
    return '$month월 지출';
  }

  @override
  String get homeNoRecordsSubtext => '하단의 플러스 버튼을 눌러 기록을 추가하세요';

  @override
  String get homeBaseCurrencyNeedLedger => '먼저 장부를 생성해 주세요';

  @override
  String homeBaseCurrencySwitched(String code) {
    return '기준 통화를 $code(으)로 변경했습니다';
  }

  @override
  String get homePullCloudSuccess => '클라우드 장부 데이터를 동기화했습니다';

  @override
  String get homePullCloudFailed => '새로고침 실패, 다시 시도하세요';

  @override
  String get homePullLocalSuccess => '로컬 장부 데이터 및 설정을 새로고침했습니다';

  @override
  String get homePullCloudFailedButLocalOk => '클라우드 동기화 실패, 로컬 데이터 새로고침됨(환율/설정)';

  @override
  String homePullCloudHealed(int count) {
    return '누락된 클라우드 데이터 $count건을 자동 복구했습니다';
  }

  @override
  String get homePullCloudGap => '일부 클라우드 기록을 자동 복구하지 못했습니다. 동기화 페이지에서 \'클라우드에서 복원\'을 실행하세요';

  @override
  String get homeSyncing => '장부 데이터 동기화 중';

  @override
  String get homeSwitchMonthHint => '목록을 좌우로 스와이프해 월 전환';

  @override
  String get analyticsMonth => '월';

  @override
  String get analyticsYear => '년';

  @override
  String get analyticsAll => '전체';

  @override
  String get analyticsWeek => '주';

  @override
  String analyticsSwipePeriodHint(Object period) {
    return '목록을 좌우로 스와이프해 $period 전환';
  }

  @override
  String get analyticsTrend => '지출 추세';

  @override
  String get analyticsTotalExpenseLabel => '총 지출';

  @override
  String get analyticsDailyExpense => '일일 지출';

  @override
  String get analyticsMoMLastWeek => '전주 대비';

  @override
  String get analyticsMoMLastMonth => '전월 대비';

  @override
  String get analyticsMoMLastYear => '전년 대비';

  @override
  String get analyticsCategoryLabel => '카테고리';

  @override
  String get analyticsExpenseRatio => '지출 비율';

  @override
  String get analyticsThisWeek => '이번 주';

  @override
  String get analyticsBackToThisWeek => '이번 주로';

  @override
  String get analyticsBackToThisMonth => '이번 달로';

  @override
  String get analyticsBackToThisYear => '올해로';

  @override
  String analyticsWeekN(int week) {
    return '$week주차';
  }

  @override
  String get analyticsSelectWeek => '주 선택';

  @override
  String get ledgersTitle => '가계부 관리';

  @override
  String get ledgersNew => '새 가계부';

  @override
  String get ledgersClear => '가계부 비우기';

  @override
  String ledgersClearMessage(Object name) {
    return '가계부 \"$name\"의 모든 거래를 비우시겠습니까? 이 작업은 되돌릴 수 없습니다.\\n가계부 자체는 유지되며 거래 데이터만 삭제됩니다.';
  }

  @override
  String get ledgerDefaultName => '기본 가계부';

  @override
  String get ledgersEdit => '가계부 편집';

  @override
  String get ledgersDelete => '가계부 삭제';

  @override
  String get ledgersDeleteConfirm => '가계부 삭제';

  @override
  String get ledgersDeleteMessage => '이 가계부와 모든 기록을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.\\n클라우드에 백업이 있는 경우 함께 삭제됩니다.';

  @override
  String get ledgersDeleted => '삭제됨';

  @override
  String get ledgersDeleteFailed => '삭제 실패';

  @override
  String get ledgersClearTitle => '가계부 비우기';

  @override
  String get ledgersClearSuccess => '가계부를 비웠습니다';

  @override
  String get ledgersCreateSuccess => '가계부가 생성되었습니다';

  @override
  String get ledgerNameLabel => '장부 이름';

  @override
  String get ledgerNameHint => '장부 이름을 입력하세요';

  @override
  String get ledgersDefaultLedgerName => '기본 가계부';

  @override
  String get ledgersCurrency => '통화';

  @override
  String get ledgersMonthStartDay => '월 시작일';

  @override
  String get ledgersMonthStartDayHint => '통계와 예산은 이 날짜(1~28)를 매월 기간의 시작으로 사용합니다';

  @override
  String get ledgersMonthStartDayNatural => '1일 (달력 기준)';

  @override
  String ledgersMonthStartDayValue(int day) {
    return '매월 $day일';
  }

  @override
  String get ledgersSearchCurrency => '검색: 중국어 또는 코드';

  @override
  String get ledgersCreate => '만들기';

  @override
  String ledgersRecords(String count) {
    return '기록: $count건';
  }

  @override
  String ledgersExpense(String expense) {
    return '지출: $expense';
  }

  @override
  String get ledgersEmpty => '가계부가 없습니다';

  @override
  String get ledgersSectionLocal => '로컬 가계부';

  @override
  String get ledgersSectionCloud => 'Spitout Cloud 가계부';

  @override
  String get ledgersSectionLocalEmpty => '로컬 가계부가 없습니다. 로컬 가계부는 이 기기에만 저장됩니다.';

  @override
  String get ledgersSectionCloudEmpty => '클라우드 가계부가 없습니다. 클라우드 가계부는 기기 간에 동기화됩니다.';

  @override
  String get ledgersSectionCloudSignInHint => 'Spitout Cloud에 로그인하면 클라우드 가계부를 사용할 수 있습니다';

  @override
  String get ledgersStorageLocation => '저장 위치';

  @override
  String get ledgersStorageLocalHint => '이 기기에만 저장되며 클라우드에 업로드되지 않습니다';

  @override
  String get ledgersStorageCloudHint => 'Spitout Cloud에 업로드되어 기기 간에 동기화됩니다';

  @override
  String get ledgersActionMoveToCloud => 'Spitout Cloud로 이동';

  @override
  String get ledgersActionMoveToLocal => '로컬로 이동';

  @override
  String get ledgersActionCopyToLocal => '로컬로 복사';

  @override
  String ledgersMoveToCloudMessage(String name) {
    return '가계부 \"$name\"의 데이터가 Spitout Cloud에 업로드되어 기기 간에 동기화됩니다.';
  }

  @override
  String ledgersMoveToLocalMessage(String name) {
    return '가계부 \"$name\"이(가) Spitout Cloud에서 삭제되고 이 기기에만 남습니다. 다른 기기에서는 더 이상 볼 수 없습니다.';
  }

  @override
  String ledgersCopyToLocalMessage(String name) {
    return '가계부 \"$name\"의 로컬 사본을 만듭니다. 클라우드 원본은 그대로 유지됩니다.';
  }

  @override
  String get ledgersMoveToCloudSuccess => 'Spitout Cloud로 이동했습니다';

  @override
  String get ledgersMoveToLocalSuccess => '로컬로 이동했습니다';

  @override
  String get ledgersCopyToLocalSuccess => '로컬로 복사했습니다';

  @override
  String ledgersSwitched(String name) {
    return '가계부 \"$name\"(으)로 전환되었습니다';
  }

  @override
  String get categoryTitle => '카테고리 관리';

  @override
  String get categoryExpense => '지출';

  @override
  String get categoryEmpty => '카테고리가 없습니다';

  @override
  String categoryLoadFailed(String error) {
    return '불러오기 실패: $error';
  }

  @override
  String get importReading => '파일 읽는 중…';

  @override
  String get importPreparing => '준비 중…';

  @override
  String importColumnNumber(Object number) {
    return '$number열';
  }

  @override
  String get importConfirmMapping => '매핑 확인';

  @override
  String get importCategoryMapping => '카테고리 매핑';

  @override
  String get importNoDataParsed => '파싱된 데이터가 없습니다. 이전 페이지로 돌아가 CSV 내용이나 구분자를 확인해 주세요.';

  @override
  String get importFieldDate => '날짜';

  @override
  String get importFieldType => '유형';

  @override
  String get importFieldAmount => '금액';

  @override
  String get importFieldCategory => '카테고리';

  @override
  String get importFieldNote => '메모';

  @override
  String get importPreview => '데이터 미리보기';

  @override
  String importPreviewLimit(Object shown, Object total) {
    return '전체 $total건 중 처음 $shown건을 표시합니다';
  }

  @override
  String get importCategoryNotSelected => '카테고리가 선택되지 않았습니다';

  @override
  String get importCategoryMappingDescription => '각 카테고리 이름에 해당하는 로컬 카테고리를 선택하세요:';

  @override
  String get importKeepOriginalName => '원래 이름 유지';

  @override
  String importProgress(Object fail, Object ok) {
    return '가져오는 중, 성공: $ok, 실패: $fail';
  }

  @override
  String get importCancelImport => '가져오기 취소';

  @override
  String get importCompleteTitle => '가져오기 완료';

  @override
  String get importSelectCategoryFirst => '먼저 카테고리 매핑을 선택해 주세요';

  @override
  String get importNextStep => '다음 단계';

  @override
  String get importPreviousStep => '이전 단계';

  @override
  String get importStartImport => '가져오기 시작';

  @override
  String get importAutoDetect => '자동 감지';

  @override
  String get importInProgress => '가져오는 중';

  @override
  String importProgressDetail(Object done, Object fail, Object ok, Object total) {
    return '$total건 중 $done건 가져옴, 성공 $ok, 실패 $fail';
  }

  @override
  String get importBackgroundImport => '백그라운드로 가져오기';

  @override
  String get importCancelled => '가져오기 취소됨';

  @override
  String importCompleted(Object cancelled, Object fail, Object ok) {
    return '가져오기 완료$cancelled, 성공 $ok, 실패 $fail';
  }

  @override
  String importSkippedNonTransactionTypes(Object count) {
    return '거래가 아닌 $count건(부채 등)을 건너뛰었습니다';
  }

  @override
  String importTransactionFailed(Object error) {
    return '가져오기에 실패하여 모든 변경사항이 롤백되었습니다: $error';
  }

  @override
  String importFileOpenError(String error) {
    return '파일 선택기를 열 수 없습니다: $error';
  }

  @override
  String get mineTitle => '내 정보';

  @override
  String get mineLanguageSettings => '앱 언어';

  @override
  String get languageTitle => '언어 설정';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystemDefault => '시스템 따르기';

  @override
  String get mineSlogan => '닉네임을 설정하세요.';

  @override
  String get mineDisplayNameEditTitle => '닉네임 설정';

  @override
  String get mineDisplayNameHint => '닉네임을 입력하세요';

  @override
  String get mineDisplayNameSaved => '닉네임이 업데이트되었습니다';

  @override
  String get mineGreetingMorning => '좋은 아침이에요';

  @override
  String get mineGreetingNoon => '좋은 점심이에요';

  @override
  String get mineGreetingAfternoon => '좋은 오후예요';

  @override
  String get mineGreetingEvening => '좋은 저녁이에요';

  @override
  String get mineGreetingNight => '편안한 밤 되세요';

  @override
  String mineGreetingNamed(String greeting, String name) {
    return '$greeting, $name님';
  }

  @override
  String get mineAvatarDelete => '아바타 삭제';

  @override
  String get mineAvatarUploadNew => '새 아바타 업로드';

  @override
  String get mineCloudService => '클라우드 서비스';

  @override
  String get mineCloudServiceLoading => '불러오는 중...';

  @override
  String get mineSyncTitle => '동기화';

  @override
  String get mineSyncNotLoggedIn => '로그인하지 않음';

  @override
  String get mineSyncNotConfigured => '클라우드가 설정되지 않음';

  @override
  String get mineSyncNoRemote => '클라우드 데이터 없음';

  @override
  String mineSyncInSync(Object count) {
    return '동기화됨 (로컬 $count건)';
  }

  @override
  String mineSyncLocalNewer(Object count) {
    return '로컬이 최신 상태입니다 ($count건, 업로드를 권장합니다)';
  }

  @override
  String get mineSyncCloudNewer => '클라우드가 최신 상태입니다 (다운로드하여 동기화하세요)';

  @override
  String get mineSyncDifferent => '로컬과 클라우드가 다릅니다. 다운로드하여 비교하세요';

  @override
  String get mineSyncError => '상태를 가져오지 못했습니다';

  @override
  String get mineSyncDetailTitle => '동기화 상태 상세';

  @override
  String mineSyncLocalRecords(Object count) {
    return '로컬 기록: $count건';
  }

  @override
  String mineSyncCloudRecords(Object count) {
    return '클라우드 기록: $count건';
  }

  @override
  String mineSyncCloudLatest(Object time) {
    return '클라우드 최신 기록 시각: $time';
  }

  @override
  String mineSyncLocalFingerprint(Object fingerprint) {
    return '로컬 지문: $fingerprint';
  }

  @override
  String mineSyncCloudFingerprint(Object fingerprint) {
    return '클라우드 지문: $fingerprint';
  }

  @override
  String mineSyncMessage(Object message) {
    return '메시지: $message';
  }

  @override
  String get mineUploadTitle => '업로드';

  @override
  String get mineUploadNeedLogin => '로그인이 필요합니다';

  @override
  String get mineUploadNeedCloudService => '클라우드 서비스 모드에서만 사용 가능합니다';

  @override
  String get mineUploadInProgress => '업로드 중...';

  @override
  String get mineUploadRefreshing => '새로고침 중...';

  @override
  String get mineUploadSynced => '동기화됨';

  @override
  String get mineUploadSuccess => '업로드 완료';

  @override
  String get mineUploadSuccessMessage => '현재 가계부가 클라우드에 동기화되었습니다';

  @override
  String get mineDownloadTitle => '다운로드 및 동기화';

  @override
  String get mineDownloadNeedCloudService => '클라우드 서비스 모드에서만 사용 가능합니다';

  @override
  String get mineDownloadComplete => '동기화 완료';

  @override
  String mineDownloadResult(Object inserted) {
    return '가져옴: $inserted건';
  }

  @override
  String get mineLoginTitle => '로그인';

  @override
  String get mineLoginSubtitle => '동기화할 때만 필요합니다';

  @override
  String get cloudReloginTitle => '다시 로그인';

  @override
  String get cloudReloginSuccess => '다시 로그인했습니다';

  @override
  String get mineLoggedInEmail => '로그인됨';

  @override
  String get mineLogoutSubtitle => '눌러서 로그아웃';

  @override
  String get mineLogoutConfirmTitle => '로그아웃';

  @override
  String get mineLogoutConfirmMessage => '로그아웃하시겠습니까?\n로그아웃하면 클라우드 동기화를 사용할 수 없습니다.';

  @override
  String get mineLogoutButton => '로그아웃';

  @override
  String get mineAutoSyncTitle => '가계부 자동 동기화';

  @override
  String get mineAutoSyncSubtitle => '기록 후 클라우드에 자동 업로드';

  @override
  String get mineAutoSyncNeedLogin => '사용하려면 로그인이 필요합니다';

  @override
  String get mineCategoryManagement => '카테고리 관리';

  @override
  String get mineCategoryManagementSubtitle => '사용자 지정 카테고리 편집';

  @override
  String get mineRecurringTransactions => '정기 결제';

  @override
  String get mineRecurringTransactionsSubtitle => '정기 결제 관리';

  @override
  String get mineReminderSettings => '알림 설정';

  @override
  String get mineReminderSettingsSubtitle => '매일 기록 알림 설정';

  @override
  String get categoryEditTitle => '카테고리 편집';

  @override
  String get categoryNewTitle => '새 카테고리';

  @override
  String get categoryDetailTooltip => '카테고리 요약';

  @override
  String get categoryDefaultTitle => '기본 카테고리';

  @override
  String get categoryNameLabel => '카테고리 이름';

  @override
  String get categoryNameHint => '카테고리 이름을 입력하세요';

  @override
  String get categoryNameRequired => '카테고리 이름을 입력해 주세요';

  @override
  String get categoryNameTooLong => '카테고리 이름은 4자를 초과할 수 없습니다';

  @override
  String get categoryNameDuplicate => '이미 존재하는 카테고리 이름입니다';

  @override
  String get categoryIconLabel => '카테고리 아이콘';

  @override
  String get categoryCurrentIcon => '현재 아이콘';

  @override
  String get categorySaveError => '저장 실패';

  @override
  String categoryUpdated(Object name) {
    return '카테고리 \"$name\"이(가) 수정되었습니다';
  }

  @override
  String categoryCreated(Object name) {
    return '카테고리 \"$name\"이(가) 생성되었습니다';
  }

  @override
  String get categoryCannotDelete => '삭제할 수 없습니다';

  @override
  String get categoryClearUnused => '사용하지 않는 카테고리 정리';

  @override
  String get categoryClearUnusedTitle => '사용하지 않는 카테고리 정리';

  @override
  String categoryClearUnusedMessage(Object count) {
    return '사용하지 않는 카테고리 $count개를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get categoryClearUnusedListTitle => '삭제될 카테고리:';

  @override
  String get categoryClearUnusedEmpty => '사용하지 않는 카테고리가 없습니다';

  @override
  String categoryClearUnusedSuccess(Object count) {
    return '카테고리 $count개를 삭제했습니다';
  }

  @override
  String get categoryClearUnusedFailed => '정리 실패';

  @override
  String get categoryDeleteError => '삭제 실패';

  @override
  String categorySubCategoryCreated(Object name) {
    return '하위 카테고리가 추가되었습니다: $name';
  }

  @override
  String get categoryParentCategoryTitle => '소속 분류';

  @override
  String get categorySelectParentTitle => '분류 선택';

  @override
  String get categoryHasSubCategories => '이 분류에는 하위 분류가 있어 수정할 수 없습니다';

  @override
  String get categorySearchCategory => '분류 검색';

  @override
  String get categoryTopLevelLabel => '최상위';

  @override
  String get categorySecondLevelLabel => '하위';

  @override
  String get categoryExpenseList => '식사-교통-쇼핑-오락-홈리빙-가족-통신비-공과금-주거-의료-교육-반려동물-운동-디지털-여행-술담배-육아-미용-수리-인간관계-학습-자동차-택시-지하철-배달음식-관리비-주차-기부-선물-세금-음료-의류-간식-축의금-과일-게임-도서-데이트-인테리어-생활용품-복권-주식-사회보험-택배-업무-이체-기타';

  @override
  String get categoryExpenseDining => '식사-아침-점심-저녁-배달의민족-쿠팡이츠-요기요-외식-식비';

  @override
  String get categoryExpenseSnacks => '간식-쿠키-과자-사탕-초콜릿-견과류';

  @override
  String get categoryExpenseFruit => '과일-사과-바나나-오렌지-포도-수박-기타 과일';

  @override
  String get categoryExpenseBeverage => '음료-밀크티-커피-주스-탄산음료-생수';

  @override
  String get categoryExpensePastry => '제과제빵-케이크-빵-디저트-베이커리';

  @override
  String get categoryExpenseCooking => '식재료-채소-육류-해산물-조미료-곡물·식용유';

  @override
  String get categoryExpenseShopping => '쇼핑-슈퍼마켓-생활용품-의류-신발-가방';

  @override
  String get categoryExpensePets => '반려동물-반려동물 사료-반려동물 용품-반려동물 병원-반려동물 미용';

  @override
  String get categoryExpenseTransport => '교통-교통카드충전-택시-주차비-주유비';

  @override
  String get categoryExpenseCar => '자동차-자동차 정비-자동차 수리-자동차 보험-세차-교통 범칙금';

  @override
  String get categoryExpenseClothing => '의류-상의-하의-원피스-신발-패션 소품';

  @override
  String get categoryExpenseDailyGoods => '생활용품-위생용품-화장지-세제-주방용품';

  @override
  String get categoryExpenseEducation => '교육-학비-학원비-도서-문구-사무용품-학습';

  @override
  String get categoryExpenseInvestLoss => '투자 손실-주식 손실-펀드 손실-기타 투자 손실';

  @override
  String get categoryExpenseEntertainment => '오락-영화-노래방-놀이공원-술집-기타 오락';

  @override
  String get categoryExpenseGame => '게임-게임 충전-게임 아이템-게임 멤버십';

  @override
  String get categoryExpenseHealthProducts => '건강기능식품-비타민-건강식품-영양보충제';

  @override
  String get categoryExpenseSubscription => '구독-영상 멤버십-음악 멤버십-클라우드 저장소-기타 구독';

  @override
  String get categoryExpenseSports => '운동-헬스장-운동용품-운동 강습-야외활동';

  @override
  String get categoryExpenseHousing => '주거-공과금-관리비-월세-대출 상환-리모델링-인터넷';

  @override
  String get categoryExpenseHome => '홈리빙-가구-가전제품-인테리어 소품-침구';

  @override
  String get categoryExpenseBeauty => '미용-스킨케어-화장품-헤어컷-네일아트';

  @override
  String get categoryExpenseTransfer => '이체-생활비-가족-부모-연인-돈빌림';

  @override
  String get appearanceThemeMode => '다크 모드';

  @override
  String get appearanceThemeModeSystem => '시스템 따르기';

  @override
  String get appearanceThemeModeLight => '라이트 모드';

  @override
  String get appearanceThemeModeDark => '다크 모드';

  @override
  String get appearanceExpenseColorScheme => '지출 색상';

  @override
  String get appearanceExpenseColorRed => '지출을 빨간색으로';

  @override
  String get appearanceExpenseColorGreen => '지출을 초록색으로';

  @override
  String get appearanceExpenseColorApplied => '변경됨';

  @override
  String get reminderTitle => '기록 알림';

  @override
  String get reminderSubtitle => '매일 기록 알림 시간을 설정하세요';

  @override
  String get reminderDailyTitle => '매일 기록 알림';

  @override
  String get reminderDailySubtitle => '활성화하면 지정한 시간에 기록하라는 알림을 보냅니다';

  @override
  String get reminderTimeTitle => '알림 시간';

  @override
  String get commonSelectTime => '시간 선택';

  @override
  String get reminderTestNotification => '테스트 알림 보내기';

  @override
  String get reminderTestSent => '테스트 알림을 보냈습니다';

  @override
  String get reminderTestTitle => '테스트 알림';

  @override
  String get reminderTestBody => '테스트 알림입니다. 눌러서 효과를 확인해 보세요';

  @override
  String get reminderCheckBattery => '배터리 최적화 상태 확인';

  @override
  String get reminderBatteryStatus => '배터리 최적화 상태';

  @override
  String reminderManufacturer(Object value) {
    return '제조사: $value';
  }

  @override
  String reminderModel(Object value) {
    return '모델: $value';
  }

  @override
  String reminderAndroidVersion(Object value) {
    return 'Android 버전: $value';
  }

  @override
  String get reminderBatteryIgnored => '배터리 최적화: 제외됨 ✅';

  @override
  String get reminderBatteryNotIgnored => '배터리 최적화: 제외되지 않음 ⚠️';

  @override
  String get reminderBatteryAdvice => '알림이 정상적으로 오도록 배터리 최적화를 꺼두는 것을 권장합니다';

  @override
  String get reminderCheckChannel => '알림 채널 설정 확인';

  @override
  String get reminderChannelStatus => '알림 채널 상태';

  @override
  String get reminderChannelEnabled => '채널 활성화: 예 ✅';

  @override
  String get reminderChannelDisabled => '채널 활성화: 아니요 ❌';

  @override
  String reminderChannelImportance(Object value) {
    return '중요도: $value';
  }

  @override
  String get reminderChannelSoundOn => '소리: 켜짐 🔊';

  @override
  String get reminderChannelSoundOff => '소리: 꺼짐 🔇';

  @override
  String get reminderChannelVibrationOn => '진동: 켜짐 📳';

  @override
  String get reminderChannelVibrationOff => '진동: 꺼짐';

  @override
  String get reminderChannelDndBypass => '방해 금지 모드: 무시하고 알림 가능';

  @override
  String get reminderChannelDndNoBypass => '방해 금지 모드: 무시하고 알림 불가';

  @override
  String get reminderChannelAdvice => '⚠️ 권장 설정:';

  @override
  String get reminderChannelAdviceImportance => '• 중요도: 긴급 또는 높음';

  @override
  String get reminderChannelAdviceSound => '• 소리와 진동을 켜세요';

  @override
  String get reminderChannelAdviceBanner => '• 배너 알림을 허용하세요';

  @override
  String get reminderChannelAdviceXiaomi => '• 샤오미(Xiaomi) 기기는 채널을 개별적으로 설정해야 합니다';

  @override
  String get reminderChannelGood => '✅ 알림 채널이 잘 설정되어 있습니다';

  @override
  String get reminderOpenAppSettings => '앱 설정 열기';

  @override
  String get reminderAppSettingsMessage => '설정에서 알림을 허용하고 배터리 최적화를 꺼주세요';

  @override
  String get reminderDescription => '팁: 기록 알림을 활성화하면 시스템이 매일 지정한 시간에 알림을 보내 지출 기록을 상기시켜 줍니다.';

  @override
  String get reminderAndroidInstructions => '알림이 제대로 오지 않는다면 다음을 확인하세요:\n• 앱의 알림 전송이 허용되어 있는지\n• 앱의 배터리 최적화/절전 모드를 꺼두었는지\n• 앱의 백그라운드 실행과 자동 시작이 허용되어 있는지\n• Android 12 이상은 정확한 알람 권한이 필요합니다\n\n📱 샤오미(Xiaomi) 기기 특별 설정:\n• 설정 > 앱 관리 > Spitout > 알림 관리\n• \"기록 알림\" 채널을 누르세요\n• 중요도를 \"긴급\" 또는 \"높음\"으로 설정하세요\n• \"배너 알림\", \"소리\", \"진동\"을 활성화하세요\n• 보안센터 > 앱 관리 > 권한 > 자동 실행\n\n🔒 백그라운드 고정 방법:\n• 최근 작업 목록에서 Spitout를 찾으세요\n• 앱 카드를 아래로 당겨 잠금 아이콘을 표시하세요\n• 잠금 아이콘을 눌러 정리되지 않도록 하세요';

  @override
  String get categoryDetailLoadFailed => '불러오기 실패';

  @override
  String get categoryDetailSummaryTitle => '카테고리 요약';

  @override
  String get categoryDetailTotalCount => '총 건수';

  @override
  String get categoryDetailTotalAmount => '총 금액';

  @override
  String get categoryDetailAverageAmount => '평균 금액';

  @override
  String get categoryDetailSortTitle => '정렬';

  @override
  String get categoryDetailSortTimeDesc => '시간 ↓';

  @override
  String get categoryDetailSortTimeAsc => '시간 ↑';

  @override
  String get categoryDetailSortAmountDesc => '금액 ↓';

  @override
  String get categoryDetailSortAmountAsc => '금액 ↑';

  @override
  String get categoryDetailNoTransactions => '거래 없음';

  @override
  String get categoryDetailNoTransactionsSubtext => '이 카테고리에는 아직 거래가 없습니다';

  @override
  String get categoryDetailDeleteFailed => '삭제 실패';

  @override
  String categoryMigrationTransactionLabel(int count) {
    return '$count건';
  }

  @override
  String get categoryTemplateEntryFlat => '1단계 템플릿';

  @override
  String get categoryTemplateEntryHierarchical => '2단계 템플릿';

  @override
  String get categoryTemplateFlatTitle => '1단계 카테고리 템플릿';

  @override
  String get categoryTemplateHierarchicalTitle => '2단계 카테고리 템플릿';

  @override
  String categoryTemplateSelectedCount(int count) {
    return '$count개 선택됨';
  }

  @override
  String get categoryTemplateSelectAll => '전체 선택';

  @override
  String get categoryTemplateDeselectAll => '전체 해제';

  @override
  String get categoryTemplateConfirmTitle => '카테고리 추가';

  @override
  String categoryTemplateConfirmMessage(int count) {
    return '선택한 $count개의 카테고리를 추가하시겠습니까?';
  }

  @override
  String categoryTemplateAddSuccess(int count) {
    return '$count개의 카테고리를 추가했습니다';
  }

  @override
  String categoryTemplateAddFailed(String error) {
    return '추가 실패: $error';
  }

  @override
  String get categoryManageAdd => '카테고리 추가';

  @override
  String get categoryManageDelete => '카테고리 삭제';

  @override
  String get categoryManageConfirmDelete => '삭제 확인';

  @override
  String get categoryManageReorderHint => '길게 눌러 순서 변경';

  @override
  String get categorySharedManageBannerOwner => '공유 가계부: 카테고리 변경 사항이 모든 구성원에게 동기화됩니다';

  @override
  String get categorySharedManageBannerEditor => '공유 가계부에서는 소유자의 카테고리를 사용하며, 여기서의 수정은 개인 카테고리에만 적용됩니다';

  @override
  String get categorySyncFailedBeforeInvite => '카테고리 동기화에 실패했습니다. 네트워크를 확인한 후 다시 시도하세요';

  @override
  String get categorySortSaveFailed => '순서 저장에 실패했습니다. 다시 시도하세요';

  @override
  String get categoryDeleteOptionAll => '카테고리와 모든 데이터 삭제 (하위 포함)';

  @override
  String get categoryDeleteOptionMigrate => '카테고리 삭제 및 다른 카테고리로 데이터 이동 (하위 포함)';

  @override
  String get categoryDeleteOptionPromote => '카테고리와 데이터 삭제 (하위는 최상위로 승격)';

  @override
  String get categoryDeleteSelectedTitle => '선택한 카테고리 삭제';

  @override
  String categoryDeleteSelectedSubtitleWithSub(int count) {
    return '$count개 선택한 카테고리를 삭제하고 데이터를 비우시겠습니까? (하위 카테고리 및 데이터 포함) 이 작업은 취소할 수 없습니다.';
  }

  @override
  String categoryDeleteSelectedSubtitleWithoutSub(int count) {
    return '$count개 선택한 카테고리를 삭제하고 데이터를 비우시겠습니까? (하위 카테고리 및 데이터 제외) 이 작업은 취소할 수 없습니다.';
  }

  @override
  String get categoryMigrateSelectTargetTitle => '데이터를 이동할 카테고리 선택';

  @override
  String get categoryMigrateConfirmButton => '확인 (데이터 이동 및 카테고리 삭제)';

  @override
  String categoryMigrateChildLabel(Object parent) {
    return '하위 · $parent';
  }

  @override
  String get subcategoryEditParent => '상위 카테고리 편집';

  @override
  String get subcategoryAdd => '하위 카테고리 추가';

  @override
  String get subcategoryDelete => '하위 카테고리 삭제';

  @override
  String get subcategoryDeleteOptionAll => '카테고리 및 해당 카테고리의 모든 데이터 삭제';

  @override
  String get subcategoryDeleteOptionMigrate => '카테고리를 삭제하고 모든 데이터를 다른 카테고리로 이동';

  @override
  String subcategoryDeleteSelectedSubtitle(int count) {
    return '선택한 카테고리 $count개를 삭제하고 데이터를 비우시겠습니까? 이 작업은 취소할 수 없습니다.';
  }

  @override
  String get subcategoryEmpty => '하위 카테고리 없음';

  @override
  String get cloudSupabaseUrlLabel => 'Supabase URL';

  @override
  String get cloudSupabaseUrlHint => 'https://xxx.supabase.co';

  @override
  String get cloudAnonKeyLabel => 'Anon Key';

  @override
  String get cloudMultiDeviceWarningTitle => '여러 기기 사용 팁';

  @override
  String get cloudMultiDeviceWarningMessage => '기기를 전환하기 전에 업로드하고, 새 기기에서는 편집 전에 다운로드하세요. 같은 가계부를 두 기기에서 동시에 편집하지 마세요. 자세히 보려면 눌러주세요 →';

  @override
  String get cloudWebdavUrlLabel => 'WebDAV 서버 URL';

  @override
  String get cloudWebdavUrlHint => 'https://dav.jianguoyun.com/dav/';

  @override
  String get cloudWebdavUsernameLabel => '사용자 이름';

  @override
  String get cloudWebdavPasswordLabel => '비밀번호';

  @override
  String get cloudWebdavPathHint => '/Spitout';

  @override
  String get cloudS3EndpointLabel => '엔드포인트';

  @override
  String get cloudS3EndpointHint => 's3.amazonaws.com 또는 사용자 지정 엔드포인트';

  @override
  String get cloudS3RegionLabel => '리전';

  @override
  String get cloudS3RegionHint => 'us-east-1 (자동 설정하려면 비워두세요)';

  @override
  String get cloudS3AccessKeyLabel => '액세스 키';

  @override
  String get cloudS3AccessKeyHint => 'Access Key ID를 입력하세요';

  @override
  String get cloudS3SecretKeyLabel => '시크릿 키';

  @override
  String get cloudS3SecretKeyHint => 'Secret Access Key를 입력하세요';

  @override
  String get cloudS3BucketLabel => '버킷 이름';

  @override
  String get cloudS3BucketHint => 'spitout-data';

  @override
  String get cloudS3UseSSLLabel => 'HTTPS 사용';

  @override
  String get cloudS3PortLabel => '포트 (선택 사항)';

  @override
  String get cloudS3PortHint => '기본값을 사용하려면 비워두세요';

  @override
  String get cloudSupabaseBucketLabel => '저장소 버킷 이름';

  @override
  String get cloudSupabaseBucketHint => '기본값을 사용하려면 비워두세요: spitout-backups';

  @override
  String get authRememberAccount => '계정 기억하기';

  @override
  String get authRememberAccountHint => '다음 로그인 시 자동으로 입력됩니다 (Supabase만 해당)';

  @override
  String get cloudFirstSaveSwitchTitle => '설정 저장 완료';

  @override
  String get cloudFirstSaveSwitchMessage => '이 클라우드 서비스를 지금 현재 동기화 설정으로 전환하시겠습니까?';

  @override
  String get cloudSaveOnlyNoSwitch => '나중에';

  @override
  String get cloudSaveAndSwitch => '지금 전환';

  @override
  String get cloudClearConfig => '설정 지우기';

  @override
  String get cloudClearConfigConfirmTitle => '클라우드 설정 지우기';

  @override
  String get cloudClearConfigConfirmMessage => '이 클라우드 서비스 설정을 지우시겠습니까?\n클라우드에 백업된 데이터는 삭제되지 않으며, 언제든 다시 설정하고 복구할 수 있습니다.';

  @override
  String get cloudClearConfigDone => '설정이 지워졌습니다';

  @override
  String get cloudPurgeFailed => '클라우드 장부 정리에 실패했습니다. 나중에 다시 시도하세요.';

  @override
  String get authLogin => '로그인';

  @override
  String get authEmail => '이메일';

  @override
  String get authPassword => '비밀번호';

  @override
  String get authInvalidEmail => '올바른 이메일 주소를 입력해 주세요';

  @override
  String get authErrorInvalidCredentials => '이메일 또는 비밀번호가 올바르지 않습니다.';

  @override
  String get authErrorEmailNotConfirmed => '이메일이 인증되지 않았습니다. 로그인하기 전에 이메일에서 인증을 완료해 주세요.';

  @override
  String get authErrorRateLimit => '시도 횟수가 너무 많습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get authErrorNetworkIssue => '네트워크 오류입니다. 연결 상태를 확인하고 다시 시도해 주세요.';

  @override
  String get authErrorLoginFailed => '로그인에 실패했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get exportCsvHeaderType => '유형';

  @override
  String get exportCsvHeaderCategory => '카테고리';

  @override
  String get exportCsvHeaderSubCategory => '하위 카테고리';

  @override
  String get exportCsvHeaderAmount => '금액';

  @override
  String get exportCsvHeaderNote => '메모';

  @override
  String get exportCsvHeaderTime => '시간';

  @override
  String get exportSuccessTitle => '내보내기 성공';

  @override
  String exportSuccessMessageAndroid(String path) {
    return '저장 위치:\n$path';
  }

  @override
  String get exportFailedTitle => '내보내기 실패';

  @override
  String get exportTypeExpense => '지출';

  @override
  String get currencyCNY => '중국 위안';

  @override
  String get currencyUSD => '미국 달러';

  @override
  String get currencyEUR => '유로';

  @override
  String get currencyJPY => '일본 엔';

  @override
  String get currencyHKD => '홍콩 달러';

  @override
  String get currencyTWD => '신 타이완 달러';

  @override
  String get currencyGBP => '영국 파운드';

  @override
  String get currencyAUD => '호주 달러';

  @override
  String get currencyCAD => '캐나다 달러';

  @override
  String get currencyKRW => '대한민국 원';

  @override
  String get currencySGD => '싱가포르 달러';

  @override
  String get currencyMYR => '말레이시아 링깃';

  @override
  String get currencyTHB => '태국 바트';

  @override
  String get currencyIDR => '인도네시아 루피아';

  @override
  String get currencyPHP => '필리핀 페소';

  @override
  String get currencyVND => '베트남 동';

  @override
  String get currencyINR => '인도 루피';

  @override
  String get currencyRUB => '러시아 루블';

  @override
  String get currencyBYN => '벨라루스 루블';

  @override
  String get currencyNZD => '뉴질랜드 달러';

  @override
  String get currencyCHF => '스위스 프랑';

  @override
  String get currencySEK => '스웨덴 크로나';

  @override
  String get currencyNOK => '노르웨이 크로네';

  @override
  String get currencyDKK => '덴마크 크로네';

  @override
  String get currencyBRL => '브라질 헤알';

  @override
  String get currencyMXN => '멕시코 페소';

  @override
  String get currencyTRY => '터키 리라';

  @override
  String get currencyZAR => '남아프리카공화국 랜드';

  @override
  String get currencyAED => '아랍에미리트 디르함';

  @override
  String get currencySAR => '사우디아라비아 리얄';

  @override
  String get currencyPLN => '폴란드 즈워티';

  @override
  String get currencyCZK => '체코 코루나';

  @override
  String get currencyHUF => '헝가리 포린트';

  @override
  String get currencyARS => '아르헨티나 페소';

  @override
  String get currencyCLP => '칠레 페소';

  @override
  String get currencyCOP => '콜롬비아 페소';

  @override
  String get currencyPEN => '페루 솔';

  @override
  String get currencyEGP => '이집트 파운드';

  @override
  String get currencyNGN => '나이지리아 나이라';

  @override
  String get currencyKZT => '카자흐스탄 텐게';

  @override
  String get currencyUAH => '우크라이나 흐리우냐';

  @override
  String get currencyILS => '이스라엘 신 셰켈';

  @override
  String get currencyPKR => '파키스탄 루피';

  @override
  String get currencyBDT => '방글라데시 타카';

  @override
  String get currencyLKR => '스리랑카 루피';

  @override
  String get currencyMMK => '미얀마 짯';

  @override
  String get webdavConfiguredTitle => 'WebDAV 클라우드 서비스가 설정되었습니다';

  @override
  String get webdavConfiguredMessage => 'WebDAV 클라우드 서비스는 설정 시 입력한 인증 정보를 사용하므로 추가 로그인이 필요하지 않습니다.';

  @override
  String get recurringTransactionTitle => '정기 결제';

  @override
  String get recurringTransactionAdd => '정기 결제 추가';

  @override
  String get recurringTransactionEdit => '정기 결제 편집';

  @override
  String get recurringTransactionFrequency => '주기';

  @override
  String get recurringTransactionDaily => '매일';

  @override
  String get recurringTransactionWeekly => '매주';

  @override
  String get recurringTransactionMonthly => '매월';

  @override
  String get recurringTransactionYearly => '매년';

  @override
  String get recurringTransactionInterval => '간격';

  @override
  String get recurringTransactionDayOfMonth => '매월 날짜';

  @override
  String get recurringTransactionStartDate => '시작일';

  @override
  String get recurringTransactionEndDate => '종료일';

  @override
  String get recurringTransactionNoEndDate => '무기한';

  @override
  String get recurringTransactionDeleteConfirm => '이 정기 결제를 삭제하시겠습니까?';

  @override
  String get recurringTransactionEmpty => '정기 결제가 없습니다';

  @override
  String get recurringTransactionEmptyHint => '우측 상단의 + 버튼을 눌러 추가하세요';

  @override
  String recurringTransactionEveryNDays(int n) {
    return '$n일마다';
  }

  @override
  String recurringTransactionEveryNWeeks(int n) {
    return '$n주마다';
  }

  @override
  String recurringTransactionEveryNMonths(int n) {
    return '$n개월마다';
  }

  @override
  String recurringTransactionEveryNYears(int n) {
    return '$n년마다';
  }

  @override
  String get recurringTransactionUsageTitle => '사용 안내';

  @override
  String get recurringTransactionUsageContent => '정기 결제는 앱을 완전히 새로 시작할 때 자동으로 스캔되어 생성됩니다. 날짜를 설정하면 해당 날짜 이후 처음 실행될 때 시스템이 관련 거래를 생성합니다. 예를 들어 11월 27일로 설정하면 11월 27일 이후 첫 실행 시 자동으로 거래가 기록됩니다.';

  @override
  String get ledgerSelectTitle => '가계부 선택';

  @override
  String get ledgerSelect => '가계부 선택';

  @override
  String get syncNotConfiguredMessage => '클라우드가 설정되지 않음';

  @override
  String get syncNotLoggedInMessage => '로그인하지 않음';

  @override
  String get syncCloudBackupCorruptedMessage => '클라우드 백업 내용이 손상되었습니다. 이전 버전의 인코딩 문제일 수 있습니다. \'현재 가계부를 클라우드에 업로드\'를 눌러 덮어써 복구해 주세요.';

  @override
  String get syncNoCloudBackupMessage => '클라우드 백업이 없음';

  @override
  String get syncAccessDeniedMessage => '403 접근 거부 (저장소 RLS 정책과 경로를 확인하세요)';

  @override
  String get cloudTestConnection => '연결 테스트';

  @override
  String cloudLastTestTime(String time) {
    return '마지막 테스트 시간: $time';
  }

  @override
  String get cloudLocalStorageTitle => '로컬 저장';

  @override
  String get cloudLocalStorageSubtitle => '데이터가 로컬 기기에만 저장됩니다';

  @override
  String get localBackupPageTitle => '로컬 저장';

  @override
  String get localBackupAutoTitle => '자동 로컬 백업';

  @override
  String get localBackupAutoSubtitle => '매일 첫 실행 시 데이터베이스 스냅샷을 자동으로 백업합니다';

  @override
  String get storagePermissionTitle => '저장 공간 권한 필요';

  @override
  String get storagePermissionMessage => 'Android 11 이상에서 공용 Download 디렉터리에 파일을 저장하려면 \'모든 파일 액세스\' 권한이 필요합니다(파일 관리자에서 보이며 앱 삭제 후에도 유지됨).\n\n\'계속\'을 선택하면 앱 전용 디렉터리에 저장되며, 파일 관리자에서 보이지 않고 앱 삭제 시 함께 삭제됩니다.';

  @override
  String get storagePermissionGrant => '권한 허용';

  @override
  String get storagePermissionContinue => '계속';

  @override
  String get exportStorageUnavailable => '외부 저장소를 사용할 수 없습니다. 기기 저장소 상태를 확인하세요';

  @override
  String get localBackupNowTooltip => '지금 백업';

  @override
  String get localBackupSuccess => '백업 완료';

  @override
  String get localBackupFailed => '백업 실패. 저장 공간과 권한을 확인하세요';

  @override
  String get localBackupListHint => '복원할 데이터를 선택하세요:';

  @override
  String get localBackupImportFromFile => '파일에서 복원';

  @override
  String get localBackupImportInvalidFile => '.sqlite 형식의 백업 파일을 선택하세요';

  @override
  String get localBackupListEmpty => '백업 없음';

  @override
  String get localBackupRestoreTitle => '백업 복원';

  @override
  String get localBackupRestoreMessage => '복원하면 현재 모든 데이터가 덮어씌워지며 되돌릴 수 없습니다. 계속하시겠습니까?';

  @override
  String get localBackupRestoreSuccess => '복원 완료';

  @override
  String get localBackupRestoreFailed => '복원 실패';

  @override
  String get localBackupEmergencyFailed => '현재 데이터의 안전 사본을 만들 수 없어 복원을 취소했습니다';

  @override
  String get localBackupIntegrityFailed => '백업 파일이 손상되어 복원할 수 없습니다';

  @override
  String get localBackupVersionTooNew => '이 백업은 최신 버전 앱에서 생성되었습니다. 앱을 업데이트한 후 복원하세요';

  @override
  String get localBackupRestoring => '복원 중…';

  @override
  String get cloudCustomSupabaseTitle => '사용자 지정 Supabase';

  @override
  String get cloudCustomSupabaseSubtitle => '눌러서 셀프 호스팅 Supabase를 설정하세요';

  @override
  String get cloudCustomWebdavTitle => '사용자 지정 WebDAV';

  @override
  String get cloudCustomWebdavSubtitle => '눌러서 Nutstore/Nextcloud 등을 설정하세요';

  @override
  String get cloudCustomS3Title => 'S3 프로토콜 저장소';

  @override
  String get cloudCustomS3Subtitle => 'AWS S3 / Cloudflare R2 / MinIO';

  @override
  String get cloudSpitoutCloudTitle => 'Spitout Cloud';

  @override
  String get cloudSpitoutCloudSubtitle => '셀프 호스팅 · 증분 동기화 · 다중 기기';

  @override
  String get cloudConfigureSpitoutCloudTitle => 'Spitout Cloud 설정';

  @override
  String get cloudSpitoutCloudUrlLabel => '서버 URL';

  @override
  String get cloudSpitoutCloudUrlHint => 'https://your-server.com';

  @override
  String get cloudSpitoutCloudEmailLabel => '이메일';

  @override
  String get cloudSpitoutCloudEmailHint => 'your@email.com';

  @override
  String get cloudSpitoutCloudPasswordLabel => '비밀번호';

  @override
  String get cloudSpitoutCloudPasswordHint => '비밀번호를 입력하세요';

  @override
  String get cloudSpitoutCloudLoginSuccess => '로그인 성공';

  @override
  String get cloudSpitoutCloudLoginFailed => '로그인 실패';

  @override
  String get cloudTabOffline => '오프라인';

  @override
  String get cloudTabBackup => '백업';

  @override
  String get cloudTabBackupSubtitle => '카드를 탭하여 백업 방식을 전환하세요. 처음 설정 시 정보 입력이 필요합니다.';

  @override
  String get cloudTabCloudSync => '클라우드 동기화';

  @override
  String get cloudSupabaseHelpTitle => 'Supabase 설정 가이드';

  @override
  String get cloudSupabaseHelpIntro => 'Supabase란?';

  @override
  String get cloudSupabaseHelpIntro1 => 'Supabase는 오픈소스 BaaS(백엔드 서비스) 플랫폼입니다';

  @override
  String get cloudSupabaseHelpIntro2 => '무료 요금제를 제공하며 개인 용도로 충분합니다';

  @override
  String get cloudSupabaseHelpIntro3 => '데이터를 완전히 직접 관리할 수 있습니다';

  @override
  String get cloudSupabaseHelpSteps => '설정 단계';

  @override
  String get cloudSupabaseHelpStep1 => '1. supabase.com에 방문해 계정을 만드세요';

  @override
  String get cloudSupabaseHelpStep2 => '2. 새 프로젝트를 생성하세요 (무료 요금제 선택)';

  @override
  String get cloudSupabaseHelpStep3 => '3. Project Settings > API로 이동하세요';

  @override
  String get cloudSupabaseHelpStep4 => '4. Project URL과 anon key를 복사하세요';

  @override
  String get cloudSupabaseHelpStep5 => '5. 앱 설정에 붙여넣으세요';

  @override
  String get cloudSupabaseHelpFaq => '자주 묻는 질문';

  @override
  String get cloudSupabaseHelpFaq1 => '무료 요금제는 500MB 저장 공간을 포함합니다';

  @override
  String get cloudSupabaseHelpFaq2 => '데이터는 암호화되어 안전하게 보관됩니다';

  @override
  String get cloudSupabaseHelpFaq3 => '다중 기기 동기화를 지원합니다';

  @override
  String get cloudSupabaseHelpNote => '설정 후 동기화를 사용하려면 가입/로그인이 필요합니다';

  @override
  String get cloudWebdavHelpTitle => 'WebDAV 설정 가이드';

  @override
  String get cloudWebdavHelpIntro => 'WebDAV란?';

  @override
  String get cloudWebdavHelpIntro1 => 'WebDAV는 네트워크 파일 프로토콜입니다';

  @override
  String get cloudWebdavHelpIntro2 => '많은 클라우드 저장소와 NAS 기기에서 지원됩니다';

  @override
  String get cloudWebdavHelpIntro3 => '데이터가 사용자 자신의 서버에 저장됩니다';

  @override
  String get cloudWebdavHelpProviders => '지원되는 제공업체';

  @override
  String get cloudWebdavHelpProvider1 => '- Nutstore (중국 사용자에게 권장)';

  @override
  String get cloudWebdavHelpProvider2 => '- Nextcloud / ownCloud';

  @override
  String get cloudWebdavHelpProvider3 => '- Synology / QNAP NAS';

  @override
  String get cloudWebdavHelpProvider4 => '- 기타 WebDAV 호환 서비스';

  @override
  String get cloudWebdavHelpSteps => '설정 단계 (Nutstore 예시)';

  @override
  String get cloudWebdavHelpStep1 => '1. Nutstore 웹 버전에 로그인하세요';

  @override
  String get cloudWebdavHelpStep2 => '2. 계정 이름 > 계정 정보를 클릭하세요';

  @override
  String get cloudWebdavHelpStep3 => '3. 보안 옵션 탭을 선택하세요';

  @override
  String get cloudWebdavHelpStep4 => '4. 애플리케이션 비밀번호를 추가하세요 (제3자 앱용)';

  @override
  String get cloudWebdavHelpStep5 => '5. 서버 주소, 계정, 앱 비밀번호를 복사하세요';

  @override
  String get cloudWebdavHelpNote => '계정 비밀번호 대신 앱 전용 비밀번호를 사용하세요';

  @override
  String get cloudS3HelpTitle => 'S3 저장소 설정 가이드';

  @override
  String get cloudS3HelpIntro => 'S3란?';

  @override
  String get cloudS3HelpIntro1 => 'S3는 표준 객체 저장소 프로토콜입니다';

  @override
  String get cloudS3HelpIntro2 => '많은 클라우드 제공업체에서 지원됩니다';

  @override
  String get cloudS3HelpIntro3 => '데이터가 선택한 클라우드 서비스에 저장됩니다';

  @override
  String get cloudS3HelpProviders => '지원되는 제공업체';

  @override
  String get cloudS3HelpProvider1 => '- AWS S3 (Amazon Web Services)';

  @override
  String get cloudS3HelpProvider2 => '- Cloudflare R2 (월 10GB 무료)';

  @override
  String get cloudS3HelpProvider3 => '- Backblaze B2 (10GB 무료)';

  @override
  String get cloudS3HelpProvider4 => '- MinIO (셀프 호스팅)';

  @override
  String get cloudS3HelpProvider5 => '- 알리바바 클라우드 OSS';

  @override
  String get cloudS3HelpProvider6 => '- 텐센트 클라우드 COS';

  @override
  String get cloudS3HelpProvider7 => '- 치니우 코도 (Qiniu Kodo)';

  @override
  String get cloudS3HelpSteps => '설정 단계 (Cloudflare R2 예시)';

  @override
  String get cloudS3HelpStep1 => '1. Cloudflare 대시보드에 로그인하세요';

  @override
  String get cloudS3HelpStep2 => '2. R2 > Create Bucket로 이동하세요';

  @override
  String get cloudS3HelpStep3 => '3. R2 > Manage R2 API Tokens로 이동하세요';

  @override
  String get cloudS3HelpStep4 => '4. API 토큰을 생성하고 인증 정보를 복사하세요';

  @override
  String get cloudS3HelpStep5 => '5. 엔드포인트, 액세스 키, 시크릿 키, 버킷 이름을 붙여넣으세요';

  @override
  String get cloudS3HelpNote => '권장: Cloudflare R2는 10GB의 무료 저장 공간을 제공하며 트래픽 비용이 없습니다';

  @override
  String get cloudStatusNotTested => '테스트하지 않음';

  @override
  String get cloudStatusNormal => '연결 정상';

  @override
  String get cloudStatusFailed => '연결 실패';

  @override
  String get cloudErrorAuthFailed => '인증 실패: API 키가 올바르지 않습니다';

  @override
  String cloudErrorServerStatus(String code) {
    return '서버가 상태 코드 $code를 반환했습니다';
  }

  @override
  String get cloudErrorWebdavNotSupported => '서버가 WebDAV 프로토콜을 지원하지 않습니다';

  @override
  String get cloudErrorAuthFailedCredentials => '인증 실패: 사용자 이름 또는 비밀번호가 올바르지 않습니다';

  @override
  String get cloudErrorAccessDenied => '접근 거부: 권한을 확인해 주세요';

  @override
  String cloudErrorPathNotFound(String path) {
    return '서버 경로를 찾을 수 없습니다: $path';
  }

  @override
  String cloudErrorNetwork(String message) {
    return '네트워크 오류: $message';
  }

  @override
  String get cloudTestSuccessMessage => '연결이 정상이며 설정이 유효합니다';

  @override
  String get cloudTestFailedMessage => '연결에 실패했습니다';

  @override
  String get cloudSwitchConfirmTitle => '클라우드 서비스 전환';

  @override
  String get cloudSwitchConfirmMessage => '클라우드 서비스를 전환하면 현재 계정이 로그아웃됩니다. 전환하시겠습니까?';

  @override
  String get cloudSwitchFailedTitle => '전환 실패';

  @override
  String get cloudSwitchFailedConfigMissing => '먼저 이 클라우드 서비스를 설정해 주세요';

  @override
  String get cloudConfigInvalidMessage => '모든 정보를 입력해 주세요';

  @override
  String get cloudSaveFailed => '저장 실패';

  @override
  String cloudSwitchedTo(String type) {
    return '$type(으)로 전환되었습니다';
  }

  @override
  String get cloudConfigureSupabaseTitle => 'Supabase 설정';

  @override
  String get cloudConfigureWebdavTitle => 'WebDAV 설정';

  @override
  String get cloudConfigureS3Title => 'S3 설정';

  @override
  String get cloudSupabaseAnonKeyHintLong => '전체 anon key를 붙여넣으세요';

  @override
  String get cloudWebdavRemotePathLabel => '원격 경로';

  @override
  String get cloudWebdavRemotePathHelperText => '데이터를 저장할 원격 디렉터리 경로';

  @override
  String get welcomeSelectCurrencyTitle => '기록 통화 선택';

  @override
  String get welcomeCurrencyDescription => '선호하는 통화를 선택하세요. 설정에서 언제든지 변경할 수 있습니다';

  @override
  String get aiOcrNoLedger => '가계부를 찾을 수 없습니다';

  @override
  String get cloudTutorialTitle => '시작하기';

  @override
  String get cloudTutorialIntro => 'Spitout Cloud는 실시간 다중 기기 협업을 지원하는 셀프 호스팅 동기화 서버입니다. 사용 방법은 간단합니다:';

  @override
  String get cloudTutorialStep1Title => '1단계: 서버 배포 또는 참여';

  @override
  String get cloudTutorialStep1Desc => 'Docker 명령어 한 줄로 셀프 호스팅할 수 있습니다 (GitHub README의 Docker 가이드 참고). 또는 지인/팀이 운영하는 기존 Spitout Cloud 서버에 참여하세요.';

  @override
  String get cloudTutorialStep2Title => '2단계: 계정 받기';

  @override
  String get cloudTutorialStep2Desc => 'Spitout Cloud는 (공개 서버 악용을 막기 위해) 자체 가입 기능을 제공하지 않습니다. 직접 호스팅하는 경우: Docker를 처음 실행하면 로그에 무작위 관리자 이메일과 비밀번호가 출력되니 이를 사용하세요. 다른 사람의 서버에 참여하는 경우: 관리자에게 웹 → 사용자에서 계정을 만들어 달라고 요청하세요.';

  @override
  String get cloudTutorialStep3Title => '3단계: 로그인 및 동기화 활성화';

  @override
  String get cloudTutorialStep3Desc => '앱에서 Spitout Cloud를 선택하고 서버 URL과 2단계에서 받은 계정을 입력하세요. 첫 로그인 시 로컬 가계부 전체가 업로드되며, 이후의 모든 변경 사항은 실시간으로 전송됩니다.';

  @override
  String get cloudTutorialStep4Title => '4단계: 다른 기기에서 로그인';

  @override
  String get cloudTutorialStep4Desc => '휴대폰 / 태블릿 / 웹 — 같은 계정으로 즉시 상태를 공유합니다. 변경 사항은 몇 초 안에 전파됩니다.';

  @override
  String get cloudTutorialTipTitle => '팁';

  @override
  String get cloudTutorialTipDesc => '웹 UI는 서버 URL에 있습니다. 브라우저에서 열어 가계부와 멤버를 관리하고 로그를 확인하세요.';

  @override
  String get cloudTutorialFeaturesTitle => '기능';

  @override
  String get cloudTutorialFeature1 => '📱 실시간 다중 기기: 휴대폰 A + 휴대폰 B + 웹을 하나의 계정으로, 1초 이내 동기화';

  @override
  String get cloudTutorialFeature2 => '🌐 웹 UI 내장: Docker 이미지 하나에 서버와 웹이 모두 포함되어 바로 브라우저로 사용 가능';

  @override
  String get cloudTutorialFeature3 => '👥 다중 사용자 분리: 하나의 서버에 여러 사용자, 데이터는 완전히 분리';

  @override
  String get cloudTutorialFeature4 => '🤝 공유 가계부: 가족/팀을 초대해 하나의 가계부를 몇 초 단위로 동기화';

  @override
  String get cloudTutorialGotIt => '확인했습니다';

  @override
  String get cloudSyncHint => '다운로드 시 차이점을 자동으로 비교해 선택적으로 미리 볼 수 있습니다. 실시간이 아니므로 여러 기기에서 동시에 같은 가계부를 편집하지 마세요. 동기화 범위는 가계부 데이터(연결된 계정, 카테고리 포함)입니다.';

  @override
  String get appearanceSettings => '개인화';

  @override
  String get appearanceSettingsDesc => '테마, 글꼴, 언어, 앱 잠금 등';

  @override
  String get appearanceSettingsPageTitle => '개인화';

  @override
  String get appearanceSettingsPageSubtitle => '화면, 표시, 보안 등 앱 환경 설정';

  @override
  String get logCenterTitle => '로그 센터';

  @override
  String get logCenterSubtitle => '앱 실행 로그를 확인하세요';

  @override
  String get logCenterSearchHint => '로그 내용이나 태그 검색...';

  @override
  String get logCenterFilterLevel => '로그 수준';

  @override
  String get logCenterFilterPlatform => '플랫폼';

  @override
  String get logCenterTotal => '전체';

  @override
  String get logCenterFiltered => '필터링됨';

  @override
  String get logCenterEmpty => '로그가 없습니다';

  @override
  String get logCenterExport => '내보내기';

  @override
  String get logCenterClear => '지우기';

  @override
  String get logCenterExportFailed => '내보내기 실패';

  @override
  String get logCenterClearConfirmTitle => '로그 지우기';

  @override
  String get logCenterClearConfirmMessage => '모든 로그를 지우시겠습니까? 이 작업은 되돌릴 수 없습니다.';

  @override
  String get logCenterCleared => '로그가 지워졌습니다';

  @override
  String get logCenterCopied => '클립보드에 복사되었습니다';

  @override
  String get configImportExportTitle => '설정 가져오기/내보내기';

  @override
  String get configImportExportSubtitle => '앱 설정을 백업하고 복원하세요';

  @override
  String get configImportExportInfoTitle => '기능 설명';

  @override
  String get configImportExportInfoMessage => '앱 설정을 백업하고 복원하여 다른 기기로 이동하거나 설정을 복구할 수 있습니다. YAML 형식으로 내보내며, 확인하고 편집할 수 있습니다.\n\n앱 설정만 포함되며 거래 내역은 포함되지 않습니다 (거래 데이터는 명세 가져오기/내보내기 기능을 사용하세요).';

  @override
  String get configImportExportWarning => '설정 파일에는 클라우드 서비스 키, 비밀번호 등 민감한 정보가 포함되어 있습니다. 안전하게 보관하세요. 가져오기 시 같은 이름의 설정이 덮어씌워지니 먼저 백업하는 것을 권장합니다.';

  @override
  String get configExportTitle => '설정 내보내기';

  @override
  String get configExportSubtitle => '현재 설정을 YAML 파일로 내보내기';

  @override
  String get configExportShareSubject => 'Spitout 설정 파일';

  @override
  String get configExportSuccess => '설정을 내보냈습니다';

  @override
  String get configExportFailed => '설정 내보내기 실패';

  @override
  String get configImportTitle => '설정 가져오기';

  @override
  String get configImportSubtitle => 'YAML 파일에서 설정을 복원하세요';

  @override
  String get configImportNoFilePath => '선택된 파일이 없습니다';

  @override
  String get configImportConfirmTitle => '가져오기 확인';

  @override
  String get configImportSuccess => '설정을 가져왔습니다';

  @override
  String get configImportFailed => '설정 가져오기 실패';

  @override
  String get configImportRestartTitle => '재시작이 필요합니다';

  @override
  String get configImportRestartMessage => '설정을 가져왔습니다. 일부 설정은 앱을 재시작해야 적용됩니다.';

  @override
  String get configImportOverwriteWarning => '가져오기 시 기존 설정이 덮어씌워집니다. 먼저 현재 설정을 백업하는 것을 권장합니다.';

  @override
  String get configImportExportIncludesTitle => '포함된 설정';

  @override
  String configExportSavedTo(String path) {
    return '저장 위치: $path';
  }

  @override
  String get configExportViewContent => '내용 보기';

  @override
  String get configExportCopyContent => '내용 복사';

  @override
  String get configExportContentCopied => '클립보드에 복사되었습니다';

  @override
  String get configExportReadFileFailed => '파일을 읽지 못했습니다';

  @override
  String get configIncludeLedgers => '가계부';

  @override
  String get configIncludeSupabase => 'Supabase 클라우드 서비스 설정';

  @override
  String get configIncludeWebdav => 'WebDAV 클라우드 서비스 설정';

  @override
  String get configIncludeS3 => 'S3 클라우드 서비스 설정';

  @override
  String get configIncludeSpitoutCloud => 'Spitout Cloud 클라우드 서비스 설정';

  @override
  String get configIncludeAppSettings => '앱 설정 (알림, 언어, 화면, 글꼴, 동기화 등)';

  @override
  String get configIncludeRecurringTransactions => '정기 결제';

  @override
  String get configIncludeCategories => '카테고리';

  @override
  String get configIncludeOtherSettings => '기타 설정';

  @override
  String get configIncludeOtherSettingsSubtitle => '클라우드 서비스 설정 및 앱 설정 포함';

  @override
  String get configExportSelectTitle => '내보낼 내용 선택';

  @override
  String get configExportPreviewTitle => '내보내기 미리보기';

  @override
  String get configExportConfirmTitle => '내보내기 확인';

  @override
  String get configImportSelectTitle => '가져올 내용 선택';

  @override
  String get configImportPreviewTitle => '가져오기 미리보기';

  @override
  String get ledgersConflictTitle => '동기화 충돌';

  @override
  String get ledgersConflictMessage => '로컬과 클라우드 가계부 데이터가 일치하지 않습니다. 처리 방법을 선택해 주세요:';

  @override
  String ledgersConflictLocalInfo(int count) {
    return '로컬: 거래 $count건';
  }

  @override
  String ledgersConflictRemoteInfo(int count) {
    return '클라우드: 거래 $count건';
  }

  @override
  String ledgersConflictRemoteUpdated(String time) {
    return '클라우드 업데이트: $time';
  }

  @override
  String ledgersConflictLocalFingerprint(String fp) {
    return '로컬 지문: $fp';
  }

  @override
  String ledgersConflictRemoteFingerprint(String fp) {
    return '클라우드 지문: $fp';
  }

  @override
  String get ledgersConflictUpload => '클라우드에 업로드';

  @override
  String get ledgersConflictDownload => '로컬로 다운로드';

  @override
  String get ledgersConflictUploading => '업로드 중...';

  @override
  String get ledgersConflictDownloading => '다운로드 중...';

  @override
  String get ledgersConflictUploadSuccess => '업로드 성공';

  @override
  String ledgersConflictDownloadSuccess(int inserted) {
    return '다운로드 성공, 거래 $inserted건이 병합되었습니다';
  }

  @override
  String get welcomeExistingUserTitle => '기존 사용자이신가요?';

  @override
  String get welcomeExistingUserButton => '설정 가져오기';

  @override
  String get welcomeImportingConfig => '설정을 가져오는 중...';

  @override
  String get welcomeImportSuccess => '설정을 가져왔습니다';

  @override
  String welcomeImportFailed(String error) {
    return '가져오기 실패: $error';
  }

  @override
  String get welcomeImportNoFile => '선택된 파일이 없습니다';

  @override
  String get calendarTitle => '캘린더';

  @override
  String get calendarToday => '오늘로 돌아가기';

  @override
  String get calendarNoTransactions => '거래 없음';

  @override
  String get calendarAddTransaction => '이 날짜에 기록 추가';

  @override
  String get commonUncategorized => '미분류';

  @override
  String get syncPreviewTitle => '동기화 미리보기';

  @override
  String get syncPreviewSelectAll => '전체 선택';

  @override
  String get syncPreviewDeselectAll => '전체 선택 해제';

  @override
  String get syncPreviewAdded => '추가됨';

  @override
  String get syncPreviewModified => '수정됨';

  @override
  String get syncPreviewDeleted => '삭제됨';

  @override
  String syncPreviewAddedCount(int count) {
    return '$count건 추가됨';
  }

  @override
  String syncPreviewModifiedCount(int count) {
    return '$count건 수정됨';
  }

  @override
  String syncPreviewDeletedCount(int count) {
    return '$count건 삭제됨';
  }

  @override
  String syncPreviewApply(int count) {
    return '$count건 적용';
  }

  @override
  String get syncPreviewEmpty => '클라우드 데이터가 로컬과 일치합니다. 동기화가 필요하지 않습니다';

  @override
  String get syncPreviewOldFormat => '이전 클라우드 형식, 전체 교체가 필요합니다';

  @override
  String get syncPreviewOldFormatMessage => '클라우드 데이터에 동기화 ID가 없습니다. 로컬 데이터를 지우고 클라우드에서 다시 가져옵니다.';

  @override
  String syncPreviewApplied(int count) {
    return '$count건의 변경 사항을 적용했습니다';
  }

  @override
  String get cloudSyncGuideTitle => '클라우드 동기화 안내';

  @override
  String get cloudSyncGuideGotIt => '확인했습니다';

  @override
  String get cloudSyncGuideHowItWorks => '작동 방식';

  @override
  String get cloudSyncGuideHowItem1 => '업로드: 현재 가계부의 모든 데이터를 묶어 클라우드에 업로드하고 기존 클라우드 데이터를 대체합니다';

  @override
  String get cloudSyncGuideHowItem2 => '다운로드: 클라우드 데이터를 가져와 로컬 기록과 하나씩 비교합니다 — 적용할 변경 사항을 직접 선택할 수 있습니다';

  @override
  String get cloudSyncGuideHowItem3 => '클라우드에는 항상 가장 최근에 업로드된 스냅샷만 저장되며 버전 기록은 없습니다';

  @override
  String get cloudSyncGuideCorrect => '올바른 사용법';

  @override
  String get cloudSyncGuideCorrectItem1 => '한 번에 한 기기에서만 편집하고, 끝나면 업로드하세요';

  @override
  String get cloudSyncGuideCorrectItem2 => '새 기기에서는 편집을 시작하기 전에 다운로드하세요';

  @override
  String get cloudSyncGuideCorrectItem3 => '변경 사항을 적용하기 전에 미리보기를 꼼꼼히 확인하세요';

  @override
  String get cloudSyncGuideCorrectItem4 => '편집 → 업로드 → 기기 전환 → 다운로드 → 편집 순서를 따르세요';

  @override
  String get cloudSyncGuideWrong => '피해야 할 사용법';

  @override
  String get cloudSyncGuideWrongItem1 => '두 기기에서 동시에 같은 가계부를 편집하는 것 — 나중에 업로드한 쪽이 이전 것을 덮어씁니다';

  @override
  String get cloudSyncGuideWrongItem2 => '업로드 직후 바로 다운로드하는 것 — 클라우드 서비스는 수 초에서 수 분의 동기화 지연이 있을 수 있으니 잠시 기다려 주세요';

  @override
  String get cloudSyncGuideWrongItem3 => '오랫동안 동기화하지 않다가 한 번에 많은 변경 사항을 다운로드하는 것 — 중요한 차이를 놓치기 쉽습니다';

  @override
  String get cloudSyncGuideLimitations => '알려진 제한 사항';

  @override
  String get cloudSyncGuideLimitItem1 => '실시간이 아닙니다: 업로드와 다운로드를 수동으로 눌러야 합니다';

  @override
  String get cloudSyncGuideLimitItem2 => '충돌 병합이 없습니다: 양쪽의 편집을 자동으로 병합하지 않으며 마지막 업로드가 우선합니다';

  @override
  String get cloudSyncGuideLimitItem3 => '클라우드 서비스 지연: 업로드된 파일을 다른 기기가 읽을 수 있게 되기까지 사용하는 클라우드 제공업체에 따라 수 초에서 수 분이 걸릴 수 있습니다';

  @override
  String get appLockTitle => '앱 잠금';

  @override
  String get appLockDesc => 'PIN과 생체 인식으로 개인정보를 보호하세요';

  @override
  String get appLockEnable => '앱 잠금 사용';

  @override
  String get appLockEnableDesc => '실행 및 재개 시 인증을 요구합니다';

  @override
  String get appLockSetPin => 'PIN 설정';

  @override
  String get appLockChangePin => 'PIN 변경';

  @override
  String get appLockVerifyPin => 'PIN 확인';

  @override
  String get appLockVerifyCurrentPin => '현재 PIN을 입력하세요';

  @override
  String get appLockSetNewPin => '새 PIN 설정';

  @override
  String get appLockConfirmPin => 'PIN 확인';

  @override
  String get appLockEnterPin => 'PIN 입력';

  @override
  String get appLockPinSetSuccess => 'PIN이 설정되었습니다';

  @override
  String get appLockDisabled => '앱 잠금이 비활성화되었습니다';

  @override
  String get appLockBiometric => '생체 인식 잠금 해제';

  @override
  String get appLockBiometricDesc => 'Face ID 또는 지문으로 잠금을 해제합니다';

  @override
  String get appLockBiometricReason => 'Spitout 잠금을 해제하려면 본인 인증이 필요합니다';

  @override
  String get appLockTimeout => '자동 잠금 시간';

  @override
  String get appLockTimeoutImmediate => '즉시';

  @override
  String get appLockTimeout1Min => '1분 후';

  @override
  String get appLockTimeout5Min => '5분 후';

  @override
  String get appLockTimeout15Min => '15분 후';

  @override
  String dayOfMonth(int day) {
    return '매월 $day일';
  }

  @override
  String get syncHealthTitle => '동기화 상태';

  @override
  String get cloudSyncHelpTitle => '동기화 작동 방식 · 가끔 멈추는 이유';

  @override
  String get cloudSyncHelpModesTitle => '세 가지 동기화 모드';

  @override
  String get cloudSyncHelpModesBody => '• 증분 동기화 (자동, 매일): 항목을 추가하거나 편집하면 해당 변경 사항만 자동으로 업로드/다운로드됩니다 — 빠르고 수동 작업이 필요 없습니다. 항상 실행되는 방식입니다.\n• 전체 업로드: 클라우드 동기화를 처음 활성화하거나 이 가계부에 대한 클라우드 데이터가 아직 없을 때, 로컬 데이터 전체가 한 번에 클라우드로 전송됩니다.\n• 전체 다운로드: 새 기기, 재설치 후, 또는 로컬이 비어 있을 때 클라우드에서 모든 데이터를 가져옵니다.';

  @override
  String get cloudSyncHelpWhenFullTitle => '전체 동기화는 언제 발생하나요?';

  @override
  String get cloudSyncHelpWhenFullBody => '전체 동기화는 한쪽이 비어 있을 때만 자동으로 실행됩니다 (클라우드 동기화 최초 활성화 / 새 기기 / 재설치 / 로컬 또는 클라우드 데이터 삭제 후). 양쪽 모두 데이터가 있는 한 동기화는 증분 방식을 유지하며 스스로 다시 시작하지 않습니다. 강제로 전체 재동기화를 하려면 먼저 해당 쪽의 데이터를 지워야 합니다.';

  @override
  String get cloudSyncHelpStuckTitle => '동기화가 가끔 멈추는 이유';

  @override
  String get cloudSyncHelpStuckBody => '• 전체 업로드/다운로드는 이어받기를 지원하지 않습니다: 네트워크가 끊기거나 앱이 백그라운드에서 종료되면 이어서 진행하지 않고 처음부터 다시 시작합니다. 데이터가 클 경우 안정적인 네트워크(Wi-Fi 권장)를 사용하고 완료될 때까지 다른 곳으로 전환하지 마세요.\n• 증분 동기화는 이어받기가 안전하며 일상적인 사용에서는 영향을 받지 않습니다.';

  @override
  String get cloudSyncHelpTroubleshootTitle => '문제 해결';

  @override
  String get cloudSyncHelpTroubleshootBody => '• 먼저 이 페이지를 아래로 당겨 정밀 검사를 실행하고 로컬과 클라우드를 비교하세요.\n• 그래도 해결되지 않으면 로그 센터를 열어 동기화 로그(실패 원인 포함)를 확인하고 신고해 주세요.';

  @override
  String get cloudSyncHelpOpenLogCenter => '로그 센터 열기';

  @override
  String syncHealthCheckFailed(String msg) {
    return '확인 실패: $msg';
  }

  @override
  String get syncHealthRecovering => '로그인 상태 복구 중…';

  @override
  String get syncHealthNeedsLogin => '로그인되지 않았거나 세션이 만료되었습니다. 클라우드 동기화에 다시 로그인해 주세요.';

  @override
  String get syncHealthHasDiff => '차이가 감지되어 자동으로 동기화되었습니다';

  @override
  String get cloudSyncHealFailed => 'Auto-restore failed; please restore from cloud manually';

  @override
  String get syncHealthInSync => '로컬과 클라우드가 일치합니다';

  @override
  String get syncHealthGroupCurrentLedger => '현재 장부';

  @override
  String get syncHealthGroupAll => '전체 장부';

  @override
  String get syncHealthRowTx => '거래';

  @override
  String get syncHealthRowCategory => '분류';

  @override
  String get syncHealthRowUnpushed => '미전송 변경';

  @override
  String syncHealthValue(int local, int remote) {
    return '로컬 $local · 원격 $remote';
  }

  @override
  String syncHealthValueRemoteMissing(int local) {
    return '로컬 $local · 원격 —';
  }

  @override
  String get twofaChallengeTitle => '2단계 인증';

  @override
  String get twofaMethodTotp => '인증 코드';

  @override
  String get twofaMethodRecovery => '복구 코드';

  @override
  String get twofaTotpInputPlaceholder => '6자리 코드';

  @override
  String get twofaRecoveryInputPlaceholder => '복구 코드';

  @override
  String get twofaVerifyButton => '확인';

  @override
  String get twofaStatusTitle => '2단계 인증';

  @override
  String get twofaStatusEnabled => '활성화됨 ✓';

  @override
  String get twofaStatusDisabled => '비활성화됨';

  @override
  String twofaStatusEnabledAt(String date) {
    return '$date에 활성화됨';
  }

  @override
  String get sharedRoleOwner => '소유자';

  @override
  String get sharedRoleEditor => '편집자';

  @override
  String get commonCopied => '복사됨';

  @override
  String get commonRemove => '제거';

  @override
  String get sharedJoinPageTitle => '공유 가계부 참여';

  @override
  String get sharedJoinPageSubtitle => '초대 코드를 입력하거나 공유 링크를 누르세요';

  @override
  String get sharedJoinEnterCode => '초대 코드 입력';

  @override
  String get sharedJoinEnterCodeHint => '대문자와 숫자 6자리입니다. 공유 링크를 누르면 이 단계를 건너뛸 수 있습니다.';

  @override
  String get sharedJoinPreviewButton => '코드 확인';

  @override
  String get sharedJoinAcceptButton => '참여하기';

  @override
  String sharedJoinInvitedBy(String name) {
    return '$name님이 초대했습니다';
  }

  @override
  String sharedJoinRoleLine(String role) {
    return '역할: $role';
  }

  @override
  String sharedJoinExpiresInMinutes(int n) {
    return '$n분 후 만료';
  }

  @override
  String sharedJoinExpiresInHours(int n) {
    return '$n시간 후 만료';
  }

  @override
  String sharedJoinExpiresInDays(int n) {
    return '$n일 후 만료';
  }

  @override
  String sharedJoinSuccess(String name) {
    return '\"$name\"에 참여했습니다';
  }

  @override
  String get sharedJoinCodeFormatError => '초대 코드는 6자리 문자/숫자여야 합니다.';

  @override
  String get sharedJoinInvalidOrExpired => '초대 코드가 유효하지 않거나 만료되었습니다. 초대한 사람에게 새 코드를 요청하세요.';

  @override
  String get sharedJoinAlreadyMember => '이미 이 가계부의 멤버입니다.';

  @override
  String get sharedJoinMemberLimit => '이 가계부의 멤버 수 한도에 도달했습니다. 소유자에게 문의하세요.';

  @override
  String get sharedInviteFormRole => '역할';

  @override
  String get sharedInviteFormExpiry => '유효 기간';

  @override
  String sharedInviteExpiryHours(int n) {
    return '$n시간';
  }

  @override
  String sharedInviteExpiryDays(int n) {
    return '$n일';
  }

  @override
  String get sharedInviteGenerate => '초대 코드 생성';

  @override
  String get sharedInviteGenerateAnother => '다른 코드 생성';

  @override
  String get sharedInviteCopyCode => '코드 복사';

  @override
  String get sharedInviteCopyLink => '링크 복사';

  @override
  String get sharedInviteShareLink => '링크 공유';

  @override
  String sharedInviteExpiresAt(String dt) {
    return '$dt에 만료';
  }

  @override
  String get sharedInviteWarning => '⚠️ 초대 코드를 공개 그룹이나 SNS에 게시하지 마세요. 코드를 가진 사람은 누구나 참여할 수 있습니다. 유출되었다면 멤버 화면에서 취소하고 다시 생성하세요.';

  @override
  String get sharedInviteInstruction => '코드나 짧은 링크를 상대방에게 전달하세요. Spitout를 설치한 후 링크를 누르거나 \"내 정보 → 공유 가계부 참여\"에서 코드를 입력하면 됩니다.';

  @override
  String sharedInviteShareText(String ledger, String code, String url) {
    return 'Spitout 공유 가계부 \"$ledger\"에 초대합니다.\n\n코드: $code\n링크: $url\n\n링크를 누르거나 Spitout → 내 정보 → 공유 가계부 참여에서 이 코드를 입력하세요.';
  }

  @override
  String get sharedMembersPageTitle => '멤버';

  @override
  String get sharedMembersYou => '나';

  @override
  String get sharedMembersInviteCta => '새 멤버 초대';

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
  String get sharedMembersRemoveTitle => '멤버 제거';

  @override
  String get sharedMembersRemoveCta => '이 멤버 제거';

  @override
  String sharedMembersRemoveConfirm(String name) {
    return '$name님을 제거하시겠습니까? 즉시 이 가계부에 대한 접근 권한을 잃게 됩니다.';
  }

  @override
  String get sharedMembersRemoved => '멤버가 제거되었습니다';

  @override
  String get sharedMembersSyncPending => 'For a newly created ledger, select it on the ledger management page first, then re-enter this page to invite members.';

  @override
  String get sharedMembersSaveFirst => '먼저 가계부를 저장해 주세요';

  @override
  String get sharedMembersInviteSyncFailed => '클라우드 동기화가 아직 완료되지 않았습니다. 나중에 다시 시도하세요.';

  @override
  String sharedTxCreatedBy(String name) {
    return '$name님이 생성함';
  }

  @override
  String sharedTxEditedBy(String name) {
    return '$name님이 마지막으로 편집함';
  }

  @override
  String sharedTxCreatedAndEditedBy(String name) {
    return '$name님이 생성 및 편집함';
  }

  @override
  String get sharedRequiresCloudSync => '먼저 클라우드 동기화를 활성화해 주세요';

  @override
  String get sharedMembersStatsTitle => '멤버별 지출';

  @override
  String get sharedMembersStatsEmpty => '아직 거래가 없습니다';

  @override
  String sharedMembersStatsTxCount(int count) {
    return '거래 $count건';
  }

  @override
  String get maintenanceOrphanCleanupTitle => '데이터 정리';

  @override
  String get maintenanceOrphanCleanupSubtitle => '로컬의 고아 데이터를 감지하고 정리합니다';

  @override
  String get maintenanceOrphanRescan => '다시 검사';

  @override
  String get maintenanceOrphanEmpty => '로컬 데이터가 깨끗합니다. 고아 데이터가 없습니다';

  @override
  String get maintenanceOrphanGroupDb => '데이터베이스 고아 데이터';

  @override
  String get maintenanceOrphanGroupSync => '동기화 상태 고아 데이터';

  @override
  String maintenanceOrphanSummary(int count) {
    return '$count건의 문제를 발견했습니다';
  }

  @override
  String get maintenanceOrphanSelectAll => '전체 선택';

  @override
  String get maintenanceOrphanDeselectAll => '전체 선택 해제';

  @override
  String get maintenanceOrphanDeleteOne => '이것만 삭제';

  @override
  String maintenanceOrphanSelectedHint(int count) {
    return '$count개 선택됨';
  }

  @override
  String get maintenanceOrphanCleanSelected => '선택 항목 정리';

  @override
  String get maintenanceOrphanConfirmTitle => '정리 확인';

  @override
  String maintenanceOrphanConfirmDeleteOne(String title) {
    return '\"$title\"을(를) 삭제하시겠습니까? 되돌릴 수 없습니다.';
  }

  @override
  String maintenanceOrphanConfirmDeleteBatch(int count) {
    return '선택한 $count개 항목을 삭제하시겠습니까? 되돌릴 수 없습니다.';
  }

  @override
  String maintenanceOrphanCleanSuccess(int count) {
    return '$count개 항목을 정리했습니다';
  }

  @override
  String maintenanceOrphanCleanPartial(int ok, int fail) {
    return '$ok개 정리 완료, $fail개 실패';
  }

  @override
  String maintenanceOrphanDeletedLedgerGroup(int ledgerId, int count) {
    return '삭제된 장부 #$ledgerId ($count개)';
  }

  @override
  String get maintenanceOrphanMoveSingle => '장부로 이동';

  @override
  String get maintenanceOrphanMoveToLedger => '장부로 이동';

  @override
  String maintenanceOrphanMoveToLedgerSuccess(int count) {
    return '$count개를 장부로 이동했습니다';
  }

  @override
  String get exchangeRatePageTitle => '환율';

  @override
  String get exchangeRateEntrySubtitle => '자동으로 가져온 환율을 직접 수정할 수 있습니다';

  @override
  String get rateSourceAuto => '자동';

  @override
  String get rateSourceManual => '수동';

  @override
  String rateUpdatedAt(String date) {
    return '$date 업데이트됨';
  }

  @override
  String get rateNotFetched => '가져오지 않음';

  @override
  String get rateEditTitle => '환율 편집';

  @override
  String rateInverseHint(String base, String rate, String quote) {
    return '역환율: 1 $base ≈ $rate $quote';
  }

  @override
  String get rateResetToAuto => '자동으로 재설정';

  @override
  String get rateRefreshSuccess => '환율이 업데이트되었습니다';

  @override
  String get rateRefreshFailed => '가져오기에 실패했습니다. 직접 환율을 설정할 수 있습니다';

  @override
  String get rateDisclaimer => '출처: 공개 환율 데이터, 매일 업데이트됩니다. 환산은 참고용이며 은행 환율과 다를 수 있습니다.';

  @override
  String get txFlagExcludedTag => '제외됨';

  @override
  String get txRateLabel => 'Rate';

  @override
  String get txRateMissingHint => 'Please enter the rate for this entry before saving';

  @override
  String get ledgerBaseCurrencyLabel => '기준 통화';

  @override
  String statsConvertedFootnote(Object currency) {
    return 'Includes foreign currency, converted to $currency at entry-time rates';
  }

  @override
  String get ledgerCurrencyChangeRecalcHint => '기준 통화를 변경하면 모든 내역이 현재 환율로 다시 환산됩니다';

  @override
  String get ledgerCurrencyChangeRecalcWarning => '이 장부의 모든 거래 환산 금액이 최신 환율로 재계산되어 덮어쓰기되며, 다른 통화로 변경했다가 다시 돌아와도 원래 환산 값은 복원되지 않습니다';

  @override
  String get recalcForeignTxBanner => '이 장부에 환산되지 않은 외화 거래가 있습니다';

  @override
  String get recalcForeignTxAction => '현재 환율로 다시 환산';

  @override
  String recalcForeignTxDone(Object count) {
    return '외화 거래 $count건의 환산 값을 다시 계산했습니다';
  }

  @override
  String get txCurrencyPickerTitle => 'Select currency';

  @override
  String get txAddEntryTitle => '기록하기';

  @override
  String get txDeleteLongPress => '길게 눌러 초기화';

  @override
  String get txSelectDateTimeTitle => '거래 시간 선택';

  @override
  String get txSelectDateTimeHint => '위아래로 슬라이드하여 선택';

  @override
  String get txEditCategory => '분류 편집';

  @override
  String get txEditCategoryReadOnly => '분류 편집 (공유 가계부 읽기 전용)';

  @override
  String get txLedgerBaseCurrency => '장부 기본 통화';

  @override
  String recalcSyncCountHint(Object count) {
    return '$count건의 거래가 재환산되어 동기화됩니다';
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
  String get detailImportExportTitle => '상세 가져오기/내보내기';

  @override
  String get detailImportExportSubtitle => 'Expense CSV file';

  @override
  String get detailImportExportImportTitle => '상세 가져오기';

  @override
  String get detailImportExportImportSubtitle => 'CSV/TSV/XLSX 및 알리페이/위챗 명세서 지원';

  @override
  String get detailImportExportExportTitle => '상세 내보내기';

  @override
  String get detailImportExportExportSubtitle => '장부 내역을 CSV 파일로 내보내기';

  @override
  String get detailImportExportImportPoint1 => '일반 CSV, 알리페이, 위챗 세 가지 명세서를 지원하며 파일 형식은 CSV/TSV/XLSX입니다';

  @override
  String get detailImportExportImportPoint2 => '차이는 파일 구조뿐입니다: 일반 CSV는 깔끔한 헤더 행을, 알리페이/위챗 명세서는 설명용 머리말 행을 포함하며 앱이 자동으로 건너뛰고 헤더를 찾습니다';

  @override
  String get detailImportExportImportPoint3 => '세 가지 모두 동일한 열 매핑(날짜, 유형, 금액, 통화, 카테고리, 하위 카테고리, 메모)으로 인식되므로 가져오기 흐름이 동일합니다';

  @override
  String get detailImportExportExportPoint1 => '장부의 거래 내역을 UTF-8 BOM 인코딩의 CSV 파일로 내보내며 Excel에서 바로 열 수 있습니다';

  @override
  String get detailImportExportExportPoint2 => '파일명은 spitout_타임스탬프.csv이며 기본적으로 Download/Spitout 디렉터리에 저장됩니다';

  @override
  String get detailImportExportExportPoint3 => '포함 필드는 다음과 같습니다:';

  @override
  String get detailExportLedgerLabel => '장부 내보내기';

  @override
  String get detailExportSelectAllLabel => '전체 선택';

  @override
  String get detailExportSelectAllSubtitle => '전체 데이터 내보내기';

  @override
  String get detailExportStartDate => '시작 날짜';

  @override
  String get detailExportEndDate => '종료 날짜';

  @override
  String get detailExportDateInvalid => '시작 날짜은 종료 날짜보다 늦을 수 없습니다';

  @override
  String get detailExportAction => '내보내기';

  @override
  String exchangeRateCurrentLedger(Object name) {
    return '현재 장부: $name';
  }

  @override
  String get exchangeRateInfoTitle => '기준 통화 안내';

  @override
  String get exchangeRateInfoMessage => '기준 통화는 현재 장부의 기본 통화로, 장부 내 외화 거래는 환율에 따라 기준 통화로 환산되어 통계와 자산 개요에서 통합 집계됩니다. 장부마다 고유한 기준 통화가 있으며 언제든지 변경할 수 있고, 변경하면 이 장부의 모든 거래 환산 금액이 최신 환율로 재계산됩니다.\n\n환율은 공개 데이터 소스에서 매일 자동으로 가져옵니다. 아래 목록에서 원하는 통화의 \'편집\'을 눌러 수동 환율을 설정할 수도 있으며, 수동 환율은 자동 데이터를 덮어쓰고 즉시 적용됩니다.';

  @override
  String get rateEditLabel => '편집';

  @override
  String get rateInvalidInput => '유효한 환율 값을 입력하세요 (0보다 큰 숫자)';

  @override
  String get currencyManageTitle => '표시 통화 관리';

  @override
  String get currencyManageEntry => '통화 관리';

  @override
  String currencyManageCount(Object count) {
    return '$count개 통화 선택됨';
  }

  @override
  String get currencyManageBaseLocked => '장부 기준 통화(숨길 수 없음)';

  @override
  String get currencyManageHint => '숨긴 통화는 기존 거래에 영향을 주지 않으며 언제든 다시 활성화할 수 있습니다.';

  @override
  String get detailImportExportMigrateTitle => '장부 데이터 마이그레이션';

  @override
  String get detailImportExportMigrateTip => '현재 장부의 데이터를 CSV 파일로 내보낸 다음, 대상 장부로 전환해 해당 파일을 가져오면 장부 간 데이터를 원활하게 마이그레이션할 수 있습니다.';

  @override
  String get mineCheckUpdate => '업데이트 확인';

  @override
  String get updateChecking => '업데이트 확인 중…';

  @override
  String get updateAvailableTitle => '새 버전 있음';

  @override
  String updateLatestVersion(String version) {
    return '최신 버전 v$version';
  }

  @override
  String get updateAlreadyLatestTitle => '최신 버전입니다';

  @override
  String updateAlreadyLatest(String version) {
    return '현재 최신 버전 v$version 사용 중';
  }

  @override
  String get updateGotoDownload => '다운로드로 이동';

  @override
  String updateCurrentVersion(String version) {
    return '현재 버전 v$version';
  }

  @override
  String updateNewVersionHint(String version) {
    return '새 버전 v$version 있음';
  }

  @override
  String get updateLater => '나중에';

  @override
  String get updateOk => '확인';

  @override
  String get updateCantAutoCheckTitle => '업데이트를 자동으로 확인할 수 없음';

  @override
  String get updateCantAutoCheck => '버전 정보를 가져올 수 없습니다. GitHub에서 최신 릴리스를 확인하세요.';

  @override
  String get updateGoToGithub => 'GitHub에서 보기';

  @override
  String get mineUpdateNow => '업데이트';

  @override
  String get ledgerMetaReadOnlyToast => '공동 작업자는 가계부 정보를 수정할 수 없습니다.';

  @override
  String get aaSettlementTitle => 'AA 통계';

  @override
  String get aaSettlementOverview => '요약';

  @override
  String get aaSettlementTotalAmount => '분담 총액';

  @override
  String aaSettlementTxCount(int count) {
    return '분담 거래 $count건';
  }

  @override
  String get aaSettlementPerPerson => '분담 상세';

  @override
  String get aaSettlementPaid => '지출';

  @override
  String get aaSettlementShare => '분담';

  @override
  String get aaSettlementNet => '차액';

  @override
  String get aaSettlementNetReceive => '받을 금액';

  @override
  String get aaSettlementNetPay => '보낼 금액';

  @override
  String get aaSettlementTransferPlan => '송금 계획';

  @override
  String aaSettlementTransferPayTo(String from, String to) {
    return '$from → $to';
  }

  @override
  String get aaSettlementNoTransfers => '정산 완료, 송금이 필요 없습니다';

  @override
  String get aaSettlementExcluded => '상세 내역 미포함';

  @override
  String aaSettlementParticipantCount(int count) {
    return '분담 인원 $count명';
  }

  @override
  String get aaSettlementExcludedEmpty => '상세 내역 제외 거래가 없습니다';

  @override
  String get aaEditTitle => '분담 편집';

  @override
  String get aaEditSplitButton => '분담 편집';

  @override
  String get aaPayer => '지출한 사람';

  @override
  String get aaSplitMode => '분담 방식';

  @override
  String get aaParticipants => '참여자';

  @override
  String get aaModePerPerson => '균등 분담';

  @override
  String get aaModeCustom => '금액 지정 분담';

  @override
  String get aaModeNoSplit => '미분담';

  @override
  String get aaParticipantsAll => '모든 멤버';

  @override
  String aaParticipantsAllCount(int count) {
    return '모든 멤버($count명)';
  }

  @override
  String get aaParticipantsUnit => '명';

  @override
  String get aaSplitTotal => '합계';

  @override
  String get aaVirtualUserTitle => '가상 사용자';

  @override
  String get aaVirtualUserAdd => '가상 사용자 추가';

  @override
  String get aaVirtualUserNameHint => '닉네임 입력';

  @override
  String get aaVirtualUserRename => '이름 변경';

  @override
  String get aaVirtualUserEmpty => '가상 사용자가 없습니다';

  @override
  String aaVirtualUserDeleteConfirm(String name) {
    return '가상 사용자「$name」을(를) 삭제하시겠습니까?';
  }

  @override
  String get aaVirtualUserInUse => '관련 거래가 있어 삭제할 수 없습니다';

  @override
  String aaVirtualUserDefaultName(int index) {
    return '가상 사용자$index';
  }

  @override
  String get aaAddVirtualUser => '가상 사용자 추가';

  @override
  String get aaUnknownUser => '알 수 없음';

  @override
  String get aaMe => '나';

  @override
  String get ledgerAaEnabled => 'AA 분담';

  @override
  String get ledgerAaEnabledHint => '활성화하면 지출을 멤버와 분담할 수 있습니다';

  @override
  String get ledgerAaSettlementEntry => 'AA 통계';

  @override
  String get ledgerAaVirtualUsersEntry => '가상 사용자 관리';

  @override
  String get aaNoParticipants => '참여자를 먼저 추가하세요';

  @override
  String get aaSplitAmountIncomplete => '모든 참여자의 금액을 입력하세요';
}
