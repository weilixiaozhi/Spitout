// 作者身份按账本归属选择 provider 测试。
//
// 需求锚点：
// - 本地账本记账身份永远用 localSelfId，不受云端登录影响；
// - 云端账本记账身份永远用缓存的云 userId，绝不降级写 localSelfId；
// - 云身份缓存未就绪时返回 null（作者位留空，由同步服务端回填），不允许阻塞保存。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';
import 'package:spitout/cloud/spitout_cloud.dart' show SpitoutCloudSyncBackend;
import 'package:spitout/data/db.dart' as db;
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/providers/providers.dart';

class _MockRepo extends Mock implements LocalRepository {}

db.Ledger _ledger({required String storageMode, bool isShared = false}) =>
    db.Ledger(
      id: 1,
      name: '测试账本',
      currency: 'CNY',
      type: 'personal',
      createdAt: DateTime(2026, 1, 1),
      myRole: 'owner',
      memberCount: 1,
      isShared: isShared,
      monthStartDay: 1,
      syncId: isShared ? 'sync-ledger-1' : null,
      storageMode: storageMode,
      aaEnabled: false,
    );

class _Harness {
  _Harness(this.repo, this.container);

  final _MockRepo repo;
  final ProviderContainer container;
}

Future<_Harness> _harness({required SpitoutCloudSyncBackend? cloud}) async {
  final repo = _MockRepo();
  final container = ProviderContainer(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      localSelfIdProvider.overrideWith((ref) async => 'local-self'),
      spitoutCloudProviderInstance.overrideWith((ref) async => cloud),
    ],
  );
  addTearDown(container.dispose);
  return _Harness(repo, container);
}

/// 通过 Consumer 在 build 阶段取回真实 WidgetRef（动作函数参数）。
Future<WidgetRef> _captureRef(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final completer = Completer<WidgetRef>();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) {
          if (!completer.isCompleted) completer.complete(ref);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  // 让 StreamProvider 首帧（含 null）落定，保证动作函数读 asData 时已解析。
  await tester.pump();
  return completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('authorUserIdForLedger：本地账本返回 localSelfId，不受云端登录影响',
      (tester) async {
    final h = await _harness(
      cloud: FakeSpitoutCloudProvider(userId: 'cloud-1'),
    );
    when(() => h.repo.getLedgerById(1))
        .thenAnswer((_) async => _ledger(storageMode: 'local'));
    final ref = await _captureRef(tester, h.container);

    expect(await authorUserIdForLedger(ref, 1), 'local-self');
  });

  testWidgets('authorUserIdForLedger：云端账本返回缓存的云 userId', (tester) async {
    final h = await _harness(
      cloud: FakeSpitoutCloudProvider(userId: 'cloud-1'),
    );
    when(() => h.repo.getLedgerById(1))
        .thenAnswer((_) async => _ledger(storageMode: 'cloud'));
    final ref = await _captureRef(tester, h.container);

    expect(await authorUserIdForLedger(ref, 1), 'cloud-1');
  });

  testWidgets('authorUserIdForLedger：云端账本但云身份未就绪 → null，绝不降级',
      (tester) async {
    final h = await _harness(cloud: null);
    when(() => h.repo.getLedgerById(1))
        .thenAnswer((_) async => _ledger(storageMode: 'cloud'));
    final ref = await _captureRef(tester, h.container);

    expect(await authorUserIdForLedger(ref, 1), isNull);
  });

  testWidgets('currentAuthorIdByLedgerMode：本地→localSelfId；云端→云 userId；云缺失→null',
      (tester) async {
    final h = await _harness(
      cloud: FakeSpitoutCloudProvider(userId: 'cloud-1'),
    );
    final ref = await _captureRef(tester, h.container);

    expect(
      await currentAuthorIdByLedgerMode(ref, isCloudLedger: false),
      'local-self',
    );
    expect(
      await currentAuthorIdByLedgerMode(ref, isCloudLedger: true),
      'cloud-1',
    );
  });

  testWidgets('currentAuthorIdByLedgerMode：云端且云身份未就绪 → null', (tester) async {
    final h = await _harness(cloud: null);
    final ref = await _captureRef(tester, h.container);

    expect(
      await currentAuthorIdByLedgerMode(ref, isCloudLedger: true),
      isNull,
    );
  });
}
