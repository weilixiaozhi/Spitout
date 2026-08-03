// UserDisplayNameResolver 展示名解析器测试。
//
// 覆盖修复「id/邮箱/昵称混用」的解析优先级:
//   1. 共享账本成员表(昵称 → 邮箱)
//   2. 当前登录用户(userId == cloudUserId → 邮箱/本地昵称)
//   3. localSelfId(本地账本未登录的「我」→ 本地昵称/「我」)
//   4. 虚拟用户名
//   5. 本地昵称兜底(本地账本无成员表时,任意作者位统一展示昵称)
//   6. 兜底原始 id

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' show CloudUser;
import 'package:spitout/cloud/spitout_cloud.dart' show SpitoutCloudLedgerMember;

import 'package:spitout/widgets/user_display_name_resolver.dart';
import 'package:spitout/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUp(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  UserDisplayNameResolver buildResolver({
    Map<String, SpitoutCloudLedgerMember> memberDisplayMap = const {},
    String? localOwnerDisplayName,
    String localSelfId = 'local-self-uuid',
    CloudUser? currentUser,
    Map<String, String> virtualNames = const {},
  }) {
    return UserDisplayNameResolver(
      memberDisplayMap: memberDisplayMap,
      localOwnerDisplayName: localOwnerDisplayName,
      localSelfId: localSelfId,
      currentUser: currentUser,
      virtualNames: virtualNames,
      l10n: l10n,
    );
  }

  /// 构造成员实例（填充必填字段）。
  SpitoutCloudLedgerMember mkMember({
    required String userId,
    required String email,
    String? displayName,
  }) =>
      SpitoutCloudLedgerMember(
        userId: userId,
        email: email,
        displayName: displayName,
        role: 'member',
        joinedAt: DateTime(2026, 1, 1),
        isSelf: false,
      );

  group('resolve 优先级', () {
    test('1. 成员表昵称优先', () {
      final r = buildResolver(
        memberDisplayMap: {
          'u1': mkMember(userId: 'u1', email: 'alice@example.com', displayName: 'Alice'),
        },
      );
      expect(r.resolve('u1'), 'Alice');
    });

    test('1b. 成员表无昵称时回退邮箱', () {
      final r = buildResolver(
        memberDisplayMap: {
          'u1': mkMember(userId: 'u1', email: 'alice@example.com', displayName: null),
        },
      );
      expect(r.resolve('u1'), 'alice@example.com');
    });

    test('2. 当前登录用户(userId 命中 cloudUserId)用邮箱', () {
      final r = buildResolver(
        currentUser: CloudUser(id: 'cloud-user-1', email: 'me@example.com'),
      );
      expect(r.resolve('cloud-user-1'), 'me@example.com');
    });

    test('2b. 当前登录用户无邮箱时用本地昵称', () {
      final r = buildResolver(
        localOwnerDisplayName: '我的昵称',
        currentUser: const CloudUser(id: 'cloud-user-1'),
      );
      expect(r.resolve('cloud-user-1'), '我的昵称');
    });

    test('2c. 当前登录用户无邮箱无昵称时回退「未设置昵称(我)」', () {
      final r = buildResolver(
        currentUser: const CloudUser(id: 'cloud-user-1'),
      );
      expect(r.resolve('cloud-user-1'), '${l10n.mineSlogan}(${l10n.aaMe})');
    });

    test('3. localSelfId 映射为本地昵称', () {
      final r = buildResolver(
        localOwnerDisplayName: '本地昵称',
        localSelfId: 'local-uuid',
      );
      expect(r.resolve('local-uuid'), '本地昵称');
    });

    test('3b. localSelfId 无昵称时回退「未设置昵称(我)」', () {
      final r = buildResolver(localSelfId: 'local-uuid');
      expect(r.resolve('local-uuid'), '${l10n.mineSlogan}(${l10n.aaMe})');
    });

    test('4. 虚拟用户名', () {
      final r = buildResolver(
        virtualNames: {'vu_1': '虚拟成员A'},
      );
      expect(r.resolve('vu_1'), '虚拟成员A');
    });

    test('5. 本地昵称兜底:未知 id 但已设置昵称时展示昵称', () {
      final r = buildResolver(localOwnerDisplayName: '本地昵称');
      expect(r.resolve('unknown-id'), '本地昵称');
    });

    test('5b. 虚拟用户优先于本地昵称兜底', () {
      final r = buildResolver(
        localOwnerDisplayName: '本地昵称',
        virtualNames: {'vu_1': '虚拟成员A'},
      );
      expect(r.resolve('vu_1'), '虚拟成员A');
    });

    test('6. 兜底原始 id', () {
      final r = buildResolver();
      expect(r.resolve('unknown-id'), 'unknown-id');
    });

    test('null/空 userId 返回空串', () {
      final r = buildResolver();
      expect(r.resolve(null), '');
      expect(r.resolve(''), '');
    });

    test('成员表优先于当前登录用户(成员表有此 userId 时用成员表)', () {
      final r = buildResolver(
        memberDisplayMap: {
          'cloud-user-1': mkMember(
              userId: 'cloud-user-1', email: 'me@example.com', displayName: '成员昵称'),
        },
        currentUser: CloudUser(id: 'cloud-user-1', email: 'me@example.com'),
      );
      expect(r.resolve('cloud-user-1'), '成员昵称');
    });
  });
}
