// CsvParser 纯逻辑测试：分隔符自动检测、引号转义、空行过滤、BOM 去除、回退路径。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/services/import/csv_parser.dart';

void main() {
  test('逗号分隔基础解析', () {
    final rows = CsvParser.parse('a,b,c\n1,2,3');
    expect(rows, [
      ['a', 'b', 'c'],
      ['1', '2', '3'],
    ]);
  });

  test('引号包裹字段且含转义引号', () {
    final rows = CsvParser.parse('"hello, world","say ""hi"""\n"x","y"');
    expect(rows, [
      ['hello, world', 'say "hi"'],
      ['x', 'y'],
    ]);
  });

  test('CRLF 与孤立 CR 归一化 + 空行过滤', () {
    final rows = CsvParser.parse('a,b\r\n\r\n1,2\r3,4\r\n');
    expect(rows, [
      ['a', 'b'],
      ['1', '2'],
      ['3', '4'],
    ]);
  });

  test('UTF-8 BOM 去除', () {
    final rows = CsvParser.parse('\uFEFFa,b\n1,2');
    expect(rows.first.first, 'a');
  });

  test('空输入返回空列表', () {
    expect(CsvParser.parse(''), isEmpty);
    expect(CsvParser.parse('\n\n  \n'), isEmpty);
  });

  test('字段内 tab 被移除（非 tab 分隔时）', () {
    final rows = CsvParser.parse('a,b\n1\tx,2');
    expect(rows, [
      ['a', 'b'],
      ['1x', '2'],
    ]);
  });

  test('tab 分隔符优先识别', () {
    final rows = CsvParser.parse('a\tb\n1\t2');
    expect(rows, [
      ['a', 'b'],
      ['1', '2'],
    ]);
  });

  test('分号分隔符', () {
    final rows = CsvParser.parse('a;b\n1;2');
    expect(rows, [
      ['a', 'b'],
      ['1', '2'],
    ]);
  });

  test('竖线分隔符', () {
    final rows = CsvParser.parse('a|b\n1|2');
    expect(rows, [
      ['a', 'b'],
      ['1', '2'],
    ]);
  });

  test('连续多空格分隔（space 模式）', () {
    final rows = CsvParser.parse('a  b\n1  2');
    expect(rows, [
      ['a', 'b'],
      ['1', '2'],
    ]);
  });

  test('单列文本保持单列', () {
    final rows = CsvParser.parse('hello\nworld');
    expect(rows, [
      ['hello'],
      ['world'],
    ]);
  });

  test('引号内分隔符不计入检测', () {
    final rows = CsvParser.parse('"a,b",c\n"1;2",3');
    expect(rows, [
      ['a,b', 'c'],
      ['1;2', '3'],
    ]);
  });
}
