import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cloud_sync_supabase/flutter_cloud_sync_supabase.dart';
import 'package:flutter_cloud_sync_webdav/flutter_cloud_sync_webdav.dart';
import 'package:flutter_cloud_sync_s3/flutter_cloud_sync_s3.dart';
import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'router.dart';
import 'widgets/app_route.dart';
import 'widgets/login_2fa_challenge_view.dart';
import 'theme/app_theme.dart';
import 'package:spitout/providers/providers.dart';
import 'services/notification/notification_factory.dart';
import 'pages/auth/welcome_page.dart';
import 'pages/auth/app_lock_screen.dart';
import 'services/system/reminder_monitor_service.dart';
import 'core/logging/logger_service.dart';
import 'l10n/app_localizations.dart';
import 'dart:ui';

import 'dart:async';
import 'theme/icons/app_icons.dart';


/// 全局 navigator key — 给 service 层(没有 BuildContext)push 路由使用。
/// 当前用途:Spitout Cloud 登录拿到 requires_2fa 时弹出 [Login2FAChallengeView]。
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Composition Root：注册云同步 adapter 后端（插件化自注册）。
  // 核心包 flutter_cloud_sync 不感知任何 adapter；必须在使用
  // createCloudServices 之前完成注册，否则对应后端会抛 StateError。
  registerSupabaseBackend();
  registerWebDavBackend();
  registerS3Backend();
  registerSpitoutCloudBackend();

  // Edge-to-edge:让 Flutter 自己把内容(PrimaryHeader/皮肤)画到状态栏底下,
  // 而不是请求系统给状态栏刷色 —— 后者在部分 OEM(华为 EMUI/鸿蒙)上会被无视,
  // 导致 header 背景无法渗透到状态栏。iOS 本来就是全屏布局,不受影响。
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // 初始化日志系统（确保原生日志桥接就绪）
  logger.info('App', '应用启动，日志系统已初始化');

  // 初始化时区（必须在通知服务之前完成）
  try {
    NotificationFactory.initializeTimeZone();
  } catch (e) {
    logger.warning('App', '时区初始化失败（可能在不支持的平台上运行）: $e');
  }

  // 初始化通知服务
  try {
    final notificationUtil = NotificationFactory.getInstance();
    await notificationUtil.initialize();
  } catch (e) {
    logger.warning('App', '通知服务初始化失败（可能在不支持的平台上运行）: $e');
  }

  // 恢复用户的记账提醒设置（应用重启后自动恢复提醒）
  await _restoreUserReminder();

  // 启动提醒监控服务（监听应用生命周期，自动恢复丢失的提醒）
  try {
    ReminderMonitorService().startMonitoring();
  } catch (e) {
    logger.warning('App', '提醒监控服务启动失败（可能在不支持的平台上运行）: $e');
  }

  // 创建全局ProviderContainer（需要在周期交易生成之前创建，因为需要使用 repositoryProvider）
  final container = ProviderContainer();

  // 注册 Spitout Cloud 2FA challenge handler。当 server 返回 requires_2fa=true,
  // service 层会调这个 handler 弹出 Login2FAChallengeDialog 让用户输码。
  // 验证失败留在对话框就地展示错误,验证通过 / 用户取消才关闭。
  SpitoutCloudProvider.globalTwoFactorHandler = (request) async {
    final ctx = globalNavigatorKey.currentContext;
    if (ctx == null) {
      // 极端场景:cloud auth 在 navigator 还没 attach 之前触发,只能视为取消
      return false;
    }
    return await Login2FAChallengeDialog.show(ctx, request);
  };

  // 后台静默预加载：在 runApp 之前完成数据加载
  // 原生启动图覆盖整个加载过程，用户无感知
  // runApp 后 appInitState 已是 ready，闸门直接放行，首页首次渲染即有数据
  await Future.wait([
    container.read(welcomeCheckProvider.future),
    container.read(appSplashInitProvider.future),
  ]);

  runApp(UncontrolledProviderScope(
    container: container,
    child: const MainApp(),
  ));
}

