/// 头像全屏预览页（AvatarPreviewPage）组件测试。
///
/// 覆盖 2026-07-24 我的页头部调整后的核心行为：
///   1. 有头像：黑色背景，居中显示圆形大图（InteractiveViewer）。
///   2. 无头像：黑色背景，居中显示 person 图标，无删除按钮。
///   3. 有头像：底部显示上传 + 删除两个按钮。
///   4. 无头像：底部仅显示上传按钮，无删除按钮。
///   5. 关闭按钮在左上角，点击关闭当前页面。
///   6. 点击上传按钮触发 onUpload 回调。
///   7. 点击删除按钮触发 onDelete 回调。
///   8. 单点屏幕空白处可收起（tap-to-dismiss）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/avatar_preview_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 构建带 Material 上下文的预览页（Navigator 路由需要 Material 祖先）。
  ///
  /// 使用 [MaterialApp] 而不是裸 [Material]，是因为 IconButton 的
  /// `tooltip` 需要 `MaterialLocalizations`，裸环境会抛 "No MaterialLocalizations found"。
  Widget buildHarness({
    String? avatarPath,
    required String uploadLabel,
    required VoidCallback onUpload,
    String? deleteLabel,
    VoidCallback? onDelete,
  }) {
    return MaterialApp(
      // 不挂 localizationsDelegates：测试只校验按钮位置与文案，
      // 不依赖任何本地化文案分支；tooltip 默认空串即可。
      home: AvatarPreviewPage(
        // 路径可以是任意字符串，Image.file 在测试环境因缺少平台插件会走
        // errorBuilder 分支（返回 broken_image 图标），不影响布局断言。
        avatarPath: avatarPath,
        uploadLabel: uploadLabel,
        onUpload: onUpload,
        deleteLabel: deleteLabel,
        onDelete: onDelete,
      ),
    );
  }

  // ── 有头像场景 ──────────────────────────────────────────────

  testWidgets('有头像：背景黑色，居中显示头像图片', (tester) async {
    await tester.pumpWidget(buildHarness(
      avatarPath: '/tmp/test_avatar.jpg',
      uploadLabel: '上传新头像',
      onUpload: () {},
    ));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.black);

    // 居中大图（InteractiveViewer 内层 Image.file 在测试环境渲染为 broken image）
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('有头像：底部显示上传 + 删除两个按钮', (tester) async {
    await tester.pumpWidget(buildHarness(
      avatarPath: '/tmp/test_avatar.jpg',
      uploadLabel: '上传新头像',
      onUpload: () {},
      deleteLabel: '删除头像',
      onDelete: () {},
    ));

    expect(find.text('上传新头像'), findsOneWidget);
    expect(find.text('删除头像'), findsOneWidget);
  });

  // ── 无头像场景 ──────────────────────────────────────────────

  testWidgets('无头像：居中显示 person 图标，无删除按钮', (tester) async {
    await tester.pumpWidget(buildHarness(
      avatarPath: null,
      uploadLabel: '上传新头像',
      onUpload: () {},
      deleteLabel: '删除头像',
      onDelete: () {},
    ));

    // 无头像 → 居中显示 person 图标（虚拟用户同等占位）
    expect(find.byIcon(AppIcons.person), findsOneWidget);
    // 无头像 → 不显示删除按钮（即使传了 deleteLabel/onDelete）
    expect(find.text('删除头像'), findsNothing);
    // 始终显示上传按钮
    expect(find.text('上传新头像'), findsOneWidget);
    // 无头像 → 不渲染 InteractiveViewer
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  // ── 关闭按钮 ──────────────────────────────────────────────

  testWidgets('关闭按钮在左上角，点击关闭当前页面', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AvatarPreviewPage(
                    avatarPath: '/tmp/x.jpg',
                    uploadLabel: '上传新头像',
                    onUpload: () {},
                  ),
                ));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 找到关闭按钮（Icons.close）
    final closeFinder = find.byIcon(Icons.close);
    expect(closeFinder, findsOneWidget);

    // 左上角：x 坐标应明显小于屏幕中线，y 坐标应明显小于屏幕中线
    final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    final closeCenter = tester.getCenter(closeFinder);
    expect(closeCenter.dx, lessThan(screenSize.width / 2),
        reason: '关闭按钮应在左半屏');
    expect(closeCenter.dy, lessThan(screenSize.height / 2),
        reason: '关闭按钮应在上半屏');

    // 点击关闭：pop 当前路由
    await tester.tap(closeFinder);
    await tester.pumpAndSettle();
    // pop 后回到初始页（'open' 按钮可见），不再有 AvatarPreviewPage
    expect(find.text('open'), findsOneWidget);
    expect(find.byType(AvatarPreviewPage), findsNothing);
  });

  // ── 回调触发 ──────────────────────────────────────────────

  testWidgets('点击上传按钮触发 onUpload 回调', (tester) async {
    int uploadTaps = 0;
    await tester.pumpWidget(buildHarness(
      avatarPath: '/tmp/test_avatar.jpg',
      uploadLabel: '上传新头像',
      onUpload: () => uploadTaps++,
      deleteLabel: '删除头像',
      onDelete: () {},
    ));

    // 点击上传按钮：定位包含文案的 InkWell
    final uploadFinder = find.ancestor(
      of: find.text('上传新头像'),
      matching: find.byType(InkWell),
    );
    expect(uploadFinder, findsOneWidget);
    await tester.tap(uploadFinder);
    await tester.pump();

    expect(uploadTaps, 1, reason: '上传按钮应只触发一次回调');
  });

  testWidgets('点击删除按钮触发 onDelete 回调', (tester) async {
    int deleteTaps = 0;
    await tester.pumpWidget(buildHarness(
      avatarPath: '/tmp/test_avatar.jpg',
      uploadLabel: '上传新头像',
      onUpload: () {},
      deleteLabel: '删除头像',
      onDelete: () => deleteTaps++,
    ));

    final deleteFinder = find.ancestor(
      of: find.text('删除头像'),
      matching: find.byType(InkWell),
    );
    expect(deleteFinder, findsOneWidget);
    await tester.tap(deleteFinder);
    await tester.pump();

    expect(deleteTaps, 1, reason: '删除按钮应只触发一次回调');
  });

  // ── 单点屏幕收起 ──────────────────────────────────────────────

  testWidgets('单点屏幕空白处可收起预览页', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AvatarPreviewPage(
                    avatarPath: '/tmp/x.jpg',
                    uploadLabel: '上传新头像',
                    onUpload: () {},
                  ),
                ));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 确认预览页已打开
    expect(find.byType(AvatarPreviewPage), findsOneWidget);

    // 点击屏幕右上角空白处（远离左上关闭按钮和底部操作条）
    final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.tapAt(Offset(screenSize.width * 0.85, screenSize.height * 0.15));
    await tester.pumpAndSettle();

    // 单点空白处应 pop 预览页，回到初始页
    expect(find.byType(AvatarPreviewPage), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
