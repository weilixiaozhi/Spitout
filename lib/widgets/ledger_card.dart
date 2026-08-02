/// 账本卡片组件
///
/// 展示账本基本信息，同步状态通过 syncStatusProvider 单独获取
library;

import 'package:flutter/material.dart';
import 'package:spitout/cloud/spitout_cloud.dart' show CloudBackendType;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import 'package:spitout/providers/sync/sync_providers.dart';
import '../utils/format_utils.dart';
import 'currency_flag.dart';
import 'format_money.dart';
import '../l10n/app_localizations.dart';
import '../theme/colors.dart';
import '../theme/icons/app_icons.dart';

/// 账本卡片
class LedgerCard extends ConsumerWidget {
  final LedgerDisplayItem ledger;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 右下角编辑按钮回调 —— 与 [onLongPress] 调同一个入口（进入编辑二级页面）。
  /// 长按是不可发现的手势,必须有一个可见的等价入口。
  final VoidCallback? onMore;
  final bool selected;

  const LedgerCard({
    super.key,
    required this.ledger,
    this.onTap,
    this.onLongPress,
    this.onMore,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context);

    // 获取同步状态
    final syncStatusAsync = ref.watch(syncStatusProvider(ledger.id));
    final syncStatus = syncStatusAsync.valueOrNull;

    // 检查是否正在上传
    final uploadingIds = ref.watch(uploadingLedgerIdsProvider);
    final isUploading = uploadingIds.contains(ledger.id);

    // 判断同步状态
    final isSynced = syncStatus?.diff == SyncDiff.inSync;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: SpitoutTokens.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: SpitoutTokens.isDark(context)
              ? Border.all(color: SpitoutTokens.border(context), width: 1)
              : null,
          boxShadow: SpitoutTokens.isDark(context)
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // 左侧色条：仅选中时显示
              if (selected)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                  ),
                ),

              // 底层：账本信息（始终显示）
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 顶部：名称 + 状态图标
                    Row(
                      children: [
                        // 账本名称
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: translateLedgerName(context, ledger.name),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: SpitoutTokens.textPrimary(context),
                                  ),
                                ),
                                TextSpan(
                                  text: ' (ID:${ledger.id})',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: SpitoutTokens.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 共享账本角标 + 成员数,图标与成员管理入口保持一致
                        if (ledger.isShared) ...[
                          const SizedBox(width: 6),
                          Icon(
                            AppIcons.people,
                            size: 14,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${ledger.memberCount}',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                            ),
                          ),
                        ],

                        const SizedBox(width: 8),

                        // 状态图标
                        _buildStatusIcon(
                          context,
                          ref,
                          isSynced,
                          isUploading,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 统计数据（本地和远程都显示）
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 币种：全局统一「ISO + (符号)」展示
                        Row(
                          children: [
                            Text(
                              '${l10n.ledgersCurrency}：',
                              style: TextStyle(
                                fontSize: 14,
                                color: SpitoutTokens.textSecondary(context),
                              ),
                            ),
                            currencyFlagLabel(
                              context,
                              ledger.currency,
                              textStyle: TextStyle(
                                fontSize: 14,
                                color: SpitoutTokens.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 记账笔数
                        Text(
                          l10n.ledgersRecords('${ledger.transactionCount}'),
                          style: TextStyle(
                            fontSize: 14,
                            color: SpitoutTokens.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 支出：账本累计支出总额（数据即 expenseTotal；中性显示，不取负、不染色）
                        Text(
                          l10n.ledgersExpense(
                            // 符号+金额统一走唯一来源 formatMoneyWithCurrency
                            formatMoneyWithCurrency(ledger.expenseTotal,
                                currencyCode: ledger.currency),
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: SpitoutTokens.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 右下角编辑按钮(进入编辑二级页面)
              if (onMore != null)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: IconButton(
                    onPressed: onMore,
                    tooltip: l10n.ledgersEdit,
                    icon: Icon(
                      AppIcons.edit,
                      size: 20,
                      color: SpitoutTokens.iconSecondary(context),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 状态图标
  ///
  /// 图标策略(UI 不判断具体后端实现,只认两个输入):
  /// 1. 账本归属 storage_mode → 是否画"云"图标;
  /// 2. 激活后端枚举 → 画哪种云:Spitout Cloud=cloudy,其它云后端=database。
  /// 颜色语义:绿=已同步,红=未同步/有备份但当前未配置云,灰=纯本地。
  ///
  /// 为什么用 storage_mode 判断云图标:归属模型下用户可以把云端账本移回本地,
  /// 此时 syncId 已清空;反过来也存在"标了 cloud 但 syncId 还没补上"的中间态。
  /// 判断"这本账会不会同步"的唯一权威是 storage_mode,图标必须跟它保持一致,
  /// 否则用户看到云图标却发现根本不同步。
  Widget _buildStatusIcon(
    BuildContext context,
    WidgetRef ref,
    bool isSynced,
    bool isUploading,
  ) {
    // 优先显示上传中状态
    if (isUploading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
        ),
      );
    }

    // 统一读取当前激活后端类型:本地账本据此判断是否处于快照备份态,
    // 云端账本据此决定图标形状(云端账本恒为云形,此处仅保留读取以备扩展)。
    final backendType =
        ref.watch(activeCloudConfigProvider).valueOrNull?.type;

    // 云端账本:恒为云形图标。仅 SpitoutCloud 真正持有云端账本,切走后已被 purge
    // 清空;webdav/s3/supabase 属"本地快照备份"范畴,云端账本形态一致用云形。
    if (ledger.isCloudLedger) {
      // 已同步：绿色；其余（未同步 / 有备份但云状态脱钩）统一红色提醒。
      final color = isSynced ? Colors.green : Colors.red;
      return Icon(AppIcons.cloudQueue, color: color, size: 20);
    }

    // 纯本地账本(storage_mode='local'):默认灰色硬盘图标表达"纯本地无备份"。
    // 但若当前激活后端是快照型(webdav/s3/supabase),本地账本会被周期性快照
    // 备份到这些后端,用 database 图标表达"有快照备份",与纯本地视觉区分。
    final isSnapshotBackup = backendType == CloudBackendType.webdav ||
        backendType == CloudBackendType.s3 ||
        backendType == CloudBackendType.supabase;
    if (isSnapshotBackup) {
      return const Icon(AppIcons.storage, color: Colors.grey, size: 20);
    }
    return const Icon(AppIcons.localStorage, color: Colors.grey, size: 20);
  }

}
