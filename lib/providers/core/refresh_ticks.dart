import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/providers/core/simple_state_notifier.dart';

import 'package:spitout/data/db.dart';

// providers 层「叶子」模块：跨域共享的刷新 tick + 首屏缓存。
//
// 本文件不 import 任何其他 providers 子文件，处于 providers 层依赖链最底端；
// sync_providers / shared_ledger_providers / ui_state_providers 均单向依赖本文件。
//
// 消费方无需感知本文件：sync_providers.dart / ui_state_providers.dart /
// shared_ledger_providers.dart 均对其做了 re-export，可见符号不变。

/// 刷新账本列表的触发器
final ledgerListRefreshProvider =
    NotifierProvider<TickStateNotifier, int>(() => TickStateNotifier((ref) => 0));

/// 共享账本资源刷新 tick：Owner 改 / WS 收 / accept 接受 → ++，picker / 反查
/// widget watch 它即可 reactive 刷新，确保跨设备改动立即反映到 Editor 的
/// picker UI。
final sharedResourceRefreshProvider =
    NotifierProvider<TickStateNotifier, int>(() => TickStateNotifier((ref) => 0));

// 首页切换到 Stream 模式触发器（用户交互时触发）
final homeSwitchToStreamProvider =
    NotifierProvider<TickStateNotifier, int>(() => TickStateNotifier((ref) => 0));

/// 完整的交易展示数据（不含标签、附件字段）
/// 用于首页列表一次性加载，避免二次查询闪烁
typedef TransactionDisplayItem = ({
  Transaction t,
  Category? category,
});

// 两侧使用方：sync_providers 的 bootstrap 完成时清缓存，
// ui_state_providers 的启屏预加载时写缓存。
final cachedTransactionsProvider = NotifierProvider<
    SimpleStateNotifier<List<TransactionDisplayItem>?>,
    List<TransactionDisplayItem>?>(
  () => SimpleStateNotifier((ref) => null),
);
