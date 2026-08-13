import 'package:flutter/material.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/widgets.dart';

class SpitoutCloudConfigDialog extends StatefulWidget {
  final String initialUrl;
  final String initialApiPrefix;
  final String initialAccount;
  final String initialPassword;
  // 已存在配置时标题栏显示清除图标;点击后由弹窗自身用路由 context pop 删除哨兵
  final bool canDelete;

  const SpitoutCloudConfigDialog({
    super.key,
    required this.initialUrl,
    required this.initialApiPrefix,
    this.initialAccount = '',
    this.initialPassword = '',
    this.canDelete = false,
  });

  @override
  State<SpitoutCloudConfigDialog> createState() =>
      _SpitoutCloudConfigDialogState();
}

class _SpitoutCloudConfigDialogState extends State<SpitoutCloudConfigDialog> {
  late final TextEditingController urlController;
  late final TextEditingController apiPrefixController;
  late final TextEditingController accountController;
  late final TextEditingController passwordController;
  // 显式 FocusNode:用于焦点链式切换,避免多输入框切换时键盘反复收起/拉起。
  late final FocusNode urlFocus;
  late final FocusNode accountFocus;
  late final FocusNode passwordFocus;
  bool obscurePassword = true;
  // 内联校验状态:url 为必填,保存时若为空则在字段下方显示弱提示,不切换弹窗、不丢失已填内容。
  String? _urlError;

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController(text: widget.initialUrl);
    apiPrefixController = TextEditingController(text: widget.initialApiPrefix);
    accountController = TextEditingController(text: widget.initialAccount);
    passwordController = TextEditingController(text: widget.initialPassword);
    urlFocus = FocusNode();
    accountFocus = FocusNode();
    passwordFocus = FocusNode();
  }

  @override
  void dispose() {
    urlController.dispose();
    apiPrefixController.dispose();
    accountController.dispose();
    passwordController.dispose();
    // 释放焦点节点,防止内存泄漏与悬空引用。
    urlFocus.dispose();
    accountFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用顶部贴边弹层(AppSheet + 自定义路由 showAppSheetTop):彻底规避底部弹层
    // AnimatedPadding 随键盘 viewInsets 动画导致的「弹窗弹跳」。弹层钉在屏幕顶部、
    // 高度随键盘瞬缩(普通 ConstrainedBox,无动画),保存/取消始终在键盘之上可点;
    // 删除图标常驻标题栏 trailing,内容区可滚动。
    final l10n = AppLocalizations.of(context);
    return AppSheet(
      title: AppLocalizations.of(context).cloudConfigureSpitoutCloudTitle,
      // 删除图标放在标题栏右侧 trailing,吸顶时常驻可见。
      trailing: widget.canDelete
          ? IconButton(
              icon: const Icon(AppIcons.delete, size: SpitoutDimens.icon22),
              tooltip: AppLocalizations.of(context).cloudClearConfig,
              // 用弹窗自身路由 context 直接 pop 删除哨兵。
              onPressed: () => Navigator.of(context).pop('__DELETE__'),
            )
          : null,
      showGrabHandle: false,
      // 内容区顶部内边距为 0:叠加 header 底部 0 后,标题↔首行间距收敛到最小
      // (仅剩标题在 32px 行内居中产生的 ~4px 行内空隙)。
      contentPadding: const EdgeInsets.fromLTRB(SpitoutDimens.p16, 0, SpitoutDimens.p16, SpitoutDimens.p16),
      // ignore: sort_child_properties_last
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: urlController,
              focusNode: urlFocus,
              textInputAction: TextInputAction.next,
              // 回车/下一步:焦点移交给下一个字段,避免键盘因焦点丢失而收起。
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(accountFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).cloudSpitoutCloudUrlLabel,
                hintText: AppLocalizations.of(context).cloudSpitoutCloudUrlHint,
                // 必填项为空时的内联弱提示(不弹窗),保留已填内容。
                errorText: _urlError,
              ),
              keyboardType: TextInputType.url,
            ),
            // API Prefix 输入框移除 —— 后端固定 /api/v1,前端用户没有配置场景;
            // 保留 apiPrefixController(默认 /api/v1)让 save 流程不破。
            const SizedBox(height: SpitoutDimens.p16),
            TextField(
              controller: accountController,
              focusNode: accountFocus,
              textInputAction: TextInputAction.next,
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(passwordFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).cloudSpitoutCloudAccountLabel,
                hintText: AppLocalizations.of(
                  context,
                ).cloudSpitoutCloudAccountHint,
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: SpitoutDimens.p16),
            TextField(
              controller: passwordController,
              focusNode: passwordFocus,
              textInputAction: TextInputAction.done,
              // 最后一个字段:完成后收起键盘,不向下传递焦点。
              onEditingComplete: () => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).cloudSpitoutCloudPasswordLabel,
                hintText: AppLocalizations.of(
                  context,
                ).cloudSpitoutCloudPasswordHint,
                // 明示密码只用于本次登录验证,保存配置不会把它写入本地存储。
                helperText: AppLocalizations.of(
                  context,
                ).cloudSpitoutCloudPasswordNotSavedHint,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? AppIcons.visibility
                        : AppIcons.visibilityOff,
                    size: SpitoutDimens.icon20,
                  ),
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: obscurePassword,
            ),
          ],
        ),
      ),
      footer: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(AppLocalizations.of(context).commonCancel),
            ),
          ),
          const SizedBox(width: SpitoutDimens.p12),
          Expanded(
            child: FilledButton(
              onPressed: () {
                // 内联校验:必填项 url 为空时仅在字段下方显示弱提示,不切换弹窗、不丢失已填内容。
                final url = urlController.text.trim();
                final account = accountController.text.trim();
                final password = passwordController.text.trim();
                setState(() {
                  _urlError = url.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                });
                if (_urlError != null) return;
                Navigator.of(context).pop({
                  'url': url,
                  'apiPrefix': apiPrefixController.text.trim(),
                  'account': account,
                  'password': password,
                });
              },
              child: Text(AppLocalizations.of(context).commonSave),
            ),
          ),
        ],
      ),
    );
  }
}

