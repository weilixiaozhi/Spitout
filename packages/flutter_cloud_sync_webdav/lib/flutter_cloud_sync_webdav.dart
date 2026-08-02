/// WebDAV provider for flutter_cloud_sync.
///
/// This library provides WebDAV integration for the flutter_cloud_sync package,
/// enabling cloud synchronization using WebDAV protocol with Basic Auth.
///
/// To use this library:
///
/// ```dart
/// import 'package:flutter_cloud_sync_webdav/flutter_cloud_sync_webdav.dart';
///
/// final provider = WebDAVProvider();
/// await provider.initialize({
///   'url': 'https://webdav.example.com',
///   'username': 'your-username',
///   'password': 'your-password',
///   'remotePath': '/sync/', // optional, defaults to '/'
/// });
/// ```
library;

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

import 'src/webdav_provider.dart';

export 'src/webdav_provider.dart';
export 'src/webdav_auth_service.dart';
export 'src/webdav_storage_service.dart';

/// 把 WebDAV 后端自注册到核心包的 [CloudProviderRegistry]。
///
/// 插件化约定：核心包不依赖本 adapter；由主工程 Composition Root（main.dart）
/// 调用本函数完成注册后，`createCloudServices` 才能分发到 WebDAV。
/// 重复调用安全（后者覆盖前者）。
void registerWebDavBackend() {
  CloudProviderRegistry.register(CloudBackendType.webdav, (config) async {
    final provider = WebDAVProvider();
    await provider.initialize({
      'url': config.webdavUrl!,
      'username': config.webdavUsername!,
      'password': config.webdavPassword!,
      'remotePath': config.webdavRemotePath ?? '/',
    });

    // Auth service 直接从 provider 获取
    return (provider: provider, auth: provider.auth);
  });
}
