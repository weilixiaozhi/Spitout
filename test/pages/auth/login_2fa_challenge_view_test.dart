// 2FA 输码对话框（Login2FAChallengeDialog）交互测试。
//
// 锚点（见 login_2fa_challenge_view.dart 头注释）：
//   - 失败 → 就地展示 server 错误信息并允许重试，绝不跳走/关闭；
//   - 成功 → 关闭对话框并 pop true；取消 → pop false；
//   - TOTP 仅接受 6 位数字；恢复码接受 >=6 位（可含连字符）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/spitout_cloud.dart'
    show TwoFactorChallengeRequest;
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/widgets/login_2fa_challenge_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<(String, String)> verifyCalls;
  String? Function(String method, String code) verifyImpl =
      (method, code) => null;

  TwoFactorChallengeRequest buildRequest({
    List<String> methods = const ['totp'],
  }) {
    return TwoFactorChallengeRequest(
      challengeToken: 'token-1',
      availableMethods: methods,
      account: 'a@example.com',
      verify: (method, code) async {
        verifyCalls.add((method, code));
        return verifyImpl(method, code);
      },
    );
  }

  setUp(() {
    verifyCalls = [];
    verifyImpl = (method, code) => null;
  });

  Future<bool? Function()> pumpDialog(
    WidgetTester tester, {
    List<String> methods = const ['totp'],
  }) async {
    bool? result;
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
                    result = await Login2FAChallengeDialog.show(
                      context,
                      buildRequest(methods: methods),
                    );
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
    return () => result;
  }

  testWidgets('TOTP 验证成功 → 关闭并返回 true', (tester) async {
    final result = await pumpDialog(tester);

    expect(find.text('二次验证'), findsOneWidget);
    expect(find.text('a@example.com'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '验证'));
    await tester.pumpAndSettle();

    expect(verifyCalls.single, ('totp', '123456'));
    expect(result(), isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('server 返回错误 → 就地展示并可重试', (tester) async {
    verifyImpl = (method, code) =>
        code == '123456' ? '动态码已失效，请重试' : null;
    final result = await pumpDialog(tester);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '验证'));
    await tester.pumpAndSettle();

    expect(find.text('动态码已失效，请重试'), findsOneWidget);
    expect(result(), isNull, reason: '失败绝不能关闭对话框');

    // 输入框已清空，可重新输入
    await tester.enterText(find.byType(TextField), '654321');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '验证'));
    await tester.pumpAndSettle();
    expect(result(), isTrue);
    expect(verifyCalls, hasLength(2));
  });

  testWidgets('verify 抛异常 → 展示异常文案', (tester) async {
    verifyImpl = (method, code) => throw Exception('network down');
    final result = await pumpDialog(tester);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '验证'));
    await tester.pumpAndSettle();

    expect(find.textContaining('network down'), findsOneWidget);
    expect(result(), isNull);
  });

  testWidgets('取消 → pop false', (tester) async {
    final result = await pumpDialog(tester);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result(), isFalse);
    expect(verifyCalls, isEmpty);
  });

  testWidgets('TOTP 不足 6 位时验证按钮禁用', (tester) async {
    await pumpDialog(tester);
    await tester.enterText(find.byType(TextField), '123');
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '验证'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('恢复码模式：切换方法、接受连字符、按 recovery_code 调 verify',
      (tester) async {
    final result = await pumpDialog(
      tester,
      methods: const ['totp', 'recovery_code'],
    );

    // 默认 TOTP；切到恢复码
    await tester.tap(find.text('恢复码'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ABCD-1234');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '验证'));
    await tester.pumpAndSettle();

    // 提交前只去空白，连字符原样交给 server（recovery code 语义由服务端解析）
    expect(verifyCalls.single, ('recovery_code', 'ABCD-1234'));
    expect(result(), isTrue);
  });

  testWidgets('仅提供恢复码方法时默认选中恢复码', (tester) async {
    await pumpDialog(tester, methods: const ['recovery_code']);
    expect(find.text('恢复码'), findsOneWidget);
    // 默认方法为恢复码：输入框占位符应为恢复码提示
    expect(find.text('输入恢复码'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'RECOVERY123');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '验证'));
    await tester.pumpAndSettle();
    expect(verifyCalls.single.$1, 'recovery_code');
  });
}
