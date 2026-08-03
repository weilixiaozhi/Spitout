/// AA 分摊计算服务单测(文档 §九 测试计划 #4 分摊精度)。
///
/// 覆盖:
/// - 人均分摊:3 人 10.00 → 3.33/3.33/3.34,支出人实付差归支出人,总和恒等。
/// - 不分摊:跳过,不进入统计。
/// - 指定分摊:aaSplits 即最终应摊。
/// - 账本汇总:实付/应摊/净额 + 转账方案。
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/services/settlement/aa_settlement_service.dart';
import 'package:spitout/services/settlement/aa_decimal_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  group('aa_decimal_util', () {
    test('toDecimal2 规范 2 位小数', () {
      // Decimal.parse 会规范化尾随零('10.00' → '10'),用 toDouble 比较值。
      expect(toDouble(toDecimal2(10.0)), 10.0);
      expect(toDouble(toDecimal2(0.1 + 0.2)), 0.3,
          reason: '入口规范化避免浮点尾差');
    });

    test('splitEvenly: 3 人 10.00 余数归支出人,总和恒等', () {
      final total = toDecimal2(10.0);
      final splits = splitEvenly(
        total: total,
        participantCount: 3,
        payerIndex: 0, // 支出人 = 第 0 个
      );
      expect(splits, hasLength(3));
      // floor(1000/3) = 333 分 = 3.33;余数 1 分归支出人 → 3.34
      expect(toDouble(splits[0]).toStringAsFixed(2), '3.34');
      expect(toDouble(splits[1]).toStringAsFixed(2), '3.33');
      expect(toDouble(splits[2]).toStringAsFixed(2), '3.33');
      // 总和恒等
      final sum = toDouble(splits.fold(
          toDecimal2(0.0), (acc, v) => acc + v));
      expect(sum.toStringAsFixed(2), '10.00');
    });

    test('splitEvenly: 整除场景无余数', () {
      final total = toDecimal2(9.0);
      final splits = splitEvenly(
        total: total,
        participantCount: 3,
        payerIndex: 1,
      );
      // 9.00 / 3 = 3.00 整除,无余数
      for (final s in splits) {
        expect(toDouble(s).toStringAsFixed(2), '3.00');
      }
    });

    test('validateSplitsTotal: 合计校验', () {
      final total = toDecimal2(10.0);
      // 合计 10.00,校验通过
      final ok = [
        toDecimal2(3.34),
        toDecimal2(3.33),
        toDecimal2(3.33),
      ];
      expect(validateSplitsTotal(total: total, splits: ok), isTrue);
      // 合计 9.00,校验失败(超 0.01 容差)
      final bad = [
        toDecimal2(3.0),
        toDecimal2(3.0),
        toDecimal2(3.0),
      ];
      expect(validateSplitsTotal(total: total, splits: bad), isFalse);
    });
  });

  group('AaSettlementService.computeTx', () {
    late SpitoutDatabase db;

    setUp(() {
      db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async => db.close());

    /// 构造一条交易行(不写库,仅用 data class)。
    Transaction makeTx({
      required int id,
      double amount = 10.0,
      String? paidByUserId = 'u1',
      int? aaMode,
      String? aaParticipants,
      String? aaSplits,
      String? syncId = 'tx1',
    }) {
      return Transaction(
        id: id,
        ledgerId: 1,
        type: 'expense',
        amount: amount,
        categoryId: null,
        happenedAt: DateTime(2026, 7, 1),
        note: null,
        recurringId: null,
        syncId: syncId,
        createdByUserId: null,
        lastEditedByUserId: null,
        categorySyncIdOverride: null,
        excludeFromStats: false,
        currencyCode: null,
        nativeAmount: null,
        version: 1,
        lastEditedAt: null,
        paidByUserId: paidByUserId,
        aaMode: aaMode,
        aaParticipants: aaParticipants,
        aaSplits: aaSplits,
      );
    }

    test('人均: 3 人 10.00,支出人 u1 实付差归 u1', () {
      final tx = makeTx(
        id: 1,
        amount: 10.0,
        paidByUserId: 'u1',
        aaMode: 0, // 人均
        aaParticipants: jsonEncode(['u1', 'u2', 'u3']),
      );
      final result = AaSettlementService.computeTx(
        tx: tx,
        allParticipants: ['u1', 'u2', 'u3'],
      )!;
      expect(result.mode, AaMode.perPerson);
      expect(result.paidBy, 'u1');
      // u1 取余数 → 3.34;u2/u3 → 3.33
      expect(result.shares['u1']!.toStringAsFixed(2), '3.34');
      expect(result.shares['u2']!.toStringAsFixed(2), '3.33');
      expect(result.shares['u3']!.toStringAsFixed(2), '3.33');
      // 总和 == 实付
      final sum = result.shares.values.fold(0.0, (a, b) => a + b);
      expect(sum.toStringAsFixed(2), '10.00');
    });

    test('人均: aaParticipants 空 → 展开为账本全部成员', () {
      final tx = makeTx(
        id: 1,
        amount: 9.0,
        paidByUserId: 'u2',
        aaMode: null, // null 视为人均
        aaParticipants: null,
      );
      final result = AaSettlementService.computeTx(
        tx: tx,
        allParticipants: ['u1', 'u2', 'u3'],
      )!;
      // 9.00 / 3 = 3.00 整除
      expect(result.shares['u1']!.toStringAsFixed(2), '3.00');
      expect(result.shares['u2']!.toStringAsFixed(2), '3.00');
      expect(result.shares['u3']!.toStringAsFixed(2), '3.00');
    });

    test('不分摊(aaMode=1): 返回 null,不进入 AA 统计', () {
      final tx = makeTx(
        id: 1,
        aaMode: 1,
      );
      final result = AaSettlementService.computeTx(
        tx: tx,
        allParticipants: ['u1', 'u2'],
      );
      expect(result, isNull);
    });

    test('指定分摊: aaSplits 即最终应摊', () {
      final tx = makeTx(
        id: 1,
        amount: 10.0,
        paidByUserId: 'u1',
        aaMode: 2, // 指定
        aaParticipants: jsonEncode(['u1', 'u2']),
        aaSplits: jsonEncode({'u1': '6.00', 'u2': '4.00'}),
      );
      final result = AaSettlementService.computeTx(
        tx: tx,
        allParticipants: ['u1', 'u2'],
      )!;
      expect(result.mode, AaMode.custom);
      expect(result.shares['u1']!.toStringAsFixed(2), '6.00');
      expect(result.shares['u2']!.toStringAsFixed(2), '4.00');
    });

    test('指定分摊: aaSplits 为空 → 返回 null', () {
      final tx = makeTx(
        id: 1,
        aaMode: 2,
        aaSplits: null,
      );
      final result = AaSettlementService.computeTx(
        tx: tx,
        allParticipants: ['u1', 'u2'],
      );
      expect(result, isNull);
    });

    test('paidByUserId 为空 → 取参与人首个兜底', () {
      final tx = makeTx(
        id: 1,
        amount: 10.0,
        paidByUserId: null,
        aaMode: 0,
        aaParticipants: jsonEncode(['u1', 'u2']),
      );
      final result = AaSettlementService.computeTx(
        tx: tx,
        allParticipants: ['u1', 'u2'],
      )!;
      expect(result.paidBy, 'u1', reason: '空串降级取首个参与人');
    });
  });

  group('AaSettlementService.computeLedger', () {
    Transaction makeTx({
      required int id,
      required double amount,
      required String paidByUserId,
      int? aaMode,
      String? aaParticipants,
      String? aaSplits,
    }) {
      return Transaction(
        id: id,
        ledgerId: 1,
        type: 'expense',
        amount: amount,
        categoryId: null,
        happenedAt: DateTime(2026, 7, 1),
        note: null,
        recurringId: null,
        syncId: 'tx$id',
        createdByUserId: null,
        lastEditedByUserId: null,
        categorySyncIdOverride: null,
        excludeFromStats: false,
        currencyCode: null,
        nativeAmount: null,
        version: 1,
        lastEditedAt: null,
        paidByUserId: paidByUserId,
        aaMode: aaMode,
        aaParticipants: aaParticipants,
        aaSplits: aaSplits,
      );
    }

    test('汇总: u1 实付 10 人均 3 人 + u2 实付 6 人均 2 人,净额正确', () {
      final txs = [
        makeTx(
          id: 1,
          amount: 10.0,
          paidByUserId: 'u1',
          aaMode: 0,
          aaParticipants: jsonEncode(['u1', 'u2', 'u3']),
        ),
        makeTx(
          id: 2,
          amount: 6.0,
          paidByUserId: 'u2',
          aaMode: 0,
          aaParticipants: jsonEncode(['u1', 'u2']),
        ),
      ];
      final settlement = AaSettlementService.computeLedger(
        transactions: txs,
        allParticipants: ['u1', 'u2', 'u3'],
        displayNameMap: {'u1': 'Alice', 'u2': 'Bob', 'u3': 'Carol'},
      );

      // u1: 实付 10.00,应摊 = 3.34(tx1) + 3.00(tx2) = 6.34,净额 = 3.66
      final u1 = settlement.participants.firstWhere((p) => p.participantId == 'u1');
      expect(u1.totalPaid.toStringAsFixed(2), '10.00');
      expect(u1.totalShouldPay.toStringAsFixed(2), '6.34');
      expect(u1.net.toStringAsFixed(2), '3.66');

      // u2: 实付 6.00,应摊 = 3.33 + 3.00 = 6.33,净额 = -0.33
      final u2 = settlement.participants.firstWhere((p) => p.participantId == 'u2');
      expect(u2.totalPaid.toStringAsFixed(2), '6.00');
      expect(u2.totalShouldPay.toStringAsFixed(2), '6.33');
      expect(u2.net.toStringAsFixed(2), '-0.33');

      // u3: 实付 0,应摊 = 3.33,净额 = -3.33
      final u3 = settlement.participants.firstWhere((p) => p.participantId == 'u3');
      expect(u3.totalPaid.toStringAsFixed(2), '0.00');
      expect(u3.totalShouldPay.toStringAsFixed(2), '3.33');
      expect(u3.net.toStringAsFixed(2), '-3.33');
    });

    test('转账方案: 净额>0 与 <0 配对,贪心最小化笔数', () {
      final txs = [
        makeTx(
          id: 1,
          amount: 30.0,
          paidByUserId: 'u1',
          aaMode: 0,
          aaParticipants: jsonEncode(['u1', 'u2', 'u3']),
        ),
      ];
      final settlement = AaSettlementService.computeLedger(
        transactions: txs,
        allParticipants: ['u1', 'u2', 'u3'],
        displayNameMap: {'u1': 'Alice', 'u2': 'Bob', 'u3': 'Carol'},
      );

      // u1 实付 30,应摊 10,净额 +20
      // u2/u3 各应摊 10,净额 -10
      // 转账方案: u2→u1 10, u3→u1 10(2 笔)
      expect(settlement.transfers, hasLength(2));
      for (final t in settlement.transfers) {
        expect(t.to, 'u1', reason: '所有转账指向净额>0 的 u1');
        expect(t.amount.toStringAsFixed(2), '10.00');
      }
      final fromIds = settlement.transfers.map((t) => t.from).toSet();
      expect(fromIds, {'u2', 'u3'});
    });

    test('虚拟用户参与: syncId 作为参与人标识', () {
      final vuSyncId = 'vu-uuid-1';
      final txs = [
        makeTx(
          id: 1,
          amount: 10.0,
          paidByUserId: 'u1',
          aaMode: 0,
          aaParticipants: jsonEncode(['u1', vuSyncId]),
        ),
      ];
      final settlement = AaSettlementService.computeLedger(
        transactions: txs,
        allParticipants: ['u1', vuSyncId],
        displayNameMap: {'u1': 'Alice', vuSyncId: '室友'},
      );

      // u1 实付 10,应摊 5,净额 +5
      final u1 = settlement.participants.firstWhere((p) => p.participantId == 'u1');
      expect(u1.net.toStringAsFixed(2), '5.00');
      // 虚拟用户应摊 5,净额 -5
      final vu = settlement.participants.firstWhere((p) => p.participantId == vuSyncId);
      expect(vu.displayName, '室友');
      expect(vu.net.toStringAsFixed(2), '-5.00');
      // 转账: vu → u1 5.00
      expect(settlement.transfers, hasLength(1));
      expect(settlement.transfers.single.from, vuSyncId);
      expect(settlement.transfers.single.to, 'u1');
    });
  });
}
