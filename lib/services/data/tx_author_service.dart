import 'package:spitout/cloud/spitout_cloud.dart';

import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/core/logging/logger_service.dart';

/// 交易作者标记工具。
///
/// 依赖方式：本服务不 import providers 层（services → providers 为反向
/// 依赖），所需的云认证实例、仓储、localSelfId 由调用方（widget / provider
/// 编排层）读取 provider 后以参数显式注入。
///
/// 依赖倒置：参数类型为 [CloudAuthService] 抽象接口（核心包定义），
/// 而非具体 `SpitoutCloudProvider`，使本服务不耦合特定后端适配器。
/// 调用方传 `cloud?.auth`（`SpitoutCloudProvider.auth` 即返回此接口）。
///
/// 调用场景:
/// - `markCreated`:本地新建 tx 后调,写 createdByUserId + lastEditedByUserId,
///   并按规则回填 paidByUserId(为空时取操作者 = 创建人,已显式写入的值不覆盖)。
/// - `markEdited`:本地编辑 tx 后调,仅写 lastEditedByUserId(createdByUserId
///   维持 first-write-wins);paidByUserId 不在编辑路径回填,保持新建时
///   确定的值(创建人或手动值)不变。
///
/// 身份解析优先级:云 userId(已登录) > localSelfId(未登录设备身份)。
/// 已登录时三字段(paidBy/createdBy/lastEditedBy)统一写云 userId;
/// 未登录时统一写 localSelfId(真 UUID,不再用 'me' 占位)。
class TxAuthorService {
  TxAuthorService._();

  /// 标记交易创建人。
  ///
  /// [auth] 当前云认证实例(未配置 / 未登录时传 null);
  /// [repo] 本地仓储(非 LocalRepository 时静默跳过);
  /// [localSelfId] 未登录时的设备身份(由调用方从 localSelfIdProvider 注入)。
  static Future<void> markCreated(
    CloudAuthService? auth,
    LocalRepository repo,
    int txId, {
    required String localSelfId,
  }) =>
      _markImpl(auth, repo, txId, isCreate: true, localSelfId: localSelfId);

  /// 标记交易编辑人。参数语义同 [markCreated]。
  static Future<void> markEdited(
    CloudAuthService? auth,
    LocalRepository repo,
    int txId, {
    required String localSelfId,
  }) =>
      _markImpl(auth, repo, txId, isCreate: false, localSelfId: localSelfId);

  /// 读取当前登录用户 id;未登录 / 未初始化 / 异常时返回 null。
  ///
  /// 调用方据此决定是否写云 userId;未登录时由 _markImpl 用 localSelfId 兜底。
  static Future<String?> currentUserId(CloudAuthService? auth) async {
    try {
      if (auth == null) return null;
      final me = await auth.currentUser;
      final userId = me?.id;
      if (userId == null || userId.isEmpty) return null;
      return userId;
    } catch (e, st) {
      logger.warning('TxAuthorService', 'currentUserId 读取失败', '$e\n$st');
      return null;
    }
  }

  /// 读取当前登录用户 id 的同步缓存（不触发网络刷新）。
  ///
  /// 供保存/导入等写路径使用：本地持久化会话在离线时也可用，
  /// 不等待 token refresh；未登录 / 会话未恢复时返回 null。
  static String? cachedCurrentUserId(CloudAuthService? auth) {
    try {
      if (auth == null) return null;
      final userId = auth.currentUserId;
      return (userId == null || userId.isEmpty) ? null : userId;
    } catch (e, st) {
      logger.warning('TxAuthorService', 'cachedCurrentUserId 读取失败', '$e\n$st');
      return null;
    }
  }

  static Future<void> _markImpl(
    CloudAuthService? auth,
    LocalRepository repo,
    int txId, {
    required bool isCreate,
    required String localSelfId,
  }) async {
    try {
      // 身份解析:优先云 userId,未登录时用 localSelfId 兜底。
      // localSelfId 是持久化的真 UUID,三字段统一写它,不再有 'me' 占位。
      String effectiveUserId;
      if (auth != null) {
        try {
          final me = await auth.currentUser;
          final cloudUserId = me?.id;
          if (cloudUserId != null && cloudUserId.isNotEmpty) {
            effectiveUserId = cloudUserId;
          } else {
            effectiveUserId = localSelfId;
          }
        } catch (e, st) {
          logger.warning('TxAuthorService', 'currentUser 读取失败,降级 localSelfId', '$e\n$st');
          effectiveUserId = localSelfId;
        }
      } else {
        effectiveUserId = localSelfId;
      }

      await repo.markTxAuthor(
        txId: txId,
        userId: effectiveUserId,
        isCreate: isCreate,
      );
    } catch (e, st) {
      logger.error('TxAuthorService',
          'markImpl 失败 txId=$txId isCreate=$isCreate', e, st);
    }
  }
}
