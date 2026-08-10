import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spitout/cloud/spitout_cloud.dart';
import 'package:spitout/cloud/sync/backend_capability_factory.dart';
import 'package:spitout/data/db.dart';

void main() {
  late SpitoutDatabase db;

  setUp(() {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('BackendCapabilityFactory', () {
    test('Spitout Cloud 注入增量追踪器', () {
      final trackers = backendCapabilityFactory.createTrackers(
        db,
        const CloudServiceConfig(
          type: CloudBackendType.spitoutCloud,
          name: 'spitout',
          spitoutCloudBaseUrl: 'https://example.com',
        ),
      );
      expect(trackers.changeTracker, isNotNull);
      expect(trackers.snapshotDirtyTracker, isNull);
    });

    test('快照型后端注入快照脏标记器', () {
      for (final type in [
        CloudBackendType.webdav,
        CloudBackendType.s3,
        CloudBackendType.supabase,
      ]) {
        final trackers = backendCapabilityFactory.createTrackers(
          db,
          CloudServiceConfig(
            type: type,
            name: 'snapshot',
            webdavUrl: type == CloudBackendType.webdav ? 'https://dav' : null,
            webdavUsername: type == CloudBackendType.webdav ? 'u' : null,
            webdavPassword: type == CloudBackendType.webdav ? 'p' : null,
            supabaseUrl: type == CloudBackendType.supabase ? 'https://sb' : null,
            supabaseAnonKey: type == CloudBackendType.supabase ? 'key' : null,
            s3Endpoint: type == CloudBackendType.s3 ? 's3.example' : null,
            s3AccessKey: type == CloudBackendType.s3 ? 'ak' : null,
            s3SecretKey: type == CloudBackendType.s3 ? 'sk' : null,
            s3Bucket: type == CloudBackendType.s3 ? 'bucket' : null,
          ),
        );
        expect(trackers.changeTracker, isNull);
        expect(trackers.snapshotDirtyTracker, isNotNull);
      }
    });

    test('本地模式与无效配置不注入任何追踪器', () {
      final local = backendCapabilityFactory.createTrackers(
        db,
        CloudServiceConfig.localStorage(),
      );
      expect(local.changeTracker, isNull);
      expect(local.snapshotDirtyTracker, isNull);

      final invalid = backendCapabilityFactory.createTrackers(
        db,
        const CloudServiceConfig(
          type: CloudBackendType.spitoutCloud,
          name: 'invalid',
        ),
      );
      expect(invalid.changeTracker, isNull);
      expect(invalid.snapshotDirtyTracker, isNull);
    });
  });
}
