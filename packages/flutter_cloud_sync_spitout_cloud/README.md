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
