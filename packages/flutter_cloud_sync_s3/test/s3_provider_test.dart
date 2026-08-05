import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_cloud_sync_s3/flutter_cloud_sync_s3.dart';
import 'package:flutter_cloud_sync_s3/src/s3_client.dart';
import 'package:flutter_cloud_sync_s3/src/s3_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('S3Provider', () {
    late S3Provider provider;

    setUp(() {
      provider = S3Provider();
    });

    test('should have correct provider ID and name', () {
      expect(provider.providerId, 's3');
      expect(provider.providerName, isNotEmpty);
    });

    test('validateConfig should return false for missing keys', () {
      expect(provider.validateConfig({}), isFalse);
      expect(
        provider.validateConfig({
          'endpoint': 's3.example.com',
          'accessKey': 'ak',
          'secretKey': 'sk',
        }),
        isFalse,
      );
    });

    test('validateConfig should return true for valid config', () {
      expect(
        provider.validateConfig({
          'endpoint': 's3.example.com',
          'accessKey': 'ak',
          'secretKey': 'sk',
          'bucket': 'bucket',
        }),
        isTrue,
      );
    });

    test('uninitialized auth getter throws CloudConfigurationException', () {
      expect(
        () => provider.auth,
        throwsA(isA<CloudConfigurationException>()),
      );
    });

    test('uninitialized storage getter throws CloudConfigurationException', () {
      expect(
        () => provider.storage,
        throwsA(isA<CloudConfigurationException>()),
      );
    });

    test('initialize with invalid config throws CloudConfigurationException',
        () async {
      expect(
        () => provider.initialize({}),
        throwsA(isA<CloudConfigurationException>()),
      );
      expect(
        () => provider.initialize({
          'endpoint': 's3.example.com',
          'accessKey': 'ak',
          'secretKey': 'sk',
          // 缺 bucket
        }),
        throwsA(isA<CloudConfigurationException>()),
      );
    });
  });

  group('S3StorageService 路径校验', () {
    test('upload 拒绝 ../ 穿越路径', () async {
      final storage = S3StorageService(
        S3Client(
          endpoint: 'localhost',
          region: 'us-east-1',
          accessKey: 'ak',
          secretKey: 'sk',
          useSSL: false,
        ),
        'bucket',
      );

      // 校验发生在任何网络请求之前。
      expect(
        () => storage.upload(path: '../secret.json', data: 'x'),
        throwsA(isA<CloudStorageException>()),
      );
    });
  });
}
