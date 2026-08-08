// FileReaderService 纯逻辑测试：编码探测、分块读取、进度回调与取消分支。
//
// 覆盖点：
//   - decodeBytes：UTF-16 LE/BE（带 BOM）、UTF-8（带/不带 BOM）、GBK、latin1 兜底
//   - readFile：bytes 入参（无 path）、真实文件流式读取（进度回调）、取消中断
//   - XLSX：converter 调用 / 缺失 converter 抛 ArgumentError
//   - 空文件 / 文件不存在返回空串
// 不依赖平台通道：纯 File IO + 内存字节，Windows 宿主可直接运行。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbk_codec/gbk_codec.dart';

import 'package:spitout/services/import/file_reader.dart';

PlatformFile _bytesFile(String name, List<int> bytes) => PlatformFile(
  name: name,
  size: bytes.length,
  bytes: Uint8List.fromList(bytes),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('decodeBytes 编码探测', () {
    test('UTF-8 无 BOM 直接解码', () {
      expect(
        FileReaderService.decodeBytes(utf8.encode('你好,world')),
        '你好,world',
      );
    });

    test('UTF-8 带 BOM 去掉 BOM 解码', () {
      final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('hello')];
      expect(FileReaderService.decodeBytes(bytes), 'hello');
    });

    test('UTF-16 LE 带 BOM 解码', () {
      final bytes = <int>[0xFF, 0xFE];
      for (final unit in '中文测试'.codeUnits) {
        bytes.add(unit & 0xFF);
        bytes.add((unit >> 8) & 0xFF);
      }
      expect(FileReaderService.decodeBytes(bytes), '中文测试');
    });

    test('UTF-16 BE 带 BOM 解码', () {
      final bytes = <int>[0xFE, 0xFF];
      for (final unit in '中文测试'.codeUnits) {
        bytes.add((unit >> 8) & 0xFF);
        bytes.add(unit & 0xFF);
      }
      expect(FileReaderService.decodeBytes(bytes), '中文测试');
    });

    test('GBK 解码命中中文字符', () {
      final bytes = gbk_bytes.encode('支付宝账单测试');
      expect(FileReaderService.decodeBytes(bytes), '支付宝账单测试');
    });

    test('非法 UTF-8 且非 GBK 时回落 allowMalformed UTF-8', () {
      final bytes = <int>[0xC3, 0x28]; // 非法 UTF-8 序列
      final text = FileReaderService.decodeBytes(bytes);
      expect(text, isNotEmpty);
    });

    test('合法 UTF-8 三字节中文按 UTF-8 解码', () {
      // 0xE4 0xBD 0xA0 是「你」的 UTF-8 编码，走 UTF-8 快速路径而非 latin1
      expect(FileReaderService.decodeBytes(<int>[0xE4, 0xBD, 0xA0]), '你');
    });
  });

  group('readFile bytes 入参', () {
    test('空字节返回空串', () async {
      final result = await FileReaderService.readFile(
        _bytesFile('empty.csv', []),
      );
      expect(result, isEmpty);
    });

    test('CSV UTF-8 内容直接解码', () async {
      final result = await FileReaderService.readFile(
        _bytesFile('a.csv', utf8.encode('金额,分类\n12.5,餐饮')),
      );
      expect(result, contains('餐饮'));
    });

    test('入口取消抛 FileReadCancelledException', () async {
      expect(
        () => FileReaderService.readFile(
          _bytesFile('a.csv', utf8.encode('x')),
          isCancelled: () => true,
        ),
        throwsA(isA<FileReadCancelledException>()),
      );
    });

    test('XLSX 调用 converter 并返回结果', () async {
      final result = await FileReaderService.readFile(
        _bytesFile('a.xlsx', [1, 2, 3]),
        xlsxConverter: (bytes) => 'converted:${bytes.length}',
      );
      expect(result, 'converted:3');
    });

    test('XLSX 缺少 converter 抛 ArgumentError', () async {
      expect(
        () => FileReaderService.readFile(
          _bytesFile('a.xlsx', [1, 2, 3]),
        ),
        throwsArgumentError,
      );
    });
  });

  group('readFile 文件路径', () {
    test('文件不存在返回空串', () async {
      final result = await FileReaderService.readFile(
        PlatformFile(
          name: 'missing.csv',
          size: 0,
          path: 'Z:/definitely/missing.csv',
        ),
      );
      expect(result, isEmpty);
    });

    test('小文件读取并回调进度', () async {
      final dir = await Directory.systemTemp.createTemp('spitout_fr_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/data.csv');
      await file.writeAsBytes(utf8.encode('列1,列2\n1,2\n3,4'));

      final progresses = <double>[];
      final result = await FileReaderService.readFile(
        PlatformFile(name: 'data.csv', size: 0, path: file.path),
        onProgress: progresses.add,
      );

      expect(result, contains('列1'));
      expect(progresses, isNotEmpty);
      expect(progresses.last, 1.0);
    });

    test('大文件读取中取消抛 FileReadCancelledException', () async {
      final dir = await Directory.systemTemp.createTemp('spitout_fr_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/big.csv');
      // 超过一个 chunk（256KB），保证循环进入第二次读取前可取消
      final big = utf8.encode('x' * (256 * 1024 + 100));
      await file.writeAsBytes(big);

      var calls = 0;
      expect(
        () => FileReaderService.readFile(
          PlatformFile(name: 'big.csv', size: 0, path: file.path),
          isCancelled: () => ++calls > 1,
        ),
        throwsA(isA<FileReadCancelledException>()),
      );
    });
  });
}