class SupabaseConfigDialog extends StatefulWidget {
  final String initialUrl;
  final String initialKey;
  final String initialBucket;
  // 已存在配置时标题栏显示清除图标;点击后由弹窗自身用路由 context pop 删除哨兵
  final bool canDelete;

  const SupabaseConfigDialog({
    super.key,
    required this.initialUrl,
    required this.initialKey,
    required this.initialBucket,
    this.canDelete = false,
  });

  @override
  State<SupabaseConfigDialog> createState() => _SupabaseConfigDialogState();
}

class _SupabaseConfigDialogState extends State<SupabaseConfigDialog> {
  late final TextEditingController urlController;
  late final TextEditingController keyController;
  late final TextEditingController bucketController;
  // 显式 FocusNode:用于焦点链式切换。
  late final FocusNode urlFocus;
  late final FocusNode keyFocus;
  late final FocusNode bucketFocus;
  // 内联校验状态:url 与 key 为必填,保存时若为空则在对应字段下方显示弱提示。
  String? _urlError;
  String? _keyError;

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController(text: widget.initialUrl);
    keyController = TextEditingController(text: widget.initialKey);
    bucketController = TextEditingController(text: widget.initialBucket);
    urlFocus = FocusNode();
    keyFocus = FocusNode();
    bucketFocus = FocusNode();
  }

  @override
  void dispose() {
    urlController.dispose();
    keyController.dispose();
    bucketController.dispose();
    // 释放焦点节点,防止内存泄漏与悬空引用。
    urlFocus.dispose();
    keyFocus.dispose();
    bucketFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用顶部贴边弹层(showAppSheetTop),消除底部弹层 + 键盘 viewInsets 动画的弹窗弹跳。
    final l10n = AppLocalizations.of(context);
    return AppSheet(
      title: AppLocalizations.of(context).cloudConfigureSupabaseTitle,
      // 删除图标常驻于标题栏右侧 trailing。
      trailing: widget.canDelete
          ? IconButton(
              icon: const Icon(AppIcons.delete, size: SpitoutDimens.icon22),
              tooltip: AppLocalizations.of(context).cloudClearConfig,
              // 删除图标按钮高度固定 32px:默认 48px 最小高度会把标题栏 Row 撑到 48px,
              // 导致标题居中后下方多挤 12px 空白、且「无图标」状态 Row 仅 24px,两种状态
              // 顶部留白不一致。固定 32px 后 Row 恒为 32px,标题上沿与图标上沿对齐,
              // 标题↔首行间距收敛到 ~8px。点击宽度仍保留 48px,保证可点性。
              constraints: const BoxConstraints(minWidth: 48, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop('__DELETE__'),
            )
          : null,
      showGrabHandle: false,
      // 内容区顶部内边距为 0:叠加 header 底部 0 后,标题↔首行间距收敛到最小
      // (仅剩标题在 32px 行内居中产生的 ~4px 行内空隙)。
      contentPadding: const EdgeInsets.fromLTRB(SpitoutDimens.p16, 0, SpitoutDimens.p16, SpitoutDimens.p16),
      // ignore: sort_child_properties_last
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: urlController,
              focusNode: urlFocus,
              textInputAction: TextInputAction.next,
              // 焦点移交给 key 字段。
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(keyFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudSupabaseUrlLabel,
                hintText: AppLocalizations.of(context).cloudSupabaseUrlHint,
                errorText: _urlError,
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: SpitoutDimens.p16),
            // anon key 为多行输入框,保持换行动作,不强制 next 链式切换。
            TextField(
              controller: keyController,
              focusNode: keyFocus,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudAnonKeyLabel,
                hintText: AppLocalizations.of(
                  context,
                ).cloudSupabaseAnonKeyHintLong,
                errorText: _keyError,
              ),
              keyboardType: TextInputType.text,
              minLines: 1,
              maxLines: 5,
            ),
            const SizedBox(height: SpitoutDimens.p16),
            TextField(
              controller: bucketController,
              focusNode: bucketFocus,
              textInputAction: TextInputAction.done,
              // 最后一个字段:完成后收起键盘。
              onEditingComplete: () => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).cloudSupabaseBucketLabel,
                hintText: AppLocalizations.of(context).cloudSupabaseBucketHint,
              ),
              keyboardType: TextInputType.text,
            ),
          ],
        ),
      ),
      footer: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(AppLocalizations.of(context).commonCancel),
            ),
          ),
          const SizedBox(width: SpitoutDimens.p12),
          Expanded(
            child: FilledButton(
              onPressed: () {
                // 内联校验:url 与 key 必填,任一为空则在对应字段下显示弱提示,不关闭弹窗。
                final url = urlController.text.trim();
                final key = keyController.text.trim();
                setState(() {
                  _urlError = url.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                  _keyError = key.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                });
                if (_urlError != null || _keyError != null) return;
                Navigator.of(context).pop({
                  'url': url,
                  'key': key,
                  'bucket': bucketController.text.trim(),
                });
              },
              child: Text(AppLocalizations.of(context).commonSave),
            ),
          ),
        ],
      ),
    );
  }
}

