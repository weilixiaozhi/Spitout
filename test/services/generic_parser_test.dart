/// 通用账单解析器（GenericBillParser）表头识别与列映射的契约测试。
///
/// 重点覆盖一个真实缺陷：第三方记账 App 导出的 CSV 表头列数（8 列）与
/// 数据行列数（9 列，因行尾多一个逗号）不一致。当前实现依靠"可识别字段数"
/// 定位表头，不依赖列数严格相等，避免把第一条数据行误判为表头丢掉首条明细。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/services/import/csv_parser.dart';
import 'package:spitout/services/import/parsers/generic_parser.dart';

void main() {
  group('GenericBillParser.findHeaderRow', () {
    test('表头与数据行列数不对称时仍能正确识别表头（修复缺陷）', () {
      // 还原用户"萌猪"导出文件：表头 8 列，数据行 9 列（行尾多逗号）。
      const csv = '''
时间,分类,类型,金额,账户1,账户2,备注,账单图片
2025-09-28 14:44:05,交通,支出,330.0,,,"单程车票",,
2025-09-28 14:44:40,通讯,支出,50.0,,,"香港电话卡",,
2025-09-28 14:45:34,交通,支出,4.5,,,"地铁",,
2025-09-28 14:45:57,交通,支出,14.52,,,"地铁",,
2025-09-28 14:46:07,餐饮,支出,20.68,,,"可乐",,
2025-09-28 14:46:37,餐饮,支出,91.89,,,"麦当劳",,
''';
      final rows = CsvParser.parse(csv);
      // 表头 8 列、数据行 9 列（行尾逗号带来第 9 个空列）
      expect(rows.first.length, 8);
      expect(rows[1].length, 9);

      final parser = GenericBillParser();
      // 关键断言：表头必须是第 0 行，而非被误判为第 1 行（首条数据）。
      expect(parser.findHeaderRow(rows), 0);
    });

    test('列数对称的常规文件表头仍可被识别', () {
      const csv = '''
时间,分类,类型,金额,备注
2025-09-28 14:44:05,交通,支出,330.0,单程车票
2025-09-28 14:44:40,通讯,支出,50.0,香港电话卡
2025-09-28 14:45:34,交通,支出,4.5,地铁
''';
      final rows = CsvParser.parse(csv);
      final parser = GenericBillParser();
      expect(parser.findHeaderRow(rows), 0);
    });

    test('支付宝含描述性前言的导出文件仍命中关键词检测', () {
      // 关键词检测优先级最高，前言不会影响表头定位。
      const csv = '''
支付宝交易记录明细查询
导出时间:2025-01-01
交易时间,商品说明,交易金额,交易类型
2025-01-01 10:00:00,测试商品,100.00,支出
2025-01-02 10:00:00,测试商品2,200.00,支出
''';
      final rows = CsvParser.parse(csv);
      final parser = GenericBillParser();
      // 第 2 行（索引 2）才是真正的表头。
      expect(parser.findHeaderRow(rows), 2);
    });

    test('数据行偶然含多字段值也不会被误判为表头', () {
      // 构造一个"数据行识别字段数"很高的边界场景，验证阈值与去重逻辑：
      // 表头用自定义字段名、数据行用具体取值（取值几乎无法映射到字段名）。
      const csv = '''
日期,类目,收支,数额,账户名
2025-09-28,餐饮,支出,330.00,招商银行
2025-09-29,交通,支出,14.52,微信钱包
2025-09-30,购物,支出,255.38,支付宝
''';
      final rows = CsvParser.parse(csv);
      final parser = GenericBillParser();
      expect(parser.findHeaderRow(rows), 0);
    });
  });

  group('GenericBillParser.mapColumns', () {
    test('自定义表头正确映射到字段', () {
      final header = ['时间', '分类', '类型', '金额', '账户1', '账户2', '备注', '账单图片', '附件'];
      final parser = GenericBillParser();
      final mapping = parser.mapColumns(header);

      expect(mapping['date'], 0);
      expect(mapping['category'], 1);
      expect(mapping['type'], 2);
      expect(mapping['amount'], 3);
      // 账户1/账户2 都命中 account，去重后保留第一个（账户1）。
      expect(mapping['account'], 4);
      expect(mapping['note'], 6);
      // 交易附件功能已下线，名为"附件/Attachments/账单图片"的列一律被忽略，不进入映射。
      expect(mapping.containsKey('attachments'), isFalse);
    });
  });
}
