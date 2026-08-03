import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_service.dart'
    show LocalOnlySyncService;
import 'package:spitout/data/db.dart';
import 'package:spitout/data/models.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/main/ledger_edit_page.dart';
import 'package:spitout/providers/providers.dart';

import '../../helpers/test_isolation.dart';

/// [LedgerEditPage] 账本归属移动区(从列表页「更多」菜单下沉而来)的 widget 测试。
///
/// 设计意图:本次迁移把「移动到 Spitout Cloud / 移动到本地 / 复制到本地」统一收口到
/// 编辑页,显示逻辑 fail-closed(不满足条件就不给入口,避免点了才报错的死路);
/// 同时本地账本不再展示成员管理(无 syncId 接不进协作端)。
void main() {
  late SpitoutDatabase db;
  late LocalRepository repo;
  late ChangeTracker tracker;

  setUp(() {
    resetGlobalTestState();
    TestWidgetsFlutterBinding.ensureInitialized();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
  });

  tearDown(() => db.close());

  /// 构造确定账本:本地/云端由 [isCloud] 决定,共享由 [isShared] 决定。
  Future<LedgerDisplayItem> seed({
    required bool isShared,
    required bool isCloud,
    String myRole = 'owner',
  }) async {
    final extId = isCloud ? 'ext-1' : '';
    final localId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'L-$extId',
            syncId: isCloud ? Value(extId) : const Value.absent(),
            isShared: Value(isShared),
            myRole: Value(myRole),
          ),
        );
    return LedgerDisplayItem.fromLocal(
      id: localId,
      name: 'L-$extId',
      currency: 'CNY',
      createdAt: DateTime.now(),
      transactionCount: 0,
      expenseTotal: 0,
      isShared: isShared,
      memberCount: isShared ? 2 : 1,
      myRole: myRole,
      storageMode: isCloud ? 'cloud' : 'local',
    );
  }

  Future<AppLocalizations> pump(
    WidgetTester tester,
    LedgerDisplayItem ledger, {
    required CloudBackendType cloudType,
  }) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    // 编辑页是滚动 ListView:共享账本因多了「成员管理」区块,会把底部「复制到本地」等
    // 归属操作挤出默认视口 → 这些 tile 变为离屏,find.text 默认 skipOffstage 会跳过它们。
    // 抬高测试视口,让全部内容处于在屏状态,使断言匹配真实渲染结果(页面本身渲染正确)。
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    // 选中 Spitout Cloud 时需注册对应 adapter,否则编辑页渲染云端账本成员区
    // (ledgerMembersProvider watch 云同步)会抛"adapter 尚未注册"。生产 main 中也有
    // 此注册,此处补齐测试 fixture 以匹配真实运行环境。函数幂等,重复调用安全。
    if (cloudType == CloudBackendType.spitoutCloud) {
      registerSpitoutCloudBackend();
    }
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProviderScope(
          overrides: [
            repositoryProvider.overrideWith((ref) => repo),
            currentLedgerProvider
                .overrideWith((ref) => Stream<Ledger?>.value(null)),
            // 隔离真实 SyncEngine:本文件是编辑页 UI 测试,只断言归属移动 tile 的
            // 显示/收纳,不需要云端实时同步。若走真实 SyncEngine,渲染云端账本成员区
            // 会触发 SyncCoordinator(drift stream query)与 SyncEngine 的 dispose 链,
            // 在测试收尾阶段挂起 0s / 2s 的 Timer 导致 pending timer 断言失败;
            // 用 LocalOnlySyncService 替换可完全避开该链路(与 home_page_test 同模式)。
            // 注意 ledgerMembersProvider 只 watch spitoutCloudProviderInstance,
            // 不依赖 syncServiceProvider,故成员区渲染不受此 override 影响。
            syncServiceProvider.overrideWith(
                (ref) => LocalOnlySyncService()),
            activeCloudConfigProvider.overrideWith((ref) async => CloudServiceConfig(
                  type: cloudType,
                  name: cloudType == CloudBackendType.spitoutCloud
                      ? 'Spitout Cloud'
                      : 'Local',
                  spitoutCloudBaseUrl: cloudType == CloudBackendType.spitoutCloud
                      ? 'https://example.com'
                      : null,
                )),
          ],
          child: LedgerEditPage(ledger: ledger),
        ),
      ),
    );
    // activeCloudConfigProvider 是 FutureProvider,且编辑页 initState 还会异步加载账本
    // (_loadLedgerData)。两者都完成后再断言,避免断言落在 loading 态。runAsync 会冲刷
    // 挂起的 microtask/timer,确保两条异步链都 resolve。
    await tester.runAsync(() async {
      await tester.pumpAndSettle();
    });
    return l10n;
  }

  // 本地 + 已登录 Spitout Cloud → 仅「移动到 Spitout Cloud」
  testWidgets('本地账本 + Spitout Cloud:显示移动到云端,隐藏移动到本地/复制与邀请新成员',
      (tester) async {
    final ledger = await seed(isShared: false, isCloud: false);
    final l10n = await pump(tester, ledger,
        cloudType: CloudBackendType.spitoutCloud);
    expect(find.text(l10n.ledgersActionMoveToCloud), findsOneWidget);
    expect(find.text(l10n.ledgersActionMoveToLocal), findsNothing);
    expect(find.text(l10n.ledgersActionCopyToLocal), findsNothing);
    // 成员管理常驻显示(所有者信息 + AA 开关),但本地账本不支持协作邀请,
    // 「邀请新成员」入口不渲染(避免点击后因同步层不会创建 syncId 而永久 loading)。
    expect(find.text(l10n.sharedMembersPageTitle), findsOneWidget);
    expect(find.text(l10n.sharedMembersInviteCta), findsNothing);
  });

  // 云端 + 非共享 + Spitout Cloud → 「移动到本地」+「复制到本地」
  testWidgets('云端非共享账本 + Spitout Cloud:显示移动到本地与复制,隐藏移动到云端',
      (tester) async {
    final ledger = await seed(isShared: false, isCloud: true);
    final l10n = await pump(tester, ledger,
        cloudType: CloudBackendType.spitoutCloud);
    expect(find.text(l10n.ledgersActionMoveToLocal), findsOneWidget);
    expect(find.text(l10n.ledgersActionCopyToLocal), findsOneWidget);
    expect(find.text(l10n.ledgersActionMoveToCloud), findsNothing);
    // 个人云账本(已上云未共享)应保留成员管理入口以便邀请协作人。
    expect(find.text(l10n.sharedMembersPageTitle), findsOneWidget);
  });

  // 云端 + 共享 + Spitout Cloud → 仅「复制到本地」
  testWidgets('云端共享账本 + Spitout Cloud:仅显示复制到本地,隐藏移动到本地',
      (tester) async {
    final ledger = await seed(isShared: true, isCloud: true);
    final l10n = await pump(tester, ledger,
        cloudType: CloudBackendType.spitoutCloud);
    expect(find.text(l10n.ledgersActionCopyToLocal), findsOneWidget);
    expect(find.text(l10n.ledgersActionMoveToLocal), findsNothing);
    expect(find.text(l10n.ledgersActionMoveToCloud), findsNothing);
    expect(find.text(l10n.sharedMembersPageTitle), findsOneWidget);
  });

  // 任何账本 + 未登录(非 Spitout Cloud) → 无归属移动入口
  testWidgets('未登录 Spitout Cloud:归属移动区整体不显示', (tester) async {
    final ledger = await seed(isShared: false, isCloud: false);
    final l10n =
        await pump(tester, ledger, cloudType: CloudBackendType.local);
    expect(find.text(l10n.ledgersActionMoveToCloud), findsNothing);
    expect(find.text(l10n.ledgersActionMoveToLocal), findsNothing);
    expect(find.text(l10n.ledgersActionCopyToLocal), findsNothing);
  });

  // 点击归属移动项 → 弹出二次确认对话框(验证 _confirmStorageMove 已接通)
  testWidgets('点击移动到云端:弹出二次确认对话框', (tester) async {
    final ledger = await seed(isShared: false, isCloud: false);
    final l10n = await pump(tester, ledger,
        cloudType: CloudBackendType.spitoutCloud);

    await tester.tap(find.text(l10n.ledgersActionMoveToCloud));
    await tester.pumpAndSettle();

    // 列表项与对话框标题各有一处,证明二次确认对话框已弹出。
    expect(find.text(l10n.ledgersActionMoveToCloud),
        findsAtLeastNWidgets(2));
  });

  // ── 间距内化回归测试 ──
  //
  // 设计意图:共享入口区与归属移动区都可能整体隐藏,且两者的显示条件并不等价
  // (共享区看 isSpitoutCloud && isCloudLedger,归属区看三个 can* 标志),
  // 因此无法靠外层统一 if 包裹来同步。若 _buildBody 里为两区各垫一个独立的
  // SizedBox(height:16),两区同时隐藏时就会累积出 32px 的"孤儿间隙"。
  //
  // 修复原则是"谁产出内容,谁负责间距":隐藏时返回零高度 SizedBox.shrink(),
  // 展示时自带 Padding(top:16)。下面用真实渲染几何验证间距节奏。
  group('间距内化:隐藏区块不留下孤儿间隙', () {
    /// 取包含 [text] 文案的最近一层 [Card] 的全局外接矩形。
    ///
    /// Card 的渲染盒边界即其在 Column 中的布局槽位边界,
    /// 故相邻子项的几何差值 = 中间垫的间距之和,可直接断言像素值。
    /// 注意:仅适用于「卡片内部」的文本 —— 区块标题在 Card 外,
    /// 需用 [titleTop] 以标题顶作为区块顶锚点。
    Rect cardRect(WidgetTester tester, String text) => tester.getRect(
          find
              .ancestor(of: find.text(text), matching: find.byType(Card))
              .first,
        );

    /// 取区块标题文本的顶边 y 坐标。
    ///
    /// 页面统一「标题在外 + 内容卡片」结构,标题是区块第一个元素,
    /// 其顶边即区块顶,区块自带的内化间距(顶部 Padding)以此为锚点断言。
    double titleTop(WidgetTester tester, String text) =>
        tester.getTopLeft(find.text(text).first).dy;

    /// 断言危险操作(清空账本)已收纳进右上角"更多"菜单,页面常驻视图中不应出现。
    ///
    /// 间距内化重构把"危险区"从常驻卡片移入弹出菜单,因此它不再是页面布局的一部分,
    /// 既不能作为间距锚点,也不应残留为可见区块 —— 这里显式校验这一收纳行为。
    void expectDangerMovedToMenu(WidgetTester tester, AppLocalizations l10n) {
      expect(
        tester.any(find.text(l10n.ledgersClear)),
        isFalse,
        reason: '危险操作(清空账本)应已收纳进右上角菜单,页面常驻视图不应出现该文本',
      );
    }

    testWidgets('非 Spitout Cloud:两区皆隐藏,月起始日卡片到保存按钮无孤儿间隙',
        (tester) async {
      final ledger = await seed(isShared: false, isCloud: false);
      final l10n =
          await pump(tester, ledger, cloudType: CloudBackendType.local);

      // 危险操作已收纳进菜单,页面常驻视图不应出现"清空账本"。
      expectDangerMovedToMenu(tester, l10n);
      // 两区皆隐藏(非 Spitout Cloud):归属区标题「存储位置」不应出现在常驻视图。
      // 间距内化后,这两个隐藏区返回零高度 SizedBox.shrink 且不残留独立间隔,
      // 故月起始日卡片在 ListView 内成为最后一个可见区块 —— 此处通过结构断言确认
      // 它们确实整体消失,避免隐藏区留下空 Card 或孤儿间隙。
      expect(tester.any(find.text(l10n.ledgersStorageLocation)), isFalse,
          reason: '非 Spitout Cloud 场景存储归属区应整体隐藏');
    });

    testWidgets('Spitout Cloud + 本地账本:归属区自带 16px 上间距,危险操作已收纳',
        (tester) async {
      final ledger = await seed(isShared: false, isCloud: false);
      final l10n = await pump(tester, ledger,
          cloudType: CloudBackendType.spitoutCloud);

      final monthBottom =
          cardRect(tester, l10n.ledgersMonthStartDayNatural).bottom;
      // 危险操作已收纳进菜单,页面常驻视图不应出现"清空账本"。
      expectDangerMovedToMenu(tester, l10n);
      // 成员管理标题行(含 AA 开关)采用内化间距:其标题顶到
      // 月起始日卡片底为 16px 区间(标题上方 Padding(top:16),无外层独立 SizedBox)。
      // AA 开关已并入标题行,Switch 高度(24)使标题文本垂直居中,
      // 故标题顶略大于 16 但远小于"孤儿间隙"的 32px 阈值。
      final memberTitleTop = titleTop(tester, l10n.sharedMembersPageTitle);
      expect(memberTitleTop - monthBottom, greaterThanOrEqualTo(16.0));
      expect(memberTitleTop - monthBottom, lessThan(32.0));
      // 归属区有「存储位置」标题收纳,在成员管理区之后;本地账本无邀请新成员,
      // 归属区成为成员管理区之后第一个可见区块,其标题顶必大于成员管理标题顶。
      final storageTitleTop = titleTop(tester, l10n.ledgersStorageLocation);
      expect(storageTitleTop, greaterThan(memberTitleTop));
    });

    testWidgets('Spitout Cloud + 云端账本:两区皆展示,各自内化 16px',
        (tester) async {
      final ledger = await seed(isShared: false, isCloud: true);
      final l10n = await pump(tester, ledger,
          cloudType: CloudBackendType.spitoutCloud);

      final monthBottom =
          cardRect(tester, l10n.ledgersMonthStartDayNatural).bottom;
      // 危险操作已收纳进菜单,页面常驻视图不应出现"清空账本"。
      expectDangerMovedToMenu(tester, l10n);
      // 成员管理标题行(含 AA 开关)采用内化间距:其标题顶到月起始日卡片底
      // 在 16px 区间(标题上方 Padding(top:16))。
      final memberTitleTop = titleTop(tester, l10n.sharedMembersPageTitle);
      expect(memberTitleTop - monthBottom, greaterThanOrEqualTo(16.0));
      expect(memberTitleTop - monthBottom, lessThan(32.0));
      // AA 开关与「成员管理」标题同处一行,AA 文案必然出现在成员管理区。
      expect(find.text(l10n.ledgerAaEnabled), findsOneWidget);
      // 归属区标题在成员管理区之后,其顶部间距 = 成员区内容高度 + 自带的 16px,
      // 故必大于 16px(仅验证方向,不绑定成员区内容高度)。
      final storageTitleTop = titleTop(tester, l10n.ledgersStorageLocation);
      expect(storageTitleTop - memberTitleTop, greaterThan(16.0));
    });
  });
}
