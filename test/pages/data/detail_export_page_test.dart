// 导出明细页（二级页面）测试
//
// - 默认态：账本下拉选中当前账本、全选数据勾选、日期行置灰；
// - 全选联动：取消勾选后日期行恢复可用，重新勾选再次置灰；
// - 非法区间：开始日期晚于结束日期时显示提示且导出按钮禁用；
// - 日期选择：点击日期行拉起年-月-日滚轮选择器；
// - 账本下拉：可切换导出账本；
// - 单元：buildDetailExportRange 起止日展开边界。

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/data/detail_export_page.dart';
import 'package:spitout/providers/core/database_providers.dart';

// Mock 整个 LocalRepository，仅需 stub 账本列表查询。
class _MockRepo extends Mock implements LocalRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;

  /// 构造账本数据行（仅本页所需的字段语义，其余按表默认值填充）
  Ledger buildLedger(int id, String name) => Ledger(
        id: id,
        name: name,
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
    when(() => repo.getAllLedgers()).thenAnswer(
      (_) async => [buildLedger(1, '默认账本'), buildLedger(2, '测试账本')],
    );
  });

  /// 构建测试宿主：注入 mock repo 与当前账本 ID（=1），挂载多语言 delegates。
  Widget buildApp({
    Locale locale = const Locale('zh'),
    DateTime? initialStartDate,
    DateTime? initialEndDate,
  }) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: DetailExportPage(
          initialStartDate: initialStartDate,
          initialEndDate: initialEndDate,
        ),
      ),
    );
  }

  /// 分步 pump：等待首帧、账本列表 Future 与 l10n 资源加载完成。
  Future<void> prime(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// 取指定文本所在日期行的置灰透明度（1.0=可用，0.5=置灰）
  double dateRowOpacity(WidgetTester tester, String label) {
    return tester
        .widget<Opacity>(
          find.ancestor(of: find.text(label), matching: find.byType(Opacity)),
        )
        .opacity;
  }

  group('导出明细页交互', () {
    testWidgets('默认态：当前账本选中、全选勾选、日期行置灰、导出可用', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 页面标题
      expect(find.text('导出明细'), findsOneWidget);
      // 账本下拉默认选中当前账本（ID=1 → 默认账本）
      expect(find.text('默认账本'), findsOneWidget, reason: '下拉应默认选中当前账本');
      // 全选数据默认勾选
      final checkbox =
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
      expect(checkbox.value, isTrue, reason: '全选数据应默认勾选');
      // 日期行展示且置灰不可用
      expect(find.text('开始日期'), findsOneWidget);
      expect(find.text('结束日期'), findsOneWidget);
      expect(dateRowOpacity(tester, '开始日期'), 0.5, reason: '全选勾选时开始日期行应置灰');
      expect(dateRowOpacity(tester, '结束日期'), 0.5, reason: '全选勾选时结束日期行应置灰');
      // 全选勾选时无非法区间，导出按钮可用
      final exportButton =
          tester.widget<FilledButton>(find.byType(FilledButton));
      expect(exportButton.onPressed, isNotNull, reason: '默认态导出按钮应可用');
    });

    testWidgets('取消全选后日期行恢复可用，重新勾选再次置灰', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 取消勾选全选数据
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(dateRowOpacity(tester, '开始日期'), 1.0, reason: '取消全选后日期行应恢复可用');
      expect(dateRowOpacity(tester, '结束日期'), 1.0);

      // 重新勾选
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(dateRowOpacity(tester, '开始日期'), 0.5, reason: '重新勾选后日期行应再次置灰');
      expect(dateRowOpacity(tester, '结束日期'), 0.5);
    });

    testWidgets('非法区间：开始日期晚于结束日期时提示且导出禁用', (tester) async {
      await tester.pumpWidget(buildApp(
        initialStartDate: DateTime(2026, 7, 10),
        initialEndDate: DateTime(2026, 7, 1),
      ));
      await prime(tester);

      // 全选勾选时不参与校验：无提示、按钮可用
      expect(find.text('开始日期不能晚于结束日期'), findsNothing);

      // 取消全选后非法区间生效
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(find.text('开始日期不能晚于结束日期'), findsOneWidget);
      final exportButton =
          tester.widget<FilledButton>(find.byType(FilledButton));
      expect(exportButton.onPressed, isNull, reason: '非法区间时导出按钮应禁用');
    });

    testWidgets('取消全选后合法区间的导出按钮可用', (tester) async {
      await tester.pumpWidget(buildApp(
        initialStartDate: DateTime(2026, 7, 1),
        initialEndDate: DateTime(2026, 7, 10),
      ));
      await prime(tester);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(find.text('开始日期不能晚于结束日期'), findsNothing);
      final exportButton =
          tester.widget<FilledButton>(find.byType(FilledButton));
      expect(exportButton.onPressed, isNotNull, reason: '合法区间时导出按钮应可用');
    });

    testWidgets('点击日期行拉起年-月-日滚轮选择器', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 全选勾选时点击日期行不应拉起选择器（置灰不可用）
      await tester.tap(find.text('开始日期'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('选择日期'), findsNothing, reason: '置灰时点击不应拉起日期选择器');

      // 取消全选后点击开始日期行 → 拉起滚轮选择器
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('开始日期'));
      await tester.pumpAndSettle();
      // 滚轮选择器底部弹层出现：标题为「选择日期」，确认按钮为「完成」。
      // 组件仅提供单一确认按钮（取消靠点遮罩/系统返回），无独立「取消」按钮。
      expect(find.text('选择日期'), findsOneWidget,
          reason: '应拉起标题为「选择日期」的滚轮选择器');
      expect(find.text('完成'), findsOneWidget,
          reason: '滚轮选择器应提供确认按钮「完成」');

      // 点击确认按钮关闭弹层（确认后回显 YYYY-MM-DD）
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(find.text('完成'), findsNothing, reason: '点击确认后弹层应关闭');
    });

    testWidgets('账本下拉可切换导出账本', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 点开下拉
      await tester.tap(find.text('默认账本'));
      await tester.pumpAndSettle();
      // 菜单中包含两个账本选项（按钮本身 1 处 + 菜单项 2 处，「默认账本」共 2 处）
      expect(find.text('测试账本'), findsOneWidget);

      // 选择「测试账本」
      await tester.tap(find.text('测试账本').last);
      await tester.pumpAndSettle();
      expect(find.text('测试账本'), findsOneWidget, reason: '下拉应切换为所选账本');
      expect(find.text('默认账本'), findsNothing);
    });
  });

  group('buildDetailExportRange 单元测试', () {
    test('起始日归零、结束日取 23:59:59', () {
      final range = buildDetailExportRange(
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 31),
      );
      expect(range.start, DateTime(2026, 7, 1, 0, 0, 0));
      expect(range.end, DateTime(2026, 7, 31, 23, 59, 59));
    });

    test('起止同日：覆盖当日全天', () {
      final range = buildDetailExportRange(
        DateTime(2026, 7, 15),
        DateTime(2026, 7, 15),
      );
      expect(range.start, DateTime(2026, 7, 15, 0, 0, 0));
      expect(range.end, DateTime(2026, 7, 15, 23, 59, 59));
    });

    test('跨年区间：结束日归属次年', () {
      final range = buildDetailExportRange(
        DateTime(2025, 12, 31),
        DateTime(2026, 1, 1),
      );
      expect(range.start, DateTime(2025, 12, 31, 0, 0, 0));
      expect(range.end, DateTime(2026, 1, 1, 23, 59, 59));
    });

    test('传入含时分秒的日期也会被归一化', () {
      final range = buildDetailExportRange(
        DateTime(2026, 7, 1, 13, 45, 30),
        DateTime(2026, 7, 2, 8, 0, 0),
      );
      expect(range.start, DateTime(2026, 7, 1, 0, 0, 0));
      expect(range.end, DateTime(2026, 7, 2, 23, 59, 59));
    });
  });
}
