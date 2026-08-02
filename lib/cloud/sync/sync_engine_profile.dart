part of 'sync_engine.dart';

/// 用户 profile + avatar 同步。拉 `/profile/me` 把支配配色 / 外观
/// / 显示名 / 头像都回写到本地。
///
/// `syncMyProfile` 是 public,被外部 sync_providers / 内部 WS 事件调用,
/// 所以 extension 名是 public。
///
/// app 不消费 `primary_currency`(折算基准已账本维度化),
/// 这里只拉仍在使用的字段。
extension SyncEngineProfile on SyncEngine {
  /// 独立调这个而不是夹在 sync() 中间（sync() 前置步骤抛错会 skip 掉这里）。
  /// 返回 true 表示有实际下载并写盘，调用方用来决定要不要 bump 刷新信号。
  /// 拉 /profile/me 并把 appearance /
  /// 头像都落回本地(SharedPreferences + 本地文件)。任意字段有更新都返 true,
  /// 让调用方 bump 对应 UI refresh tick。
  ///
  /// 所有字段更新走 [events] stream emit `ProfileFieldApplied` 事件,
  /// UI 通过 syncEventStreamProvider 订阅处理。
  Future<bool> syncMyProfile() async {
    final localVersion = await avatarStorage.getStoredRemoteVersion();
    logger.info('avatar_sync',
        'syncMyProfile start, localVersion=$localVersion');
    bool anyChanged = false;
    try {
      final profile = await provider.getMyProfile();

      // === display_name === (只在 server 有值时下行;不下空,故对端不会被清空)
      final displayName = profile.displayName;
      if (displayName != null && displayName.isNotEmpty) {
        _emit(ProfileFieldApplied.displayName(displayName));
        anyChanged = true;
      }

      // === appearance (show_transaction_time / expense_color_scheme) ===
      final appearance = profile.appearance;
      if (appearance != null && appearance.isNotEmpty) {
        _emit(ProfileFieldApplied.appearance(appearance));
        anyChanged = true;
      }

      // === avatar ===
      final url = profile.avatarUrl;
      final remoteVersion = profile.avatarVersion;
      logger.info('avatar_sync',
          'got profile url=$url remoteVersion=$remoteVersion');
      // 服务端头像已删除(avatar_url 为 null):
      // 若本机这份头像来自云端(localVersion>0),说明是云端缓存,需同步清掉并通知
      // UI 刷新,否则其它设备/本机再次同步时还会残留过期头像(即"回灌");
      // 纯本地头像(localVersion==0,从未上传/下载过云端头像)则不动,避免误删。
      if (url == null || url.isEmpty) {
        // 复用外层已声明的 localVersion,此处不重复声明
        if (localVersion > 0) {
          logger.info('avatar_sync',
              'server avatar gone, clear local cached avatar (localVersion=$localVersion)');
          try {
            await avatarStorage.deleteAvatar();
          } catch (e, st) {
            // 本地缓存清不掉不应中断同步:服务端头像已删,UI 靠 emit 仍会刷新
            logger.warning('avatar_sync', 'clear local avatar failed: $e', st);
          }
          _emit(const AvatarChanged()); // 通知 UI 刷新(走 avatarRefreshProvider)
          return true;
        }
        logger.info('avatar_sync', 'server has no avatar, local is local-only, skip');
        return anyChanged;
      }
      // 复用外层已声明的 localVersion 做版本比对,不重复声明
      if (remoteVersion > 0 && remoteVersion == localVersion) {
        logger.info('avatar_sync',
            'avatar up-to-date (version=$remoteVersion), skip download');
        return anyChanged;
      }
      // profile 头像专用下载路径:服务端 URL 是 `/profile/avatar/<user_id>?v=<v>`，
      // 与 attachment 存储(`/attachments/{fileId}`)不是同一套,不能从 avatar_url
      // 里抠 fileId 走 downloadAttachment。直接用 downloadMyAvatar(userId,
      // version) 走正确的端点。
      final bytes = await provider.downloadMyAvatar(
        userId: profile.userId,
        version: remoteVersion > 0 ? remoteVersion : null,
      );
      logger.info('avatar_sync', 'downloaded size=${bytes.length}B');
      await avatarStorage.saveAvatarFromBytes(bytes);
      await avatarStorage.setStoredRemoteVersion(remoteVersion);
      logger.info('avatar_sync',
          'saved to local, bumped localVersion=$remoteVersion');
      // 真下载了头像才 emit AvatarChanged,让 UI bump avatarRefreshProvider。
      // up-to-date / no avatar 分支不触发,避免冷启动一次刷新。
      _emit(const AvatarChanged());
      return true;
    } catch (e, st) {
      logger.warning('avatar_sync', '同步失败: $e', st);
      return anyChanged;
    }
  }
}
