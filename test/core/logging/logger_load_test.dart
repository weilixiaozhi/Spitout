// LoggerService 首次访问加载持久化日志路径测试。
//
// 单独文件的原因：LoggerService 是进程级单例，本文件所在 isolate 内首次访问
// 才会触发 _loadLogs；若与其它用例共用文件（setUp 先 clear 置 _isLoaded=true）
// 则加载分支永远不可达。
//
// 需求锚点：
//   1. 首次访问自动读取 prefs 中的历史日志并按时间合并；
//   2. 超 48h 的过期日志被过滤，损坏条目被跳过；
//   3. 加载完成后通知监听器。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/core/logging/logger_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('首次访问加载持久化日志并过滤过期/损坏条目', () async {
    final now = DateTime.now();
    final fresh = LogEntry(
      timestamp: now.subtract(const Duration(hours: 1)),
      level: LogLevel.info,
      platform: LogPlatform.android,
      tag: 'old',
      message: 'from prefs',
    );
    final expired = LogEntry(
      timestamp: now.subtract(const Duration(days: 3)),
      level: LogLevel.info,
      platform: LogPlatform.flutter,
      tag: 'stale',
      message: 'too old',
    );
    resetGlobalTestState(
      initialPrefs: {
        'app_logs': jsonEncode([
          fresh.toJson(),
          expired.toJson(),
          {'broken': true},
        ]),
      },
    );

    var notified = false;
    void markNotified() => notified = true;
    logger.addListener(markNotified);
    addTearDown(() => logger.removeListener(markNotified));

    // 首次访问触发异步加载。
    logger.logs;
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final logs = logger.logs;
    expect(logs.map((e) => e.tag), contains('old'),
        reason: '48h 内的持久化日志被加载');
    expect(logs.map((e) => e.tag), isNot(contains('stale')),
        reason: '超 48h 的日志被过滤');
    expect(notified, isTrue, reason: '加载完成后通知监听器刷新页面');

    await logger.clear();
  });
}
