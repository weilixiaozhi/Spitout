// 共享账本:本地写 tx 后回填创建人 / 编辑人。
// 不阻塞主流程 — auth 取不到 / 单人账本场景静默跳过,不抛错。
import 'package:spitout/cloud/spitout_cloud.dart';

import '../../data/repositories/base_repository.dart';
import '../../data/repositories/local/local_repository.dart';
import '../../core/logging/logger_service.dart';

/// 共享账本 tx 作者标记工具。
///
/// 依赖方式：本服务不 import providers 层（services → providers 为反向
/// 依赖），所需的云实例与仓储由调用方（widget / provider 编排层）读取
/// provider 后以参数显式注入。
///
/// 调用场景:
/// - `markCreated`:本地新建 tx 后调,写 createdByUserId + lastEditedByUserId
/// - `markEdited`:本地编辑 tx 后调,只写 lastEditedByUserId(createdByUserId
///   维持 first-write-wins)
///
/// 失败一律 swallow 走 logger.warning — 头像数据不是关键路径,影响仅是 UI
/// 展示稍迟回填(下次 server pull / push 拉回时也会修正)。
class TxAuthorService {
  TxAuthorService._();

  /// [cloud] 当前 Spitout Cloud provider 实例（未配置 / 未登录时传 null，
  /// 静默跳过）；[repo] 本地仓储（非 LocalRepository 时静默跳过）。
  static Future<void> markCreated(
    SpitoutCloudProvider? cloud,
    BaseRepository repo,
    int txId,
  ) =>
      _markImpl(cloud, repo, txId, isCreate: true);

  /// 参数语义同 [markCreated]。
  static Future<void> markEdited(
    SpitoutCloudProvider? cloud,
    BaseRepository repo,
    int txId,
  ) =>
      _markImpl(cloud, repo, txId, isCreate: false);

  /// 读取当前登录用户 id;未登录 / 未初始化 / 异常时返回 null。
  ///
  /// 设计意图:编辑器在写编辑历史时需要 operatorUserId,但"如何拿到当前
  /// 用户 id"属于作者域知识,集中在此处暴露一个只读入口,避免 UI 层各自
  /// 重复 cloud.auth.currentUser 的样板代码,也便于未来鉴权方式变更时
  /// 只改一处。返回 null 时调用方应理解为本机单人模式,历史记录不写
  /// operatorUserId(详情页对应行不显示操作者)。
  static Future<String?> currentUserId(SpitoutCloudProvider? cloud) async {
    try {
      if (cloud == null) return null;
      final me = await cloud.auth.currentUser;
      final userId = me?.id;
      if (userId == null || userId.isEmpty) return null;
      return userId;
    } catch (e, st) {
      logger.warning('TxAuthorService', 'currentUserId 读取失败', '$e\n$st');
      return null;
    }
  }

  static Future<void> _markImpl(
    SpitoutCloudProvider? cloud,
    BaseRepository repo,
    int txId, {
    required bool isCreate,
  }) async {
    try {
      if (cloud == null) return;
      final me = await cloud.auth.currentUser;
      final userId = me?.id;
      if (userId == null || userId.isEmpty) return;
      if (repo is! LocalRepository) return;
      await repo.markTxAuthor(
        txId: txId,
        userId: userId,
        isCreate: isCreate,
      );
    } catch (e, st) {
      logger.error('TxAuthorService',
          'markImpl 失败 txId=$txId isCreate=$isCreate', e, st);
    }
  }
}