/// 恢复用户之前设置的记账提醒
///
/// 问题场景：
/// - 应用被系统杀死后，通知任务会丢失
/// - 应用更新后，通知任务会被清除
/// - 手机重启后，通知任务需要重新设置
///
/// 解决方案：
/// - 在应用启动时检查用户是否开启了提醒
/// - 如果开启了，重新设置通知任务
Future<void> _restoreUserReminder() async {
  try {
    logger.info('Reminder', '检查并恢复记账提醒...');
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('reminder_enabled') ?? false;

    if (isEnabled) {
      final hour = prefs.getInt('reminder_hour') ?? 21;
      final minute = prefs.getInt('reminder_minute') ?? 0;
      logger.info('Reminder', '发现用户已启用记账提醒: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
      logger.info('Reminder', '正在重新设置提醒任务...');

      try {
        final notificationUtil = NotificationFactory.getInstance();
        await notificationUtil.scheduleDailyReminder(
          id: 1001,
          title: '记账提醒',
          body: '别忘了记录今天的收支哦 💰',
          hour: hour,
          minute: minute,
        );
        logger.info('Reminder', '记账提醒已成功恢复');
      } catch (e) {
        logger.warning('Reminder', '记账提醒设置失败（可能在不支持的平台上运行）: $e');
      }
    } else {
      logger.info('Reminder', '用户未启用记账提醒，跳过恢复');
    }
  } catch (e) {
    logger.warning('Reminder', '恢复记账提醒失败: $e');
    // 不抛出异常，避免影响应用启动
  }
}

class NoGlowScrollBehavior extends MaterialScrollBehavior {
  const NoGlowScrollBehavior();
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child; // 去除 Android 上的发光效果，避免顶部出现一抹红
  }
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  // 根据初始化状态和欢迎页面状态决定显示哪个页面
  Widget _getHomePage(AppInitState initState, WidgetRef ref) {
    // 首先检查是否需要显示欢迎页面
    final shouldShowWelcome = ref.watch(shouldShowWelcomeProvider);
    if (shouldShowWelcome) {
      return const WelcomePage();
    }

    // 欢迎页面完成后，根据初始化状态显示对应页面
    // 闸门安全网：正常流程下 appSplashInitProvider 已在 main() 中完成，
    // appInitState 已是 ready，此处不会触发。
    // 仅作为防御性兜底（如 main() 中预加载异常未执行）。
    if (initState != AppInitState.ready) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SizedBox.shrink(),
      );
    }

    // 检查是否需要显示锁屏
    final isLocked = ref.watch(isAppLockedProvider);
    if (isLocked) {
      return const AppLockScreen();
    }

    return const SpitoutApp();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 首先检查是否需要显示欢迎页面
    ref.watch(welcomeCheckProvider);

    // 检查应用初始化状态
    final initState = ref.watch(appInitStateProvider);
    final selectedLanguage = ref.watch(languageProvider);

    // 如果是启屏状态，启动初始化
    if (initState == AppInitState.splash) {
      ref.watch(appSplashInitProvider);
    }

    // 周期交易生成已统一在 appSplashInitProvider 中处理

    final platform = Theme.of(context).platform; // 当前平台

    // 亮暗主题均由 SpitoutTheme 统一定义（ColorScheme.fromSeed + 全部子主题内联），
    // main.dart 不做任何 copyWith 覆盖。
    final theme = SpitoutTheme.lightTheme(platform: platform);

    // 不干预系统字体缩放：以手机系统缩放为准。
    return MaterialApp(
        navigatorKey: globalNavigatorKey,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        scrollBehavior: const NoGlowScrollBehavior(),
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: SpitoutTheme.darkTheme(platform: platform), // ⭐ 暗黑主题
        themeMode: ref.watch(themeModeProvider),         // ⭐ 使用 provider 支持手动切换
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('zh'),
          Locale('zh', 'TW'),
          Locale('ko'),
        ],
        locale: selectedLanguage,
        builder: (context, child) {
          final showPrivacy = ref.watch(showPrivacyScreenProvider);
          return Stack(
            children: [
              // 输入框焦点收起交由 Flutter 默认行为（EditableText.onTapOutside）及各处显式 FocusManager.unfocus() 处理。
              child ?? const SizedBox.shrink(),
              if (showPrivacy)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      alignment: Alignment.center,
                      child: Icon(
                        AppIcons.lock,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        // 显式命名根路由，便于路由名调试与埋点识别
        home: _getHomePage(initState, ref),
        onGenerateRoute: (settings) {
          // 先委托给全局路由层：由 router.dart 统一解析命名路由。
          final named = appRoute(settings);
          if (named != null) return named;
          if (settings.name == Navigator.defaultRouteName ||
              settings.name == '/') {
            return appPageRoute(
                builder: (_) => _getHomePage(initState, ref),
                settings: const RouteSettings(name: '/'));
          }
          return null;
        },
    );
  }
}


