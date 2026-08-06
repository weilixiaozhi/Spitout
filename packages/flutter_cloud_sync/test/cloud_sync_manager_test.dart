import 'dart:convert';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';

// Manual mocks (simpler than using mockito code generation)
class MockCloudProvider implements CloudProvider {
  final MockCloudAuthService _auth = MockCloudAuthService();
  final MockCloudStorageService _storage = MockCloudStorageService();

  @override
  CloudAuthService get auth => _auth;

  @override
  CloudStorageService get storage => _storage;

  @override
  String get providerId => 'mock';

  @override
  String get providerName => 'Mock Provider';

  @override
  Future<void> initialize(Map<String, dynamic> config) async {}

  @override
  bool validateConfig(Map<String, dynamic> config) => true;

  @override
  Future<void> dispose() async {}
}

class MockCloudAuthService implements CloudAuthService {
  CloudUser? _currentUser;

  void setCurrentUser(CloudUser? user) {
    _currentUser = user;
  }

  @override
  Future<CloudUser?> get currentUser async => _currentUser;

  @override
  Stream<CloudUser?> get authStateChanges => Stream.value(_currentUser);

  @override
  Future<CloudUser> signInWithAccount({
    required String account,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CloudUser> signUpWithAccount({
    required String account,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordResetAccount({required String account}) async {}

  @override
  Future<void> resendAccountVerification({required String account}) async {}
}

class MockCloudStorageService implements CloudStorageService {
  final Map<String, _StoredFile> _files = {};
  int downloadCalls = 0;

  @override
  Future<void> upload({
    required String path,
    required String data,
    Map<String, String>? metadata,
  }) async {
    _files[path] = _StoredFile(data, metadata);
  }

  @override
  Future<String?> download({required String path}) async {
    downloadCalls++;
    return _files[path]?.data;
  }

  @override
  Future<void> delete({required String path}) async {
    _files.remove(path);
  }

  @override
  Future<List<CloudFile>> list({required String path}) async {
    return _files.keys
        .where((key) => key.startsWith(path))
        .map((key) => CloudFile(
              name: key.split('/').last,
              path: key,
              metadata: _files[key]?.metadata,
            ))
        .toList();
  }

  @override
  Future<bool> exists({required String path}) async {
    return _files.containsKey(path);
  }

  @override
  Future<CloudFile?> getMetadata({required String path}) async {
    final file = _files[path];
    if (file == null) return null;
    return CloudFile(
      name: path.split('/').last,
      path: path,
      metadata: file.metadata,
    );
  }
}

class _StoredFile {
  final String data;
  final Map<String, String>? metadata;

  _StoredFile(this.data, this.metadata);
}

class MockDataSerializer implements DataSerializer<int> {
  bool failSerialize = false;

  @override
  Future<String> serialize(int data) async {
    if (failSerialize) {
      throw StateError('serialize boom');
    }
    return jsonEncode({'id': data});
  }

  @override
  Future<int> deserialize(String data) async {
    final json = jsonDecode(data) as Map<String, dynamic>;
    return json['id'] as int;
  }

  @override
  String fingerprint(String data) {
    // 测试替身：返回确定性字符串指纹即可满足各断言（isNotNull / 相等比较），
    // 避免让核心包 dev_dependencies 为测试引入 crypto 等额外依赖（保持零寄生依赖）。
    return 'fp-$data';
  }
}

void main() {
  late CloudSyncManager<int> syncManager;
  late MockCloudProvider mockProvider;
  late MockCloudAuthService mockAuth;
  late MockCloudStorageService mockStorage;
  late MockDataSerializer mockSerializer;

  setUp(() {
    mockProvider = MockCloudProvider();
    mockAuth = mockProvider.auth as MockCloudAuthService;
    mockStorage = mockProvider.storage as MockCloudStorageService;
    mockSerializer = MockDataSerializer();
    mockSerializer.failSerialize = false;

    syncManager = CloudSyncManager<int>(
      provider: mockProvider,
      serializer: mockSerializer,
      logger: CloudSyncLogger(onLog: (level, msg) {
        // ignore: avoid_print
        print('[$level] $msg');
      }),
    );
  });

  group('CloudSyncManager - upload', () {
    test('should throw CloudNotAuthenticatedException when not authenticated',
        () async {
      // Arrange
      mockAuth.setCurrentUser(null);

      // Act & Assert
      expect(
        () => syncManager.upload(data: 123, path: 'test.json'),
        throwsA(isA<CloudNotAuthenticatedException>()),
      );
    });

    test('should upload data successfully when authenticated', () async {
      // Arrange
      const testUser = CloudUser(id: 'user123', account: 'test@example.com');
      const testData = 123;
      const testPath = 'ledgers/123.json';

      mockAuth.setCurrentUser(testUser);

      // Act
      await syncManager.upload(data: testData, path: testPath);

      // Assert
      final exists = await mockStorage.exists(path: testPath);
      expect(exists, isTrue);

      final metadata = await mockStorage.getMetadata(path: testPath);
      expect(metadata, isNotNull);
      expect(metadata!.metadata!['userId'], equals(testUser.id));
      expect(metadata.metadata!['fingerprint'], isNotNull);
    });

    test('should include custom metadata in upload', () async {
      // Arrange
      const testUser = CloudUser(id: 'user123');
      mockAuth.setCurrentUser(testUser);

      // Act
      await syncManager.upload(
        data: 123,
        path: 'test.json',
        metadata: {'version': '1.0', 'app': 'MyApp'},
      );

      // Assert
      final metadata = await mockStorage.getMetadata(path: 'test.json');
      expect(metadata!.metadata!['version'], equals('1.0'));
      expect(metadata.metadata!['app'], equals('MyApp'));
      expect(metadata.metadata!['fingerprint'], isNotNull);
    });

    test('should throw CloudSerializationException when serializer fails',
        () async {
      // Arrange
      const testUser = CloudUser(id: 'user123');
      mockAuth.setCurrentUser(testUser);
      mockSerializer.failSerialize = true;

      // Act & Assert
      expect(
        () => syncManager.upload(data: 123, path: 'test.json'),
        throwsA(isA<CloudSerializationException>()),
      );
    });
  });

  group('CloudSyncManager - download', () {
    test('should throw CloudNotAuthenticatedException when not authenticated',
        () async {
      // Arrange
      mockAuth.setCurrentUser(null);

      // Act & Assert
      expect(
        () => syncManager.download(path: 'test.json'),
        throwsA(isA<CloudNotAuthenticatedException>()),
      );
    });

    test('should return null when file does not exist', () async {
      // Arrange
      const testUser = CloudUser(id: 'user123');
      mockAuth.setCurrentUser(testUser);

      // Act
      final result = await syncManager.download(path: 'nonexistent.json');

      // Assert
      expect(result, isNull);
    });

    test('should download and deserialize data successfully', () async {
      // Arrange
      const testUser = CloudUser(id: 'user123');
      const testData = 123;
      const testPath = 'ledgers/123.json';

      mockAuth.setCurrentUser(testUser);

      // Upload first
      await syncManager.upload(data: testData, path: testPath);

      // Act
      final result = await syncManager.download(path: testPath);

      // Assert
      expect(result, equals(testData));
    });
  });

  group('CloudSyncManager - getStatus', () {
    test('should return notAuthenticated when user not authenticated',
        () async {
      // Arrange
      mockAuth.setCurrentUser(null);

      // Act
      final status = await syncManager.getStatus(path: 'test.json');

      // Assert
      expect(status.state, equals(SyncState.notAuthenticated));
      expect(status.message, equals('User not authenticated'));
    });

    test('should return localOnly when cloud file does not exist', () async {
      // Arrange
      const testUser = CloudUser(id: 'user123');
      const localData = 123;

      mockAuth.setCurrentUser(testUser);

      // Act
      final status =
          await syncManager.getStatus(data: localData, path: 'test.json');

      // Assert
      expect(status.state, equals(SyncState.localOnly));
      expect(status.localFingerprint, isNotNull);
      expect(status.cloudFingerprint, isNull);
    });

    test('should return synced when fingerprints match', () async {
      // Arrange
      const testUser = CloudUser(id: 'user123');
      const testData = 123;
      const testPath = 'test.json';

      mockAuth.setCurrentUser(testUser);

      // Upload first
      await syncManager.upload(data: testData, path: testPath);

      // Act
      final status =
          await syncManager.getStatus(data: testData, path: testPath);

      // Assert
      expect(status.state, equals(SyncState.synced));
      expect(status.localFingerprint, equals(status.cloudFingerprint));
    });

    test('should return outOfSync when fingerprints differ', () async {
      // Arrange
      const testUser = CloudUser(id: 'user123');
      const uploadedData = 123;
      const localData = 456;
      const testPath = 'test.json';

      mockAuth.setCurrentUser(testUser);

      // Upload with one data
      await syncManager.upload(data: uploadedData, path: testPath);

      // Check status with different local data
      final status =
          await syncManager.getStatus(data: localData, path: testPath);

      // Assert
      expect(status.state, equals(SyncState.outOfSync));
      expect(status.localFingerprint, isNot(equals(status.cloudFingerprint)));
    });

    test('should use cache when not expired', () async {
      // Arrange
      const testUser = CloudUser(id: 'user123');
      const testData = 123;
      const testPath = 'test.json';

      mockAuth.setCurrentUser(testUser);
      await syncManager.upload(data: testData, path: testPath);

      // Act - first call
      await syncManager.getStatus(data: testData, path: testPath);

      // Manually modify cloud data to verify cache is used
      await mockStorage.upload(
        path: testPath,
        data: '{"id": 999}',
        metadata: {'fingerprint': 'different'},
      );

      // Second call should use cache and not see the new fingerprint
      final status =
          await syncManager.getStatus(data: testData, path: testPath);

      // Assert - should still show synced because of cache
      expect(status.state, equals(SyncState.synced));
    });

    test('should refresh cache when forceRefresh is true', () async {
      // Arrange
      const testUser = CloudUser(id: 'user123');
      const testData = 123;
      const testPath = 'test.json';

      mockAuth.setCurrentUser(testUser);
      await syncManager.upload(data: testData, path: testPath);

      // First call to populate cache
      await syncManager.getStatus(data: testData, path: testPath);

      // Modify cloud data
      await mockStorage.upload(
        path: testPath,
        data: '{"id": 999}',
        metadata: {'fingerprint': 'different'},
      );

      // Act - force refresh should see the change
      final status = await syncManager.getStatus(
        data: testData,
        path: testPath,
        forceRefresh: true,
      );

      // Assert - should detect out of sync
      expect(status.state, equals(SyncState.outOfSync));
    });

    test('should not download cloud data when metadata fingerprint matches',
        () async {
      // Arrange
      const testUser = CloudUser(id: 'user123');
      const testData = 123;
      const testPath = 'test.json';

      mockAuth.setCurrentUser(testUser);
      await syncManager.upload(data: testData, path: testPath);

      // Act
      mockStorage.downloadCalls = 0;
      final status = await syncManager.getStatus(
        data: testData,
        path: testPath,
        forceRefresh: true,
      );

      // Assert - 指纹一致时仅用 metadata 判断，无需下载正文。
      expect(status.state, equals(SyncState.synced));
      expect(mockStorage.downloadCalls, 0);
    });

    test('should return unknown when local data is missing', () async {
      // Arrange
      const testUser = CloudUser(id: 'user123');
      const testData = 123;
      const testPath = 'test.json';

      mockAuth.setCurrentUser(testUser);
      await syncManager.upload(data: testData, path: testPath);

      // Act - 不传 data，本地无可比对的指纹。
      final status = await syncManager.getStatus(path: testPath);

      // Assert - 不得误报 synced。
      expect(status.state, equals(SyncState.unknown));
    });

    test('cache is isolated per user', () async {
      // Arrange
      const userA = CloudUser(id: 'userA');
      const userB = CloudUser(id: 'userB');
      const testData = 123;
      const testPath = 'test.json';

      mockAuth.setCurrentUser(userA);
      await syncManager.upload(data: testData, path: testPath);
      // 填充 userA 的缓存（synced）。
      await syncManager.getStatus(data: testData, path: testPath);

      // 云端改为不同指纹。
      await mockStorage.upload(
        path: testPath,
        data: '{"id": 999}',
        metadata: {'fingerprint': 'different'},
      );

      // Act - 切换账号后同一 path 再次查询。
      mockAuth.setCurrentUser(userB);
      final status =
          await syncManager.getStatus(data: testData, path: testPath);

      // Assert - 若命中 userA 缓存会误报 synced；正确行为是 outOfSync。
      expect(status.state, equals(SyncState.outOfSync));
    });
  });

  group('CloudSyncManager - deleteRemote', () {
    test('should throw CloudNotAuthenticatedException when not authenticated',
        () async {
      // Arrange
      mockAuth.setCurrentUser(null);

      // Act & Assert
      expect(
        () => syncManager.deleteRemote(path: 'test.json'),
        throwsA(isA<CloudNotAuthenticatedException>()),
      );
    });

    test('should delete file successfully', () async {
      // Arrange
      const testUser = CloudUser(id: 'user123');
      const testData = 123;
      const testPath = 'ledgers/123.json';

      mockAuth.setCurrentUser(testUser);

      // Upload first
      await syncManager.upload(data: testData, path: testPath);
      expect(await mockStorage.exists(path: testPath), isTrue);

      // Act
      await syncManager.deleteRemote(path: testPath);

      // Assert
      expect(await mockStorage.exists(path: testPath), isFalse);
    });
  });

  group('CloudSyncManager - cache management', () {
    test('should clear all cached status', () async {
      // Arrange
      const testUser = CloudUser(id: 'user123');
      const testData = 123;
      const testPath = 'test.json';

      mockAuth.setCurrentUser(testUser);
      await syncManager.upload(data: testData, path: testPath);

      // Build cache
      await syncManager.getStatus(data: testData, path: testPath);

      // Modify cloud data
      await mockStorage.upload(
        path: testPath,
        data: '{"id": 999}',
        metadata: {'fingerprint': 'different'},
      );

      // Should use cache (synced)
      var status = await syncManager.getStatus(data: testData, path: testPath);
      expect(status.state, equals(SyncState.synced));

      // Clear cache
      syncManager.clearCache();

      // Should detect out of sync after cache clear
      status = await syncManager.getStatus(data: testData, path: testPath);
      expect(status.state, equals(SyncState.outOfSync));
    });

    test('should invalidate cache after upload', () async {
      // Arrange
      const testUser = CloudUser(id: 'user123');
      const testData = 123;
      const testPath = 'test.json';

      mockAuth.setCurrentUser(testUser);

      // Upload and build cache
      await syncManager.upload(data: testData, path: testPath);
      await syncManager.getStatus(data: testData, path: testPath);

      // Upload again (invalidates cache)
      await syncManager.upload(data: testData, path: testPath);

      // Cache should be invalidated, status check should work correctly
      final status =
          await syncManager.getStatus(data: testData, path: testPath);
      expect(status.state, equals(SyncState.synced));
    });
  });
}
