import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/providers/core/post_processor.dart';
import 'package:spitout/providers/providers.dart';

import '../../helpers/test_isolation.dart';

/// 记录调用的同步服务替身（非 SyncEngine → PostProcessor 走 auto_sync 分支）。
class _RecordingSyncService extends LocalOnlySyncService {
  final List<int> marked = [];
  final List<int> uploaded = [];
  bool throwOnMark = false;

  @override
  void markLocalChanged({required int ledgerId}) {
    if (throwOnMark) throw StateError('mark failed');
    marked.add(ledgerId);
  }

  @override
  Future<void> uploadCurrentLedger({required int ledgerId}) async {
    uploaded.add(ledgerId);
  }
}

/// PostProcessor 行为锁定测试：
/// 先固化 run/sync 系列（container/Ref 两种载体）的既有行为，
/// 再进行「三套 _doSync 实现三合一」重构，保证重构前后行为一致。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingSyncService sync;
  late ProviderContainer container;

  setUp(() {
    resetGlobalTestState();
    sync = _RecordingSyncService();
    container = ProviderContainer(overrides: [
      syncServiceProvider.overrideWithValue(sync),
    ]);
  });

  tearDown(() => container.dispose());

  /// 读取三个刷新信号的当前值，便于断言 bump 次数
  ({int stats, int calendar, int syncStatus, int ledgerList}) ticks() => (
        stats: container.read(statsRefreshProvider),
        calendar: container.read(calendarRefreshProvider),
        syncStatus: container.read(syncStatusRefreshProvider),
        ledgerList: container.read(ledgerListRefreshProvider),
      );

  group('syncC（ProviderContainer 载体）', () {
    test('标记本地变更 + bump 日历/同步状态/账本列表；auto_sync 关闭时不上传', () async {
      final before = ticks();
      await PostProcessor.syncC(container, ledgerId: 7);
      // 让内部 fire-and-forget 的后台 Future 有机会执行
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final after = ticks();
      expect(sync.marked, [7]);
      expect(after.calendar, before.calendar + 1);
      expect(after.syncStatus, before.syncStatus + 1);
      expect(after.ledgerList, before.ledgerList + 1);
      expect(after.stats, before.stats, reason: 'sync 系列不刷统计');
      expect(sync.uploaded, isEmpty, reason: 'auto_sync 关闭不应上传');
    });

    test('auto_sync 开启时后台上传当前账本，完成后再 bump 同步状态', () async {
      SharedPreferences.setMockInitialValues({'auto_sync': true});
      final before = ticks();
      await PostProcessor.syncC(container, ledgerId: 9);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sync.uploaded, [9]);
      // 同步前 bump 1 次 + 上传完成后 bump 1 次
      expect(container.read(syncStatusRefreshProvider), before.syncStatus + 2);
    });

    test('markLocalChanged 抛错被吞掉，不影响刷新信号', () async {
      sync.throwOnMark = true;
      final before = ticks();
      await PostProcessor.syncC(container, ledgerId: 3);

      expect(container.read(ledgerListRefreshProvider), before.ledgerList + 1);
      expect(container.read(syncStatusRefreshProvider), before.syncStatus + 1);
    });
  });

  group('runC（ProviderContainer 载体）', () {
    test('在 sync 基础上额外 bump 统计刷新', () async {
      final before = ticks();
      await PostProcessor.runC(container, ledgerId: 5);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final after = ticks();
      expect(sync.marked, [5]);
      expect(after.stats, before.stats + 1);
      expect(after.calendar, before.calendar + 1);
      expect(after.syncStatus, before.syncStatus + 1);
      expect(after.ledgerList, before.ledgerList + 1);
    });
  });

  group('syncR / runR（Ref 载体）', () {
    test('通过 provider 内部 Ref 调用，行为与 container 版一致', () async {
      // 用探针 provider 拿到真实的 Ref 载体；注意必须在 provider 初始化
      // 完成之后再调用 PostProcessor（初始化期间禁止修改其他 provider）
      final probe = Provider<Ref>((ref) => ref);
      final r = container.read(probe);
      final before = ticks();
      await PostProcessor.syncR(r, ledgerId: 11);
      await PostProcessor.runR(r, ledgerId: 12);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final after = ticks();
      expect(sync.marked, [11, 12]);
      expect(after.stats, before.stats + 1, reason: '仅 runR 刷统计');
      expect(after.calendar, before.calendar + 2);
      expect(after.syncStatus, before.syncStatus + 2);
      expect(after.ledgerList, before.ledgerList + 2);
    });
  });

  group('runAfterDownloadC', () {
    test('只刷新四个信号，不触发任何同步', () async {
      final before = ticks();
      PostProcessor.runAfterDownloadC(container);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final after = ticks();
      expect(after.stats, before.stats + 1);
      expect(after.calendar, before.calendar + 1);
      expect(after.syncStatus, before.syncStatus + 1);
      expect(after.ledgerList, before.ledgerList + 1);
      expect(sync.marked, isEmpty);
      expect(sync.uploaded, isEmpty);
    });
  });
}
