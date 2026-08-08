/// LedgerEditPage 行为流测试（第二弹）：加载失败/重试、新建保存、货币与月起始日
/// 选择器、归属选择、编辑改名保存。
///
/// 第一弹（danger_zone / fast_exit / read_only / storage_move）已覆盖危险操作与
/// 竞态；本文件补齐「加载与表单主路径」，用真实内存库驱动创建/更新落库断言。
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/models.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/main/ledger_edit_page.dart';
import 'package:spitout/providers/providers.dart';

import '../../helpers/test_isolation.dart';

/// 可注入「首次 getLedgerById 抛错」的仓库，用于覆盖加载异常分支。
class _FailOnceRepo extends LocalRepository {
  _FailOnceRepo(super.db, {this.failFirstGet = false});

  bool failFirstGet;

  @override
  Future<Ledger?> getLedgerById(int id) async {
    if (failFirstGet) {
      failFirstGet = false;
      throw StateError('load boom');
    }
    return super.getLedgerById(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;

  CloudServiceConfig spitoutConfig() => const CloudServiceConfig(
    type: CloudBackendType.spitoutCloud,
    name: 'Spitout Cloud',
    spitoutCloudBaseUrl: 'https://example.com',
  );

  void buildContainer({
    LocalRepository? useRepo,
    CloudServiceConfig config = const CloudServiceConfig(
      type: CloudBackendType.local,
      name: 'Local',
    ),
  }) {
    container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(useRepo ?? repo),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
      currentLedgerProvider.overrideWith((ref) => Stream<Ledger?>.value(null)),
      activeCloudConfigProvider.overrideWith((ref) async => config),
    ]);
  }

