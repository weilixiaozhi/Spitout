import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/cloud/spitout_cloud.dart'
    show CloudBackendType, CloudServiceConfig;
import 'package:spitout/cloud/auth_error_localizer.dart' as auth_error_localizer;
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/widgets.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final emailCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  String? errorText;
  bool busy = false;
  bool _showPwd = false;
  bool _rememberAccount = false;

  @override
  void initState() {
    super.initState();
    // 延迟加载凭证，确保 provider 已初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedCredentials();
    });
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final cloudConfig = await ref.read(activeCloudConfigProvider.future);
      String? savedEmail;
      String? savedPassword;
      if (cloudConfig.type == CloudBackendType.supabase) {
        savedEmail = cloudConfig.supabaseEmail;
        savedPassword = cloudConfig.supabasePassword;
      } else if (cloudConfig.type == CloudBackendType.spitoutCloud) {
        // Spitout Cloud：跟 Supabase 一样，勾选"记住账号"时同时存邮箱+密码，
        // 作为 token 失效时的兜底登录途径（见 spitoutCloudProviderInstance
        // 里的 fallback signInWithEmail）。
        savedEmail = cloudConfig.spitoutCloudEmail;
        savedPassword = cloudConfig.spitoutCloudPassword;
      } else {
        return;
      }

      if (savedEmail != null && savedEmail.isNotEmpty && mounted) {
        setState(() {
          emailCtrl.text = savedEmail!;
          if (savedPassword != null && savedPassword.isNotEmpty) {
            pwdCtrl.text = savedPassword;
            _rememberAccount = true;
          }
        });
      }
    } catch (e) {
      logger.warning('auth', '加载保存的账号密码失败: $e');
    }
  }

  Future<void> _saveCredentials(String email, String password) async {
    try {
      final cloudConfig = await ref.read(activeCloudConfigProvider.future);
      final store = ref.read(cloudServiceStoreProvider);

      if (cloudConfig.type == CloudBackendType.supabase) {
        // Supabase 仍旧保留"记住账号"时同时存密码（老 SDK 没有 refresh token 持久化）。
        final updatedConfig = CloudServiceConfig(
          type: cloudConfig.type,
          name: cloudConfig.name,
          supabaseUrl: cloudConfig.supabaseUrl,
          supabaseAnonKey: cloudConfig.supabaseAnonKey,
          supabaseBucket: cloudConfig.supabaseBucket ?? 'spitout-backups',
          supabaseEmail: _rememberAccount ? email : null,
          supabasePassword: _rememberAccount ? password : null,
        );
        await store.saveOnly(updatedConfig);
        ref.invalidate(supabaseConfigProvider);
        ref.invalidate(activeCloudConfigProvider);
        logger.info('auth', 'Supabase 账号密码保存状态：${_rememberAccount ? "已保存" : "已清除"}');
        return;
      }

      if (cloudConfig.type == CloudBackendType.spitoutCloud) {
        // Spitout Cloud：勾选"记住账号"时存邮箱+密码 —— token 机制平时够用，
        // 但 token 失效 / 老版本升级 / 本地 SharedPreferences 被清等场景都靠
        // 这份密码做兜底自动登录。
        final updatedConfig = CloudServiceConfig(
          type: cloudConfig.type,
          name: cloudConfig.name,
          spitoutCloudBaseUrl: cloudConfig.spitoutCloudBaseUrl,
          spitoutCloudApiPrefix: cloudConfig.spitoutCloudApiPrefix,
          spitoutCloudEmail: _rememberAccount ? email : null,
          spitoutCloudPassword: _rememberAccount ? password : null,
        );
        await store.saveOnly(updatedConfig);
        ref.invalidate(spitoutCloudConfigProvider);
        ref.invalidate(activeCloudConfigProvider);
        logger.info('auth',
            'Spitout Cloud 账号密码保存状态：${_rememberAccount ? "已保存" : "已清除"}');
      }
    } catch (e, st) {
      logger.error('auth', '保存账号密码失败', e, st);
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    pwdCtrl.dispose();
    super.dispose();
  }

  bool isValidEmail(String s) {
    final t = s.trim();
    final emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRe.hasMatch(t);
  }

  /// 登录失败文案：委托给共享 helper（[auth_error_localizer.friendlyAuthError]）。
  ///
  /// 设计意图：错误分类逻辑统一放在 `cloud/auth_error_localizer.dart`，
  /// 三处登录逻辑共享同一套分类规则。
  ///
  /// 注意：方法名与共享函数同名，故调用时显式带库前缀
  /// `auth_error_localizer.friendlyAuthError`，避免递归调用到自身。
  String friendlyAuthError(Object? e) {
    return auth_error_localizer.friendlyAuthError(e, context);
  }

  // 恢复流程在登录后回到“我的”页时由该页触发，不在登录页内执行

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(12);

    // 检测云服务类型
    final cloudConfig = ref.watch(activeCloudConfigProvider);
    if (cloudConfig.hasValue && cloudConfig.value!.type == CloudBackendType.webdav) {
      // WebDAV 不需要登录页面
      return Scaffold(
        backgroundColor: SpitoutTokens.scaffoldBackground(context),
        body: Column(
          children: [
            PrimaryHeader(title: AppLocalizations.of(context).authLogin, showBack: true),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: SpitoutTokens.surface(context),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: SpitoutTokens.isDark(context) ? null : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.checkCircle,
                          size: 64,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          AppLocalizations.of(context).webdavConfiguredTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: SpitoutTokens.textPrimary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.of(context).webdavConfiguredMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: SpitoutTokens.textSecondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(AppLocalizations.of(context).commonBack),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: SpitoutTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(title: AppLocalizations.of(context).authLogin, showBack: true),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    decoration: BoxDecoration(
                      color: SpitoutTokens.surface(context),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: SpitoutTokens.isDark(context) ? null : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(labelText: AppLocalizations.of(context).authEmail),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: pwdCtrl,
                          obscureText: !_showPwd,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context).authPassword,
                            suffixIcon: IconButton(
                              icon: Icon(_showPwd
                                  ? AppIcons.visibilityOff
                                  : AppIcons.visibility),
                              onPressed: () =>
                                  setState(() => _showPwd = !_showPwd),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _rememberAccount = !_rememberAccount;
                            });
                          },
                          child: Row(
                            children: [
                              Checkbox(
                                value: _rememberAccount,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberAccount = value ?? false;
                                  });
                                },
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalizations.of(context).authRememberAccount,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: SpitoutTokens.textPrimary(context),
                                      ),
                                    ),
                                    Text(
                                      AppLocalizations.of(context).authRememberAccountHint,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: SpitoutTokens.textSecondary(context),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (errorText != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              errorText!,
                              style: TextStyle(color: SpitoutTokens.error(context)),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: radius),
                                  ),
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          final email = emailCtrl.text.trim();
                                          final pwd = pwdCtrl.text;
                                          logger.info('auth', '开始登录：邮箱=$email');
                                          if (!isValidEmail(email)) {
                                            setState(() => errorText =
                                                AppLocalizations.of(context)
                                                    .authInvalidEmail);
                                            return;
                                          }
                                          // 不本地校验密码强度:密码规则由服务端决定,
                                          // App 不二次猜测(否则会把服务端能登录的合法
                                          // 密码挡在门外,见 issue #358)。
                                          setState(() {
                                            busy = true;
                                            errorText = null;
                                          });
                                          try {
                                            final auth = await ref.read(authServiceProvider.future);
                                            await auth.signInWithEmail(
                                                email: email, password: pwd);
                                            if (!context.mounted) return;
                                            logger.info('auth', '登录成功：邮箱=$email');

                                            // Save credentials if "remember account" is checked
                                            await _saveCredentials(email, pwd);

                                            // 再次检查 mounted（_saveCredentials 产生了新的 async gap）
                                            if (!context.mounted) return;

                                            // 刷新认证服务和同步服务以触发状态更新
                                            ref.invalidate(authServiceProvider);
                                            // 治本:登录成功且 session 已持久化后,invalidate 缓存的
                                            // cloud provider,让它以新 session 重建。spitoutCloudProviderInstance
                                            // 是 FutureProvider,登录前已缓存且内部 _session 为 null;不
                                            // invalidate 则 sync 链带 null 会话 → readLedgers() 抛
                                            // CloudNotAuthenticatedException 被吞 → 旧账本一条都清不掉。
                                            // syncServiceProvider 内部 watch 了该 provider,会级联重建。
                                            ref.invalidate(spitoutCloudProviderInstance);
                                            ref.invalidate(syncServiceProvider);

                                            // 刷新同步状态
                                            ref
                                                .read(syncStatusRefreshProvider
                                                    .notifier)
                                                .tick();
                                            // 直接切到"我的"页并关闭登录页
                                            ref
                                                .read(bottomTabIndexProvider
                                                    .notifier)
                                                .set(3); // Mine tab index
                                            final can = Navigator.of(context)
                                                .canPop();
                                            logger.info('nav',
                                                'login: success -> switch tab to Mine, canPop=$can; pop login');
                                            if (can) {
                                              Navigator.of(context).pop();
                                            }
                                          } catch (e, st) {
                                            final msg = friendlyAuthError(e);
                                            final detailedMsg = 'Type: ${e.runtimeType}, Message: $e';
                                            logger.error(
                                                'auth',
                                                '登录失败：邮箱=$email，用户友好信息=$msg，详细错误=$detailedMsg',
                                                e,
                                                st);
                                            setState(() => errorText = '$msg\n\n调试信息: $detailedMsg');
                                          } finally {
                                            if (mounted) {
                                              setState(() => busy = false);
                                            }
                                          }
                                        },
                                  child: busy
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : Text(AppLocalizations.of(context).authLogin),
                                ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 对外暴露的就是 LoginPage —— 登录一件事。注册走不通(server 禁自助注册,
/// Supabase 官网注册 or 管理员后台加账号),内部也没有 SignupPage / VerifyPage。
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) => const AuthPage();
}
