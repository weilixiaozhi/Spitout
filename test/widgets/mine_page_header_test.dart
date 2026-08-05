/// 我的页头部（MinePageHeader）组件测试。
///
/// 覆盖「我的页头部抽离独立文件」重构后的核心行为：
///   1. 未设置昵称时显示 slogan，无时段问候图标。
///   2. 已设置昵称时显示「问候语+昵称」，并带时段图标。
///   3. 点击昵称弹出编辑弹窗，保存后写入 displayNameProvider 并弹 Toast。
///   4. 取消弹窗不改动昵称。
///   5. 无头像时点击头像进入全屏预览页（显示 person 图标，无删除按钮）。
///
/// 依赖处理：
///   - SharedPreferences 走 setMockInitialValues，avatarStorage.getAvatarPath
///     读到空值提前返回 null，不触碰 path_provider / image_picker 平台插件。
///   - avatarPathProvider / displayNameProvider 用 ProviderScope override，
///     绕开持久化与云同步 listener（那些挂在 displayNameInitProvider 上，
///     测试不 watch 它，无副作用）。
///
/// 注意：昵称编辑弹窗的 TextField autofocus 光标闪烁会持续调度帧，
/// pumpAndSettle 会超时，弹窗相关断言一律用分步 pump(Duration) 代替。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/ui/avatar_providers.dart';
import 'package:spitout/providers/sync/sync_providers.dart';
import 'package:spitout/providers/ui/theme_providers.dart';
import 'package:spitout/services/storage/avatar_storage.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/avatar_preview_page.dart';
import 'package:spitout/widgets/mine_page_header.dart';
import 'package:spitout/widgets/person_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 中文文案真值：直接走 delegate 加载，避免硬编码文案导致 arb 改动后测试误挂。
  late AppLocalizations l10n;

  setUp(() async {
    // 空偏好：avatarStorage.getAvatarPath 读到 null → 无头像分支，
    // 不会继续调用 getApplicationDocumentsDirectory（测试环境无该平台插件）。
    SharedPreferences.setMockInitialValues({});
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  /// 构建带 provider override 与本地化上下文的测试宿主。
  ///
  /// 用 [MaterialApp] 而不是裸 [Material]：头部点击会拉 Navigator 路由/
  /// BottomSheet/Dialog，且 showToast 依赖 Overlay，均需 MaterialApp 祖先。
  Widget buildHarness({String displayName = ''}) {
    return ProviderScope(
      overrides: [
        // 无云同步头像：直接给 null，等价于「未从服务端拉到头像」。
        avatarPathProvider.overrideWith((ref) async => null),
        displayNameProvider.overrideWithBuild((ref, notifier) => displayName),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const Scaffold(body: MinePageHeader()),
      ),
    );
  }

  /// 等头部初始化完成：_loadAvatar 走 mock SharedPreferences，一两个事件循环
  /// 即可返回。加载期间头像位是 CircularProgressIndicator（持续动画），
  /// 不能用 pumpAndSettle，故固定分步 pump。
  Future<void> pumpHeaderReady(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// 从 widget 树里取 ProviderContainer，读取 provider 真值断言。
  ProviderContainer containerOf(WidgetTester tester) {
    return ProviderScope.containerOf(tester.element(find.byType(MinePageHeader)));
  }

  testWidgets('未设置昵称：显示 slogan，无时段图标，头像为占位 person 图标',
      (tester) async {
    await tester.pumpWidget(buildHarness(displayName: ''));
    await pumpHeaderReady(tester);

    // 头部文案为 slogan（未设置昵称分支）
    expect(find.text(l10n.mineSlogan), findsOneWidget);
    // 时段问候图标仅在已设置昵称时出现；此时头部仅剩无头像占位的 person 图标。
    expect(find.byType(Icon), findsOneWidget);
    // 无头像 → 占位 person 图标（虚拟用户同等）
    expect(find.byType(PersonAvatar), findsOneWidget);
  });

  testWidgets('已设置昵称：显示问候语+昵称并带时段图标', (tester) async {
    await tester.pumpWidget(buildHarness(displayName: '小明'));
    await pumpHeaderReady(tester);

    // mineGreetingNamed 拼接「问候语,昵称」，具体问候语随测试运行时段变化，
    // 故只断言昵称包含在文案里。
    expect(find.textContaining('小明'), findsOneWidget);
    // 时段图标（太阳/月亮）恰好一个；此时头像仍为占位 person 图标，
    // 故按图标内容排除 person 后再断言。
    final periodIcons = tester
        .widgetList<Icon>(find.byType(Icon))
        .where((icon) => icon.icon != AppIcons.person)
        .length;
    expect(periodIcons, 1);
    // 无头像 → 占位 person 图标（虚拟用户同等）
    expect(find.byType(PersonAvatar), findsOneWidget);
  });

  testWidgets('点击昵称弹出编辑弹窗，保存后更新 displayNameProvider 并弹 Toast',
      (tester) async {
    await tester.pumpWidget(buildHarness(displayName: ''));
    await pumpHeaderReady(tester);

    // 点击昵称行（此时显示 slogan）拉起编辑弹窗
    await tester.tap(find.text(l10n.mineSlogan));
    // 弹窗含 autofocus TextField（光标闪烁持续调度帧），用分步 pump 等动画
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget);

    // 输入新昵称并保存
    await tester.enterText(find.byType(TextField), '新昵称');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, l10n.commonSave));
    // 等弹窗退场动画结束、异步保存逻辑（含 showToast）执行完
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing);
    expect(containerOf(tester).read(displayNameProvider), '新昵称');
    // 保存成功 Toast
    expect(find.text(l10n.mineDisplayNameSaved), findsOneWidget);

    // Toast 内部用 Future.delayed(2s) 自动移除，测试框架要求用例结束时
    // 无 pending Timer，故推进时间让定时器触发、OverlayEntry 移除。
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text(l10n.mineDisplayNameSaved), findsNothing);
  });

  testWidgets('取消编辑弹窗不修改昵称', (tester) async {
    await tester.pumpWidget(buildHarness(displayName: '原昵称'));
    await pumpHeaderReady(tester);

    await tester.tap(find.textContaining('原昵称'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget);

    // 改了内容但点取消 → provider 应保持原值
    await tester.enterText(find.byType(TextField), '想改的名');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing);
    expect(containerOf(tester).read(displayNameProvider), '原昵称');
  });

  testWidgets('无头像点击头像：进入全屏预览页，显示 person 图标，无删除按钮',
      (tester) async {
    await tester.pumpWidget(buildHarness(displayName: ''));
    await pumpHeaderReady(tester);

    // 点击头像（占位 PersonAvatar）→ 进入全屏预览页
    // 头部只有一个 PersonAvatar（占位），全屏预览页里也有一个 person 图标（size=120）
    await tester.tap(find.byType(PersonAvatar));
    await tester.pumpAndSettle();

    // 全屏预览页已打开
    expect(find.byType(AvatarPreviewPage), findsOneWidget);
    // 上传按钮始终显示
    expect(find.text(l10n.mineAvatarUploadNew), findsOneWidget);
    // 无头像时不提供删除按钮
    expect(find.text(l10n.mineAvatarDelete), findsNothing);
  });

  testWidgets('有头像时点击删除：触发删除逻辑且非云模式跳过云端',
      (tester) async {
    // 不构造任何真实文件、不 mock path_provider、不触碰异步 dart:io：
    // 本机 flutter test 环境下 File/Directory 等异步文件 I/O 会挂起，无法做
    // 「有头像」端到端 UI 验证（连 Image.file 的底层解码也会挂）。这里改用
    // 仅 SharedPreferences 持有远端版本记录、且不设置本地路径的方式来驱动删除
    // 逻辑：
    //   - avatarPathProvider 返回非空假路径，让 UI 进入「有头像」分支
    //     （Image.widget 存在即可，其底层图片解码挂起不影响点击流程）；
    //   - 不设置 user_avatar_path，使 avatarStorage.getAvatarPath 早返回 null，
    //     从而 deleteAvatar 全程不触碰 File/Directory，本机可安全执行；
    //   - 非 Spitout Cloud 模式（provider 为 null）下，云端删除分支被跳过。
    SharedPreferences.setMockInitialValues({
      'user_avatar_remote_version': 3,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 非空假路径：驱动 UI 进入「有头像」分支（不依赖真实文件）。
          avatarPathProvider
              .overrideWith((ref) async => 'avatars/fake_avatar.png'),
          // 非 Spitout Cloud 模式：云端删除分支应直接跳过，不发任何请求。
          spitoutCloudProviderInstance.overrideWith((ref) async => null),
          displayNameProvider.overrideWithBuild((ref, notifier) => ''),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(body: MinePageHeader()),
        ),
      ),
    );
    await pumpHeaderReady(tester);

    // 有头像 → 头部存在 Image.widget（底层解码挂起不影响后续点击）。
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.byType(AvatarPreviewPage), findsOneWidget);
    // 有头像时删除按钮可见
    expect(find.text(l10n.mineAvatarDelete), findsOneWidget);

    // 点击「删除头像」：关闭预览页并执行删除（本地记录清除 + 云端跳过）。
    await tester.tap(find.text(l10n.mineAvatarDelete));
    await tester.pumpAndSettle();

    // 推进时间让 LoggerService 的 2s 节流保存定时器触发并清空，
    // 避免测试结束时仍有 pending timer 导致断言失败。该定时器落盘走
    // SharedPreferences mock，不触碰真实异步文件 I/O，本机可安全执行。
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    // 预览页已关闭
    expect(find.byType(AvatarPreviewPage), findsNothing);
    // 本地不应残留路径记录（未设置 user_avatar_path，删除逻辑早返回）。
    expect(await avatarStorage.getAvatarPath(), isNull,
        reason: '不应残留本地路径记录');
    // 远端版本号记录被清除（删除逻辑副作用，不依赖文件 I/O）。
    expect(await avatarStorage.getStoredRemoteVersion(), 0,
        reason: '远端版本号记录应被清除');
  });

  testWidgets('布局：头像在上、昵称在下，整体左右居中', (tester) async {
    await tester.pumpWidget(buildHarness(displayName: '小明'));
    await pumpHeaderReady(tester);

    // 头像（PersonAvatar）中心应在昵称文本中心上方
    final avatarCenter = tester.getCenter(find.byType(PersonAvatar));
    final nameCenter = tester.getCenter(find.textContaining('小明'));
    expect(avatarCenter.dy, lessThan(nameCenter.dy),
        reason: '头像应在昵称上方');

    // 两者 x 坐标应接近屏幕水平中线（居中布局）
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(avatarCenter.dx, closeTo(screenWidth / 2, 60),
        reason: '头像应左右居中');
    expect(nameCenter.dx, closeTo(screenWidth / 2, 60),
        reason: '昵称应左右居中');
  });
}
