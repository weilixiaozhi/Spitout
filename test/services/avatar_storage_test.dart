/// avatarStorage（lib/services/storage/avatar_storage.dart）单元测试。
///
/// 覆盖改动：AvatarService 拆分为 AvatarStorage(纯存储) + AvatarPicker(选取)
/// 后，存储行为测试迁移至 avatarStorage 单例。
///
/// 验证点：
/// 1. 相对路径读取的正常链路（拼接 Documents 目录、验证文件存在）。
/// 2. 文件丢失时的自愈行为（清除失效记录并返回 null）。
/// 3. 绝对路径不再被特殊提取迁移，而是按普通相对路径处理，找不到即清除。
/// 4. saveAvatarFromBytes / deleteAvatar / 远端版本号读写的完整行为。
///
/// 测试手段：method channel mock 掉 path_provider 的
/// getApplicationDocumentsDirectory 指向临时目录，
/// SharedPreferences 使用官方 mock 内存实现。
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_isolation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/services/storage/avatar_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // avatarStorage 内部的私有 key（测试侧硬编码以断言存储行为）。
  const avatarPathKey = 'user_avatar_path';
  const remoteVersionKey = 'user_avatar_remote_version';

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    // 每个用例独立的临时 Documents 目录，互不污染。
    tempDir = await Directory.systemTemp.createTemp('avatar_storage_test_');
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

  /// 在临时 Documents 目录下创建指定相对路径的文件。
  Future<File> createFile(String relativePath, List<int> bytes) async {
    final file = File(p.join(tempDir.path, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file;
  }

  group('getAvatarPath 相对路径读取', () {
    test('无记录时返回 null', () async {
      expect(await avatarStorage.getAvatarPath(), isNull);
    });

    test('相对路径且文件存在时返回拼接后的完整路径', () async {
      const relative = 'avatars/avatar_1.jpg';
      await createFile(relative, [1, 2, 3]);
      SharedPreferences.setMockInitialValues({avatarPathKey: relative});

      final result = await avatarStorage.getAvatarPath();
      expect(result, p.join(tempDir.path, relative));
    });

    test('相对路径但文件不存在时清除记录并返回 null', () async {
      SharedPreferences.setMockInitialValues(
          {avatarPathKey: 'avatars/not_exist.jpg'});

      final result = await avatarStorage.getAvatarPath();
      expect(result, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(avatarPathKey), isNull, reason: '失效记录应被清除');
    });
  });

  group('绝对路径按普通相对路径处理（回归保护）', () {
    test('绝对路径不再被提取迁移，按相对路径处理后清除', () async {
      // 场景：prefs 里存的是绝对路径（以 / 开头）。
      // 不会用 RegExp 提取 'avatars/avatar_9.jpg' 并迁移；
      // 即使该提取位置文件存在也不再迁移——拼接路径找不到即清除。
      await createFile('avatars/avatar_9.jpg', [9]);
      SharedPreferences.setMockInitialValues(
          {avatarPathKey: '/data/old/avatars/avatar_9.jpg'});

      final result = await avatarStorage.getAvatarPath();
      expect(result, isNull, reason: '绝对路径不应被迁移复用');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(avatarPathKey), isNull,
          reason: '旧绝对路径记录应被清除而非迁移');
    });
  });

  group('saveAvatarFromBytes', () {
    test('写入文件、保存相对路径并返回存在的路径', () async {
      final bytes = Uint8List.fromList([10, 20, 30]);
      final path = await avatarStorage.saveAvatarFromBytes(bytes);

      expect(path, isNotNull);
      expect(await File(path!).exists(), isTrue);
      expect(await File(path).readAsBytes(), bytes);

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(avatarPathKey);
      expect(saved, isNotNull);
      expect(saved, startsWith('avatars/avatar_'));
      expect(saved, endsWith('.jpg'));
      // 存的是相对路径而非绝对路径（iOS 更新后 UUID 变化也不失效）
      expect(saved!.startsWith('/'), isFalse);
      expect(saved.contains(tempDir.path), isFalse);
    });

    test('扩展名规范化：无点号自动补点', () async {
      final path = await avatarStorage.saveAvatarFromBytes(
          Uint8List.fromList([1]), extension: 'png');
      expect(path, isNotNull);
      expect(path, endsWith('.png'));
    });

    test('重复保存会替换旧头像内容', () async {
      await avatarStorage.saveAvatarFromBytes(Uint8List.fromList([1, 1, 1]));
      final newBytes = Uint8List.fromList([2, 2, 2]);
      final path = (await avatarStorage.saveAvatarFromBytes(newBytes))!;

      final current = (await avatarStorage.getAvatarPath())!;
      // getAvatarPath 用 p.join 保留段内分隔符，saveAvatarFromBytes 返回的是平台分隔符，
      // 归一化后再比较，避免 Windows 下 '\' 与 '/' 的误判。
      expect(p.normalize(current), p.normalize(path));
      expect(await File(current).readAsBytes(), newBytes);
    });
  });

  group('远端头像版本号读写', () {
    test('默认 0，写入后可读回，清除后归零', () async {
      expect(await avatarStorage.getStoredRemoteVersion(), 0);

      await avatarStorage.setStoredRemoteVersion(7);
      expect(await avatarStorage.getStoredRemoteVersion(), 7);

      await avatarStorage.clearStoredRemoteVersion();
      expect(await avatarStorage.getStoredRemoteVersion(), 0);
    });
  });

  group('deleteAvatar', () {
    test('删除头像文件并清除路径与版本号记录', () async {
      final bytes = Uint8List.fromList([5, 6, 7]);
      final path = await avatarStorage.saveAvatarFromBytes(bytes);
      await avatarStorage.setStoredRemoteVersion(3);
      expect(await File(path!).exists(), isTrue);

      await avatarStorage.deleteAvatar();

      expect(await File(path).exists(), isFalse, reason: '头像文件应被删除');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(avatarPathKey), isNull);
      expect(prefs.getInt(remoteVersionKey), isNull);
      expect(await avatarStorage.getAvatarPath(), isNull);
    });

    test('无头像时调用不抛异常（幂等）', () async {
      await avatarStorage.deleteAvatar();
      expect(await avatarStorage.getAvatarPath(), isNull);
    });
  });
}
