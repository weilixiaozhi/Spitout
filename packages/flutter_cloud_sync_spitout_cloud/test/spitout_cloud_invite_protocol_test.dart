/// 邀请协议调整(2026-08):创建响应带完整明文,列表响应只带掩码。
///
/// 覆盖 [SpitoutCloudInvite.fromJson] 对两种响应形状的解析:
/// - 创建响应:code / shareUrl 非空,codePrefix 为 null;
/// - 列表响应:code / shareUrl 为 null,codePrefix 为掩码前缀。
/// 防止未来把列表掩码误当完整码展示 / 复制。
library;

import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpitoutCloudInvite 协议解析', () {
    test('创建响应:完整明文 + 分享链接,无 codePrefix', () {
      final invite = SpitoutCloudInvite.fromJson({
        'id': 'inv-1',
        'code': 'ABC123',
        'formatted_code': 'ABC 123',
        'target_role': 'editor',
        'expires_at': '2026-08-06T00:00:00Z',
        'created_at': '2026-08-05T00:00:00Z',
        'share_url': '/invite/ABC123',
      });

      expect(invite.id, 'inv-1');
      expect(invite.code, 'ABC123');
      expect(invite.codePrefix, isNull);
      expect(invite.formattedCode, 'ABC 123');
      expect(invite.shareUrl, '/invite/ABC123');
      expect(invite.invitedByUserId, isNull);
    });

    test('列表响应:只带掩码,完整 code / shareUrl 为 null', () {
      final invite = SpitoutCloudInvite.fromJson({
        'id': 'inv-2',
        'code_prefix': 'ABC1',
        'formatted_code': 'ABC1 ••',
        'target_role': 'editor',
        'expires_at': '2026-08-06T00:00:00Z',
        'created_at': '2026-08-05T00:00:00Z',
        'invited_by_user_id': 'user-9',
      });

      expect(invite.id, 'inv-2');
      expect(invite.code, isNull);
      expect(invite.codePrefix, 'ABC1');
      expect(invite.formattedCode, 'ABC1 ••');
      expect(invite.shareUrl, isNull);
      expect(invite.invitedByUserId, 'user-9');
    });
  });
}
