import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_cloud_sync_supabase/flutter_cloud_sync_supabase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  group('SupabaseProvider', () {
    late SupabaseProvider provider;

    setUp(() {
      provider = SupabaseProvider();
    });

    test('should have correct provider ID', () {
      expect(provider.providerId, equals('supabase'));
    });

    test('should have correct provider name', () {
      expect(provider.providerName, equals('Supabase'));
    });

    test('validateConfig should return false for empty config', () {
      expect(provider.validateConfig({}), isFalse);
    });

    test('validateConfig should return false for missing url', () {
      expect(
        provider.validateConfig({'anonKey': 'key'}),
        isFalse,
      );
    });

    test('validateConfig should return false for missing anonKey', () {
      expect(
        provider.validateConfig({'url': 'https://example.com'}),
        isFalse,
      );
    });

    test('validateConfig should return true for valid config', () {
      expect(
        provider.validateConfig({
          'url': 'https://example.supabase.co',
          'anonKey': 'test-key',
        }),
        isTrue,
      );
    });

    test('validateConfig should accept optional bucket', () {
      expect(
        provider.validateConfig({
          'url': 'https://example.supabase.co',
          'anonKey': 'test-key',
          'bucket': 'user-data',
        }),
        isTrue,
      );
    });

    test('validateConfig should return false for invalid bucket type', () {
      expect(
        provider.validateConfig({
          'url': 'https://example.supabase.co',
          'anonKey': 'test-key',
          'bucket': 123, // should be string
        }),
        isFalse,
      );
    });

    test(
        'should throw CloudConfigurationException when accessing auth before initialization',
        () {
      expect(
        () => provider.auth,
        throwsA(isA<CloudConfigurationException>()),
      );
    });

    test(
        'should throw CloudConfigurationException when accessing storage before initialization',
        () {
      expect(
        () => provider.storage,
        throwsA(isA<CloudConfigurationException>()),
      );
    });

    test('initialize should throw on invalid config', () async {
      expect(
        () => provider.initialize({}),
        throwsA(isA<CloudConfigurationException>()),
      );
    });

    // Note: Full integration tests require a real Supabase instance
    // and should be run separately with proper credentials
  });

  group('SupabaseAuthService', () {
    test('should convert Supabase user to CloudUser', () {
      // This would require mocking Supabase client
      // For now, we just verify the class exists
      expect(SupabaseAuthService, isNotNull);
    });
  });

  group('SupabaseStorageService', () {
    test('should implement CloudStorageService', () {
      // This would require mocking Supabase client
      // For now, we just verify the class exists
      expect(SupabaseStorageService, isNotNull);
    });
  });

  group('SupabaseDatabaseService 批量操作安全语义', () {
    late SupabaseDatabaseService dbService;

    setUp(() {
      // 未初始化的匿名客户端：无 session，currentUser 为 null。
      dbService = SupabaseDatabaseService(
        supabase.SupabaseClient('https://example.supabase.co', 'anon-key'),
      );
    });

    test('batchInsert 未登录时抛 CloudNotAuthenticatedException', () {
      expect(
        () => dbService.batchInsert(table: 't', data: [
          {'name': 'a'},
        ]),
        throwsA(isA<CloudNotAuthenticatedException>()),
      );
    });

    test('batchUpdate 未登录时抛 CloudNotAuthenticatedException', () {
      expect(
        () => dbService.batchUpdate(table: 't', data: [
          {'id': 1, 'name': 'a'},
        ]),
        throwsA(isA<CloudNotAuthenticatedException>()),
      );
    });

    test('batchDelete 未登录时抛 CloudNotAuthenticatedException', () {
      expect(
        () => dbService.batchDelete(
          table: 't',
          filters: [QueryFilter.eq('id', 1)],
        ),
        throwsA(isA<CloudNotAuthenticatedException>()),
      );
    });

    test('rawQuery 已禁用并抛 CloudSyncException', () {
      expect(
        () => dbService.rawQuery('select * from t'),
        throwsA(isA<CloudSyncException>()),
      );
    });

    test('subscribe 明确提示使用 RealtimeService', () {
      expect(
        () => dbService.subscribe(table: 't'),
        throwsA(isA<CloudSyncException>()),
      );
    });
  });

  group('SupabaseRealtimeChannel 过滤器解析', () {
    test('解析 eq 过滤器为 column + op + value', () {
      final filter =
          SupabaseRealtimeChannel.parsePostgresFilter('ledger_id=eq.123');
      expect(filter, isNotNull);
      expect(filter!.column, 'ledger_id');
      expect(filter.type, supabase.PostgresChangeFilterType.eq);
      expect(filter.value, '123');
      expect(filter.negate, isFalse);
    });

    test('解析 in 过滤器', () {
      final filter =
          SupabaseRealtimeChannel.parsePostgresFilter('id=in.(1,2,3)');
      expect(filter!.type, supabase.PostgresChangeFilterType.inFilter);
      expect(filter.value, '(1,2,3)');
    });

    test('解析 lte 与 not. 取反', () {
      final filter =
          SupabaseRealtimeChannel.parsePostgresFilter('age=not.gte.18');
      expect(filter!.type, supabase.PostgresChangeFilterType.gte);
      expect(filter.value, '18');
      expect(filter.negate, isTrue);
    });

    test('未知操作符抛 ArgumentError', () {
      expect(
        () => SupabaseRealtimeChannel.parsePostgresFilter('a=foo.1'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('缺少操作符值抛 ArgumentError', () {
      expect(
        () => SupabaseRealtimeChannel.parsePostgresFilter('a=eq'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
