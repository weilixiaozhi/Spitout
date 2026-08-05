# flutter_cloud_sync

[![pub package](https://img.shields.io/pub/v/flutter_cloud_sync.svg)](https://pub.dev/packages/flutter_cloud_sync)

A modular cloud sync framework for Flutter with pluggable backend providers.

## Features

- 🔌 **Pluggable Architecture** - Choose your cloud provider (Supabase, WebDAV, S3, etc.)
- 🔄 **Auto Sync** - Automatic detection and synchronization of local/cloud changes
- 🎯 **Business Agnostic** - Works with any data model through serialization interface
- 🔐 **Authentication** - Built-in authentication service abstraction
- 📦 **Type-Safe** - Generic design with full type safety
- 🎭 **State Management** - Designed for Riverpod integration
- 📝 **Comprehensive Logging** - Hook into your existing logging framework

## Installation

Add the core package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_cloud_sync: ^0.1.0
```

Then add the cloud provider(s) you want to use:

```yaml
dependencies:
  flutter_cloud_sync_supabase: ^0.1.0  # For Supabase
  flutter_cloud_sync_webdav: ^0.1.0    # For WebDAV
  flutter_cloud_sync_s3: ^0.1.0        # For AWS S3
  flutter_cloud_sync_spitout_cloud: ^0.1.0  # For Spitout Cloud (self-hosted)
```

## Quick Start

### 1. Define Your Data Serializer

The serializer converts your business data to/from strings and calculates fingerprints:

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

class LedgerDataSerializer implements DataSerializer<int> {
  final Database db;

  LedgerDataSerializer(this.db);

  @override
  Future<String> serialize(int ledgerId) async {
    final transactions = await db.getTransactions(ledgerId);
    return jsonEncode({
      'ledgerId': ledgerId,
      'transactions': transactions,
    });
  }

  @override
  Future<int> deserialize(String data) async {
    final json = jsonDecode(data);
    return json['ledgerId'] as int;
  }

  @override
  String fingerprint(String data) {
    final bytes = utf8.encode(data);
    return sha256.convert(bytes).toString();
  }
}
```

### 2. Initialize Cloud Provider

```dart
import 'package:flutter_cloud_sync_supabase/flutter_cloud_sync_supabase.dart';

final provider = SupabaseProvider();
await provider.initialize({
  'url': 'https://your-project.supabase.co',
  'anonKey': 'your-anon-key',
  'bucket': 'user-data',
});
```

### 3. Create Sync Manager

```dart
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

final syncManager = CloudSyncManager<int>(
  provider: provider,
  serializer: LedgerDataSerializer(db),
  logger: CloudSyncLogger(onLog: (level, message) {
    print('[$level] $message');
  }),
);
```

### 4. Use It!

```dart
// Upload data to cloud
await syncManager.upload(
  ledgerId: 123,
  path: 'ledgers/123.json',
);

// Download data from cloud
final ledgerId = await syncManager.download(path: 'ledgers/123.json');

// Check sync status
final status = await syncManager.getStatus(
  ledgerId: 123,
  path: 'ledgers/123.json',
);

if (status.needsSync) {
  print('Data is out of sync!');
}

// Delete remote data
await syncManager.deleteRemote(path: 'ledgers/123.json');
```

## Integration with Riverpod

```dart
// Provider for cloud sync manager
final cloudSyncProvider = Provider<CloudSyncManager<int>>((ref) {
  final provider = ref.watch(cloudProviderProvider);
  return CloudSyncManager<int>(
    provider: provider,
    serializer: LedgerDataSerializer(ref.watch(databaseProvider)),
    logger: CloudSyncLogger(onLog: (level, message) {
      debugPrint('[$level] $message');
    }),
  );
});

// Stream provider for auth state
final authStateProvider = StreamProvider<CloudUser?>((ref) {
  final provider = ref.watch(cloudProviderProvider);
  return provider.auth.authStateChanges;
});

// FutureProvider for sync status
final syncStatusProvider = FutureProvider.family<SyncStatus, int>((ref, ledgerId) async {
  final syncManager = ref.watch(cloudSyncProvider);
  return syncManager.getStatus(
    ledgerId: ledgerId,
    path: 'ledgers/$ledgerId.json',
  );
});
```

## Available Cloud Providers

| Provider | Package | Authentication | Storage |
|----------|---------|----------------|---------|
| Supabase | `flutter_cloud_sync_supabase` | ✅ Email/Password | ✅ Storage API |
| WebDAV | `flutter_cloud_sync_webdav` | ✅ Basic Auth | ✅ WebDAV |
| AWS S3 | `flutter_cloud_sync_s3` | ❌ Uses IAM | ✅ S3 API |
| Spitout Cloud | `flutter_cloud_sync_spitout_cloud` | ✅ Email/Password + Session | ✅ Sync Engine |

## Security Notes

- **Login passwords are never persisted.** Spitout Cloud / Supabase passwords are
  treated as one-time input: `CloudServiceStore` strips them before writing to
  storage, so they never land in `SharedPreferences` (plaintext XML on Android).
- **WebDAV / S3 credentials use a pluggable credential backend.** These
  credentials are required for sync and are stored through
  `CloudCredentialStorage`. The default `SharedPreferencesCredentialStorage`
  keeps the historical plaintext behavior for compatibility; for production,
  inject a secure implementation (e.g. based on `flutter_secure_storage`) via
  `CloudServiceStore(credentialStorage: ...)`.
- **All cloud config writes go through `CloudServiceStore`.** Business code must
  not call `SharedPreferences.setString` on cloud config keys directly. Imports
  use `saveImported(...)`, which merges credentials and ignores the `***`
  redaction placeholder so a sanitized export can never overwrite real secrets.

## Architecture

```
┌─────────────────────────────────────────┐
│         Business Layer (Your App)       │
│  - Implements DataSerializer<T>         │
│  - Manages local database                │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│     flutter_cloud_sync (Core)           │
│  - CloudSyncManager<T>                   │
│  - CloudProvider interface               │
│  - CloudAuthService interface            │
│  - CloudStorageService interface         │
└─────────────────┬───────────────────────┘
                  │
       ┌──────────┼──────────┐
       ▼          ▼          ▼
┌──────────┐ ┌─────────┐ ┌────────┐
│ Supabase │ │ WebDAV  │ │  S3    │
│ Provider │ │ Provider│ │Provider│
└──────────┘ └─────────┘ └────────┘
```

## API Reference

See [API documentation](https://pub.dev/documentation/flutter_cloud_sync/latest/) for detailed information.

### Core Classes

- `CloudSyncManager<T>` - Main sync orchestrator
- `CloudProvider` - Cloud service abstraction
- `DataSerializer<T>` - Business data serialization interface
- `SyncStatus` - Sync state information
- `CloudUser` - Authenticated user information
- `CloudFile` - Cloud file metadata

### Exceptions

- `CloudSyncException` - Base exception class
- `CloudNotAuthenticatedException` - User not authenticated
- `CloudConfigurationException` - Invalid configuration
- `CloudStorageException` - Storage operation failed
- `CloudSerializationException` - Serialization / deserialization failed
- `CloudAuthException` - Authentication failed

## Example

See the [example](example/) directory for a complete working example.

## Contributing

Contributions are welcome! Please read our [contributing guide](CONTRIBUTING.md).

## License

MIT License - see [LICENSE](LICENSE) file for details.
