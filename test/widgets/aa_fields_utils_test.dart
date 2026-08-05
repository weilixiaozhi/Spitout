/// AA 字段统一工具回归测试。
///
/// 锁定三处修复：
/// 1. 编辑模式「部分参与人 / 指定分摊 → 全部成员 / 人均」必须显式写空串清空
///    旧 aaParticipants / aaSplits（update 语义 null = 不更新）；
/// 2. 共享账本 synthetic override 存在时 category_id 必须留 null，
///    不得把 synthetic 负数 id 写进共享账本交易的 category_id；
/// 3. JSON 解析失败 / 空值统一按 null 兜底（全部成员运行时展开）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/widgets/aa_fields_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseAaParticipantIds', () {
    test('null / 空串 / 解析失败返回 null（全部成员）', () {
      expect(parseAaParticipantIds(null), isNull);
      expect(parseAaParticipantIds(''), isNull);
      expect(parseAaParticipantIds('not-json'), isNull);
    });

    test('合法 JSON 数组解析为参与人列表', () {
      expect(parseAaParticipantIds('["u1","u2"]'), ['u1', 'u2']);
    });
  });

  group('parseAaSplits', () {
    test('null / 空串 / 解析失败返回 null', () {
      expect(parseAaSplits(null), isNull);
      expect(parseAaSplits(''), isNull);
      expect(parseAaSplits('not-json'), isNull);
    });

    test('合法 JSON 对象解析为金额映射', () {
      expect(
        parseAaSplits('{"u1":"4.00","u2":"4.00"}'),
        {'u1': '4.00', 'u2': '4.00'},
      );
    });
  });

  group('aaParticipantsJsonForWrite / aaSplitsJsonForWrite', () {
    test('新建模式 null → null（落库默认），编辑模式 null → 空串清空旧值', () {
      expect(aaParticipantsJsonForWrite(null, isEditing: false), isNull);
      expect(aaParticipantsJsonForWrite(null, isEditing: true), '');
      expect(aaSplitsJsonForWrite(null, isEditing: false), isNull);
      expect(aaSplitsJsonForWrite(null, isEditing: true), '');
    });

    test('非空值按 JSON 序列化落库', () {
      expect(
        aaParticipantsJsonForWrite(['u1', 'u2'], isEditing: true),
        '["u1","u2"]',
      );
      expect(
        aaSplitsJsonForWrite({'u1': '4.00'}, isEditing: false),
        '{"u1":"4.00"}',
      );
    });
  });

  group('aaEditCategoryIdForWrite', () {
    test('synthetic override 存在时 categoryId 留 null，即使本地已有 categoryId', () {
      expect(
        aaEditCategoryIdForWrite(
          categoryId: 5,
          categorySyncIdOverride: 'cat-sync-1',
        ),
        isNull,
        reason: '共享账本 Editor 不得把 synthetic 负数 id 写进 category_id',
      );
    });

    test('无 override 时保留原 categoryId', () {
      expect(
        aaEditCategoryIdForWrite(
          categoryId: 5,
          categorySyncIdOverride: null,
        ),
        5,
      );
    });
  });
}
