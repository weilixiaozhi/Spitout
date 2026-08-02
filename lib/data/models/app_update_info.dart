/// 应用更新检查相关纯数据模型。
///
/// 设计意图：
/// UI 层（pages/widgets）从本文件（或经 data/models.dart barrel）获取
/// 更新检查的纯数据类型，不直连 `services/update/app_update_service.dart`。
/// 这些类型不依赖任何 service 实现（不持有 provider / http 客户端 / db
/// 引用），属于纯数据结构——依赖方向保持
/// `pages/widgets → providers → services → data` 单向流动。
///
/// 注意：本文件**不包含** AppUpdateService 实现（它留在 services 层），
/// 只包含跨层共享的数据模型。services 层反向 import 本文件
/// （services → data）是规则允许的方向。
library;

/// 更新检查的状态枚举。
///
/// 设计意图：把「结果」与「异常」解耦。私有仓库匿名请求会返回 401、
/// 网络抖动会抛异常，这些都不应表现为硬错误，而应降级为 [unknown]，
/// 由 UI 统一引导用户前往 GitHub（浏览器带登录态，私有仓库也可访问）。
enum UpdateStatus {
  /// 检测到新版本
  hasUpdate,

  /// 已是最新版本
  latest,

  /// 无法自动检测（私有仓库 / 网络异常等），需引导用户手动前往 GitHub
  unknown,
}

/// 「检查更新」的结果。
class AppUpdateInfo {
  /// 发布/下载页基础地址（无具体 release 时使用）。
  ///
  /// 设计意图：作为静态常量随模型迁移，保证 `releaseUrl` 为 null 时
  /// UI 侧 `??` 兜底始终可用，模型不变量不依赖「当前唯一生产构造点」。
  static const String releasePageBase =
      'https://github.com/weilixiaozhi/Spitout/releases';

  /// 检查状态（三态），UI 据此切换弹窗样式与按钮。
  final UpdateStatus status;

  /// 是否存在比当前更新的版本（与 [status] 保持一致，便于旧调用方判断）。
  final bool hasUpdate;

  /// 远端最新版本号（去 "v" 后，如 "1.0.1"），无数据时为空。
  final String? latestVersion;

  /// 远端 release 的 HTML 地址，用于引导下载。可为空，UI 侧需以
  /// [releasePageBase] 兜底（共识②：保留 `??` 兜底，不用 `!` 断言）。
  final String? releaseUrl;

  /// 当前已安装的版本号。
  final String currentVersion;

  const AppUpdateInfo({
    required this.status,
    required this.hasUpdate,
    this.latestVersion,
    this.releaseUrl,
    required this.currentVersion,
  });
}
