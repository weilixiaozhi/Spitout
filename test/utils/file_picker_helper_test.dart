// FilePickerHelper 封装测试（注入假 FilePicker，不触达平台通道）。
//
// 需求锚点（以行为为准）：
//   1. 带扩展名过滤的 pick 成功返回结果；
//   2. 设备抛 PlatformException 时 fallback 到任意文件选择；
//   3. 用户取消（null / 空文件列表）返回 null；
//   4. validateExtension=true 且扩展名不匹配时抛 FileExtensionException；
//   5. pickYamlFile / pickArchiveFile / pickSqliteFile 走对应扩展名。

import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart'
    show FilePickerPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/utils/file_picker_helper.dart';

/// 假 FilePickerPlatform：记录调用并按预设返回结果/抛错。
class _FakeFilePicker extends FilePickerPlatform {
  _FakeFilePicker() : super();

  FilePickerResult? customResult;
  Object? customError; // 自定义类型选择时的异常（模拟扩展名过滤不支持）
  FilePickerResult? anyResult;

  final customCalls = <List<String>>[];
  int anyCalls = 0;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    if (type == FileType.custom) {
      customCalls.add((allowedExtensions ?? []).toList());
      if (customError != null) throw customError!;
      return customResult;
    }
    anyCalls++;
    return anyResult;
  }
}

FilePickerResult resultWith(String path) =>
    FilePickerResult([PlatformFile(name: 'f', size: 0, path: path)]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeFilePicker fake;

  setUp(() {
    fake = _FakeFilePicker();
    FilePickerPlatform.instance = fake;
  });

  test('带扩展名过滤成功返回结果', () async {
    fake.customResult = resultWith('/tmp/config.yaml');
    final result = await FilePickerHelper.pickYamlFile();
    expect(result, isNotNull);
    expect(fake.customCalls.single, ['yml', 'yaml']);
  });

  test('扩展名过滤抛 PlatformException 时 fallback 到任意文件', () async {
    fake.customError = PlatformException(code: 'unsupported');
    fake.anyResult = resultWith('/tmp/config.yaml');

    final result = await FilePickerHelper.pickYamlFile();
    expect(result, isNotNull);
    expect(fake.anyCalls, 1, reason: '必须走一次 FileType.any fallback');
  });

  test('用户取消返回 null', () async {
    fake.customResult = null;
    expect(await FilePickerHelper.pickYamlFile(), isNull);

    fake.customResult = FilePickerResult([]);
    expect(await FilePickerHelper.pickYamlFile(), isNull);
  });

  test('扩展名不匹配抛 FileExtensionException', () async {
    fake.customResult = resultWith('/tmp/evil.exe');
    expect(
      FilePickerHelper.pickFileWithExtensions(allowedExtensions: ['yml']),
      throwsA(isA<FileExtensionException>()),
    );
  });

  test('pickSqliteFile 使用 sqlite 扩展名', () async {
    fake.customResult = resultWith('/tmp/db.sqlite');
    await FilePickerHelper.pickSqliteFile();
    expect(fake.customCalls.single, ['sqlite']);
  });
}
