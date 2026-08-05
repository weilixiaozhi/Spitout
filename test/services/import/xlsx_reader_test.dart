// XLSX 公式单元格读取测试。
//
// 契约：无缓存结果的公式不能以 =SUM(...) 形式混入导入；
// 字面量公式（如 =3.14）可直接当值输出。

import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/services/import/xlsx_reader.dart';

void main() {
  test('公式单元格无缓存结果时报清晰错误', () {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.appendRow([TextCellValue('金额')]);
    sheet.updateCell(
      CellIndex.indexByString('A2'),
      const FormulaCellValue('=SUM(A1:A2)'),
    );
    final bytes = excel.encode()!;

    expect(
      () => XlsxReader.convertXlsxToCSV(Uint8List.fromList(bytes)),
      throwsA(
        predicate((e) => e.toString().contains('公式单元格')),
      ),
    );
  });

  test('公式字面量可直接当值输出', () {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.updateCell(
      CellIndex.indexByString('A1'),
      const FormulaCellValue('3.14'),
    );
    final bytes = excel.encode()!;

    final csv = XlsxReader.convertXlsxToCSV(Uint8List.fromList(bytes));
    expect(csv, contains('3.14'));
    expect(csv, isNot(contains('=')));
  });
}
