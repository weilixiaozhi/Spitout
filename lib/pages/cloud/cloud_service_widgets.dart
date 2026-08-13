import 'package:flutter/material.dart';
import 'package:spitout/cloud/spitout_cloud.dart'
    show CloudBackendType, CloudServiceConfig;
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/theme/typography.dart';
import 'package:spitout/widgets/widgets.dart';

import 'cloud_help_dialogs.dart';

/// 头部「当前类型 / 脱敏 URL / 连接状态」信息块。
///
/// 设计要点：
/// - 「测试连接」入口内联为文字链，紧贴状态徽标左侧，不用头部 icon 按钮（避免重复）。
/// - 测试结果（状态/时间/详情）全部内联展示，不弹窗。
/// - 本地后端没有可连接的远程服务，自测无意义，故不展示测试链与状态徽标。
Widget buildCloudServiceStatusHeader({
  required BuildContext context,
  required CloudServiceConfig config,
  required bool? testResult,
  required DateTime? testTime,
  required String? testMessage,
  required bool testingConnection,
  required VoidCallback onTest,
}) {
  final l10n = AppLocalizations.of(context);
  final Color statusColor;
  final String statusText;

  if (testResult == null) {
    // 未测试
    statusColor = SpitoutTokens.warning(context);
    statusText = l10n.cloudStatusNotTested;
  } else if (testResult) {
    // 测试成功
    statusColor = SpitoutTokens.success(context);
    statusText = l10n.cloudStatusNormal;
  } else {
    // 测试失败
    statusColor = SpitoutTokens.error(context);
    statusText = l10n.cloudStatusFailed;
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          // 长类型名（如 Spitout Cloud）在窄空间下省略号截断，
          // 防止与状态徽标挤压导致横向溢出（可见性测试暴露的既有缺陷）
          Expanded(
            child: Text(
              '${l10n.commonCurrent}: ${cloudBackendTypeName(context, config.type)}',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          // 本地存储没有“连接”概念，不展示未测试/成功等状态徽标与测试链，仅显示当前类型
          if (config.type != CloudBackendType.local) ...[
            const SizedBox(width: SpitoutDimens.p12),
            // 「测试连接」文字链紧贴状态徽标左侧
            _buildTestConnectionLink(
              context: context,
              config: config,
              l10n: l10n,
              testingConnection: testingConnection,
              onTest: onTest,
            ),
            const SizedBox(width: SpitoutDimens.p8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(SpitoutDimens.radius12),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: SpitoutDimens.p4),
                  Text(
                    statusText,
                    style: SpitoutTextTokens.label(context).copyWith(color: statusColor,),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: SpitoutDimens.p4),
      Text(
        config.obfuscatedUrl(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: SpitoutTokens.textSecondary(context),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // 上次测试时间：仅当存在历史测试记录（点过测试连接）时展示
      if (testTime != null) ...[
        const SizedBox(height: SpitoutDimens.p4),
        Text(
          l10n.cloudLastTestTime(formatCloudTestTime(testTime)),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      // 测试结果详情文案（成功绿 / 失败红），纯内联展示，不弹窗
      if (testMessage != null) ...[
        const SizedBox(height: SpitoutDimens.p4),
        Text(
          testMessage,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: testResult == true
                ? SpitoutTokens.success(context)
                : SpitoutTokens.error(context),
          ),
        ),
      ],
    ],
  );
}

/// 「测试连接」文字链：紧贴状态徽标左侧。
///
/// 仅在非本地后端且配置有效时可点击；测试进行中显示转圈，不弹窗。
/// 配置无效（如未填 URL）时置灰禁用，与头部按钮的业务禁用条件一致。
Widget _buildTestConnectionLink({
  required BuildContext context,
  required CloudServiceConfig config,
  required AppLocalizations l10n,
  required bool testingConnection,
  required VoidCallback onTest,
}) {
  final bool canTest = config.valid;
  return TextButton(
    onPressed: (canTest && !testingConnection) ? onTest : null,
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: testingConnection
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(
            l10n.cloudTestConnection,
            style: TextStyle(
              decoration: TextDecoration.underline,
              color: canTest
                  ? Theme.of(context).colorScheme.primary
                  : SpitoutTokens.textTertiary(context),
            ),
          ),
  );
}

/// 多设备提醒动作卡片（点击打开多设备详情）。
Widget buildCloudMultiDeviceWarning(BuildContext context) {
  final l10n = AppLocalizations.of(context);

  // 纯动作卡片（点开多设备详情），无选中态，按统一原则补 Material+InkWell 涟漪
  return Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(SpitoutDimens.radius12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => showMultiDeviceDetailDialog(context),
      borderRadius: BorderRadius.circular(SpitoutDimens.radius12),
      child: Container(
        padding: const EdgeInsets.all(SpitoutDimens.p16),
        decoration: BoxDecoration(
          color: SpitoutTokens.warning(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(SpitoutDimens.radius12),
          border: Border.all(
            color: SpitoutTokens.warning(context).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.warning,
              color: SpitoutTokens.warning(context),
              size: SpitoutDimens.icon22,
            ),
            const SizedBox(width: SpitoutDimens.p12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.cloudMultiDeviceWarningTitle,
                    style: SpitoutTextTokens.body(context).copyWith(fontWeight: FontWeight.w600, color: SpitoutTokens.textPrimary(context)),
                  ),
                  const SizedBox(height: SpitoutDimens.p4),
                  Text(
                    l10n.cloudMultiDeviceWarningMessage,
                    style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SpitoutDimens.p8),
            Icon(
              AppIcons.info,
              color: SpitoutTokens.warning(context),
              size: SpitoutDimens.icon20,
            ),
          ],
        ),
      ),
    ),
  );
}

/// 列表分组主标题，仅作视觉分组，无交互。
/// 左侧色条用于清晰区分不同分组（离线模式 / 备份同步 / 云端协同）。
///
/// [subtitle] 为可选参数：仅「备份同步」分组需要副标题提示（如操作引导），
/// 传入时在其下方多渲染一行灰色小字；其余分组不传，保持单行标题布局。
Widget buildCloudServiceSectionHeader(
  BuildContext context,
  String title, {
  String? subtitle,
}) {
  final Widget titleRow = Row(
    children: [
      // 左侧色条：用主题主色区分分组边界
      Container(
        width: 3,
        height: 15,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(SpitoutDimens.radius4),
        ),
      ),
      const SizedBox(width: SpitoutDimens.p8),
      Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: SpitoutTokens.textPrimary(context),
        ),
      ),
    ],
  );

  // 未传入副标题时，复用单行标题的原有布局，确保最新代码逻辑完全不受影响
  if (subtitle == null) {
    return Padding(
      padding: const EdgeInsets.only(top: SpitoutDimens.p4, bottom: SpitoutDimens.p8),
      child: titleRow,
    );
  }

  // 传入副标题时，在标题下方补充一行说明性文案，使用次级文字颜色降低视觉权重
  return Padding(
    padding: const EdgeInsets.only(top: SpitoutDimens.p4, bottom: SpitoutDimens.p8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titleRow,
        Padding(
          padding: const EdgeInsets.only(top: SpitoutDimens.p4),
          child: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: SpitoutTokens.textSecondary(context),
            ),
          ),
        ),
      ],
    ),
  );
}

