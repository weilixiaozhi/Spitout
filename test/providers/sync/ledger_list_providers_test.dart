// localLedgersProvider 纯 provider 测试：账本列表组装、统计缺省、异常回落空列表。
// repository 用 mocktail 替身，避免依赖真实数据库。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/models.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/sync/ledger_list_providers.dart';

class _MockRepo extends Mock implements LocalRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = _MockRepo();
    when(() => repo.getAllLedgerStats()).thenAnswer((_) async => {});
  });

  Ledger ledger(int id, {String storageMode = 'local'}) => Ledger(
    id: id,
    name: '账本$id',
    currency: 'CNY',
    type: 'personal',
    createdAt: DateTime(2026, 1, 1),
    myRole: 'owner',
    memberCount: 1,
    isShared: false,
    monthStartDay: 1,
    storageMode: storageMode,
    aaEnabled: false,
  );

  test('组装账本列表并挂载统计', () async {
    when(() => repo.getAllLedgers()).thenAnswer(
      (_) async => [ledger(1), ledger(2, storageMode: 'cloud')],
    );
    when(() => repo.getAllLedgerStats()).thenAnswer(
      (_) async => {
        1: (expenseTotal: 100.5, transactionCount: 3),
      },
    );

    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final items = await container.read(localLedgersProvider.future);
    expect(items, hasLength(2));
    expect(items[0].id, 1);
    expect(items[0].expenseTotal, 100.5);
    expect(items[0].transactionCount, 3);
    expect(items[0].storageMode, 'local');
    // 无统计的账本回落 0
    expect(items[1].expenseTotal, 0);
    expect(items[1].transactionCount, 0);
    expect(items[1].storageMode, 'cloud');
  });

  test('repository 抛错回落空列表并记日志', () async {
    when(() => repo.getAllLedgers()).thenThrow(Exception('db boom'));

    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final items = await container.read(localLedgersProvider.future);
    expect(items, isEmpty);
  });
}
