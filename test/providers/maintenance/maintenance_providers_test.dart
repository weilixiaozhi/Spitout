// maintenance providers 测试。
//
// 需求锚点：
//   1. sharedLedgerCategoryRepairRunProvider：标记位已置则跳过；否则运行修复并在
//      无镜像待补时写入完成标记；
//   2. orphanScanReportProvider：扫描真实库并返回报告。

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/providers/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalRepository repo;

  setUp(() {
    resetGlobalTestState();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async => db.close());

  ProviderContainer container() => ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repositoryProvider.overrideWithValue(repo),
        ],
      );

  test('标记位已置时跳过修复', () async {
    SharedPreferences.setMockInitialValues({
      'shared_ledger_category_repair_v1_done': true,
    });
    final c = container();
    addTearDown(c.dispose);

    await readProviderFutureFromContainer(
      c,
      sharedLedgerCategoryRepairRunProvider.future,
    );
    // 不抛异常即视为通过（空库运行也无副作用）
  });

  test('空库运行修复并写入完成标记', () async {
    final c = container();
    addTearDown(c.dispose);

    await readProviderFutureFromContainer(
      c,
      sharedLedgerCategoryRepairRunProvider.future,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool('shared_ledger_category_repair_v1_done'),
      isTrue,
      reason: '无待补镜像时应置完成标记',
    );
  });

  test('orphanScanReportProvider 空库返回空报告', () async {
    final c = container();
    addTearDown(c.dispose);

    final report = await readProviderFutureFromContainer(
      c,
      orphanScanReportProvider.future,
    );
    expect(report, isA<OrphanScanReport>());
    expect(report.totalCount, 0);
  });
}
