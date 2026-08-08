// 公共导出目录服务：非 Android 平台返回 null（由调用方走各自平台分支）。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/services/system/public_export_dir_service.dart';

void main() {
  final service = const PublicExportDirService();

  test('非 Android 平台 resolve 返回 null', () async {
    if (Platform.isAndroid) return;
    expect(await service.resolve(), isNull);
    expect(await service.resolve(subDir: 'backup'), isNull);
  });

  test('非 Android 平台 candidateDirs 为空、requestAccess 无副作用', () async {
    if (Platform.isAndroid) return;
    expect(await service.candidateDirs(), isEmpty);
    expect(await service.candidateDirs(subDir: 'backup'), isEmpty);
    await service.requestAccess();
  });

  test('非 Android 平台 hasAllFilesAccess 恒 false', () async {
    if (Platform.isAndroid) return;
    expect(await service.hasAllFilesAccess(), isFalse);
  });

  test('PublicExportDir 字段语义', () {
    final dir = PublicExportDir(
      dir: Directory('x'),
      displayPath: 'Download/Spitout',
      isPublicDownload: true,
    );
    expect(dir.dir.path, 'x');
    expect(dir.displayPath, 'Download/Spitout');
    expect(dir.isPublicDownload, isTrue);
  });
}
