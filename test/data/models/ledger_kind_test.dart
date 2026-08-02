/// 刀0 测试：账本归属谓词统一出口的四象限 + null 边界。
///
/// 设计意图（为什么必须覆盖这些组合）：
/// 1. `isCloudLedgerOf` 用 `'cloud' || isShared` —— 共享账本
///    （isShared == true 但 storageMode 尚未修正为 'cloud'）也必须判为云账本，
///    否则会绕过同步闸门把别人的数据当本地数据留存；
/// 2. `isLocalLedgerOf` 用显式 `'local' && !isShared` 而非 `!isCloudLedgerOf`
///    取反 —— storageMode == null 的遗留账本（老数据字段未回填）不能被翻转
///    成本地账本，否则会改变其同步行为（隐性回归）；
/// 3. (null, false) 是四象限之外的第五种形态：两侧谓词都返回 false，
///    同步行为保持现状，这是"保守语义"。
///
/// 红测试说明：本测试对 `isCloudLedgerOf` / `isLocalLedgerOf` 传 `null`
/// storageMode，若实现签名是 `String`（非空）则编译失败；修复为
/// `String?` 后变绿。
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/models/ledger_kind.dart';
import 'package:spitout/data/db.dart';

void main() {
  group('isCloudLedgerOf（云端账本判定）', () {
    test('(cloud, 非共享) → true：标准云端账本', () {
      expect(isCloudLedgerOf('cloud', isShared: false), isTrue);
    });

    test('(local, 共享) → true：共享账本即使 storageMode 未修正也是云账本', () {
      // 历史数据里 isShared=true 但 storageMode 还停在 'local'，此时绝不能
      // 当本地账本处理（否则绕过同步闸门，共享数据被当纯本地留存）。
      expect(isCloudLedgerOf('local', isShared: true), isTrue);
    });

    test('(cloud, 共享) → true：云账本 + 共享自然成立', () {
      expect(isCloudLedgerOf('cloud', isShared: true), isTrue);
    });

    test('(local, 非共享) → false：纯本地账本', () {
      expect(isCloudLedgerOf('local', isShared: false), isFalse);
    });

    test('(null, 非共享) → false：遗留账本判为非云账本', () {
      expect(isCloudLedgerOf(null, isShared: false), isFalse);
    });

    test('(null, 共享) → true：遗留账本但 isShared 兜底成立', () {
      expect(isCloudLedgerOf(null, isShared: true), isTrue);
    });
  });

  group('isLocalLedgerOf（本地账本判定）', () {
    test('(local, 非共享) → true：标准本地账本', () {
      expect(isLocalLedgerOf('local', isShared: false), isTrue);
    });

    test('(local, 共享) → false：共享账本不是本地账本', () {
      expect(isLocalLedgerOf('local', isShared: true), isFalse);
    });

    test('(cloud, 非共享) → false：云账本不是本地账本', () {
      expect(isLocalLedgerOf('cloud', isShared: false), isFalse);
    });

    test('(null, 非共享) → false：遗留账本不被取反翻转成本地账本', () {
      // 这是 null 边界的核心：若实现用 `!isCloudLedgerOf(...)` 取反，
      // (null, false) 会翻转成 true，改变遗留账本的同步行为 → 隐性回归。
      expect(isLocalLedgerOf(null, isShared: false), isFalse);
    });

    test('(null, 共享) → false', () {
      expect(isLocalLedgerOf(null, isShared: true), isFalse);
    });
  });

  group('LedgerKindX extension（挂在 Drift 生成类上）', () {
    Future<Ledger> insertAndGet(
      SpitoutDatabase db, {
      required String name,
      String? storageMode,
      bool isShared = false,
    }) async {
      final id = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: name,
              storageMode: storageMode == null
                  ? const Value.absent()
                  : Value(storageMode),
              isShared: Value(isShared),
            ),
          );
      return (db.select(db.ledgers)..where((t) => t.id.equals(id))).getSingle();
    }

    test('storageMode=cloud 账本：isCloudLedger=true / isLocalLedger=false', () async {
      final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ledger =
          await insertAndGet(db, name: 'C', storageMode: 'cloud');
      expect(ledger.isCloudLedger, isTrue);
      expect(ledger.isLocalLedger, isFalse);
    });

    test('storageMode=local 非共享账本：isLocalLedger=true / isCloudLedger=false', () async {
      final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ledger =
          await insertAndGet(db, name: 'L', storageMode: 'local');
      expect(ledger.isLocalLedger, isTrue);
      expect(ledger.isCloudLedger, isFalse);
    });

    test('storageMode=local 共享账本：isCloudLedger=true（isShared 兜底）', () async {
      final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ledger = await insertAndGet(
        db,
        name: 'S',
        storageMode: 'local',
        isShared: true,
      );
      expect(ledger.isCloudLedger, isTrue,
          reason: '共享账本即使 storageMode 为 local 也按云账本处理');
      expect(ledger.isLocalLedger, isFalse);
    });
  });

  // SQL 工厂 vs Dart 谓词 的逐行等价性测试（机器化双保险）。
  //
  // 设计意图：序 3 把「归属判定」的 SQL 形态也收敛进 ledger_kind.dart，
  // 与 Dart 谓词同源。本组测试用内存库插满「storageMode × isShared」全部
  // 组合，分别用 Dart 谓词与 SQL 工厂过滤，逐行断言结果完全一致 —— 未来
  // 改规则只改一处，若两侧失同步测试立即变红。
  group('cloudLedgerFilter（SQL 工厂）与 isCloudLedgerOf 等价', () {
    /// 在内存库插入一行，返回其 Dart 谓词判定结果（golden 标杆）。
    Future<bool> judgeByDartPredicate(
      SpitoutDatabase db, {
      required String name,
      String? storageMode,
      bool isShared = false,
    }) async {
      final ledger = await insertRow(db,
          name: name, storageMode: storageMode, isShared: isShared);
      return isCloudLedgerOf(ledger.storageMode, isShared: ledger.isShared);
    }

    /// 同库重查：用 SQL 工厂过滤，按 (name, isShared) 唯一定位刚插入的行，
    /// 判断它是否被 cloudLedgerFilter 选中。多个 where 在 drift 中自动 AND。
    Future<bool> judgedBySqlFactory(
      SpitoutDatabase db, {
      required String name,
      required bool isShared,
    }) async {
      final hitRows = await (db.select(db.ledgers)
            ..where(cloudLedgerFilter)
            ..where((l) => l.name.equals(name))
            ..where((l) => l.isShared.equals(isShared)))
          .get();
      return hitRows.isNotEmpty;
    }

    Future<void> assertEquivalent({
      required SpitoutDatabase db,
      required String name,
      required String? storageMode,
      required bool isShared,
    }) async {
      final dartResult = await judgeByDartPredicate(
          db, name: name, storageMode: storageMode, isShared: isShared);
      final sqlResult = await judgedBySqlFactory(db, name: name, isShared: isShared);
      expect(sqlResult, dartResult,
          reason: 'SQL 工厂与 Dart 谓词对 ($storageMode,$isShared) 必须一致');
    }

    test('(cloud, 非共享) — 两侧均判为云端账本', () async {
      final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await assertEquivalent(db: db, name: 'c1', storageMode: 'cloud', isShared: false);
    });

    test('(local, 共享) — 共享兜底,两侧均判为云端账本', () async {
      final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await assertEquivalent(db: db, name: 'c2', storageMode: 'local', isShared: true);
    });

    test('(cloud, 共享) — 两侧均判为云端账本', () async {
      final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await assertEquivalent(db: db, name: 'c3', storageMode: 'cloud', isShared: true);
    });

    test('(local, 非共享) — 两侧均不判为云端账本', () async {
      final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await assertEquivalent(db: db, name: 'c4', storageMode: 'local', isShared: false);
    });

    test('(null, 非共享) 遗留账本 — 两侧均不判为云端账本', () async {
      final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await assertEquivalent(db: db, name: 'c5', storageMode: null, isShared: false);
    });

    test('(null, 共享) 遗留共享账本 — 两侧均判为云端账本', () async {
      final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await assertEquivalent(db: db, name: 'c6', storageMode: null, isShared: true);
    });
  });
}

/// 辅助：在内存库插入一行账本并返回其 Drift 行对象（供 SQL/Dart 双侧比对）。
Future<Ledger> insertRow(
  SpitoutDatabase db, {
  required String name,
  String? storageMode,
  bool isShared = false,
}) async {
  final id = await db.into(db.ledgers).insert(
        LedgersCompanion.insert(
          name: name,
          storageMode: storageMode == null
              ? const Value.absent()
              : Value(storageMode),
          isShared: Value(isShared),
        ),
      );
  return (db.select(db.ledgers)..where((t) => t.id.equals(id))).getSingle();
}
