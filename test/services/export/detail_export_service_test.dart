// 导出明细 CSV 服务测试。
//
// 重点契约：数据库金额为整数分，导出必须换算成“元”（库内 1250 分 → 12.50），
// 防止报销/对账时金额放大 100 倍。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/services/export/detail_export_service.dart';

class _MockRepo extends Mock implements BaseRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  testWidgets('导出金额 = 库内整数分 / 100，保留两位小数', (tester) async {
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

    final tx = Transaction(
      id: 1,
      ledgerId: 1,
      type: 'expense',
      amount: 1250, // 库内整数分 = 12.50 元
      categoryId: null,
      happenedAt: DateTime(2026, 8, 5, 10, 30),
      note: null,
      recurringId: null,
      syncId: 'tx-1',
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

    when(
      () => repo.transactionsWithCategoryAll(ledgerId: any(named: 'ledgerId')),
    ).thenAnswer((_) async => [(t: tx, category: null)]);
    when(() => repo.getLedgerById(any())).thenAnswer(
      (_) async => Ledger(
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
      ),
    );
    when(() => repo.getTopLevelCategories(any()))
        .thenAnswer((_) async => <Category>[]);

    final outputDir = Directory.systemTemp.createTempSync('spitout_export_test');
    addTearDown(() {
      if (outputDir.existsSync()) outputDir.deleteSync(recursive: true);
    });

    final result = (await tester.runAsync(
      () => exportDetailCsv(
        context: ctx,
        repo: repo,
        ledgerId: 1,
        onProgress: (_) {},
        outputDirOverride: outputDir,
      ),
    ))!;

    final file = outputDir
        .listSync()
        .whereType<File>()
        .firstWhere((f) => f.path.contains('spitout_'));
    final content = (await tester.runAsync(() => file.readAsString()))!;
    final lines = content.split('\n');
    expect(lines, hasLength(2));

    // 表头:类型,分类,二级分类,金额,币种,备注,时间
    final dataColumns = lines[1].split(',');
    expect(dataColumns, hasLength(7));
    expect(dataColumns[3], '12.50',
        reason: '库内 1250 分应导出为 12.50 元，而不是放大 100 倍');
    expect(content, isNot(contains('1250.00')));

    expect(result.path, isNotEmpty);
    expect(result.displayPath, isNotEmpty);
  });
}
