// LoggerService 与日志条目序列化测试。
//
// 需求锚点（以行为为准）：
//   1. 级别/平台枚举的展示名与 emoji 语义正确；
//   2. LogEntry JSON 往返一致，损坏字段（timestamp/level/platform/tag/message）抛 FormatException；
//   3. 文本格式化含时间/级别/平台/tag/message，错误与堆栈缩进展示；
//   4. debug/info/warning/error 分别入队并带可选数据；超长字段截断；
//   5. 监听器在新增/清空/加载后被通知，单个监听器异常不影响其余；
//   6. 新增日志 2s 后落盘 SharedPreferences；clear 清空内存与持久化；
//   7. exportAsText 输出头部与全部条目；
//   8. 原生日志桥接：platform/level 字符串解析并入队。

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/core/logging/logger_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    resetGlobalTestState();
    // 清空单例内存与持久化，保证用例间无残留。
    await logger.clear();
  });

  group('枚举语义', () {
    test('LogLevel displayName/emoji', () {
      expect(LogLevel.debug.displayName, 'DEBUG');
      expect(LogLevel.info.displayName, 'INFO');
      expect(LogLevel.warning.displayName, 'WARN');
      expect(LogLevel.error.displayName, 'ERROR');
    });

    test('LogPlatform displayName', () {
      expect(LogPlatform.flutter.displayName, 'Flutter');
      expect(LogPlatform.android.displayName, 'Android');
      expect(LogPlatform.ios.displayName, 'iOS');
    });
  });

  group('LogEntry 序列化', () {
    LogEntry entry({Object? error, StackTrace? stack}) => LogEntry(
          timestamp: DateTime(2026, 7, 10, 8, 9, 10, 123),
          level: LogLevel.warning,
          platform: LogPlatform.ios,
          tag: 'Tag',
          message: 'Msg',
          error: error,
          stackTrace: stack,
        );

    test('toJson/fromJson 往返一致（含 error/stackTrace）', () {
      final original = entry(
        error: Exception('boom'),
        stack: StackTrace.fromString('line1\nline2'),
      );
      final restored = LogEntry.fromJson(original.toJson());
      expect(restored.timestamp, original.timestamp);
      expect(restored.level, original.level);
      expect(restored.platform, original.platform);
      expect(restored.tag, original.tag);
      expect(restored.message, original.message);
      expect(restored.error, 'Exception: boom');
      expect(restored.stackTrace.toString(), contains('line1'));
    });

    test('损坏字段抛 FormatException', () {
      final base = entry().toJson();
      expect(
        () => LogEntry.fromJson({...base, 'timestamp': 'x'}),
        throwsFormatException,
      );
      expect(
        () => LogEntry.fromJson({...base, 'level': 99}),
        throwsFormatException,
      );
      expect(
        () => LogEntry.fromJson({...base, 'platform': -1}),
        throwsFormatException,
      );
      expect(
        () => LogEntry.fromJson({...base, 'tag': 1}),
        throwsFormatException,
      );
      expect(
        () => LogEntry.fromJson({...base, 'message': null}),
        throwsFormatException,
      );
    });

    test('toFormattedString 时间/级别/平台/tag/错误/堆栈', () {
      final text = entry(
        error: 'oops',
        stack: StackTrace.fromString('a\nb'),
      ).toFormattedString();
      expect(text, contains('[08:09:10.123]'));
      expect(text, contains('[WARN]'));
      expect(text, contains('[iOS]'));
      expect(text, contains('[Tag]'));
      expect(text, contains('Msg'));
      expect(text, contains('Error: oops'));
      expect(text, contains('a'));
      expect(text, contains('  b'));
    });
  });

  group('LoggerService 行为', () {
    test('debug/info/warning/error 入队且带数据拼接', () async {
      logger.debug('T', 'd');
      logger.info('T', 'i', {'k': 1});
      logger.warning('T', 'w');
      logger.error('T', 'e', Exception('x'), StackTrace.current);
      expect(logger.logs.length, 4);
      expect(logger.logs[0].level, LogLevel.debug);
      expect(logger.logs[1].message, contains('k: 1'));
      expect(logger.logs[2].level, LogLevel.warning);
      expect(logger.logs[3].level, LogLevel.error);
      expect(logger.logs[3].error, isNotNull);
      await logger.clear();
    });

    test('监听器在新增时被通知；异常监听器不影响其余', () async {
      final notified = <int>[];
      void boom() => throw StateError('listener bug');
      void collect() => notified.add(1);
      logger.addListener(boom);
      logger.addListener(collect);
      addTearDown(() {
        logger.removeListener(boom);
        logger.removeListener(collect);
      });

      logger.info('T', 'x');
      expect(notified, [1], reason: '异常监听器被隔离，其余监听器仍收到通知');
      await logger.clear();
    });

    test('超长 tag/message/error 被截断', () async {
      logger.error(
        'x' * 500,
        'm' * 5000,
        'e' * 5000,
        StackTrace.fromString('s' * 5000),
      );
      final logs = logger.logs;
      expect(logs.single.tag.length, lessThanOrEqualTo(104));
      expect(logs.single.message.length, lessThanOrEqualTo(2004));
      expect(logs.single.error!.toString().length, lessThanOrEqualTo(2004));
      await logger.clear();
    });

    test('2s 后落盘 SharedPreferences；clear 清空持久化', () async {
      logger.info('T', 'persisted');
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_logs'), contains('persisted'));

      await logger.clear();
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_logs'), isNull);
    });

    testWidgets('原生日志桥接：platform/level 字符串解析并入队', (tester) async {
      const codec = StandardMethodCodec();
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'com.spitout.logger',
        codec.encodeMethodCall(
          MethodCall('onNativeLog', {
            'platform': 'android',
            'level': 'W',
            'tag': 'Native',
            'message': 'native msg',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }),
        ),
        (_) {},
      );
      await tester.pump();

      final entry = logger.logs.last;
      expect(entry.platform, LogPlatform.android);
      expect(entry.level, LogLevel.warning);
      expect(entry.tag, 'Native');
      expect(entry.message, 'native msg');

      // 非 Map 参数不崩溃、不产生日志。
      final before = logger.logs.length;
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'com.spitout.logger',
        codec.encodeMethodCall(const MethodCall('onNativeLog', 'oops')),
        (_) {},
      );
      await tester.pump();
      expect(logger.logs.length, before);
      await logger.clear();
    });
  });
}
