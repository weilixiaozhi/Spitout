// import_export providers 门面测试。
//
// 需求锚点：
//   1. ImportProgress：empty 常量 / copyWith / isJustCompleted 语义；
//   2. importProgressProvider 默认 empty；
//   3. detectConfigContent 纯函数检测 YAML 内容。
//
// 说明：exportConfigToYaml / importConfigFromYaml 门面内部使用默认 CloudServiceStore
// （安全存储通道，测试环境不返回），完整链路已在 services/export/config_export_service_test
// 中通过注入明文 store 覆盖，此处不再触碰，避免测试挂起。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/providers/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ImportProgress 语义', () {
    expect(ImportProgress.empty.running, isFalse);
    expect(ImportProgress.empty.isJustCompleted, isFalse);

    final running = ImportProgress.empty.copyWith(
      running: true,
      total: 10,
      done: 3,
      ok: 2,
      fail: 1,
      skipped: 4,
      skippedTypes: const {'dup': 4},
    );
    expect(running.isJustCompleted, isFalse, reason: '运行中不算完成');

    final done = running.copyWith(running: false);
    expect(done.isJustCompleted, isTrue);
    expect(done.skipped, 4);
    expect(done.skippedTypes, {'dup': 4});
  });

  test('importProgressProvider 默认 empty', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(importProgressProvider), ImportProgress.empty);
  });

  test('detectConfigContent 识别 YAML 内容', () {
    const yaml = '''
ledgers:
  - name: L
categories: []
''';
    final content = detectConfigContent(yaml);
    expect(content.hasLedgers, isTrue);
  });
}
