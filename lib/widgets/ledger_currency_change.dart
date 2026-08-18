import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/providers/core/post_processor.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/utils/currency/currencies.dart';
// 直接 import 兄弟文件而非 widgets.dart，避免组件反向依赖自身 barrel 成环。
import 'toast.dart';

/// 统一切换账本本位币(两入口共用:账本编辑弹窗保存、汇率页基准行)。
///
/// 流程固定:
/// 1. 同值(忽略大小写)跳过;
/// 2. 账本交易数 > 0 → 弹拦截确认弹窗,文案明确「重算覆盖 + 往返不可还原」后果;
///    0 笔跳过弹窗;取消则整体中止;
/// 3. force 预拉新本位币汇率 → 4. 同一事务内改币种并全量重算 nativeAmount →
/// 5. 新本位币补入当前账本可见集合 →
/// 6. 刷新信号(先于同步发,UI 不等 push) → 7. PostProcessor.sync →
/// 8. Toast 完成提示。
///
/// 折算快照语义(破坏性说明):切本位币是唯一覆盖历史快照的操作——
/// 旧快照按旧本位币折算,口径变更后必须全量重算;往返切换(切走再切回)
/// ≠ 撤销,外币交易记账时刻的原始折算值永久丢失。
/// 缺汇率的笔退化 native=amount,由统计页补折算横幅兜底捞回。
///
/// 返回值:`true` = 已实际应用切换;`false` = 同值跳过或用户在确认弹窗取消
/// (调用方可据此中止本次编辑中其他字段的保存,保持「一次编辑要么全部生效
/// 要么全部放弃」的语义)。
Future<bool> applyLedgerCurrencyChange(
  BuildContext context,
  WidgetRef ref, {
  required int ledgerId,
  required String newCurrency,
}) async {
  final next = newCurrency.trim().toUpperCase();
  if (next.isEmpty) return false;
  final repo = ref.read(repositoryProvider);

  // 1. 同值跳过(忽略大小写)
  final ledger = await repo.getLedgerById(ledgerId);
  if (ledger == null) return false;

  // 【权限边界】共享账本协作者禁止修改账本元信息（含币种）。
  // 该中央守卫同时覆盖「账本编辑页」与「汇率页」两个币种入口，
  // 即便 UI 层未置灰，也能在服务调用处拦截非法变更。
  if (ledger.isShared && ledger.myRole != 'owner') {
    if (context.mounted) {
      showToast(context, AppLocalizations.of(context).ledgerMetaReadOnlyToast);
    }
    return false;
  }

  if (ledger.currency.toUpperCase() == next) return false;

  // 2. 有交易时弹拦截确认:必须告知「切换即覆盖、往返不可还原」
  final stats = await repo.getLedgerStats(ledgerId: ledgerId);
  final txCount = stats.transactionCount;
  if (txCount > 0) {
    if (!context.mounted) return false;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(l10n.ledgerBaseCurrencyLabel),
        content: Text(
          '${l10n.ledgerCurrencyChangeRecalcHint}\n'
          '${l10n.recalcSyncCountHint(txCount)}\n'
          '${l10n.ledgerCurrencyChangeRecalcWarning}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(AppLocalizations.of(dctx).commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(AppLocalizations.of(dctx).commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
  }

  // 3. 先强制拉一次「以新本位币为 base」的汇率。网络 I/O 必须发生在
  // 原子换币事务之前，否则进程在 updateLedger 后中断会留下新币种配旧快照。
  // extraQuotes 带上账本实际涉及的全部外币 ∪ {新币种}。拉取失败也继续——
  // 缺汇率的笔退化 =amount,由补折算横幅兜底,绝不保留旧口径错值。
  try {
    final foreign = await repo.getLedgerForeignCurrencies(ledgerId);
    await refreshExchangeRatesFromUi(
      ref,
      force: true,
      // 历史交易可能没有 currencyCode，其 amount 仍属于换币前的本位币；
      // 主动拉取旧本位币汇率，才能在重算时恢复其真实记账币种口径。
      extraQuotes: {...foreign, ledger.currency, next},
      // 新币种尚未写入 ledgers，必须显式加入 base 集合才能提前落下该组汇率。
      extraBases: {next},
    );
  } catch (e, st) {
    logger.warning('ledger_currency_change', '切本位币前拉取汇率失败(继续重算): $e', st);
  }

  // 4. 元数据更新、逐笔快照重算及其 local_changes 必须同事务提交。
  // 任一步失败都会整体回滚，杜绝“新本位币 + 旧 nativeAmount”的静默错账。
  final recalcCount = await repo.runInTransaction(() async {
    await repo.updateLedger(id: ledgerId, currency: next);
    return repo.recalcNativeAmountsForLedger(
      ledgerId,
      next,
      previousBase: ledger.currency,
    );
  });

  // 5. 新本位币补入当前账本可见集合(仅当切的是当前账本;
  // 非当前账本的集合在其首次访问时按「13 常用 ∪ 本位币」初始化,天然含新币种)
  if (ref.read(currentLedgerIdProvider) == ledgerId) {
    await ensureCurrencyVisibleForCurrentLedger(ref, next);
  }

  // 6. 刷新信号必须在 sync 之前发:重算产生大量 change,push 可能耗时数十秒
  // 甚至失败;本地数据此刻已就绪,立即刷新,UI 不等 push。
  ref.read(ledgerListRefreshProvider.notifier).tick();
  // currentLedgerProvider 已是 StreamProvider(Drift watch 自动推送),
  // 此 invalidate 仅作防御性重订阅(如流曾进入 error 态),正常路径冗余无害。
  ref.invalidate(currentLedgerProvider);
  ref.invalidate(monthlyTotalsProvider);

  // 7. 触发同步把账本元数据 + 重算 change 推到云端;失败仅告警,本地已生效
  try {
    await PostProcessor.sync(ref, ledgerId: ledgerId);
  } catch (e) {
    logger.warning('ledger_currency_change', '切本位币后同步失败(本地已生效,下次同步重试): $e');
  }

  // 8. Toast 完成提示
  if (!context.mounted) return true;
  final l10n = AppLocalizations.of(context);
  if (recalcCount > 0) {
    showToast(context, l10n.recalcForeignTxDone(recalcCount));
  }
  showToast(context, l10n.homeBaseCurrencySwitched(displayCurrency(next, context)));
  return true;
}