  setUp(() {
    resetGlobalTestState();
    SharedPreferences.setMockInitialValues({});
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db, changeTracker: ChangeTracker(db));
    buildContainer();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    LedgerDisplayItem? ledger,
  }) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LedgerEditPage(ledger: ledger),
        ),
      ),
    );
    await tester.runAsync(() => tester.pumpAndSettle());
    return l10n;
  }

  Future<int> insertLedger(String name, {int? id}) async {
    return db.into(db.ledgers).insert(
      LedgersCompanion.insert(
        id: id == null ? const Value.absent() : Value(id),
        name: name,
        currency: const Value('CNY'),
      ),
    );
  }

  LedgerDisplayItem item(int id, String name) => LedgerDisplayItem.fromLocal(
    id: id,
    name: name,
    currency: 'CNY',
    createdAt: DateTime(2026, 1, 1),
    transactionCount: 0,
    expenseTotal: 0,
  );

  testWidgets('编辑模式：账本不存在 → 错误态 → 补建后重试成功', (tester) async {
    final l10n = await pump(tester, ledger: item(999, '不存在'));

    // 账本缺失 → 错误 UI + 重试按钮。
    expect(find.text(l10n.categoryDetailLoadFailed), findsOneWidget);
    expect(find.text(l10n.analyticsRetry), findsOneWidget);
    expect(find.text(l10n.commonSave), findsNothing,
        reason: '加载失败时不应渲染保存按钮');

    // 补齐账本后点重试 → 进入正常编辑表单。
    await insertLedger('旅行账本', id: 999);
    await tester.tap(find.text(l10n.analyticsRetry));
    await tester.runAsync(() => tester.pumpAndSettle());

    expect(find.text(l10n.categoryDetailLoadFailed), findsNothing);
    expect(find.text(l10n.commonSave), findsOneWidget,
        reason: '重试成功后应渲染保存按钮进入编辑表单');
    expect(find.textContaining('CNY', findRichText: true), findsWidgets,
        reason: '重试成功后应从数据库加载币种');
  });

  testWidgets('编辑模式：加载抛错 → 错误态 → 重试成功', (tester) async {
    final failRepo = _FailOnceRepo(db, failFirstGet: true);
    failRepo.changeTracker = ChangeTracker(db);
    buildContainer(useRepo: failRepo);
    await insertLedger('旅行账本', id: 1);

    final l10n = await pump(tester, ledger: item(1, '旅行账本'));
    expect(find.text(l10n.categoryDetailLoadFailed), findsOneWidget);

    await tester.tap(find.text(l10n.analyticsRetry));
    await tester.runAsync(() => tester.pumpAndSettle());
    expect(find.text(l10n.categoryDetailLoadFailed), findsNothing);
    expect(find.text(l10n.commonSave), findsOneWidget);
  });

  testWidgets('新建模式：空名称保存 → validator 提示且不创建', (tester) async {
    final l10n = await pump(tester);

    await tester.tap(find.text(l10n.ledgersCreate));
    await tester.runAsync(() => tester.pumpAndSettle());

    expect(find.text(l10n.ledgerNameLabel), findsWidgets,
        reason: '空名称应触发表单校验提示');
    final rows = await db.select(db.ledgers).get();
    expect(rows, isEmpty, reason: '校验失败不得创建账本');
  });

  testWidgets('新建模式：保存成功 → 落库并关闭页面', (tester) async {
    final l10n = await pump(tester);

    await tester.enterText(find.byType(TextFormField).first, '旅行账本');
    await tester.tap(find.text(l10n.ledgersCreate));
    await tester.runAsync(() => tester.pumpAndSettle());

    expect(find.byType(LedgerEditPage), findsNothing,
        reason: '创建成功应关闭编辑页');
    final rows = await db.select(db.ledgers).get();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.name, '旅行账本');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('货币选择器：点击币种行选 USD → 表单同步', (tester) async {
    await pump(tester);

    final currencyRow = find.ancestor(
      of: find.textContaining('CNY', findRichText: true),
      matching: find.byType(ListTile),
    );
    await tester.tap(currencyRow.first);
    await tester.runAsync(() => tester.pumpAndSettle());
    expect(find.textContaining('USD', findRichText: true), findsWidgets);

    await tester.tap(
      find.textContaining('USD', findRichText: true).first,
    );
    await tester.runAsync(() => tester.pumpAndSettle());
    expect(find.textContaining('USD', findRichText: true), findsWidgets,
        reason: '选择后表单币种应更新为 USD');
  });

  testWidgets('月起始日选择器：选 5 日 → 保存时写入账本', (tester) async {
    final l10n = await pump(tester);

    // 初始「1日（自然月）」。
    expect(find.text('1日（自然月）'), findsOneWidget);
    await tester.tap(find.text('1日（自然月）'));
    await tester.runAsync(() => tester.pumpAndSettle());

    // 选择 5 日。
    await tester.tap(find.text('5'));
    await tester.runAsync(() => tester.pumpAndSettle());
    expect(find.text('每月5日'), findsOneWidget,
        reason: '选择后应显示「每月5日」');

    // 保存 → monthStartDay=5 随创建落库。
    await tester.enterText(find.byType(TextFormField).first, '旅行账本');
    await tester.tap(find.text(l10n.ledgersCreate));
    await tester.runAsync(() => tester.pumpAndSettle());

    final rows = await db.select(db.ledgers).get();
    final row = rows.single;
    expect(row.monthStartDay, 5);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('新建归属：Spitout Cloud 激活时可切云端；未激活时云端禁用', (tester) async {
    final l10n = await pump(tester);
    expect(find.text(l10n.ledgersSectionLocal), findsOneWidget);
    final cloudLocal = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    final cloudSegment = cloudLocal.segments.firstWhere(
      (s) => s.value == 'cloud',
    );
    expect(cloudSegment.enabled, isFalse,
        reason: '非 Spitout Cloud 激活态下云端归属应禁用');

    // 重建为 Spitout Cloud 激活态。
    buildContainer(config: spitoutConfig());
    await pump(tester);
    final cloudSpitout = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    final cloudEnabled = cloudSpitout.segments.firstWhere(
      (s) => s.value == 'cloud',
    );
    expect(cloudEnabled.enabled, isTrue,
        reason: 'Spitout Cloud 激活时云端归属应可选');

    // 切到云端归属。
    await tester.tap(find.text(l10n.ledgersSectionCloud));
    await tester.pump();
    expect(
      tester
          .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
          .selected,
      {'cloud'},
    );
  });

  testWidgets('编辑模式：改名保存 → updateLedger 落库并关闭页面', (tester) async {
    await insertLedger('旧名字', id: 7);
    final l10n = await pump(tester, ledger: item(7, '旧名字'));

    await tester.enterText(find.byType(TextFormField).first, '新名字');
    await tester.tap(find.text(l10n.commonSave));
    await tester.runAsync(() => tester.pumpAndSettle());

    expect(find.byType(LedgerEditPage), findsNothing,
        reason: '编辑保存成功应关闭页面');
    final rows = await db.select(db.ledgers).get();
    final row = rows.single;
    expect(row.name, '新名字');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('云端账本归属动作：移动到本地/复制到本地失败 → 错误弹窗', (tester) async {
    buildContainer(config: spitoutConfig());
    final cloudId = await db.into(db.ledgers).insert(
      LedgersCompanion.insert(
        name: '云端账本',
        syncId: const Value('ext-1'),
        storageMode: const Value('cloud'),
      ),
    );
    final cloudItem = LedgerDisplayItem.fromLocal(
      id: cloudId,
      name: '云端账本',
      currency: 'CNY',
      createdAt: DateTime.now(),
      transactionCount: 0,
      expenseTotal: 0,
      storageMode: 'cloud',
    );
    final l10n = await pump(tester, ledger: cloudItem);

    // 移动到本地：确认后动作抛错（LocalOnly 不支持）→ 错误弹窗。
    await tester.tap(find.text(l10n.ledgersActionMoveToLocal));
    await tester.runAsync(() => tester.pumpAndSettle());
    await tester.tap(find.text(l10n.commonConfirm));
    await tester.runAsync(() => tester.pumpAndSettle());
    expect(find.text(l10n.commonFailed), findsOneWidget,
        reason: '移动到本地失败应弹统一错误弹窗');
    await tester.tap(find.text(l10n.commonOk));
    await tester.runAsync(() => tester.pumpAndSettle());

    // 复制到本地（popAfter=false）：失败同样弹错误弹窗且页面不关闭。
    await tester.tap(find.text(l10n.ledgersActionCopyToLocal));
    await tester.runAsync(() => tester.pumpAndSettle());
    await tester.tap(find.text(l10n.commonConfirm));
    await tester.runAsync(() => tester.pumpAndSettle());
    expect(find.text(l10n.commonFailed), findsOneWidget);
    expect(find.byType(LedgerEditPage), findsOneWidget,
        reason: '复制失败不应关闭编辑页');
    await tester.tap(find.text(l10n.commonOk));
    await tester.runAsync(() => tester.pumpAndSettle());
    await tester.pump(const Duration(seconds: 3));
  });
}
