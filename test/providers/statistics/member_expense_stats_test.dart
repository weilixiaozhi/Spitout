/// memberExpenseStatsProvider 金额单位单测。
///
/// 锁定行为：数据库金额为「整数分」，provider 输出前必须 /100 转「元」，
/// 与 AaStatisticsService / 账本卡片口径一致——否则 UI 直接展示会放大 100 倍。
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/core/local_self_id_providers.dart';
import 'package:spitout/providers/statistics/aa_statistics_providers.dart';
import 'package:spitout/providers/sync/cloud_client_providers.dart';
import 'package:spitout/providers/ui/avatar_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await repo.createLedger(
      name: '测试账本',
      storageMode: 'local',
      ownerUserId: 'u1',
      aaEnabled: true,
    );
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      spitoutCloudProviderInstance.overrideWith((ref) async => null),
      avatarPathProvider.overrideWith((ref) async => null),
      localSelfIdProvider.overrideWith((ref) async => 'local-self'),
    ]);
    addTearDown(container.dispose);
  });

  tearDown(() async => db.close());

  Future<void> seedExpense({
    required int amountCents,
    required String paidByUserId,
  }) {
    return db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: amountCents,
            happenedAt: Value(DateTime(2026, 8, 3, 12, 0)),
            paidByUserId: Value(paidByUserId),
          ),
        );
  }

  test('成员支出金额按「元」输出（数据库整数分 /100）', () async {
    // u1: 1000 分 + 2500 分 = 35 元；u2: 500 分 = 5 元。
    await seedExpense(amountCents: 1000, paidByUserId: 'u1');
    await seedExpense(amountCents: 2500, paidByUserId: 'u1');
    await seedExpense(amountCents: 500, paidByUserId: 'u2');

    final stats = await container.read(memberExpenseStatsProvider(1).future);

    final u1 = stats.firstWhere((s) => s.participantId == 'u1');
    expect(u1.expenseTotal, 35.0,
        reason: '必须输出元而非整数分，否则 UI 展示放大 100 倍');
    expect(u1.txCount, 2);

    final u2 = stats.firstWhere((s) => s.participantId == 'u2');
    expect(u2.expenseTotal, 5.0);
    expect(u2.txCount, 1);
  });
}
