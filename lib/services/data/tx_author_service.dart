import 'package:spitout/cloud/spitout_cloud.dart';

import '../../data/repositories/base_repository.dart';
import '../../data/repositories/local/local_repository.dart';
import '../../core/logging/logger_service.dart';

/// 交易作者标记工具。
///
/// 依赖方式：本服务不 import providers 层（services → providers 为反向
/// 依赖），所需的云实例与仓储由调用方（widget / provider 编排层）读取
/// provider 后以参数显式注入。
///
/// 调用场景:
/// - `markCreated`:本地新建 tx 后调,写 createdByUserId + lastEditedByUserId,
///   并按规则回填 paidByUserId(为空时取操作者,已显式写入的值不覆盖)。
/// - `markEdited`:本地编辑 tx 后调,写 lastEditedByUserId(createdByUserId
///   维持 first-write-wins);paidByUserId 为空时同样回填操作者,非空视为
///   用户手改值保留。
///
/// 本地账本兜底:cloud 为 null / 未登录 / currentUser 取不到 userId 时,
/// paidByUserId 用 'me' 占位(与 aaParticipantOptionsProvider 兜底口径一致),
/// 保证全局非空。createdByUserId / lastEditedByUserId 在 cloud 不可用时仍
/// 不写(头像数据非关键路径)。
class TxAuthorService {
  TxAuthorService._();

  /// [cloud] 当前 Spitout Cloud provider 实例（未配置 / 未登录时传 null,
  /// 此时 paidByUserId 用 'me' 兜底）；[repo] 本地仓储（非 LocalRepository
  /// 时静默跳过）。
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
  /// 调用方据此决定 createdByUserId / lastEditedByUserId 是否写入;
  /// paidByUserId 在 userId 为空时由 _markImpl 用 'me' 兜底,不依赖此返回值。
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
      if (repo is! LocalRepository) return;

      // 读取当前操作者 userId;cloud 不可用时为 null,仅影响头像字段,
      // paidByUserId 走 'me' 兜底保证非空。
      String? userId;
      if (cloud != null) {
        try {
          final me = await cloud.auth.currentUser;
          userId = me?.id;
        } catch (e, st) {
          logger.warning('TxAuthorService', 'currentUser 读取失败', '$e\n$st');
        }
      }
      final hasUserId = userId != null && userId.isNotEmpty;

      // paidByUserId 兜底:userId 取不到时用 'me' 占位,保证全局非空。
      // createdByUserId / lastEditedByUserId 仅在 cloud userId 可用时写入,
      // 否则保持现有值(first-write-wins / null)。
      await repo.markTxAuthor(
        txId: txId,
        userId: hasUserId ? userId : '',
        isCreate: isCreate,
        fallbackUserId: hasUserId ? null : 'me',
      );
    } catch (e, st) {
      logger.error('TxAuthorService',
          'markImpl 失败 txId=$txId isCreate=$isCreate', e, st);
    }
  }
}