// WebDAV配置对话框(独立Widget,避免controller生命周期问题)
class WebdavConfigDialog extends StatefulWidget {
  final String initialUrl;
  final String initialUsername;
  final String initialPassword;
  final String initialPath;
  // 已存在配置时标题栏显示清除图标;点击后由弹窗自身用路由 context pop 删除哨兵
  final bool canDelete;

  const WebdavConfigDialog({
    super.key,
    required this.initialUrl,
    required this.initialUsername,
    required this.initialPassword,
    required this.initialPath,
    this.canDelete = false,
  });

  @override
  State<WebdavConfigDialog> createState() => _WebdavConfigDialogState();
}

class _WebdavConfigDialogState extends State<WebdavConfigDialog> {
  late final TextEditingController urlController;
  late final TextEditingController usernameController;
  late final TextEditingController passwordController;
  late final TextEditingController pathController;
  // 显式 FocusNode:用于焦点链式切换。
  late final FocusNode urlFocus;
  late final FocusNode usernameFocus;
  late final FocusNode passwordFocus;
  late final FocusNode pathFocus;
  bool obscurePassword = true;
  // 内联校验状态:url/username/password 为必填,保存时若为空则在对应字段下显示弱提示。
  String? _urlError;
  String? _usernameError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController(text: widget.initialUrl);
    usernameController = TextEditingController(text: widget.initialUsername);
    passwordController = TextEditingController(text: widget.initialPassword);
    pathController = TextEditingController(text: widget.initialPath);
    urlFocus = FocusNode();
    usernameFocus = FocusNode();
    passwordFocus = FocusNode();
    pathFocus = FocusNode();
  }

  @override
  void dispose() {
    urlController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    pathController.dispose();
    // 释放焦点节点,防止内存泄漏与悬空引用。
    urlFocus.dispose();
    usernameFocus.dispose();
    passwordFocus.dispose();
    pathFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用顶部贴边弹层(showAppSheetTop),消除底部弹层 + 键盘 viewInsets 动画的弹窗弹跳。
    final l10n = AppLocalizations.of(context);
    return AppSheet(
      title: AppLocalizations.of(context).cloudConfigureWebdavTitle,
      // 删除图标常驻于标题栏右侧 trailing。
      trailing: widget.canDelete
          ? IconButton(
              icon: const Icon(AppIcons.delete, size: SpitoutDimens.icon22),
              tooltip: AppLocalizations.of(context).cloudClearConfig,
              // 删除图标按钮高度固定 32px:默认 48px 最小高度会把标题栏 Row 撑到 48px,
              // 导致标题居中后下方多挤 12px 空白、且「无图标」状态 Row 仅 24px,两种状态
              // 顶部留白不一致。固定 32px 后 Row 恒为 32px,标题上沿与图标上沿对齐,
              // 标题↔首行间距收敛到 ~8px。点击宽度仍保留 48px,保证可点性。
              constraints: const BoxConstraints(minWidth: 48, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop('__DELETE__'),
            )
          : null,
      showGrabHandle: false,
      // 内容区顶部内边距为 0:叠加 header 底部 0 后,标题↔首行间距收敛到最小
      // (仅剩标题在 32px 行内居中产生的 ~4px 行内空隙)。
      contentPadding: const EdgeInsets.fromLTRB(SpitoutDimens.p16, 0, SpitoutDimens.p16, SpitoutDimens.p16),
      // ignore: sort_child_properties_last
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: urlController,
              focusNode: urlFocus,
              textInputAction: TextInputAction.next,
              // 焦点依次移交下一个字段。
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(usernameFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudWebdavUrlLabel,
                hintText: AppLocalizations.of(context).cloudWebdavUrlHint,
                errorText: _urlError,
              ),
            ),
            const SizedBox(height: SpitoutDimens.p16),
            TextField(
              controller: usernameController,
              focusNode: usernameFocus,
              textInputAction: TextInputAction.next,
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(passwordFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).cloudWebdavUsernameLabel,
                errorText: _usernameError,
              ),
            ),
            const SizedBox(height: SpitoutDimens.p16),
            TextField(
              controller: passwordController,
              focusNode: passwordFocus,
              textInputAction: TextInputAction.next,
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(pathFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).cloudWebdavPasswordLabel,
                errorText: _passwordError,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? AppIcons.visibility
                        : AppIcons.visibilityOff,
                    size: SpitoutDimens.icon20,
                  ),
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: obscurePassword,
            ),
            const SizedBox(height: SpitoutDimens.p16),
            TextField(
              controller: pathController,
              focusNode: pathFocus,
              textInputAction: TextInputAction.done,
              // 最后一个字段:完成后收起键盘。
              onEditingComplete: () => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).cloudWebdavRemotePathLabel,
                hintText: AppLocalizations.of(context).cloudWebdavPathHint,
                helperText: AppLocalizations.of(
                  context,
                ).cloudWebdavRemotePathHelperText,
              ),
            ),
          ],
        ),
      ),
      footer: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(AppLocalizations.of(context).commonCancel),
            ),
          ),
          const SizedBox(width: SpitoutDimens.p12),
          Expanded(
            child: FilledButton(
              onPressed: () {
                // 内联校验:url/username/password 必填,任一为空则在对应字段下显示弱提示,不关闭弹窗。
                final url = urlController.text.trim();
                final username = usernameController.text.trim();
                final password = passwordController.text.trim();
                final path = pathController.text.trim();
                setState(() {
                  _urlError = url.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                  _usernameError = username.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                  _passwordError = password.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                });
                if (_urlError != null ||
                    _usernameError != null ||
                    _passwordError != null) {
                  return;
                }
                Navigator.of(context).pop({
                  'url': url,
                  'username': username,
                  'password': password,
                  'path': path,
                });
              },
              child: Text(AppLocalizations.of(context).commonSave),
            ),
          ),
        ],
      ),
    );
  }
}

