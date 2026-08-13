// DetailExportService 分支补充测试。
//
// 锚点：
//   - 全局仅支出模式下类型仍按枚举映射，未知类型兜底返回原始值；
//   - dateRange 非空时按闭区间过滤交易；
//   - 二级分类：分类列填一级分类名、二级分类列填子分类名；
//   - 无分类交易导出空分类列。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/services/export/detail_export_service.dart';

class _MockRepo extends Mock implements LocalRepository {}

Transaction _tx(
  int id, {
  String type = 'expense',
  DateTime? happenedAt,
  int? categoryId,
  String? note,
}) =>
    Transaction(
      id: id,
      ledgerId: 1,
      type: type,
      amount: 1000,
      categoryId: categoryId,
      happenedAt: happenedAt ?? DateTime(2026, 8, 5, 10, 30),
      note: note,
      recurringId: null,
      syncId: 'tx-$id',
      createdByUserId: null,
      lastEditedByUserId: null,
      categorySyncIdOverride: null,
      excludeFromStats: false,
      currencyCode: null,
      nativeAmount: null,
      version: 1,
      lastEditedAt: null,
      paidByUserId: null,
      aaMode: null,
      aaParticipants: null,
      aaSplits: null,
    );

Category _cat(int id, String name, {int? parentId, int level = 1}) =>
    Category(
      id: id,
      name: name,
      kind: 'expense',
      icon: null,
      sortOrder: 0,
      parentId: parentId,
      level: level,
      syncId: 'cat-$id',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return ctx;
  }

  Future<String> exportCsv(
    WidgetTester tester,
    BuildContext ctx, {
    required List<({Transaction t, Category? category})> rows,
    DateTimeRange? dateRange,
    List<Category> topCategories = const [],
    List<Category> subCategories = const [],
  }) async {
    when(
      () => repo.transactionsWithCategoryAll(ledgerId: any(named: 'ledgerId')),
    ).thenAnswer((_) async => rows);
    when(() => repo.getLedgerById(any())).thenAnswer((_) async => null);
    when(() => repo.getTopLevelCategories(any()))
        .thenAnswer((_) async => topCategories);
    when(() => repo.getSubCategories(any()))
        .thenAnswer((_) async => subCategories);

    final outputDir = Directory.systemTemp.createTempSync('spitout_detail_ext');
    addTearDown(() {
      if (outputDir.existsSync()) outputDir.deleteSync(recursive: true);
    });
    await tester.runAsync(
      () => exportDetailCsv(
        context: ctx,
        repo: repo,
        ledgerId: 1,
        dateRange: dateRange,
        onProgress: (_) {},
        outputDirOverride: outputDir,
      ),
    );
    final file = outputDir
        .listSync()
        .whereType<File>()
        .firstWhere((f) => f.path.contains('spitout_'));
    return (await tester.runAsync(() => file.readAsString()))!;
  }

  testWidgets('未知类型兜底返回原始值；dateRange 闭区间过滤', (tester) async {
    final ctx = await pumpContext(tester);
    final content = await exportCsv(
      tester,
      ctx,
      rows: [
        (t: _tx(1, type: 'transfer', happenedAt: DateTime(2026, 8, 5)), category: null),
        (t: _tx(2, happenedAt: DateTime(2026, 8, 20)), category: null),
      ],
      dateRange: DateTimeRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 10),
      ),
    );
    final lines = content.split('\n');
    expect(lines, hasLength(2), reason: '8/20 的交易应被过滤掉');
    expect(lines[1], contains('transfer'));
    expect(lines[1], isNot(contains('支出')));
  });

  testWidgets('二级分类导出：分类列=一级名、二级列=子分类名', (tester) async {
    final ctx = await pumpContext(tester);
    final parent = _cat(1, '餐饮');
    final child = _cat(2, '外卖', parentId: 1, level: 2);

    final content = await exportCsv(
      tester,
      ctx,
      rows: [
        (t: _tx(1, categoryId: 2), category: child),
      ],
      topCategories: [parent],
      subCategories: [child],
    );
    final dataColumns = content.split('\n')[1].split(',');
    expect(dataColumns[1], '餐饮');
    expect(dataColumns[2], '外卖');
  });

  testWidgets('无分类交易导出空分类列；有备注时原样保留', (tester) async {
    final ctx = await pumpContext(tester);
    final content = await exportCsv(
      tester,
      ctx,
      rows: [
        (t: _tx(1, note: '备注,含逗号'), category: null),
      ],
    );
    final dataColumns = content.split('\n')[1].split(',');
    expect(dataColumns[1], isEmpty);
    expect(dataColumns[2], isEmpty);
  });
}
