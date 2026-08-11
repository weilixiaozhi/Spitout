// 明细 CSV 导入确认页测试。
//
// 覆盖：解析 loading → 字段映射（自动识别表头/无表头/空数据）→ 分类映射 →
// 导入全流程（无账本阻断 / 账本不存在 / 成功 / 坏行与跳过类型 / 导入异常）。
// 测试按页面需求断言 UI 文案与仓库调用，不复制实现细节。

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';
import '../../helpers/test_isolation.dart';
import 'package:spitout/cloud/sync/sync_service.dart' show LocalOnlySyncService;
import 'package:spitout/cloud/spitout_cloud.dart' show SpitoutCloudSyncBackend;
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/data/import_confirm_page.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/core/local_self_id_providers.dart';
import 'package:spitout/providers/sync/cloud_client_providers.dart';
import 'package:spitout/providers/sync/sync_providers.dart'
    show syncServiceProvider;

class _MockRepo extends Mock implements BaseRepository {}

/// 标准三行 CSV：表头 + 两笔支出，表头可被 GenericBillParser 全字段识别。
const _csv = '日期,类型,金额,币种,分类,备注\n'
    '2026-01-01,支出,12.50,CNY,餐饮,午饭\n'
    '2026-01-02,支出,20.00,CNY,交通,地铁\n';

/// 表头缺少「分类」列，用于验证下一步被阻断。
const _csvNoCategory = '日期,类型,金额\n2026-01-01,支出,12.50\n';

