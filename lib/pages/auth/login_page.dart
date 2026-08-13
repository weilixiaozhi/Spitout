import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/cloud/spitout_cloud.dart'
    show CloudBackendType, CloudServiceConfig;
import 'package:spitout/cloud/auth_error_localizer.dart'
    as auth_error_localizer;
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/shadows.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/widgets.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final accountCtrl = TextEditingController();
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

  /// 加载「记住账号」时持久化的账号，回填到登录表单。
  ///
  /// 设计意图：密码只作为一次性输入、从不落盘，因此这里只恢复账号；
  /// 勾选状态由账号是否存在推导，避免本地残留明文密码。
  Future<void> _loadSavedCredentials() async {
    try {
      final cloudConfig = await ref.read(activeCloudConfigProvider.future);
      String? savedAccount;
      if (cloudConfig.type == CloudBackendType.supabase) {
        savedAccount = cloudConfig.supabaseAccount;
      } else if (cloudConfig.type == CloudBackendType.spitoutCloud) {
        // Spitout Cloud 与 Supabase 一致：仅持久化账号，密码不落盘。
        savedAccount = cloudConfig.spitoutCloudAccount;
      } else {
        return;
      }

      if (savedAccount != null && savedAccount.isNotEmpty && mounted) {
        setState(() {
          accountCtrl.text = savedAccount!;
          // 有账号即视为之前勾选过「记住账号」。
          _rememberAccount = true;
        });
      }
    } catch (e) {
      logger.warning('auth', '加载保存的账号失败: $e');
    }
  }

  /// 保存「记住账号」配置：仅持久化账号，密码作为一次性输入不写入存储。
  ///
  /// 设计意图：SharedPreferences 在 Android 侧是明文 XML，保存密码会随
  /// 系统备份 / root 读取泄露；Spitout Cloud 已有 session token 持久化，
  /// Supabase 同样由 SDK 持久化会话，密码不需要兜底自动登录。
  Future<void> _saveCredentials(String account, String password) async {
    try {
      final cloudConfig = await ref.read(activeCloudConfigProvider.future);
      final store = ref.read(cloudServiceStoreProvider);

      if (cloudConfig.type == CloudBackendType.supabase) {
        final updatedConfig = CloudServiceConfig(
          type: cloudConfig.type,
          name: cloudConfig.name,
          supabaseUrl: cloudConfig.supabaseUrl,
          supabaseAnonKey: cloudConfig.supabaseAnonKey,
          supabaseBucket: cloudConfig.supabaseBucket ?? 'spitout-backups',
          supabaseAccount: _rememberAccount ? account : null,
          supabasePassword: null,
        );
        await store.saveOnly(updatedConfig);
        ref.invalidate(supabaseConfigProvider);
        ref.invalidate(activeCloudConfigProvider);
        logger.info(
          'auth',
          'Supabase 记住账号状态：${_rememberAccount ? "已保存账号" : "已清除"}',
        );
        return;
      }

      if (cloudConfig.type == CloudBackendType.spitoutCloud) {
        final updatedConfig = CloudServiceConfig(
          type: cloudConfig.type,
          name: cloudConfig.name,
          spitoutCloudBaseUrl: cloudConfig.spitoutCloudBaseUrl,
          spitoutCloudApiPrefix: cloudConfig.spitoutCloudApiPrefix,
          spitoutCloudAccount: _rememberAccount ? account : null,
          spitoutCloudPassword: null,
        );
        await store.saveOnly(updatedConfig);
        ref.invalidate(spitoutCloudConfigProvider);
        ref.invalidate(activeCloudConfigProvider);
        logger.info(
          'auth',
          'Spitout Cloud 记住账号状态：${_rememberAccount ? "已保存账号" : "已清除"}',
        );
      }
    } catch (e, st) {
      logger.error('auth', '保存账号配置失败', e, st);
    }
  }

  /// 日志脱敏：避免完整账号落入日志；账号仍保留前缀与域名便于排查。
  String _maskAccount(String account) {
    final t = account.trim();
    if (t.length <= 2) return '***';
    final at = t.indexOf('@');
    if (at > 0) {
      return '${t.substring(0, 2)}***${t.substring(at)}';
    }
    return '${t.substring(0, 2)}***';
  }

  @override
  void dispose() {
    accountCtrl.dispose();
    pwdCtrl.dispose();
    super.dispose();
  }

  bool isValidAccount(String s) {
    return s.trim().isNotEmpty;
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
    if (cloudConfig.hasValue &&
        cloudConfig.value!.type == CloudBackendType.webdav) {
      // WebDAV 不需要登录页面
      return Scaffold(
        backgroundColor: SpitoutTokens.scaffoldBackground(context),
        body: Column(
          children: [
            PrimaryHeader(
              title: AppLocalizations.of(context).authLogin,
              showBack: true,
            ),
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
                      boxShadow: SpitoutTokens.isDark(context)
                          ? null
                          : SpitoutShadows.card,
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
          PrimaryHeader(
            title: AppLocalizations.of(context).authLogin,
            showBack: true,
          ),
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
                      boxShadow: SpitoutTokens.isDark(context)
                          ? null
                          : SpitoutShadows.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: accountCtrl,
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context).authAccount,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: pwdCtrl,
                          obscureText: !_showPwd,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(
                              context,
                            ).authPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPwd
                                    ? AppIcons.visibilityOff
                                    : AppIcons.visibility,
                              ),
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
                                      AppLocalizations.of(
                                        context,
                                      ).authRememberAccount,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: SpitoutTokens.textPrimary(
                                              context,
                                            ),
                                          ),
                                    ),
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                      ).authRememberAccountHint,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: SpitoutTokens.textSecondary(
                                              context,
                                            ),
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
                              style: TextStyle(
                                color: SpitoutTokens.error(context),
                              ),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: radius,
                              ),
                            ),
                            onPressed: busy
                                ? null
                                : () async {
                                    final account = accountCtrl.text.trim();
                                    final pwd = pwdCtrl.text;
                                    logger.info(
                                      'auth',
                                      '开始登录：账号=${_maskAccount(account)}',
                                    );
                                    if (!isValidAccount(account)) {
                                      setState(
                                        () => errorText = AppLocalizations.of(
                                          context,
                                        ).authInvalidAccount,
                                      );
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
                                      final auth = await ref.read(
                                        authServiceProvider.future,
                                      );
                                      await auth.signInWithAccount(
                                        account: account,
                                        password: pwd,
                                      );
                                      if (!context.mounted) return;
                                      logger.info(
                                        'auth',
                                        '登录成功：账号=${_maskAccount(account)}',
                                      );

                                      // Save credentials if "remember account" is checked
                                      await _saveCredentials(account, pwd);

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
                                      ref.invalidate(
                                        spitoutCloudProviderInstance,
                                      );
                                      ref.invalidate(syncServiceProvider);

                                      // 刷新同步状态
                                      ref
                                          .read(
                                            syncStatusRefreshProvider.notifier,
                                          )
                                          .tick();
                                      // 直接切到"我的"页并关闭登录页
                                      ref
                                          .read(bottomTabIndexProvider.notifier)
                                          .set(3); // Mine tab index
                                      final can = Navigator.of(
                                        context,
                                      ).canPop();
                                      logger.info(
                                        'nav',
                                        'login: success -> switch tab to Mine, canPop=$can; pop login',
                                      );
                                      if (can) {
                                        Navigator.of(context).pop();
                                      }
                                    } catch (e, st) {
                                      final msg = friendlyAuthError(e);
                                      logger.error(
                                        'auth',
                                        '登录失败：账号=${_maskAccount(account)}，用户友好信息=$msg',
                                        e,
                                        st,
                                      );
                                      setState(() => errorText = msg);
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
                                      color: Colors.white,
                                    ),
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
