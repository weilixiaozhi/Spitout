// 真实 SQLite 文件持久化测试（NativeDatabase + 磁盘文件，非 in-memory）。
//
// 设计意图：mock/in-memory 只能验证逻辑，无法覆盖「进程重启后状态恢复」这一真实
// 场景。本测试用真实临时文件验证：
//   1. 写入 → 关闭 → 重开（等价进程重启）→ 数据完整、schema 版本正确；
//   2. validateDatabaseSchema 校验当前 schema 与生成代码一致（防迁移漏配）；
//   3. 真实外键约束生效（违反引用完整性被拒绝）；
//   4. 同一文件双连接：A 写入关闭后，B 能读到完整数据（多进程/多连接恢复语义）。

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart'
    show VerifySelf;
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import '../helpers/test_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    resetGlobalTestState();
    tempDir = Directory.systemTemp.createTempSync('spitout_db_file_test');
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {
      // Windows 下句柄释放可能有延迟，忽略清理失败。
    }
  });

  late SpitoutDatabase db;

  Future<SpitoutDatabase> openDb(String name) async {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    final opened = SpitoutDatabase.forTesting(NativeDatabase(file));
    addTearDown(opened.close);
    return opened;
  }

  Future<void> seedData(SpitoutDatabase d) async {
    await d.into(d.ledgers).insert(
          LedgersCompanion.insert(
            name: '真实文件账本',
            syncId: const Value('ledger-file-1'),
            storageMode: const Value('cloud'),
          ),
        );
    await d.into(d.categories).insert(
          CategoriesCompanion.insert(
            name: '餐饮',
            kind: 'expense',
            syncId: const Value('cat-file-1'),
          ),
        );
    await d.into(d.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: 2500,
            syncId: const Value('tx-file-1'),
          ),
        );
  }

  test('写入 → 关闭 → 重开：数据完整 + schema 版本为 6', () async {
    db = await openDb('app.db');
    await seedData(db);
    // 显式关闭模拟进程退出
    await db.close();

    // 进程重启：重新打开同一文件
    db = await openDb('app.db');
    final ledgers = await (db.select(db.ledgers)).get();
    expect(ledgers, hasLength(1));
    expect(ledgers.first.name, '真实文件账本');
    expect(ledgers.first.syncId, 'ledger-file-1');

    final txs = await (db.select(db.transactions)).get();
    expect(txs, hasLength(1));
    expect(txs.first.amount, 2500);
    expect(txs.first.syncId, 'tx-file-1');

    // 生成代码期望的 schema 版本
    expect(db.schemaVersion, 6);
    // 磁盘上的 user_version 与生成代码一致（迁移链路的落盘证据）
    final version = await db.customSelect(
      'PRAGMA user_version',
      readsFrom: {db.ledgers},
    ).getSingle();
    expect(version.data.values.first, 6);
  });

  test('validateDatabaseSchema：磁盘 schema 与生成代码一致', () async {
    db = await openDb('app.db');
    await seedData(db);
    // drift 提供的运行时校验：逐表/列/约束比对，发现迁移漏配直接抛 SchemaMismatch。
    await db.validateDatabaseSchema();
  });

  test('真实外键约束生效：孤儿交易插入被拒绝', () async {
    db = await openDb('app.db');
    // 不存在的 ledgerId=999，外键应拒绝插入
    await expectLater(
      db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: 999,
              type: 'expense',
              amount: 100,
              syncId: const Value('tx-orphan'),
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('同一文件双连接：A 写入关闭后 B 能读到完整数据', () async {
    final dbA = await openDb('dual.db');
    await seedData(dbA);
    await dbA.close();

    final dbB = await openDb('dual.db');
    final repo = LocalRepository(dbB);
    final ledgers = await repo.getAllLedgers();
    expect(ledgers, hasLength(1));
    final txs = await (dbB.select(dbB.transactions)).get();
    expect(txs, hasLength(1));
    expect(txs.first.syncId, 'tx-file-1');
  });
}
