// 零碎 provider 补充测试。
//
// 覆盖：
//   - recordEditHistoryProvider：按 recordId 读取编辑历史；
//   - maintenance：analyticsTestDataSeederProvider / orphanScannerProvider 装配；
//   - public_export_dir_providers：动作函数在非 Android 宿主机上的安全行为
//     （resolve=null、request 空跑、showOldBackupLink=false）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/providers/providers.dart';

import '../helpers/test_isolation.dart';

class _MockRepo extends Mock implements BaseRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => resetGlobalTestState());

  test('recordEditHistoryProvider 按 recordId 返回历史列表', () async {
    final repo = _MockRepo();
    when(
      () => repo.getEditHistories(any()),
    ).thenAnswer((_) async => [
          RecordEditHistory(
            id: 2,
            recordId: 7,
            version: 2,
            operatorUserId: 'u1',
            summary: '改金额',
            createdAt: DateTime(2026, 8, 8),
          ),
        ]);
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final histories =
        await container.read(recordEditHistoryProvider(7).future);
    expect(histories.single.summary, '改金额');
    expect(histories.single.version, 2);
    verify(() => repo.getEditHistories(7)).called(1);
  });

  test('maintenance 基础 provider 装配成功', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // AnalyticsTestDataSeeder 与 OrphanScanner 均通过 repository/database
    // 注入，读取即验证装配无异常。
    expect(container.read(analyticsTestDataSeederProvider), isNotNull);
    expect(container.read(orphanScannerProvider), isNotNull);
    expect(container.read(orphanCleanerProvider), isNotNull);
    expect(container.read(sharedLedgerCategoryRepairProvider), isNotNull);
  });

  testWidgets('public_export_dir 动作函数在非 Android 宿主机安全空跑',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    late WidgetRef ref;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, r, _) {
            ref = r;
            return const Placeholder();
          },
        ),
      ),
    );

    // Windows 测试宿主机：无「公共 Download」语义。
    expect(container.read(showOldBackupLinkProvider), isFalse);
    await container.read(requestAllFilesAccessProvider)();
    expect(await container.read(allFilesAccessCheckerProvider)(), isFalse);

    // 动作函数本身不抛错（resolve 返回 null、request 空跑）
    expect(await resolveExportDir(ref), isNull);
    await requestPublicExportDirAccess(ref);
  });
}
