/// entity_serializer AA 字段序列化测试。
///
/// 覆盖:
/// - serializeTransaction: AA 字段"非空才发"守卫。
/// - serializeLedger: aaEnabled 始终下发(必同步)。
/// - serializeVirtualUser: 字段对齐 server projection。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:spitout/cloud/sync/entity_serializer.dart';
import 'package:spitout/data/db.dart';

void main() {
  group('serializeTransaction AA 字段(非空才发)', () {
    Transaction makeTx({
      String? paidByUserId,
      int? aaMode,
      String? aaParticipants,
      String? aaSplits,
    }) {
      return Transaction(
        id: 1,
        ledgerId: 1,
        type: 'expense',
        amount: 30.0,
        categoryId: null,
        happenedAt: DateTime(2026, 7, 1),
        note: null,
        recurringId: null,
        syncId: 'tx1',
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

    test('全空 → 不发 AA 键(向后兼容旧 server)', () {
      final m = EntitySerializer.serializeTransaction(makeTx());
      expect(m.containsKey('paidByUserId'), isFalse);
      expect(m.containsKey('aaMode'), isFalse);
      expect(m.containsKey('aaParticipants'), isFalse);
      expect(m.containsKey('aaSplits'), isFalse);
    });

    test('全有值 → 发全部 AA 键', () {
      final m = EntitySerializer.serializeTransaction(makeTx(
        paidByUserId: 'u1',
        aaMode: 2,
        aaParticipants: '["u1","u2"]',
        aaSplits: '{"u1":"15.00","u2":"15.00"}',
      ));
      expect(m['paidByUserId'], 'u1');
      expect(m['aaMode'], 2);
      expect(m['aaParticipants'], '["u1","u2"]');
      expect(m['aaSplits'], '{"u1":"15.00","u2":"15.00"}');
    });

    test('aaMode=0(人均)显式下发,null 不发', () {
      final m = EntitySerializer.serializeTransaction(makeTx(
        aaMode: 0,
        // paidByUserId=null 不发
      ));
      expect(m['aaMode'], 0);
      expect(m.containsKey('paidByUserId'), isFalse,
          reason: 'null 不发,缺键保护下 apply 端视为未启用');
    });

    test('空串 paidByUserId 不发(与空 null 同语义)', () {
      final m = EntitySerializer.serializeTransaction(makeTx(
        paidByUserId: '',
      ));
      expect(m.containsKey('paidByUserId'), isFalse,
          reason: '空串视为无值,不发');
    });
  });

  group('serializeLedger aaEnabled', () {
    Ledger makeLedger({required bool aaEnabled}) {
      return Ledger(
        id: 1,
        name: 'L',
        currency: 'CNY',
        type: 'personal',
        createdAt: DateTime(2026, 1, 1),
        syncId: 'L1',
        myRole: 'owner',
        memberCount: 1,
        isShared: false,
        ownerUserId: null,
        monthStartDay: 1,
        storageMode: 'cloud',
        aaEnabled: aaEnabled,
      );
    }

    test('aaEnabled=true 始终下发', () {
      final m = EntitySerializer.serializeLedger(makeLedger(aaEnabled: true));
      expect(m['aaEnabled'], true);
    });

    test('aaEnabled=false 始终下发(必同步,关闭后入口隐藏)', () {
      final m = EntitySerializer.serializeLedger(makeLedger(aaEnabled: false));
      expect(m['aaEnabled'], false);
    });
  });

  group('serializeVirtualUser', () {
    test('字段对齐 server projection(syncId + name)', () {
      final vu = LedgerVirtualUser(
        id: 1,
        ledgerId: 1,
        syncId: 'vu-uuid-1',
        name: '室友',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: null,
      );
      final m = EntitySerializer.serializeVirtualUser(vu);
      expect(m['syncId'], 'vu-uuid-1');
      expect(m['name'], '室友');
      // 不带 ledgerId:走 change log 外层,与 transaction 模式一致。
      expect(m.containsKey('ledgerId'), isFalse);
    });
  });
}
