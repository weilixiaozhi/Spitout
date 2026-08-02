/// Spitout Cloud adapter 包的测试基建入口。
///
/// 仿 `package:http/testing.dart` 模式:将测试替身(FakeSpitoutCloudProvider)
/// 作为包内正式 testing 入口随包分发,保证任何消费方拿到本包即可独立跑测,
/// 无需依赖宿主工程的 test/ 目录。
///
/// 用法:
/// ```dart
/// import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';
///
/// final fake = FakeSpitoutCloudProvider();
/// ```
library;

export 'src/testing/fake_spitout_cloud_provider.dart';
