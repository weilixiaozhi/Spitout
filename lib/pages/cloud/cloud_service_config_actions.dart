import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spitout/cloud/spitout_cloud.dart'
    show CloudAuthException, CloudBackendType, CloudServiceConfig;
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/sync/sync_providers.dart';
import 'package:spitout/widgets/widgets.dart';

import '../../cloud/auth_error_localizer.dart';
import '../../core/logging/logger_service.dart';
import 'cloud_config_dialogs.dart';

/// 云服务配置对话框流程（Spitout Cloud / Supabase / WebDAV / S3）。
/// 与页面状态解耦后单独成文件，降低 CloudServicePage 单文件体积。
mixin CloudServiceConfigActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// 激活指定云端后端（由页面 State 实现）。
  Future<void> activateService(CloudBackendType type);

  /// 询问用户是否保存后立即切换（由页面 State 实现）。
  Future<bool> confirmSaveSwitch();

  /// 清除指定云端后端配置（由页面 State 实现）。
  Future<void> deleteConfig(CloudBackendType type);

  Future<void> configureService(CloudBackendType type) async {
    // 根据类型显示配置对话框
    if (type == CloudBackendType.spitoutCloud) {
      await showSpitoutCloudConfigDialog();
    } else if (type == CloudBackendType.supabase) {
      await showSupabaseConfigDialog();
    } else if (type == CloudBackendType.webdav) {
      await showWebdavConfigDialog();
    } else if (type == CloudBackendType.s3) {
      await showS3ConfigDialog();
    }
  }

  Future<void> showSpitoutCloudConfigDialog() async {
    final existing = await ref.read(spitoutCloudConfigProvider.future);

    if (!mounted) return;

    // 在异步调用前提取 l10n，避免 use_build_context_synchronously 警告
    final l10n = AppLocalizations.of(context);

    final result = await showAppSheetTop<dynamic>(
      context: context,
      child: SpitoutCloudConfigDialog(
        initialUrl: existing?.spitoutCloudBaseUrl ?? '',
        initialApiPrefix: existing?.spitoutCloudApiPrefix ?? '/api/v1',
        initialEmail: existing?.spitoutCloudEmail ?? '',
        // 密码不持久化(见 CloudServiceStore):即使旧版本残留过密码也不回填,
        // 避免把已失效的明文凭据再次展示/复用。
        initialPassword: '',
        canDelete: existing != null,
      ),
    );

    // 删除哨兵:用户在对话框标题栏点了清除图标
    if (result == '__DELETE__') {
      await deleteConfig(CloudBackendType.spitoutCloud);
      return;
    }

    if (result != null) {
      final url = result['url'] as String;
      final apiPrefix = result['apiPrefix'] as String;
      final email = result['email'] as String;
      final password = result['password'] as String;

      // 必填校验(url)已下放到弹窗内联提示(不切换弹窗、保留已填内容),此处直接组装配置。
      final cfg = CloudServiceConfig(
        type: CloudBackendType.spitoutCloud,
        name: l10n.cloudSpitoutCloudTitle,
        spitoutCloudBaseUrl: url,
        spitoutCloudApiPrefix: apiPrefix.isEmpty ? '/api/v1' : apiPrefix,
        spitoutCloudEmail: email.isNotEmpty ? email : null,
      );

      try {
        // 仅持久化配置：不改动 _kActiveType，也不在此级联刷新 SyncEngine。
        // 这样「暂不切换」时活跃服务完全不动，符合「保存 ≠ 生效」原则。
        await ref.read(cloudServiceStoreProvider).saveOnly(cfg);
        // 仅刷新本类型配置列表，便于「暂不切换」时也能看到刚保存的配置
        ref.invalidate(spitoutCloudConfigProvider);

        // 弹窗询问用户是否立即切换激活；只有用户确认后，所有「生效」副作用
        // （登录、激活、同步、provider 重建）才会在下方统一执行。
        final wantSwitch = await confirmSaveSwitch();
        if (wantSwitch && mounted) {
          // 登录在用户确认激活后统一执行，不手动 invalidate 任何云端 provider，
          // 全部交给 activateService 经级联统一重建。
          if (email.isNotEmpty && password.isNotEmpty) {
            try {
              // 走可覆盖的工厂 provider：运行时为真实 createCloudServices；
              // Widget 测试经 overrideWith 注入桩，无需触网即可验证登录分支。
              final services = await ref.read(cloudServicesFactoryProvider)(
                cfg,
              );
              if (services.auth != null) {
                await services.auth!.signInWithEmail(
                  email: email,
                  password: password,
                );
                // 标记自动同步开启并刷新开关状态；不 invalidate 任何云端 provider，
                // 交给 activateService 经级联统一重建
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('auto_sync', true);
                ref.invalidate(autoSyncValueProvider);

                if (mounted) {
                  showToast(
                    context,
                    AppLocalizations.of(context).cloudSpitoutCloudLoginSuccess,
                  );
                }
              }
              // 能走到这里 = 登录成功（有凭证且成功登录）或本配置无 auth 可登录
              // （services.auth == null）。两种情况都应继续到下方激活服务。
              // 若登录失败，会走下方 catch 的 return，不会到达此处，从而避免
              // 「登录失败却仍激活服务」的半成品脏状态。
            } on CloudAuthException catch (e) {
              // 账号鉴权失败（邮箱/密码错、账号被锁等）：纯账号问题，用友好文案
              // 弹窗告知；不激活服务、也不弹网络 toast（本就非网络问题）。
              if (mounted) {
                await AppDialog.error(
                  context,
                  title: AppLocalizations.of(
                    context,
                  ).cloudSpitoutCloudLoginFailed,
                  message: friendlyAuthError(e, context),
                );
              }
              return;
            } catch (e) {
              // 其余异常（网络超时、服务端 5xx 等）：同样不激活服务，用友好文案提示。
              if (mounted) {
                await AppDialog.error(
                  context,
                  title: AppLocalizations.of(
                    context,
                  ).cloudSpitoutCloudLoginFailed,
                  message: friendlyAuthError(e, context),
                );
              }
              return;
            }
          }

          // —— 激活：修改 _kActiveType + addPostFrameCallback 级联 invalidate 所有相关
          // provider；Bootstrap 的 auto-sync 在此之后自动接管首次同步
          // （fullPush 会注册新账本并上传全部实体，能力严格强于原 uploadCurrentLedger）。
          await activateService(CloudBackendType.spitoutCloud);
        }
      } catch (e, st) {
        logger.error('CloudServicePage', '保存 Spitout Cloud 配置失败', e, st);
        if (mounted) {
          await AppDialog.error(
            context,
            title: AppLocalizations.of(context).cloudSaveFailed,
            message: AppLocalizations.of(context).commonOperationFailed,
          );
        }
      }
    }
  }

  Future<void> showSupabaseConfigDialog() async {
    final existing = await ref.read(supabaseConfigProvider.future);

    if (!mounted) return;

    // 在异步调用前提取 l10n，避免 use_build_context_synchronously 警告
    final l10n = AppLocalizations.of(context);

    final result = await showAppSheetTop<dynamic>(
      context: context,
      child: SupabaseConfigDialog(
        initialUrl: existing?.supabaseUrl ?? '',
        initialKey: existing?.supabaseAnonKey ?? '',
        initialBucket: existing?.supabaseBucket ?? '',
        canDelete: existing != null,
      ),
    );

    // 删除哨兵:用户在对话框标题栏点了清除图标
    if (result == '__DELETE__') {
      await deleteConfig(CloudBackendType.supabase);
      return;
    }

    if (result != null) {
      final url = result['url'] as String;
      final key = result['key'] as String;
      final bucket = result['bucket'] as String;

      // 必填校验(url/key)已下放到弹窗内联提示,此处直接组装配置。
      final cfg = CloudServiceConfig(
        type: CloudBackendType.supabase,
        name: l10n.cloudCustomSupabaseTitle,
        supabaseUrl: url,
        supabaseAnonKey: key,
        supabaseBucket: bucket.isEmpty ? 'spitout-backups' : bucket, // 业务层提供默认值
      );

      try {
        await ref.read(cloudServiceStoreProvider).saveOnly(cfg);
        ref.invalidate(supabaseConfigProvider);

        // 保存成功后统一引导用户是否立即切换（新建与编辑均弹出）
        // 注：不 invalidate activeCloudConfigProvider —— 「保存 ≠ 生效」，
        // 活跃服务是否切换由下方 activateService 在用户确认后统一处理。
        {
          final wantSwitch = await confirmSaveSwitch();
          if (wantSwitch && mounted) {
            await activateService(CloudBackendType.supabase);
          }
        }
      } catch (e, st) {
        logger.error('CloudServicePage', '保存 Supabase 配置失败', e, st);
        if (mounted) {
          await AppDialog.error(
            context,
            title: AppLocalizations.of(context).cloudSaveFailed,
            message: AppLocalizations.of(context).commonOperationFailed,
          );
        }
      }
    }
  }

  Future<void> showWebdavConfigDialog() async {
    final existing = await ref.read(webdavConfigProvider.future);

    if (!mounted) return;

    // 在异步调用前提取 l10n，避免 use_build_context_synchronously 警告
    final l10n = AppLocalizations.of(context);

    final result = await showAppSheetTop<dynamic>(
      context: context,
      child: WebdavConfigDialog(
        initialUrl: existing?.webdavUrl ?? '',
        initialUsername: existing?.webdavUsername ?? '',
        initialPassword: existing?.webdavPassword ?? '',
        initialPath: existing?.webdavRemotePath ?? '/',
        canDelete: existing != null,
      ),
    );

    // 删除哨兵:用户在对话框标题栏点了清除图标
    if (result == '__DELETE__') {
      await deleteConfig(CloudBackendType.webdav);
      return;
    }

    if (result != null) {
      final url = result['url'] as String;
      final username = result['username'] as String;
      final password = result['password'] as String;
      final path = result['path'] as String;

      // 必填校验(url/username/password)已下放到弹窗内联提示,此处直接组装配置。
      final cfg = CloudServiceConfig(
        type: CloudBackendType.webdav,
        name: l10n.cloudCustomWebdavTitle,
        webdavUrl: url,
        webdavUsername: username,
        webdavPassword: password,
        webdavRemotePath: path.isEmpty ? '/' : path,
      );

      try {
        await ref.read(cloudServiceStoreProvider).saveOnly(cfg);
        ref.invalidate(webdavConfigProvider);

        // 保存成功后统一引导用户是否立即切换（新建与编辑均弹出）
        // 注：不 invalidate activeCloudConfigProvider —— 「保存 ≠ 生效」，
        // 活跃服务是否切换由下方 activateService 在用户确认后统一处理。
        {
          final wantSwitch = await confirmSaveSwitch();
          if (wantSwitch && mounted) {
            await activateService(CloudBackendType.webdav);
          }
        }
      } catch (e, st) {
        logger.error('CloudServicePage', '保存 WebDAV 配置失败', e, st);
        if (mounted) {
          await AppDialog.error(
            context,
            title: AppLocalizations.of(context).cloudSaveFailed,
            message: AppLocalizations.of(context).commonOperationFailed,
          );
        }
      }
    }
  }

  Future<void> showS3ConfigDialog() async {
    final existing = await ref.read(s3ConfigProvider.future);

    if (!mounted) return;

    // 在异步调用前提取 l10n，避免 use_build_context_synchronously 警告
    final l10n = AppLocalizations.of(context);

    final result = await showAppSheetTop<dynamic>(
      context: context,
      child: S3ConfigDialog(
        initialEndpoint: existing?.s3Endpoint ?? '',
        initialRegion: existing?.s3Region ?? 'us-east-1',
        initialAccessKey: existing?.s3AccessKey ?? '',
        initialSecretKey: existing?.s3SecretKey ?? '',
        initialBucket: existing?.s3Bucket ?? '',
        initialUseSSL: existing?.s3UseSSL ?? true,
        initialPort: existing?.s3Port,
        canDelete: existing != null,
      ),
    );

    // 删除哨兵:用户在对话框标题栏点了清除图标
    if (result == '__DELETE__') {
      await deleteConfig(CloudBackendType.s3);
      return;
    }

    if (result != null) {
      var endpoint = result['endpoint'] as String;
      final region = result['region'] as String;
      final accessKey = result['accessKey'] as String;
      final secretKey = result['secretKey'] as String;
      final bucket = result['bucket'] as String;
      final useSSL = result['useSSL'] as bool;
      final port = result['port'] as int?;

      // 必填校验(endpoint/accessKey/secretKey/bucket)已下放到弹窗内联提示,
      // 此处直接去除 endpoint 协议前缀并组装配置。
      endpoint = endpoint.replaceFirst(RegExp(r'^https?://'), '');

      final cfg = CloudServiceConfig(
        type: CloudBackendType.s3,
        name: l10n.cloudCustomS3Title,
        s3Endpoint: endpoint,
        s3Region: region.isEmpty ? 'us-east-1' : region,
        s3AccessKey: accessKey,
        s3SecretKey: secretKey,
        s3Bucket: bucket,
        s3UseSSL: useSSL,
        s3Port: port,
      );

      try {
        await ref.read(cloudServiceStoreProvider).saveOnly(cfg);
        ref.invalidate(s3ConfigProvider);

        // 保存成功后统一引导用户是否立即切换（新建与编辑均弹出）
        // 注：不 invalidate activeCloudConfigProvider —— 「保存 ≠ 生效」，
        // 活跃服务是否切换由下方 activateService 在用户确认后统一处理。
        {
          final wantSwitch = await confirmSaveSwitch();
          if (wantSwitch && mounted) {
            await activateService(CloudBackendType.s3);
          }
        }
      } catch (e, st) {
        logger.error('CloudServicePage', '保存 S3 配置失败', e, st);
        if (mounted) {
          await AppDialog.error(
            context,
            title: AppLocalizations.of(context).cloudSaveFailed,
            message: AppLocalizations.of(context).commonOperationFailed,
          );
        }
      }
    }
  }
}
