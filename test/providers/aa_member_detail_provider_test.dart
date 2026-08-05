/// 成员账单详情 Provider 单测（按支出人维度聚合）。
///
/// 需求锚点：
/// - 详情页展示「该成员作为支出人」的全部支出明细（含不分摊 aaMode=1，
///   收入交易不计入支出明细）；
/// - 人均 / 指定金额的分摊明细、本人应摊与账本级统计口径一致；
/// - 不分摊账单无分摊明细，整笔金额即本人支出；
/// - 虚拟用户、owner、协作者均可作为支出人进入查看；
/// - 无垫付账单的成员返回空账单列表而非报错。
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/statistics/aa_statistics_providers.dart';
import 'package:spitout/services/statistics/aa_member_detail_models.dart';
import 'package:spitout/services/statistics/aa_statistics_service.dart';

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

    // 固定参与人名册与本人标记（与分摊详情表同源），
    // 让本测试只聚焦「按支出人聚合」这一新增逻辑。
    final stats = AaLedgerStatistics(
      participants: [
        AaParticipantSummary(
          participantId: 'u1',
          displayName: '张三',
          totalPaid: 0,
          totalShouldPay: 0,
          isSelf: true,
        ),
        AaParticipantSummary(
          participantId: 'u2',
          displayName: '李四',
          totalPaid: 0,
          totalShouldPay: 0,
          isSelf: false,
        ),
        AaParticipantSummary(
          participantId: 'vu1',
          displayName: '室友A',
          totalPaid: 0,
          totalShouldPay: 0,
          isSelf: false,
        ),
      ],
      transfers: const [],
    );
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        aaStatisticsProvider.overrideWith((ref, ledgerId) async => stats),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async => db.close());

  /// 直接写库插入一笔交易（绕过 sync 登记，仅作数据源）。
  Future<int> seedTx({
    required int amountCents,
    String type = 'expense',
    String? paidByUserId,
    int? aaMode,
    String? aaParticipants,
    String? aaSplits,
    DateTime? happenedAt,
  }) {
    return db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            ledgerId: 1,
            type: type,
            amount: amountCents,
            happenedAt: Value(happenedAt ?? DateTime(2026, 8, 3, 12, 0)),
            paidByUserId: paidByUserId == null
                ? const Value.absent()
                : Value(paidByUserId),
            aaMode: aaMode == null ? const Value.absent() : Value(aaMode),
            aaParticipants: aaParticipants == null
                ? const Value.absent()
                : Value(aaParticipants),
            aaSplits: aaSplits == null ? const Value.absent() : Value(aaSplits),
          ),
        );
  }

  Future<AaMemberDetailData?> readDetail(String participantId) {
    return container.read(
      aaMemberDetailProvider((
        ledgerId: 1,
        participantId: participantId,
      )).future,
    );
  }

  test('按支出人维度聚合：返回该成员全部支出明细（含不分摊，排除收入）', () async {
    // 张三垫付的人均账单：10.00 / 3 人，floor 后余数归支出人 → 3.34/3.33/3.33。
    await seedTx(
      amountCents: 1000,
      paidByUserId: 'u1',
      aaMode: 0,
      aaParticipants: jsonEncode(['u1', 'u2', 'vu1']),
      happenedAt: DateTime(2026, 8, 3, 19, 15),
    );
    // 李四垫付的账单：不应出现在张三详情中。
    await seedTx(
      amountCents: 500,
      paidByUserId: 'u2',
      aaMode: 0,
      aaParticipants: jsonEncode(['u1', 'u2']),
      happenedAt: DateTime(2026, 8, 2, 12, 0),
    );
    // 不分摊：虽不进入 AA 统计，但属于该成员垫付的支出，必须纳入。
    await seedTx(
      amountCents: 700,
      paidByUserId: 'u1',
      aaMode: 1,
      happenedAt: DateTime(2026, 8, 1, 8, 0),
    );
    // 支出人未知：无法归属，不应出现。
    await seedTx(amountCents: 900, happenedAt: DateTime(2026, 7, 31, 8, 0));
    // 收入交易：不属于支出明细，不应出现。
    await seedTx(
      amountCents: 5000,
      type: 'income',
      paidByUserId: 'u1',
      happenedAt: DateTime(2026, 7, 28, 10, 0),
    );
    // 张三垫付的指定金额账单：8.00 = 张三 4.00 + 李四 4.00。
    await seedTx(
      amountCents: 800,
      paidByUserId: 'u1',
      aaMode: 2,
      aaSplits: jsonEncode({'u1': '4.00', 'u2': '4.00'}),
      happenedAt: DateTime(2026, 7, 30, 20, 0),
    );

    final data = await readDetail('u1');
    expect(data, isNotNull);
    expect(data!.ledgerName, '测试账本');
    expect(data.member.isSelf, isTrue);
    expect(data.bills, hasLength(3), reason: '张三垫付的两笔 AA 账单 + 一笔不分摊支出，收入不计入');

    // 最新在前：人均账单 → 不分摊账单 → 指定金额账单。
    final perPersonBill = data.bills[0];
    expect(perPersonBill.mode, AaMode.perPerson);
    expect(perPersonBill.totalAmount, 10.0);
    expect(
      perPersonBill.myShare,
      closeTo(3.34, 0.001),
      reason: '人均 floor 后余数归支出人',
    );
    expect(perPersonBill.payerName, '张三');
    expect(perPersonBill.splits, hasLength(3));
    expect(perPersonBill.splits[0].participantId, 'u1');
    expect(perPersonBill.splits[0].isSelf, isTrue);
    expect(perPersonBill.splits[1].displayName, '李四');
    expect(perPersonBill.splits[2].displayName, '室友A');
    expect(
      perPersonBill.splits.fold<double>(0, (s, it) => s + it.amount),
      closeTo(10.0, 0.001),
      reason: '分摊明细合计恒等于账单实付',
    );

    // 不分摊账单：无分摊明细，整笔金额即本人支出。
    final noSplitBill = data.bills[1];
    expect(noSplitBill.mode, AaMode.noSplit);
    expect(noSplitBill.totalAmount, 7.0);
    expect(noSplitBill.myShare, closeTo(7.0, 0.001));
    expect(noSplitBill.splits, isEmpty);
    expect(noSplitBill.payerName, '张三');

    final customBill = data.bills[2];
    expect(customBill.mode, AaMode.custom);
    expect(customBill.totalAmount, 8.0);
    expect(customBill.myShare, closeTo(4.0, 0.001));
    expect(customBill.splits, hasLength(2));
  });

  test('虚拟用户作为支出人可查看其账单详情', () async {
    await seedTx(
      amountCents: 300,
      paidByUserId: 'vu1',
      aaMode: 0,
      aaParticipants: jsonEncode(['u1', 'u2', 'vu1']),
    );

    final data = await readDetail('vu1');
    expect(data, isNotNull);
    expect(data!.bills, hasLength(1));
    expect(data.bills.single.payerName, '室友A');
    expect(data.bills.single.myShare, closeTo(1.0, 0.001));
    expect(data.bills.single.splits, hasLength(3));
  });

  test('无垫付账单的成员返回空账单列表而非报错', () async {
    await seedTx(
      amountCents: 500,
      paidByUserId: 'u1',
      aaMode: 0,
      aaParticipants: jsonEncode(['u1', 'u2']),
    );

    final data = await readDetail('u2');
    expect(data, isNotNull);
    expect(data!.member.displayName, '李四');
    expect(data.bills, isEmpty);
  });
}
