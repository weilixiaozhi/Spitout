/// memberAvatarStorage（lib/core/storage/member_avatar_storage.dart）单元测试。
///
/// 验证点：
/// 1. 按 userId + 版本号命中缓存：版本一致返回路径，不一致返回 null。
/// 2. 文件丢失时自愈（清除失效登记并返回 null）。
/// 3. save / remove 的完整读写与幂等删除。
///
/// 测试手段：method channel mock 掉 path_provider 的
/// getApplicationDocumentsDirectory 指向临时目录，
/// SharedPreferences 使用官方 mock 内存实现。
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_isolation.dart';
import 'package:spitout/core/storage/member_avatar_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('member_avatar_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return tempDir.path;
          }
          return null;
        });
    resetGlobalTestState();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('getPath 版本命中', () {
    test('保存后版本一致返回路径，版本不一致返回 null', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final path = await memberAvatarStorage.save(
        userId: 'user-1',
        version: 7,
        bytes: bytes,
      );

      expect(
        p.normalize(
          (await memberAvatarStorage.getPath(userId: 'user-1', version: 7))!,
        ),
        p.normalize(path),
      );
      expect(
        await memberAvatarStorage.getPath(userId: 'user-1', version: 8),
        isNull,
        reason: '版本不一致视为新头像，不应命中旧缓存',
      );
    });

    test('文件被外部删除时清除登记并返回 null', () async {
      final path = await memberAvatarStorage.save(
        userId: 'user-1',
        version: 1,
        bytes: Uint8List.fromList([9]),
      );
      await File(path).delete();

      expect(
        await memberAvatarStorage.getPath(userId: 'user-1', version: 1),
        isNull,
        reason: '文件丢失后应自愈清除登记',
      );
    });
  });

  group('remove 幂等清理', () {
    test('删除文件并清除路径与版本登记', () async {
      final path = await memberAvatarStorage.save(
        userId: 'user-1',
        version: 3,
        bytes: Uint8List.fromList([5, 6]),
      );
      expect(await File(path).exists(), isTrue);

      await memberAvatarStorage.remove('user-1');

      expect(await File(path).exists(), isFalse, reason: '头像文件应被删除');
      expect(
        await memberAvatarStorage.getPath(userId: 'user-1', version: 3),
        isNull,
      );
    });

    test('无缓存时调用不抛异常（幂等）', () async {
      await memberAvatarStorage.remove('user-1');
      expect(
        await memberAvatarStorage.getPath(userId: 'user-1', version: 1),
        isNull,
      );
    });
  });
}
