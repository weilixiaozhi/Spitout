// PIN 设置页（PinSetupPage）交互测试。
//
// 锚点：
//   - create 模式：输入新 PIN → 二次确认 → 一致才写入并开启锁屏；
//   - change 模式：先验证旧 PIN，通过后才能设置新 PIN；
//   - 两次输入不一致 → 进入错误态并回到「输入新 PIN」步骤，允许重试；
//   - 服务异常 → 展示失败 toast 且不允许进入下一状态。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/auth/pin_setup_page.dart';
import 'package:spitout/services/security/app_lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPinPage(
    WidgetTester tester, {
    PinSetupMode mode = PinSetupMode.create,
  }) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => PinSetupPage(mode: mode),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final ch in pin.split('')) {
      await tester.tap(find.text(ch));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('create：两次输入一致 → 写入 PIN、开启锁屏、成功返回', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var popped = false;
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => const PinSetupPage(),
                      ),
                    );
                    popped = result == true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('请设置新密码'), findsOneWidget);
    await enterPin(tester, '1234');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('请再次输入密码'), findsOneWidget);

    await enterPin(tester, '1234');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3)); // flush toast

    expect(popped, isTrue);
    expect(await AppLockService.isEnabled(), isTrue);
    expect(await AppLockService.verifyPin('1234'), isTrue);
  });

  testWidgets('create：两次输入不一致 → 错误态后回到输入新 PIN', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpPinPage(tester);

    await enterPin(tester, '1234');
    await tester.pump(const Duration(milliseconds: 100));
    await enterPin(tester, '5678');
    await tester.pump(const Duration(milliseconds: 100));

    // 500ms 错误展示后复位
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('请设置新密码'), findsOneWidget);
    expect(await AppLockService.isEnabled(), isFalse);
  });

  testWidgets('change：验证旧 PIN 通过后进入新 PIN 流程', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppLockService.setPin('0000');
    await pumpPinPage(tester, mode: PinSetupMode.change);

    expect(find.text('请输入当前密码'), findsOneWidget);
    await enterPin(tester, '0000');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('请设置新密码'), findsOneWidget);

    await enterPin(tester, '9999');
    await tester.pump(const Duration(milliseconds: 100));
    await enterPin(tester, '9999');
    await tester.pumpAndSettle();

    expect(await AppLockService.verifyPin('9999'), isTrue);
    expect(await AppLockService.verifyPin('0000'), isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('change：旧 PIN 错误 → 停留验证步骤且不进入下一步', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppLockService.setPin('0000');
    await pumpPinPage(tester, mode: PinSetupMode.change);

    await enterPin(tester, '1111');
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('请输入当前密码'), findsOneWidget);
    expect(find.text('请设置新密码'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });
}
