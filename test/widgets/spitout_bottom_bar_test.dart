/// 底部导航栏（SpitoutBottomBar）命中回归测试。
///
/// 历史 bug：FAB 曾以 `Positioned(top: -25)` 凸出 Stack 边界绘制，
/// `Clip.none` 只放开绘制不放开命中（RenderBox.hitTest 的 size.contains
/// 检查），导致 FAB 凸出胶囊的上半截 25dp 是点击死区 —— 表现为
/// "记账按钮需要多次点击才弹起"。
///
/// 本测试钉死修复后的几何契约：
///   1. FAB 凸出胶囊的上半区（栏顶 ~ 胶囊顶之间）点击必须触发记账回调；
///   2. FAB 与胶囊重叠的下半区点击必须触发记账回调；
///   3. FAB 顶部与底部栏顶部对齐（凸出量已收编进栏高，不再越界）；
///   4. 明细 / 统计 / 日历 / 我的 四 tab 点击回调不受影响；
///   5. FAB 水平中心必须落在「统计」与「日历」两个 tab 之间（左右对称回归）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/app.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/icons/app_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 中文文案真值：直接走 delegate 加载，避免硬编码文案导致 arb 改动后测试误挂。
  late AppLocalizations l10n;

  setUp(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  /// 构建底部栏测试宿主。回调通过闭包记录，便于断言命中结果。
  Widget buildHarness({
    required VoidCallback onCenterTap,
    required ValueChanged<int> onTabTap,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(
        bottomNavigationBar: SpitoutBottomBar(
          currentIndex: 0,
          isDark: false,
          bottomPadding: 0,
          l10n: l10n,
          onTabTap: onTabTap,
          onCenterTap: onCenterTap,
        ),
      ),
    );
  }

  testWidgets('FAB 凸出胶囊的上半区可命中（死区回归）', (tester) async {
    var centerTaps = 0;
    await tester.pumpWidget(buildHarness(
      onCenterTap: () => centerTaps++,
      onTabTap: (_) {},
    ));

    // FAB 视觉矩形（+ 号图标即 FAB 内容，56×56）
    final fabRect = tester.getRect(find.byIcon(AppIcons.add));
    // 点击 FAB 顶部往下 5dp —— 位于凸出胶囊的 25dp 区域内，
    // 修复前该点超出 Stack bounds，命中 100% 丢失。
    await tester.tapAt(Offset(fabRect.center.dx, fabRect.top + 5));
    expect(centerTaps, 1, reason: 'FAB 凸出胶囊的上半区必须可点击');
  });

  testWidgets('FAB 与胶囊重叠的下半区可命中', (tester) async {
    var centerTaps = 0;
    await tester.pumpWidget(buildHarness(
      onCenterTap: () => centerTaps++,
      onTabTap: (_) {},
    ));

    final fabRect = tester.getRect(find.byIcon(AppIcons.add));
    // FAB 底部往上 5dp —— 与胶囊重叠区域，修复前后都应可点。
    await tester.tapAt(Offset(fabRect.center.dx, fabRect.bottom - 5));
    expect(centerTaps, 1);
  });

  testWidgets('FAB 顶部与底部栏顶部对齐（凸出量收编进栏高）', (tester) async {
    await tester.pumpWidget(buildHarness(
      onCenterTap: () {},
      onTabTap: (_) {},
    ));

    final barRect = tester.getRect(find.byType(SpitoutBottomBar));
    final fabRect = tester.getRect(find.byIcon(AppIcons.add));
    // FAB 不再越出 Stack 顶部：FAB 顶 == 栏顶。
    expect(fabRect.top, barRect.top);
    // 栏高 = 胶囊 64 + 凸出 25 + 浮动间距 12（bottomPadding 传 0）。
    expect(barRect.height, 64 + 25 + 12);
  });

  testWidgets('明细 / 统计 / 日历 / 我的 四 tab 点击回调不受影响', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(buildHarness(
      onCenterTap: () {},
      onTabTap: tapped.add,
    ));

    // 四个 tab 从左到右：明细(0) / 统计(1) / 日历(2) / 我的(3)
    await tester.tap(find.text(l10n.tabHome));
    await tester.tap(find.text(l10n.tabAnalytics));
    await tester.tap(find.text(l10n.tabCalendar));
    await tester.tap(find.text(l10n.tabMine));
    expect(tapped, [0, 1, 2, 3]);
  });

  testWidgets('FAB 水平中心落在「统计」与「日历」之间（对称对齐回归）', (tester) async {
    await tester.pumpWidget(buildHarness(
      onCenterTap: () {},
      onTabTap: (_) {},
    ));

    // 中央记账按钮的水平中心 x 坐标
    final fabCenterX = tester.getRect(find.byIcon(AppIcons.add)).center.dx;
    // 用 tab 整体命中区（GestureDetector）而非文字包围盒：文字在 tab 内是
    // `Icon(左) + 文字(右)` 布局，文字 rect 相对整个 tab 块不对称（右侧仅留
    // 18dp padding，左侧因图标占 26dp+7dp 留 51dp），直接用文字 rect 算缺口
    // 中点会天然偏移 33dp，测不出真实对齐。测 tab 块边界才能反映真实几何。
    final analyticsTab = find.ancestor(
      of: find.text(l10n.tabAnalytics),
      matching: find.byType(GestureDetector),
    );
    final calendarTab = find.ancestor(
      of: find.text(l10n.tabCalendar),
      matching: find.byType(GestureDetector),
    );
    final analyticsRect = tester.getRect(analyticsTab);
    final calendarRect = tester.getRect(calendarTab);

    expect(fabCenterX, greaterThan(analyticsRect.right),
        reason: 'FAB 必须位于统计 tab 右侧');
    expect(fabCenterX, lessThan(calendarRect.left),
        reason: 'FAB 必须位于日历 tab 左侧');
    // 进一步要求：FAB 中心应精确落在统计/日历之间的 128dp 缺口正中，
    // 即到两侧 tab 块右/左边缘的间距相等（约 64dp）。差值超 2dp 即视为
    // "整体偏左/偏右" 的视觉错位，防止回归。
    final distToAnalytics = fabCenterX - analyticsRect.right;
    final distToCalendar = calendarRect.left - fabCenterX;
    expect((distToAnalytics - distToCalendar).abs(), lessThan(2),
        reason: 'FAB 应精确居中于统计与日历之间，左右间距需对称');
  });

  testWidgets('英文长标签不溢出（375dp 窄屏回归）', (tester) async {
    // 复现原始 bug：英文 Statistics/Calendar 较长，旧布局(MainAxisSize.min +
    // 左对齐溢出)会把 Calendar/Mine 挤出屏幕右侧、FAB 压在 Statistics 上。
    // 用 375dp 窄屏复现，断言四个 tab 文字包围盒都落在胶囊水平范围内。
    final enL10n = await AppLocalizations.delegate.load(const Locale('en'));
    // 缩到手机窄屏以复现溢出；tearDown 还原，避免影响其它用例。
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          bottomNavigationBar: SpitoutBottomBar(
            currentIndex: 0,
            isDark: false,
            bottomPadding: 0,
            l10n: enL10n,
            onTabTap: (_) {},
            onCenterTap: () {},
          ),
        ),
      ),
    );

    // 布局阶段若发生溢出，Flutter 会抛异常，pump 后立即捕获。
    expect(tester.takeException(), isNull,
        reason: '英文窄屏下底部栏不应出现布局溢出');

    final barRect = tester.getRect(find.byType(SpitoutBottomBar));
    for (final label in [
      enL10n.tabHome,
      enL10n.tabAnalytics,
      enL10n.tabCalendar,
      enL10n.tabMine,
    ]) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(barRect.left - 0.5),
          reason: '[$label] 不应溢出胶囊左边界');
      expect(rect.right, lessThanOrEqualTo(barRect.right + 0.5),
          reason: '[$label] 不应溢出胶囊右边界');
    }
  });
}
