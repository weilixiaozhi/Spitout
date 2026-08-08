// 欢迎页（WelcomePage）交互流程测试。
//
// 锚点：
//   - 点击货币行即选中该币种；
//   - 「完成」= 保存币种偏好 → 播种默认账本+混合层级分类 → 选中默认账本 →
//     预加载首页数据 → 标记 welcome_shown，全部成功后才算完成；
//   - 「老用户？导入配置」入口常驻。
//
// 用 UncontrolledProviderScope + 手动 ProviderContainer（与
// settings_pages_test 同模式）：container 由测试显式 dispose 并 pump 掉
// drift stream 销毁时排队的 0s 定时器，避免 flutter_test 的 pending-timer
// 误报。
library;

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart'
    show FilePickerPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/cloud/sync/sync_service.dart' show LocalOnlySyncService;
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/auth/welcome_page.dart';
import 'package:spitout/providers/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        syncServiceProvider.overrideWith((ref) => LocalOnlySyncService()),
        autoSyncValueProvider.overrideWith((ref) async => false),
        spitoutCloudProviderInstance.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpWelcome(WidgetTester tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('zh');
    addTearDown(() {
      try {
        tester.binding.platformDispatcher.clearLocaleTestValue();
      } catch (_) {}
    });
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WelcomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 点「完成」后循环推进虚拟时钟，直到加载态结束（按钮恢复「完成」文本）。
  /// 不能用 pumpAndSettle：加载态的 CircularProgressIndicator 会无限动画。
  Future<void> finishAndWait(WidgetTester tester) async {
    await tester.tap(find.text('完成'));
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('完成').evaluate().isNotEmpty) break;
    }
    // flush LoggerService 保存定时器
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('点击货币行切换选中币种并随完成流程保存', (tester) async {
    await pumpWelcome(tester);

    final usdLabel = find.descendant(
      of: find.byKey(const Key('currencyListView')),
      matching: find.textContaining('(USD)'),
    );
    await tester.scrollUntilVisible(
      usdLabel,
      80,
      scrollable: find.descendant(
        of: find.byKey(const Key('currencyListView')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(
      find.ancestor(of: usdLabel, matching: find.byType(InkWell)),
    );
    await tester.pump();

    await finishAndWait(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_currency'), 'USD');
  });

  testWidgets('完成：种子账本+分类、选中默认账本、标记 welcome_shown', (tester) async {
    await pumpWelcome(tester);

    await finishAndWait(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('welcome_shown'), isTrue);
    expect(prefs.getString('selected_currency'), 'CNY');

    final repo = LocalRepository(db);
    expect(await repo.getAllLedgers(), isNotEmpty);
    expect(await repo.getAllCategories(), isNotEmpty);

    // 首页预加载已在本容器内完成
    expect(container.read(appInitStateProvider), AppInitState.ready);
  });

  testWidgets('老用户导入配置入口常驻', (tester) async {
    await pumpWelcome(tester);
    expect(find.textContaining('老用户？'), findsOneWidget);
    expect(find.textContaining('导入配置'), findsOneWidget);
  });

  testWidgets('导入配置：用户取消选择 → toast 未选择文件', (tester) async {
    final fake = _NullFilePicker();
    FilePickerPlatform.instance = fake;
    await pumpWelcome(tester);

    await tester.tap(find.textContaining('导入配置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('未选择文件'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3)); // flush toast
  });

  testWidgets('完成：seed 失败 → 弹错误对话框并停留在欢迎页', (tester) async {
    container.dispose();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        ensureSeedProvider.overrideWith(
          (ref) => ({AppLocalizations? l10n, String currency = 'CNY'}) async {
            throw StateError('seed boom');
          },
        ),
        syncServiceProvider.overrideWith((ref) => LocalOnlySyncService()),
        autoSyncValueProvider.overrideWith((ref) async => false),
        spitoutCloudProviderInstance.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    await pumpWelcome(tester);

    await finishAndWait(tester);

    expect(find.text('操作失败，请稍后重试'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('welcome_shown'), isNull,
        reason: '初始化失败绝不能标记完成，重启后仍走欢迎页');
  });
}

/// 用户取消文件选择的假 FilePicker。
class _NullFilePicker extends FilePickerPlatform {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async =>
      null;
}
