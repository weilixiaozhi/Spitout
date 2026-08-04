import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;

/// 全局测试配置：对 test/ 下所有测试生效。
///
/// 每个测试用例独立创建 SpitoutDatabase(in-memory)，drift 会对同一 isolate
/// 内「数据库类被多次实例化」告警；该告警针对生产场景的意外重复实例化，
/// 测试用例间本就不共享连接，属于误报，统一关闭。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await testMain();
}
