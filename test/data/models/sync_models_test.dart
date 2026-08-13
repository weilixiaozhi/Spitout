// sync_models 纯数据模型测试。
//
// 需求锚点：
//   1. PullOutcome.total = incremental + healed；
//   2. SyncCountPair.hasDiff / remoteOnly（remote 拉不到 -1 时恒 0，避免误触发自愈）；
//   3. SyncHealthReport 三种工厂（error/recovering/needsLogin）与 hasDiff / needsBackfill 判定。

import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/models.dart';

void main() {
  test('PullOutcome.total 汇总增量与自愈', () {
    const outcome = PullOutcome(
      incremental: 3,
      healed: 2,
      didHeal: true,
    );
    expect(outcome.total, 5);
    expect(outcome.didHeal, isTrue);
  });

  test('SyncCountPair.hasDiff / remoteOnly', () {
    expect(const SyncCountPair(local: 3, remote: 3).hasDiff, isFalse);
    expect(const SyncCountPair(local: 3, remote: 5).hasDiff, isTrue);
    expect(const SyncCountPair(local: 3, remote: 5).remoteOnly, 2);
    expect(const SyncCountPair(local: 5, remote: 3).remoteOnly, 0);
    // remote 拉不到（-1）时 remoteOnly 恒 0，避免网络错误被误判为自愈缺口
    expect(const SyncCountPair(local: 0, remote: -1).hasDiff, isFalse);
    expect(const SyncCountPair.missing().remoteOnly, 0);
  });

  test('SyncHealthReport 工厂与 hasDiff/needsBackfill', () {
    final error = SyncHealthReport.error('boom');
    expect(error.error, 'boom');
    expect(error.hasDiff, isFalse);
    expect(error.needsBackfill, isFalse);

    final recovering = SyncHealthReport.recovering(const Duration(seconds: 5));
    expect(recovering.recovering, isTrue);
    expect(recovering.recoveryRemaining, const Duration(seconds: 5));

    final needsLogin = SyncHealthReport.needsLogin();
    expect(needsLogin.needsLogin, isTrue);

    // 本地多、云端少 → needsBackfill（仅 category 维度）
    final backfill = SyncHealthReport(
      ledgerTx: const SyncCountPair(local: 1, remote: 1),
      totalTx: const SyncCountPair(local: 1, remote: 1),
      categories: const SyncCountPair(local: 5, remote: 2),
      unpushedChanges: 0,
    );
    expect(backfill.needsBackfill, isTrue);
    expect(backfill.hasDiff, isTrue);

    // 有 unpushed change 时不进回填分支
    final pending = SyncHealthReport(
      ledgerTx: const SyncCountPair(local: 1, remote: 1),
      totalTx: const SyncCountPair(local: 1, remote: 1),
      categories: const SyncCountPair(local: 5, remote: 2),
      unpushedChanges: 1,
    );
    expect(pending.needsBackfill, isFalse);
    expect(pending.hasDiff, isTrue);
  });
}
