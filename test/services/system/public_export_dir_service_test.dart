// 公共导出目录服务：非 Android 平台返回 null（由调用方走各自平台分支）。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/services/system/public_export_dir_service.dart';

void main() {
  test('非 Android 平台 resolve 返回 null', () async {
    if (Platform.isAndroid) return;
    final service = const PublicExportDirService();
    expect(await service.resolve(), isNull);
    expect(await service.resolve(subDir: 'backup'), isNull);
  });
}