// S3配置对话框(独立Widget,避免controller生命周期问题)
class S3ConfigDialog extends StatefulWidget {
  final String initialEndpoint;
  final String initialRegion;
  final String initialAccessKey;
  final String initialSecretKey;
  final String initialBucket;
  final bool initialUseSSL;
  final int? initialPort;
  // 已存在配置时标题栏显示清除图标;点击后由弹窗自身用路由 context pop 删除哨兵
  final bool canDelete;

  const S3ConfigDialog({
    super.key,
    required this.initialEndpoint,
    required this.initialRegion,
    required this.initialAccessKey,
    required this.initialSecretKey,
    required this.initialBucket,
    required this.initialUseSSL,
    this.initialPort,
    this.canDelete = false,
  });

  @override
  State<S3ConfigDialog> createState() => _S3ConfigDialogState();
}

class _S3ConfigDialogState extends State<S3ConfigDialog> {
  late final TextEditingController endpointController;
  late final TextEditingController regionController;
  late final TextEditingController accessKeyController;
  late final TextEditingController secretKeyController;
  late final TextEditingController bucketController;
  late final TextEditingController portController;
  // 显式 FocusNode:用于焦点链式切换。
  late final FocusNode endpointFocus;
  late final FocusNode regionFocus;
  late final FocusNode accessKeyFocus;
  late final FocusNode secretKeyFocus;
  late final FocusNode bucketFocus;
  late final FocusNode portFocus;
  late bool useSSL;
  bool obscureSecretKey = true;
  // 内联校验状态:endpoint/accessKey/secretKey/bucket 为必填,保存时若为空则在对应字段下显示弱提示。
  String? _endpointError;
  String? _accessKeyError;
  String? _secretKeyError;
  String? _bucketError;

