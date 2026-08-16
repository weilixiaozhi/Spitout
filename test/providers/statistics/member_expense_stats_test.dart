/// memberExpenseStatsProvider 金额单位单测。
///
/// 锁定行为：数据库金额为「整数分」，provider 输出前必须 /100 转「元」，
/// 与 AaStatisticsService / 账本卡片口径一致——否则 UI 直接展示会放大 100 倍。
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/core/local_self_id_providers.dart';
import 'package:spitout/providers/core/read_provider_future.dart';
import 'package:spitout/providers/statistics/aa_statistics_providers.dart';
import 'package:spitout/providers/sync/cloud_client_providers.dart';
import 'package:spitout/providers/ui/avatar_providers.dart';
import 'package:spitout/providers/ui/theme_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;

  ProviderContainer buildContainer({
    CloudUser? cloudUser,
    String displayName = '',
  }) {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        spitoutCloudProviderInstance.overrideWith((ref) async => null),
        avatarPathProvider.overrideWith((ref) async => null),
        localSelfIdProvider.overrideWith((ref) async => 'local-self'),
        displayNameProvider.overrideWithBuild(
          (ref, notifier) => displayName,
        ),
        cloudCurrentUserProvider.overrideWith(
          (ref) => Stream<CloudUser?>.value(cloudUser),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await repo.createLedger(
      name: '测试账本',
      storageMode: 'local',
      ownerUserId: 'u1',
      aaEnabled: true,
    );
    container = buildContainer();
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

  test('多币种成员支出按折本位币 nativeAmount 汇总，不再累加原币金额', () async {
    // u1: 美元原币 5000 分（nativeAmount=7000 分）+ 人民币 1000 分
    // 期望按本位币合计 80 元，而不是原币 60 元。
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: 5000,
            currencyCode: Value('USD'),
            nativeAmount: Value(7000),
            happenedAt: Value(DateTime(2026, 8, 3, 12, 0)),
            paidByUserId: Value('u1'),
          ),
        );
    await seedExpense(amountCents: 1000, paidByUserId: 'u1');

    final stats = await container.read(memberExpenseStatsProvider(1).future);

    final u1 = stats.firstWhere((s) => s.participantId == 'u1');
    expect(u1.expenseTotal, 80.0,
        reason: '跨币种必须按折本位币求和，不得把美元原币当人民币直接累加');
    expect(u1.txCount, 2);
  });

  test('本地账本：localSelfId 与云 userId 都解析为本人昵称，不再裸 id', () async {
    final c = buildContainer(
      cloudUser: const CloudUser(id: 'cloud-1', account: 'me@example.com'),
      displayName: '我的昵称',
    );
    // 让云身份缓存首帧就绪，供 provider 内 ref.read 读取。
    await readProviderFutureFromContainer(c, cloudCurrentUserProvider.future);

    await seedExpense(amountCents: 1000, paidByUserId: 'local-self');
    await seedExpense(amountCents: 500, paidByUserId: 'cloud-1');

    final stats = await c.read(memberExpenseStatsProvider(1).future);
    expect(stats, hasLength(2));
    for (final s in stats) {
      expect(s.displayName, '我的昵称',
          reason: '两种本人 id 必须显示一致，不得出现裸 id');
      expect(s.isSelf, isTrue, reason: '两种本人 id 都必须标记为本人');
    }
  });

  test('本地账本：未知 id 不再套本地昵称，兜底原始 id', () async {
    final c = buildContainer(displayName: '我的昵称');
    await seedExpense(amountCents: 1000, paidByUserId: 'foreign-id');

    final stats = await c.read(memberExpenseStatsProvider(1).future);
    final row = stats.single;
    expect(row.participantId, 'foreign-id');
    expect(row.displayName, 'foreign-id',
        reason: '未知 id 不得张冠李戴成我的昵称');
    expect(row.isSelf, isFalse);
  });
}
