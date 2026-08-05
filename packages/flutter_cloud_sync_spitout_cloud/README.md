# flutter_cloud_sync_spitout_cloud

Spitout Cloud provider for [flutter_cloud_sync](../flutter_cloud_sync), enabling cloud
synchronization using the Spitout private cloud protocol.

> **注意**：本包为 Flutter 纯 Dart 实现（依赖 `dart:io`），不支持 Web 平台。

## Features

- ✅ Spitout Cloud authentication integration (含两步验证)
- ✅ Spitout Cloud storage support
- ✅ Spitout Cloud realtime subscription (WebSocket)
- ✅ Type-safe CloudProvider implementation
- ✅ 通过 `CloudProviderRegistry` 自注册，核心包保持零反向依赖

## Security

- access / refresh token 默认经 `flutter_secure_storage` 写入系统安全存储
  （Android Keystore / iOS Keychain / Windows DPAPI / macOS Keychain），
  不会明文写入 SharedPreferences；旧版本明文 session 会在首次初始化时
  自动迁移并清理。
- 远程 `baseUrl` 强制使用 https；http 仅允许 localhost / 私网测试地址，
  防止邮箱 + 密码 / token 明文走网络。
- WebSocket 鉴权通过握手后首帧消息携带 token，token 不会出现在 URL query /
  代理日志中。
- 已知风险：服务端头像下载端点当前不校验 auth（为 Web `<img>` 无头加载而
  设计），按用户 id 可枚举公开头像；服务端补鉴权或签名 URL 属于独立的
  服务端改造项。

## Installation

Add this to your package's `pubspec.yaml`:

```yaml
dependencies:
  flutter_cloud_sync: ^0.1.0
  flutter_cloud_sync_spitout_cloud: ^0.1.0
```

## Usage

```dart
import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

// 1. 注册（一般放在 Composition Root / main.dart）
registerSpitoutCloudBackend();

// 2. 通过注册表创建
final provider = cloudProviderRegistry.builderFor(CloudBackendType.spitoutCloud)?.call(
  const CloudServiceConfig(
    authBaseUrl: 'https://api.example.com',
  ),
);
```

## License

This package is part of the Spitout project and uses the same license.
