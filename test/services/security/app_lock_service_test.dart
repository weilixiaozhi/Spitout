// AppLockService 安全加固测试。
//
// 覆盖：
// - 新哈希为加盐 PBKDF2 格式（同 PIN 两次哈希不同，verify 仍可命中）；
// - 旧版无盐 SHA-256 存量哈希可验证并自动升级；
// - 连续输错达到阈值后进入锁定窗口，锁定期内正确 PIN 也拒绝。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/services/security/app_lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('hashPin 加盐：同 PIN 两次哈希不同，verifyPin 仍可验证', () async {
    await AppLockService.setPin('1234');
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_lock_pin_hash')!;
    expect(saved, startsWith('pbkdf2_sha256\$'));
    expect(saved, isNot(AppLockService.hashPin('1234')),
        reason: '每次设置应生成新盐，同 PIN 哈希不能相同');
    expect(await AppLockService.verifyPin('1234'), isTrue);
    expect(await AppLockService.verifyPin('0000'), isFalse);
  });

  test('旧版无盐 SHA-256 存量哈希可验证并自动升级', () async {
    // sha256("1234")
    const legacy = '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4';
    SharedPreferences.setMockInitialValues({
      'app_lock_pin_hash': legacy,
      'app_lock_enabled': true,
    });

    expect(await AppLockService.verifyPin('1234'), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('app_lock_pin_hash'),
      startsWith('pbkdf2_sha256\$'),
      reason: '验证成功后应把旧哈希升级为加盐 PBKDF2',
    );
  });

  test('连续输错 5 次后进入锁定窗口，锁定期内正确 PIN 也拒绝', () async {
    await AppLockService.setPin('1234');
    for (var i = 0; i < 5; i++) {
      expect(await AppLockService.verifyPin('0000'), isFalse);
    }

    expect(await AppLockService.isLocked(), isTrue);
    expect(await AppLockService.verifyPin('1234'), isFalse,
        reason: '锁定窗口内应拒绝任何输入');

    // 模拟锁定窗口结束（直接把持久化的截止时间改到过去）。
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'app_lock_locked_until',
      DateTime.now().millisecondsSinceEpoch - 1000,
    );
    expect(await AppLockService.isLocked(), isFalse);
    expect(await AppLockService.verifyPin('1234'), isTrue);
  });
}
