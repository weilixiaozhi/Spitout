// aa_statistics_providers 共享账本分支测试。
//
// 与 aa_statistics_providers_test（本地/单人账本分支）互补，锁定：
//   - aaParticipantOptionsProvider：共享账本从 ledgerMembersProvider 取
//     真实成员 + 虚拟用户，displayName 缺失时回落 account；
//   - aaStatisticsProvider：共享账本按成员表 + 虚拟用户组装参与人名册；
//   - aaMemberExpenseStatsProvider：共享账本成员头像/显示名映射；
//   - aaParticipantAvatarContextProvider：共享账本返回成员头像上下文。
library;

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/providers/providers.dart';

import '../../helpers/test_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    // 共享账本：syncId + AA 开启
    await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: '共享AA账本',
            syncId: d.Value('led-shared-aa'),
            isShared: d.Value(true),
            myRole: d.Value('editor'),
            aaEnabled: d.Value(true),
          ),
        );
    // 成员：一个 displayName 完整、一个缺失回落 account
    await db.into(db.ledgerMembers).insert(
          LedgerMembersCompanion.insert(
            ledgerSyncId: 'led-shared-aa',
            userId: 'u-owner',
            account: d.Value('owner@x.com'),
            displayName: d.Value('Owner'),
            role: 'owner',
            joinedAt: DateTime(2026, 8, 8),
            updatedAt: DateTime(2026, 8, 8),
          ),
        );
    await db.into(db.ledgerMembers).insert(
          LedgerMembersCompanion.insert(
            ledgerSyncId: 'led-shared-aa',
            userId: 'u-editor',
            account: d.Value('editor@x.com'),
            displayName: d.Value(''),
            role: 'editor',
            joinedAt: DateTime(2026, 8, 8),
            updatedAt: DateTime(2026, 8, 8),
          ),
        );
    // 虚拟用户
    await repo.create(ledgerId: 1, name: '室友A', syncId: 'vu-1');
    // AA 交易：支出人 u-owner
    await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 12000,
      happenedAt: DateTime(2026, 8, 8),
      paidByUserId: 'u-owner',
      aaMode: 0,
    );

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        spitoutCloudProviderInstance.overrideWith((ref) async => null),
        localSelfIdProvider.overrideWith((ref) async => 'local-self'),
        // 共享成员数据源：用内存 DB 的 ledger_members 表喂给 provider
        ledgerMembersProvider.overrideWith((ref, syncId) async {
          final rows = await (db.select(db.ledgerMembers)
                ..where((m) => m.ledgerSyncId.equals(syncId)))
              .get();
          return rows
              .map(
                (m) => SpitoutCloudLedgerMember(
                  userId: m.userId,
                  account: m.account ?? '',
                  role: m.role,
                  joinedAt: m.joinedAt,
                  isSelf: m.userId == 'u-owner',
                  displayName: m.displayName,
                ),
              )
              .toList();
        }),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async => db.close());

  test('aaParticipantOptionsProvider：共享账本成员 + 虚拟用户', () async {
    final options =
        await container.read(aaParticipantOptionsProvider(1).future);
    final byId = {for (final o in options) o.id: o};

    expect(byId['u-owner']?.name, 'Owner');
    expect(byId['u-editor']?.name, 'editor@x.com',
        reason: 'displayName 为空时回落 account');
    expect(byId['vu-1']?.name, '室友A');
    expect(byId['u-owner']?.isVirtual, isFalse);
    expect(byId['vu-1']?.isVirtual, isTrue);
    expect(byId['u-owner']?.isSelf, isTrue);
  });

  test('aaStatisticsProvider：共享账本统计包含成员与虚拟用户', () async {
    final stats = await container.read(aaStatisticsProvider(1).future);
    final ids = stats.participants.map((p) => p.participantId).toSet();
    expect(ids, containsAll(['u-owner', 'u-editor', 'vu-1']));
    final owner = stats.participants
        .firstWhere((p) => p.participantId == 'u-owner');
    expect(owner.totalPaid, 120.0);
    expect(owner.displayName, 'Owner');
  });

  test('aaMemberExpenseStatsProvider：成员头像/显示名映射', () async {
    final items =
        await container.read(memberExpenseStatsProvider(1).future);
    expect(items.single.participantId, 'u-owner');
    expect(items.single.displayName, 'Owner');
    expect(items.single.isSelf, isTrue);
  });

  test('aaParticipantAvatarContextProvider：共享账本返回成员上下文', () async {
    final ctx =
        await container.read(aaParticipantAvatarContextProvider(1).future);
    expect(ctx.members, contains('u-owner'));
    expect(ctx.members, contains('u-editor'));
  });
}
