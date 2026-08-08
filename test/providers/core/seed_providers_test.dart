// ensureSeedProvider 门面测试。
//
// 需求锚点：通过 provider 门面调用 SeedService 播种默认分类，真实库中分类非空。

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/providers/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ensureSeedProvider 播种默认分类', () async {
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final ensureSeed = container.read(ensureSeedProvider);
    await ensureSeed(currency: 'CNY');

    final repo = LocalRepository(db);
    final categories = await repo.getAllCategories();
    expect(categories, isNotEmpty);
  });
}