/// 云服务选择卡片（本地 / WebDAV / S3 / Supabase / Spitout Cloud 通用）。
Widget buildCloudServiceCard({
  required BuildContext context,
  required IconData icon,
  required Color iconColor,
  required String title,
  required String subtitle,
  required bool isSelected,
  bool isConfigured = true,
  bool isDisabled = false,
  required VoidCallback onTap,
  VoidCallback? onConfigure,
  VoidCallback? onShowGuide,
}) {
  return Opacity(
    opacity: isDisabled ? 0.5 : 1.0,
    child: Container(
      decoration: BoxDecoration(
        // 选中/未选中均保留 2px 边框占位（未选中为透明），确保固定高度下
        // 所有卡片高度完全一致，不会因是否绘制绿色边框而产生 2px 高度差。
        border: Border.all(
          color: isSelected
              ? SpitoutTokens.success(context)
              : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(SpitoutDimens.radius12),
      ),
      child: SectionCard(
        margin: EdgeInsets.zero,
        // 将 SectionCard 默认 12 内边距收窄为 p4：按钮/勾选浮层 right:0 仅距卡片外边 4px
        // （保留轻量边缘留白）。
        padding: const EdgeInsets.all(SpitoutDimens.p4),
        // Stack 让「配置 / 教程」按钮行以绝对定位浮在卡片右下角，不参与布局流，
        // 因此卡片内容区高度可严格等于本地卡片（无按钮行）的自然高度，保证整页卡片等高一致。
        child: Stack(
          children: [
            // 基础层：整卡可点击选中。高度写死为本地卡片内容自然高度（约 71，
            // 即「上下内边距 10+10 + 图标/文案 51」），不随按钮行的有无而伸缩，
            // 从而所有卡片（含无按钮的本地存储卡）高度完全相同、且贴合本地卡片视觉。
            InkWell(
              onTap: isDisabled ? null : onTap,
              borderRadius: BorderRadius.circular(SpitoutDimens.radius12),
              child: SizedBox(
                height: 71,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpitoutDimens.p12,
                    vertical: SpitoutDimens.p8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 图标
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(SpitoutDimens.radius8),
                        ),
                        child: Icon(icon, color: iconColor, size: SpitoutDimens.icon16),
                      ),
                      const SizedBox(width: SpitoutDimens.p8),

                      // 文字信息。副标题为单行省略（兼顾固定卡片高度与长 URL 不横向溢出），
                      // 按钮行已下移到卡片底部右下角，与副标题在视觉上错开，无需额外右侧避让。
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (isDisabled)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: SpitoutDimens.p8,
                                      vertical: SpitoutDimens.p4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: SpitoutTokens.textTertiary(
                                        context,
                                      ).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(SpitoutDimens.radius8),
                                    ),
                                    child: Text(
                                      '不可用',
                                      style: SpitoutTextTokens.caption(context).copyWith(color: SpitoutTokens.textTertiary(
                                          context,
                                        )),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: SpitoutTokens.textSecondary(context),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 选中标记浮层：固定在卡片右上角，与右下角按钮行对称、互不重叠。
            // 仅当选中且未禁用时显示，纯展示、不参与布局高度。
            if (isSelected && !isDisabled)
              Positioned(
                top: 0,
                right: 6,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: SpitoutTokens.success(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    AppIcons.check,
                    color: SpitoutTokens.textOnPrimary(context),
                    size: SpitoutDimens.icon16,
                  ),
                ),
              ),

            // 覆盖层：配置 / 教程按钮行浮于右下角，拥有独立点击区域，
            // 不会触发卡片选中，也不参与布局高度（浮在卡片之上）。
            if (!isDisabled &&
                ((isConfigured && onConfigure != null) || onShowGuide != null))
              Positioned(
                right: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onShowGuide != null)
                      TextButton.icon(
                        onPressed: onShowGuide,
                        icon: const Icon(AppIcons.help, size: SpitoutDimens.icon16),
                        label: Text(
                          AppLocalizations.of(context).commonTutorial,
                          style: SpitoutTextTokens.label(context),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SpitoutDimens.p8,
                            vertical: SpitoutDimens.p4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    if (isConfigured && onConfigure != null) ...[
                      if (onShowGuide != null) const SizedBox(width: SpitoutDimens.p8),
                      TextButton.icon(
                        onPressed: onConfigure,
                        icon: const Icon(AppIcons.settings, size: SpitoutDimens.icon16),
                        label: Text(
                          AppLocalizations.of(context).commonConfigure,
                          style: SpitoutTextTokens.label(context),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SpitoutDimens.p12,
                            vertical: SpitoutDimens.p8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// 后端类型的用户可见名称。
String cloudBackendTypeName(BuildContext context, CloudBackendType type) {
  switch (type) {
    case CloudBackendType.local:
      return AppLocalizations.of(context).cloudLocalStorageTitle;
    case CloudBackendType.supabase:
      return 'Supabase';
    case CloudBackendType.webdav:
      return 'WebDAV';
    case CloudBackendType.s3:
      return 'S3';
    case CloudBackendType.spitoutCloud:
      return 'Spitout Cloud';
  }
}

/// 将时间格式化为固定的 YYYY-MM-DD HH:MM:SS（手动格式化，避免 locale 改变日期顺序）。
String formatCloudTestTime(DateTime dt) {
  // 使用函数声明而非变量赋值来绑定函数，避免 prefer_function_declarations_over_variables 警告
  String p(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${p(dt.month)}-${p(dt.day)} ${p(dt.hour)}:${p(dt.minute)}:${p(dt.second)}';
}