/// 包含坏行（日期/金额非法）与跳过类型（收入）的 CSV。
const _csvBadRows = '日期,类型,金额,币种,分类\n'
    '2026-01-01,支出,12.50,CNY,餐饮\n'
    '2026-01-02,收入,20.00,CNY,红包\n'
    'bad-date,支出,5.00,CNY,餐饮\n'
    '2026-01-04,支出,abc,CNY,交通\n';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;

  Ledger ledgerFixture() => Ledger(
        id: 1,
        name: '默认账本',
        currency: 'CNY',
        type: 'personal',
        createdAt: DateTime(2026, 1, 1),
        myRole: 'owner',
        memberCount: 1,
        isShared: false,
        monthStartDay: 1,
        storageMode: 'local',
        aaEnabled: false,
      );

  setUp(() {
    resetGlobalTestState();
    repo = _MockRepo();
    when(() => repo.getLedgerById(1)).thenAnswer((_) async => ledgerFixture());
    when(() => repo.getAllCategories()).thenAnswer((_) async => <Category>[]);
    when(() => repo.getTopLevelCategories('expense'))
        .thenAnswer((_) async => <Category>[]);
    when(() => repo.createCategory(
          name: any(named: 'name'),
          kind: any(named: 'kind'),
          icon: any(named: 'icon'),
          sortOrder: any(named: 'sortOrder'),
        )).thenAnswer((_) async => 100);
    // 导入服务去重与汇率预取所需数据：无存量交易、无有效汇率。
    when(() => repo.getTransactionsByLedger(any()))
        .thenAnswer((_) async => <Transaction>[]);
    when(() => repo.getLatestAutoRates(any()))
        .thenAnswer((_) async => <ExchangeRate>[]);
    when(() => repo.getOverrides(any()))
        .thenAnswer((_) async => <ExchangeRateOverride>[]);
    when(() => repo.insertTransactionsBatchWithRelations(
      transactions: any(named: 'transactions'),
      recordChanges: any(named: 'recordChanges'),
    )).thenAnswer((_) async => [1]);
  });

  /// 宿主：先渲染一个入口页，把 ImportConfirmPage 以 push 方式打开，
  /// 这样导入成功后的 pop 语义与真实导航一致，也可断言页面已关闭。
  Widget buildApp({
    required String csv,
    required bool hasHeader,
    int ledgerId = 1,
    String? localSelfId,
    SpitoutCloudSyncBackend? cloudBackend,
  }) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        if (localSelfId != null)
          localSelfIdProvider.overrideWith((ref) async => localSelfId),
        spitoutCloudProviderInstance.overrideWith((ref) async => cloudBackend),
        currentLedgerIdProvider.overrideWithBuild(
            (ref, notifier) => ledgerId),
        syncServiceProvider.overrideWith((ref) => LocalOnlySyncService()),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ImportConfirmPage(
                      csvText: csv,
                      hasHeader: hasHeader,
                    ),
                  ),
                ),
                child: const Text('open-import'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 打开页面并等待后台 isolate 解析完成。
  Future<void> openAndParse(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.tap(find.text('open-import'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // compute 在真实 isolate 中解析，必须走 runAsync 让事件循环推进。
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// 点击「下一步」进入分类映射步骤。
  Future<void> goToCategoryStep(WidgetTester tester) async {
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
  }

  group('解析与字段映射', () {
    testWidgets('解析中显示 loading，解析完成进入字段映射步骤', (tester) async {
      await tester.pumpWidget(buildApp(csv: _csv, hasHeader: true));
      await tester.tap(find.text('open-import'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 后台 isolate 尚未返回时展示「准备中…」+ 转圈
      expect(find.text('准备中…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 字段映射步骤：标题、七个字段下拉、预览表、下一步
      expect(find.text('确认映射'), findsOneWidget);
      for (final label in ['日期', '类型', '金额', '币种', '分类', '二级分类', '备注']) {
        expect(find.text(label), findsWidgets, reason: '应展示字段 $label');
      }
      expect(find.text('预览：'), findsOneWidget);
      expect(find.text('下一步'), findsOneWidget);
      // 预览表头行与两行数据
      expect(find.text('餐饮'), findsOneWidget);
      expect(find.text('12.50'), findsOneWidget);
    });

    testWidgets('表头自动识别：日期/类型/金额/分类被自动映射', (tester) async {
      await openAndParse(tester, buildApp(csv: _csv, hasHeader: true));

      await goToCategoryStep(tester);
      expect(find.text('分类映射'), findsOneWidget);
      expect(find.text('开始导入'), findsOneWidget);
      // 源分类列表包含表内去重后的分类名
      expect(find.text('餐饮'), findsOneWidget);
      expect(find.text('交通'), findsOneWidget);
    });

    testWidgets('无表头时全部字段未映射，点击下一步被阻断并提示', (tester) async {
      await openAndParse(tester, buildApp(csv: _csv, hasHeader: false));

      expect(find.text('自动'), findsWidgets, reason: '未映射字段显示「自动」提示');
      await tester.tap(find.text('下一步'));
      await tester.pump();
      expect(find.text('请先选择"分类"列再继续'), findsOneWidget);
      // 仍停留在映射步骤
      expect(find.text('确认映射'), findsOneWidget);
      // 清掉 toast 自动消失定时器
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('表头缺分类列时下一步被阻断', (tester) async {
      await openAndParse(tester, buildApp(csv: _csvNoCategory, hasHeader: true));

      await tester.tap(find.text('下一步'));
      await tester.pump();
      expect(find.text('请先选择"分类"列再继续'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('空 CSV 展示无数据提示而非崩溃', (tester) async {
      await openAndParse(tester, buildApp(csv: '', hasHeader: true));

      expect(find.text('未解析到任何数据，请返回上一页检查 CSV 内容或分隔符。'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('超过 10 行时预览展示截断提示', (tester) async {
      final buf = StringBuffer('日期,类型,金额\n');
      for (var i = 1; i <= 15; i++) {
        buf.writeln('2026-01-${i.toString().padLeft(2, '0')},支出,$i.00');
      }
      await openAndParse(tester, buildApp(csv: buf.toString(), hasHeader: true));

      // 1 行表头 + 15 行数据 = 16 行，仅预览前 10 行
      expect(find.text('仅预览前 10 行，共 16 行'), findsOneWidget);
    });
  });

  group('分类映射', () {
    testWidgets('映射下拉可选择系统分类并自动按名称匹配', (tester) async {
      when(() => repo.getAllCategories()).thenAnswer((_) async => [
            const Category(
                id: 1, name: '餐饮', kind: 'expense', sortOrder: 0, level: 1),
            const Category(
                id: 2, name: '交通', kind: 'expense', sortOrder: 1, level: 1),
            const Category(
                id: 3,
                name: '早餐',
                kind: 'expense',
                sortOrder: 0,
                level: 2,
                parentId: 1),
          ]);
      await openAndParse(tester, buildApp(csv: _csv, hasHeader: true));

      await goToCategoryStep(tester);

      // 自动匹配：餐饮命中 id=1（下拉应展示「餐饮（一级分类）」）
      expect(find.text('餐饮（一级分类）'), findsWidgets);
      // 交通未命中（初始为「保持原名」），手工改为系统分类 id=2
      final row = find.ancestor(
        of: find.text('交通').first,
        matching: find.byType(Row),
      );
      await tester.tap(find.descendant(
        of: row.first,
        matching: find.byType(DropdownButton<int?>),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('交通（一级分类）').last);
      await tester.pumpAndSettle();

      // 选中后分类映射下拉应展示系统分类名
      expect(find.text('交通（一级分类）'), findsWidgets);
    });

    testWidgets('上一步返回字段映射，再下一步回到分类映射', (tester) async {
      await openAndParse(tester, buildApp(csv: _csv, hasHeader: true));

      await goToCategoryStep(tester);
      expect(find.text('分类映射'), findsOneWidget);

      await tester.tap(find.text('上一步'));
      await tester.pumpAndSettle();
      expect(find.text('确认映射'), findsOneWidget);

      await goToCategoryStep(tester);
      expect(find.text('分类映射'), findsOneWidget);
    });
  });

  group('开始导入', () {
    testWidgets('无当前账本时阻断并提示先创建账本', (tester) async {
      await openAndParse(
          tester, buildApp(csv: _csv, hasHeader: true, ledgerId: 0));

      await goToCategoryStep(tester);
      await tester.tap(find.text('开始导入'));
      await tester.pump();

      expect(find.text('请先创建账本再导入'), findsOneWidget);
      expect(find.text('分类映射'), findsOneWidget, reason: '页面不跳转');
      // 未发起导入：仓库不应收到批量写入
      verifyNever(() => repo.insertTransactionsBatchWithRelations(
        transactions: any(named: 'transactions'),
        recordChanges: any(named: 'recordChanges'),
      ));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('账本不存在时阻断并提示', (tester) async {
      when(() => repo.getLedgerById(1)).thenAnswer((_) async => null);
      await openAndParse(tester, buildApp(csv: _csv, hasHeader: true));

      await goToCategoryStep(tester);
      await tester.tap(find.text('开始导入'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('请先创建账本再导入'), findsOneWidget);
      verifyNever(() => repo.insertTransactionsBatchWithRelations(
        transactions: any(named: 'transactions'),
        recordChanges: any(named: 'recordChanges'),
      ));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('导入成功：进度弹窗 → 完成 toast → 关闭页面', (tester) async {
      // 让批量写入耗时 100ms，确保进度弹窗可被观察到。
      when(() => repo.insertTransactionsBatchWithRelations(
        transactions: any(named: 'transactions'),
        recordChanges: any(named: 'recordChanges'),
      )).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return [1];
      });
      await openAndParse(tester, buildApp(csv: _csv, hasHeader: true));

      await goToCategoryStep(tester);
      await tester.tap(find.text('开始导入'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // 进度弹窗出现（导入仍在等待写入完成）
      expect(find.text('正在导入…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('正在导入…'), findsNothing);
      expect(find.text('导入完成：成功 1 条，失败 0 条'), findsOneWidget);
      // 页面已 pop 回宿主
      expect(find.text('open-import'), findsOneWidget);
      expect(find.text('开始导入'), findsNothing);

      // 仓库收到一次批量写入（两笔交易一个批次）
      verify(() => repo.insertTransactionsBatchWithRelations(
        transactions: any(named: 'transactions'),
        recordChanges: any(named: 'recordChanges'),
      )).called(1);

      // 冲刷 5 秒延迟清空进度与 toast 定时器
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('导入落库：本地账本以 localSelfId 为作者身份', (tester) async {
      await openAndParse(
        tester,
        buildApp(csv: _csv, hasHeader: true, localSelfId: 'device-1'),
      );
      await goToCategoryStep(tester);
      await tester.tap(find.text('开始导入'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 2));

      final captured = verify(
        () => repo.insertTransactionsBatchWithRelations(
          transactions: captureAny(named: 'transactions'),
          recordChanges: any(named: 'recordChanges'),
        ),
      ).captured;
      final txs = captured.single as List<TransactionsCompanion>;
      expect(txs, hasLength(2));
      for (final t in txs) {
        expect(t.paidByUserId.value, 'device-1');
        expect(t.createdByUserId.value, 'device-1');
        expect(t.lastEditedByUserId.value, 'device-1');
      }
    });

    testWidgets('导入落库：云端账本以云 userId 为作者身份', (tester) async {
      when(() => repo.getLedgerById(1)).thenAnswer((_) async => Ledger(
            id: 1,
            name: '云端账本',
            currency: 'CNY',
            type: 'personal',
            createdAt: DateTime(2026, 1, 1),
            myRole: 'owner',
            memberCount: 1,
            isShared: true,
            monthStartDay: 1,
            syncId: 'sync-1',
            storageMode: 'cloud',
            aaEnabled: false,
          ));
      await openAndParse(
        tester,
        buildApp(
          csv: _csv,
          hasHeader: true,
          cloudBackend: FakeSpitoutCloudProvider(userId: 'cloud-1'),
        ),
      );
      await goToCategoryStep(tester);
      await tester.tap(find.text('开始导入'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 2));

      final captured = verify(
        () => repo.insertTransactionsBatchWithRelations(
          transactions: captureAny(named: 'transactions'),
          recordChanges: any(named: 'recordChanges'),
        ),
      ).captured;
      final txs = captured.single as List<TransactionsCompanion>;
      expect(txs, hasLength(2));
      for (final t in txs) {
        expect(t.paidByUserId.value, 'cloud-1');
        expect(t.createdByUserId.value, 'cloud-1');
        expect(t.lastEditedByUserId.value, 'cloud-1');
      }
    });

    testWidgets('坏行与跳过类型：完成弹窗展示明细，确认后关闭页面', (tester) async {
      await openAndParse(tester, buildApp(csv: _csvBadRows, hasHeader: true));

      await goToCategoryStep(tester);
      await tester.tap(find.text('开始导入'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // 有失败/跳过 → 弹「导入完成」对话框
      expect(find.text('导入完成'), findsOneWidget);
      expect(find.textContaining('无法解析的 2 行已跳过'), findsOneWidget);
      expect(find.textContaining('跳过 1 条非支出记录'), findsOneWidget);
      expect(find.textContaining('收入(1)'), findsOneWidget);

      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(find.text('open-import'), findsOneWidget, reason: '确认后关闭确认页');

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('导入服务异常：提示操作失败并进入失败统计弹窗', (tester) async {
      // 页面在 _startImport 先查一次账本，导入服务内部再查一次；
      // 第二次查询抛错，模拟导入中途失败。
      var ledgerCalls = 0;
      when(() => repo.getLedgerById(1)).thenAnswer((_) async {
        ledgerCalls++;
        if (ledgerCalls > 1) throw Exception('boom');
        return ledgerFixture();
      });
      await openAndParse(tester, buildApp(csv: _csv, hasHeader: true));

      await goToCategoryStep(tester);
      await tester.tap(find.text('开始导入'));
      await tester.pump();

      // 异常发生在同一帧微任务内:toast 已弹出(1 秒后自动消失)
      expect(find.text('操作失败，请稍后重试'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('导入完成'), findsOneWidget);
      expect(find.textContaining('成功 0 条，失败 2 条'), findsOneWidget);

      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