  /// 端口输入错误:非空但解析失败时内联提示,不静默丢弃。
  String? _portError;

  @override
  void initState() {
    super.initState();
    endpointController = TextEditingController(text: widget.initialEndpoint);
    regionController = TextEditingController(text: widget.initialRegion);
    accessKeyController = TextEditingController(text: widget.initialAccessKey);
    secretKeyController = TextEditingController(text: widget.initialSecretKey);
    bucketController = TextEditingController(text: widget.initialBucket);
    portController = TextEditingController(
      text: widget.initialPort?.toString() ?? '',
    );
    endpointFocus = FocusNode();
    regionFocus = FocusNode();
    accessKeyFocus = FocusNode();
    secretKeyFocus = FocusNode();
    bucketFocus = FocusNode();
    portFocus = FocusNode();
    useSSL = widget.initialUseSSL;
  }

  @override
  void dispose() {
    endpointController.dispose();
    regionController.dispose();
    accessKeyController.dispose();
    secretKeyController.dispose();
    bucketController.dispose();
    portController.dispose();
    // 释放焦点节点,防止内存泄漏与悬空引用。
    endpointFocus.dispose();
    regionFocus.dispose();
    accessKeyFocus.dispose();
    secretKeyFocus.dispose();
    bucketFocus.dispose();
    portFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用顶部贴边弹层(showAppSheetTop),消除底部弹层 + 键盘 viewInsets 动画的弹窗弹跳。
    final l10n = AppLocalizations.of(context);
    return AppSheet(
      title: AppLocalizations.of(context).cloudConfigureS3Title,
      // 删除图标常驻于标题栏右侧 trailing。
      trailing: widget.canDelete
          ? IconButton(
              icon: const Icon(AppIcons.delete, size: SpitoutDimens.icon22),
              tooltip: AppLocalizations.of(context).cloudClearConfig,
              // 删除图标按钮高度固定 32px:默认 48px 最小高度会把标题栏 Row 撑到 48px,
              // 导致标题居中后下方多挤 12px 空白、且「无图标」状态 Row 仅 24px,两种状态
              // 顶部留白不一致。固定 32px 后 Row 恒为 32px,标题上沿与图标上沿对齐,
              // 标题↔首行间距收敛到 ~8px。点击宽度仍保留 48px,保证可点性。
              constraints: const BoxConstraints(minWidth: 48, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop('__DELETE__'),
            )
          : null,
      showGrabHandle: false,
      // 内容区顶部内边距为 0:叠加 header 底部 0 后,标题↔首行间距收敛到最小
      // (仅剩标题在 32px 行内居中产生的 ~4px 行内空隙)。
      contentPadding: const EdgeInsets.fromLTRB(SpitoutDimens.p16, 0, SpitoutDimens.p16, SpitoutDimens.p16),
      // ignore: sort_child_properties_last
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: endpointController,
              focusNode: endpointFocus,
              textInputAction: TextInputAction.next,
              // 焦点依次移交下一个字段。
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(regionFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudS3EndpointLabel,
                hintText: AppLocalizations.of(context).cloudS3EndpointHint,
                errorText: _endpointError,
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: SpitoutDimens.p16),
            TextField(
              controller: regionController,
              focusNode: regionFocus,
              textInputAction: TextInputAction.next,
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(accessKeyFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudS3RegionLabel,
                hintText: AppLocalizations.of(context).cloudS3RegionHint,
              ),
            ),
            const SizedBox(height: SpitoutDimens.p16),
            TextField(
              controller: accessKeyController,
              focusNode: accessKeyFocus,
              textInputAction: TextInputAction.next,
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(secretKeyFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudS3AccessKeyLabel,
                hintText: AppLocalizations.of(context).cloudS3AccessKeyHint,
                errorText: _accessKeyError,
              ),
            ),
            const SizedBox(height: SpitoutDimens.p16),
            TextField(
              controller: secretKeyController,
              focusNode: secretKeyFocus,
              textInputAction: TextInputAction.next,
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(bucketFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudS3SecretKeyLabel,
                hintText: AppLocalizations.of(context).cloudS3SecretKeyHint,
                errorText: _secretKeyError,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureSecretKey
                        ? AppIcons.visibility
                        : AppIcons.visibilityOff,
                    size: SpitoutDimens.icon20,
                  ),
                  onPressed: () {
                    setState(() {
                      obscureSecretKey = !obscureSecretKey;
                    });
                  },
                ),
              ),
              obscureText: obscureSecretKey,
            ),
            const SizedBox(height: SpitoutDimens.p16),
            TextField(
              controller: bucketController,
              focusNode: bucketFocus,
              textInputAction: TextInputAction.next,
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(portFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudS3BucketLabel,
                hintText: AppLocalizations.of(context).cloudS3BucketHint,
                errorText: _bucketError,
              ),
            ),
            const SizedBox(height: SpitoutDimens.p16),
            Row(
              children: [
                Expanded(
                  child: Text(AppLocalizations.of(context).cloudS3UseSSLLabel),
                ),
                Switch(
                  value: useSSL,
                  onChanged: (value) {
                    setState(() {
                      useSSL = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: SpitoutDimens.p8),
            TextField(
              controller: portController,
              focusNode: portFocus,
              textInputAction: TextInputAction.done,
              // 最后一个字段:完成后收起键盘。
              onEditingComplete: () => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudS3PortLabel,
                hintText: AppLocalizations.of(context).cloudS3PortHint,
                errorText: _portError,
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      footer: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(AppLocalizations.of(context).commonCancel),
            ),
          ),
          const SizedBox(width: SpitoutDimens.p12),
          Expanded(
            child: FilledButton(
              onPressed: () {
                // 内联校验:endpoint/accessKey/secretKey/bucket 必填,任一为空则在对应字段下
                // 显示弱提示,不切换弹窗、不丢失已填内容。
                final endpoint = endpointController.text.trim();
                final accessKey = accessKeyController.text.trim();
                final secretKey = secretKeyController.text.trim();
                final bucket = bucketController.text.trim();
                final portText = portController.text.trim();
                final parsedPort = portText.isEmpty
                    ? null
                    : int.tryParse(portText);
                setState(() {
                  _endpointError = endpoint.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                  _accessKeyError = accessKey.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                  _secretKeyError = secretKey.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                  _bucketError = bucket.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                  // 端口非空但无法解析为数字时给出内联错误,避免静默置 null。
                  _portError = (portText.isNotEmpty && parsedPort == null)
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                });
                if (_endpointError != null ||
                    _accessKeyError != null ||
                    _secretKeyError != null ||
                    _bucketError != null ||
                    _portError != null) {
                  return;
                }
                Navigator.of(context).pop({
                  'endpoint': endpoint,
                  'region': regionController.text.trim(),
                  'accessKey': accessKey,
                  'secretKey': secretKey,
                  'bucket': bucket,
                  'useSSL': useSSL,
                  'port': parsedPort,
                });
              },
              child: Text(AppLocalizations.of(context).commonSave),
            ),
          ),
        ],
      ),
    );
  }
}
