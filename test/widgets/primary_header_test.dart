/// PrimaryHeader 及统一 action 封装（HeaderIconAction/HeaderTextAction）组件测试。
///
/// 背景：全局头部规范已收敛至 PrimaryHeader 单组件承载。
/// 本测试锁定组件内置规范：默认留白上/下10左/右12、返回键 20px、图标键 20px、
/// 文字链 14px/w600、spinning 转圈禁用、onTitleTap 标题可点击，
/// 防止后续提交在组件层引入分叉。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/widgets/primary_header.dart';

void main() {
  /// 构建最小测试宿主：PrimaryHeader 是 ConsumerWidget，需 ProviderScope。
  /// 用 Column 包裹让 PrimaryHeader 在垂直方向自然收缩，
  /// 否则 Scaffold body 的全屏高度约束会把 PrimaryHeader 撑满整个屏幕，
  /// 导致高度断言失效。
  Widget buildHost(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: Column(children: [child])),
      ),
    );
  }

  group('PrimaryHeader 内置规范', () {
    testWidgets('标题字号 14px w600，走文本 token', (tester) async {
      await tester.pumpWidget(buildHost(const PrimaryHeader(title: '标题')));

      final style = tester.widget<Text>(find.text('标题')).style;
      expect(style?.fontSize, 14, reason: '头部标题应为 14px');
      expect(style?.fontWeight, FontWeight.w600, reason: '头部标题应为 w600');
    });

    testWidgets('默认留白为上 8、下 0、左/右 12，调用方不传 padding 即全局统一', (tester) async {
      await tester.pumpWidget(buildHost(const PrimaryHeader(title: '标题')));

      final header =
          tester.widget<PrimaryHeader>(find.byType(PrimaryHeader));
      expect(header.padding,
          const EdgeInsets.only(top: 8, left: 12, right: 12, bottom: 0),
          reason: 'PrimaryHeader 默认 padding 应为上8、下0、左右12，承载全局头部留白规范');
    });

    testWidgets('showBack 返回键图标为 20px、热区 30x30，与 HeaderIconAction 规格一致', (tester) async {
      await tester
          .pumpWidget(buildHost(const PrimaryHeader(title: '标题', showBack: true)));

      // 返回键是首个 Icon（leading 位置），断言其 size 显式为 20
      final backIcon = tester.widget<Icon>(find.byType(Icon).first);
      expect(backIcon.size, 20, reason: '返回键图标应显式 20px，与 HeaderIconAction 统一');
      final backButton =
          tester.widget<IconButton>(find.byType(IconButton).first);
      expect(backButton.constraints,
          const BoxConstraints(minWidth: 30, minHeight: 30),
          reason: '返回键热区应为 30x30，与首行最小高度一致');
    });

    group('首行行高全局统一为 30（header 总高 38 = padding 8+30+0）', () {
      // 测试环境 MediaQuery.viewPadding 默认为 0，SafeArea 不增加额外高度。
      double headerHeight(WidgetTester tester) =>
          tester.getSize(find.byType(PrimaryHeader)).height;

      testWidgets('无 actions：行高不被标题文字压低', (tester) async {
        await tester.pumpWidget(buildHost(const PrimaryHeader(title: '标题')));
        expect(headerHeight(tester), 38,
            reason: '仅标题时行高应为最小高度 30（8+30+0=38），不随文字行高收缩');
      });

      testWidgets('含 HeaderIconAction：行高不被默认 48 热区撑大', (tester) async {
        await tester.pumpWidget(buildHost(PrimaryHeader(
          title: '标题',
          actions: [HeaderIconAction(icon: Icons.refresh, onPressed: () {})],
        )));
        expect(headerHeight(tester), 38,
            reason: '含功能键时行高应仍为 30（热区 30x30），与无 action 页面一致');
      });

      testWidgets('含 HeaderTextAction：文字链不撑大行高', (tester) async {
        await tester.pumpWidget(buildHost(PrimaryHeader(
          title: '标题',
          actions: [HeaderTextAction(label: '今天', onPressed: () {})],
        )));
        expect(headerHeight(tester), 38,
            reason: '含文字链时行高应仍为 30，与图标键页面一致');
      });

      testWidgets('含副标题：内容高度超过 30，行高随内容增高', (tester) async {
        await tester.pumpWidget(
            buildHost(const PrimaryHeader(title: '标题', subtitle: '副标题')));
        expect(headerHeight(tester), greaterThan(40),
            reason: '含副标题时内容 (~36px) 超过最小高度 30，行高应随内容增高（>40）');
      });
    });

    testWidgets('onTitleTap 非空时标题可点击并触发回调', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(buildHost(
        PrimaryHeader(title: '2026年7月', onTitleTap: () => tapped++),
      ));

      await tester.tap(find.text('2026年7月'));
      await tester.pump();
      expect(tapped, 1, reason: '点击标题应触发 onTitleTap（首页月份/统计账期入口）');
    });

    testWidgets('onTitleTap 为 null 时标题区无 InkWell（纯文本无热区）', (tester) async {
      await tester.pumpWidget(buildHost(const PrimaryHeader(title: '纯文本')));

      expect(
        find.ancestor(of: find.text('纯文本'), matching: find.byType(InkWell)),
        findsNothing,
        reason: 'onTitleTap 为 null 时标题不应有可点热区（与禁用态外观一致）',
      );
    });
  });

  group('HeaderIconAction 统一图标键', () {
    testWidgets('正常态渲染 20px Icon、热区 30x30 且 onPressed 透传', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(buildHost(
        HeaderIconAction(icon: Icons.refresh, onPressed: () => pressed++),
      ));

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.refresh));
      expect(iconWidget.size, 20,
          reason: '图标键图标应固定 20px（与首行最小高度 30 对齐）');
      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.constraints, const BoxConstraints(minWidth: 30, minHeight: 30),
          reason: '图标键热区应固定 30x30，防止裸 IconButton 默认 48 热区撑大首行');
      await tester.tap(find.byType(IconButton));
      expect(pressed, 1);
    });

    testWidgets('spinning 态显示 20x20 转圈并禁用点击', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(buildHost(
        HeaderIconAction(
          icon: Icons.refresh,
          spinning: true,
          onPressed: () => pressed++,
        ),
      ));

      // 转圈替换图标，且尺寸收敛为 20x20
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);
      final spinnerBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(spinnerBox.width, 20);
      expect(spinnerBox.height, 20);

      // spinning 时 onPressed 被强制置 null（禁用态）
      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.onPressed, isNull,
          reason: 'spinning 时应禁用点击，避免刷新中重复触发');
    });
  });

  group('HeaderTextAction 统一文字链', () {
    testWidgets('文字规格锁定为 14px / w600', (tester) async {
      await tester.pumpWidget(buildHost(
        HeaderTextAction(label: '回到当月', onPressed: () {}),
      ));

      final text = tester.widget<Text>(find.text('回到当月'));
      expect(text.style?.fontSize, 14, reason: '文字链字号全局统一为 14');
      expect(text.style?.fontWeight, FontWeight.w600,
          reason: '文字链字重全局统一为 w600');
    });

    testWidgets('点击透传 onPressed', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(buildHost(
        HeaderTextAction(label: '今天', onPressed: () => pressed++),
      ));

      await tester.tap(find.text('今天'));
      expect(pressed, 1);
    });
  });
}
