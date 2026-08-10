// friendlyAuthError 分类测试：认证异常 → 用户友好文案的纯函数映射。
//
// 设计意图：集中式「类型判断式」分类（CloudAuthException 结构化 code →
// 网络层异常 → CloudAuthException 语义细分 → 字符串关键词兜底）。
// 本测试逐分支断言，防止未来调整顺序/关键词时静默改变 UI 文案。

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:spitout/cloud/auth_error_localizer.dart';
import 'package:spitout/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BuildContext ctx;
  late AppLocalizations l10n;

  Future<void> pumpContext(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    l10n = AppLocalizations.of(ctx);
  }

  group('friendlyAuthError', () {
    testWidgets('CloudAuthException 结构化 code 分支', (tester) async {
      await pumpContext(tester);

      expect(
        friendlyAuthError(
          CloudAuthException(
            'bad credentials',
            null,
            'invalid_credentials',
          ),
          ctx,
        ),
        l10n.authErrorInvalidCredentials,
      );
      expect(
        friendlyAuthError(
          CloudAuthException('unconfirmed', null, 'account_not_confirmed'),
          ctx,
        ),
        l10n.authErrorAccountNotConfirmed,
      );
      expect(
        friendlyAuthError(
          CloudAuthException(
            'too fast',
            null,
            'over_account_send_rate_limit',
          ),
          ctx,
        ),
        l10n.authErrorRateLimit,
      );
      // 未命中已知 code → 落到后续类型/关键词分支
      expect(
        friendlyAuthError(
          CloudAuthException('unknown code', null, 'some_new_code'),
          ctx,
        ),
        l10n.authErrorLoginFailed,
      );
    });

    testWidgets('网络层异常单独归类', (tester) async {
      await pumpContext(tester);

      expect(
        friendlyAuthError(const SocketException('no route'), ctx),
        l10n.authErrorNetworkIssue,
      );
      expect(
        friendlyAuthError(TimeoutException('timeout'), ctx),
        l10n.authErrorNetworkIssue,
      );
      expect(
        friendlyAuthError(http.ClientException('connection reset'), ctx),
        l10n.authErrorNetworkIssue,
      );
    });

    testWidgets('CloudAuthException 语义细分', (tester) async {
      await pumpContext(tester);

      expect(
        friendlyAuthError(
          CloudAuthException('Invalid account or password'),
          ctx,
        ),
        l10n.authErrorInvalidCredentials,
      );
      expect(
        friendlyAuthError(
          CloudAuthException('User not found'),
          ctx,
        ),
        l10n.authErrorInvalidCredentials,
      );
      expect(
        friendlyAuthError(
          CloudAuthException('Too many requests, rate limited'),
          ctx,
        ),
        l10n.authErrorRateLimit,
      );
      expect(
        friendlyAuthError(
          CloudAuthException('account is not confirmed'),
          ctx,
        ),
        l10n.authErrorAccountNotConfirmed,
      );
      expect(
        friendlyAuthError(CloudAuthException('something else'), ctx),
        l10n.authErrorLoginFailed,
      );
    });

    testWidgets('字符串关键词兜底 + 最终回落', (tester) async {
      await pumpContext(tester);

      expect(
        friendlyAuthError(Exception('account not confirmed'), ctx),
        l10n.authErrorAccountNotConfirmed,
      );
      expect(
        friendlyAuthError(Exception('invalid login credential'), ctx),
        l10n.authErrorInvalidCredentials,
      );
      expect(
        friendlyAuthError(Exception('rate limit exceeded'), ctx),
        l10n.authErrorRateLimit,
      );
      expect(
        friendlyAuthError(Exception('network timeout'), ctx),
        l10n.authErrorNetworkIssue,
      );
      expect(
        friendlyAuthError(Exception('未知错误'), ctx),
        l10n.authErrorLoginFailed,
      );
      expect(friendlyAuthError(null, ctx), l10n.authErrorLoginFailed);
    });
  });
}
