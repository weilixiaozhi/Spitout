/// 数据模型解析严格性测试。
///
/// 覆盖审查项:
/// - 关键标识字段缺失时抛 [FormatException],不允许空串进入同步逻辑;
/// - 邀请 / 成员时间戳缺失或格式异常时为 null,不再伪造 DateTime.now()。
library;

import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('关键标识字段严格解析', () {
    test('ReadLedger 缺 ledger_id 抛 FormatException', () {
      expect(
        () => SpitoutCloudReadLedger.fromJson(const {
          'ledger_name': 'x',
          'currency': 'CNY',
        }),
        throwsFormatException,
      );
    });

    test('Invite 缺 id 抛 FormatException', () {
      expect(
        () => SpitoutCloudInvite.fromJson(const {
          'code': 'ABC123',
          'formatted_code': 'ABC 123',
        }),
        throwsFormatException,
      );
    });

    test('InvitePreview 缺 ledger_external_id 抛 FormatException', () {
      expect(
        () => SpitoutCloudInvitePreview.fromJson(const {
          'code': 'ABC123',
          'ledger_currency': 'CNY',
        }),
        throwsFormatException,
      );
    });
  });

  group('时间戳缺失/异常不伪造当前时刻', () {
    test('Invite 缺 expires_at/created_at 时返回 null', () {
      final invite = SpitoutCloudInvite.fromJson(const {
        'id': 'inv-1',
        'formatted_code': 'ABC 123',
        'target_role': 'editor',
      });

      expect(invite.expiresAt, isNull);
      expect(invite.createdAt, isNull);
    });

    test('InvitePreview expires_at 格式异常时返回 null', () {
      final preview = SpitoutCloudInvitePreview.fromJson(const {
        'code': 'ABC123',
        'ledger_external_id': 'ledger-1',
        'ledger_currency': 'CNY',
        'invited_by_display': 'Owner',
        'target_role': 'editor',
        'expires_at': 'not-a-date',
      });

      expect(preview.expiresAt, isNull);
    });

    test('LedgerMember 缺 joined_at 时返回 null', () {
      final member = SpitoutCloudLedgerMember.fromJson(const {
        'user_id': 'u-1',
        'account': 'a@b.com',
        'role': 'editor',
        'is_self': false,
      });

      expect(member.joinedAt, isNull);
    });
  });
}
