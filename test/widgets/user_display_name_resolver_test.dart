// UserDisplayNameResolver 展示名解析器测试。
//
// 覆盖修复「id/账号/昵称混用」的解析优先级:
//   1. 共享账本成员表(昵称 → 账号)
//   2. 本人(当前云 userId 或 localSelfId → 本地昵称 → 云账号 → 「未设置昵称」)
//   3. 虚拟用户名
//   4. 兜底原始 id(未知 id 不套用本地昵称,避免张冠李戴)

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' show CloudUser;
import 'package:spitout/cloud/spitout_cloud.dart' show SpitoutCloudLedgerMember;

import 'package:spitout/providers/ui/user_display_name_resolver.dart';
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
    required String account,
    String? displayName,
  }) =>
      SpitoutCloudLedgerMember(
        userId: userId,
        account: account,
        displayName: displayName,
        role: 'member',
        joinedAt: DateTime(2026, 1, 1),
        isSelf: false,
      );

  group('resolve 优先级', () {
    test('1. 成员表昵称优先', () {
      final r = buildResolver(
        memberDisplayMap: {
          'u1': mkMember(userId: 'u1', account: 'alice@example.com', displayName: 'Alice'),
        },
      );
      expect(r.resolve('u1'), 'Alice');
    });

    test('1b. 成员表无昵称时回退账号', () {
      final r = buildResolver(
        memberDisplayMap: {
          'u1': mkMember(userId: 'u1', account: 'alice@example.com', displayName: null),
        },
      );
      expect(r.resolve('u1'), 'alice@example.com');
    });

    test('2. 当前登录用户(userId 命中 cloudUserId)有本地昵称时优先昵称', () {
      final r = buildResolver(
        localOwnerDisplayName: '我的昵称',
        currentUser: CloudUser(id: 'cloud-user-1', account: 'me@example.com'),
      );
      expect(r.resolve('cloud-user-1'), '我的昵称');
    });

    test('2b. 当前登录用户无本地昵称时用云账号', () {
      final r = buildResolver(
        currentUser: CloudUser(id: 'cloud-user-1', account: 'me@example.com'),
      );
      expect(r.resolve('cloud-user-1'), 'me@example.com');
    });

    test('2c. 当前登录用户无账号无昵称时回退「未设置昵称」', () {
      final r = buildResolver(
        currentUser: const CloudUser(id: 'cloud-user-1'),
      );
      // 仅纯名:「(我)」后缀由 UI 层共享 meSuffixSpan 统一渲染,不在数据层拼接。
      expect(r.resolve('cloud-user-1'), l10n.mineSlogan);
    });

    test('3. localSelfId 映射为本地昵称', () {
      final r = buildResolver(
        localOwnerDisplayName: '本地昵称',
        localSelfId: 'local-uuid',
      );
      expect(r.resolve('local-uuid'), '本地昵称');
    });

    test('3b. localSelfId 无昵称时回退「未设置昵称」', () {
      final r = buildResolver(localSelfId: 'local-uuid');
      // 仅纯名,后缀由 UI 层渲染。
      expect(r.resolve('local-uuid'), l10n.mineSlogan);
    });

    test('3c. 本人两种 id 显示一致：都优先本地昵称', () {
      final r = buildResolver(
        localOwnerDisplayName: '我的昵称',
        localSelfId: 'local-uuid',
        currentUser: CloudUser(id: 'cloud-user-1', account: 'me@example.com'),
      );
      expect(r.resolve('local-uuid'), '我的昵称');
      expect(r.resolve('cloud-user-1'), '我的昵称');
    });

    test('4. 虚拟用户名', () {
      final r = buildResolver(
        virtualNames: {'vu_1': '虚拟成员A'},
      );
      expect(r.resolve('vu_1'), '虚拟成员A');
    });

    test('5. 未知 id 不套用本地昵称,直接兜底原始 id', () {
      final r = buildResolver(localOwnerDisplayName: '本地昵称');
      expect(r.resolve('unknown-id'), 'unknown-id');
    });

    test('5b. 虚拟用户名优先于未知 id 兜底', () {
      final r = buildResolver(
        localOwnerDisplayName: '本地昵称',
        virtualNames: {'vu_1': '虚拟成员A'},
      );
      expect(r.resolve('vu_1'), '虚拟成员A');
    });

    test('6. 无任何名称可用时兜底原始 id', () {
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
              userId: 'cloud-user-1', account: 'me@example.com', displayName: '成员昵称'),
        },
        currentUser: CloudUser(id: 'cloud-user-1', account: 'me@example.com'),
      );
      expect(r.resolve('cloud-user-1'), '成员昵称');
    });
  });

  group('isSelf 本人判定', () {
    test('currentUser 命中为本人', () {
      final r = buildResolver(
        currentUser: const CloudUser(id: 'cloud-user-1'),
      );
      expect(r.isSelf('cloud-user-1'), isTrue);
    });

    test('localSelfId 命中为本人', () {
      final r = buildResolver(localSelfId: 'local-uuid');
      expect(r.isSelf('local-uuid'), isTrue);
    });

    test('未登录时 currentUser 不参与判定,仅 localSelfId', () {
      final r = buildResolver(localSelfId: 'local-uuid');
      expect(r.isSelf('someone-else'), isFalse);
    });

    test('null/空 userId 非本人', () {
      final r = buildResolver();
      expect(r.isSelf(null), isFalse);
      expect(r.isSelf(''), isFalse);
    });
  });
}
