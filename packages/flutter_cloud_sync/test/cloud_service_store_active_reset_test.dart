/// CloudServiceStore.clearConfig 激活标记复位测试。
///
/// 覆盖独立1:清除当前激活的云配置后,_kActiveType 持久化标记必须复位为
/// 'local',不能残留僵尸脏值(如 'webdav')。
///
/// 背景:loadActive() 虽因配置 key 缺失会静默回退本地,但 _kActiveType
/// 仍停留在已删除的云类型上,属于"持久化状态与真实状态不一致"的僵尸残留,
/// 可能被后续判断误读(例如"当前激活的云类型"类逻辑)。
///
/// 红测试:clearConfig(webdav) 后直接读 SharedPreferences 中的
/// 'cloud_active_type',当前仍是 'webdav' → 断言 'local' 失败(红)。
library;

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kActiveTypeKey = 'cloud_active_type';

CloudServiceConfig _webdavCfg() => const CloudServiceConfig(
      type: CloudBackendType.webdav,
      name: 'WebDAV',
      webdavUrl: 'https://dav.example.com',
      webdavUsername: 'u',
      webdavPassword: 'p',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('clearConfig 激活标记复位', () {
    test('清除当前激活的云配置后 _kActiveType 复位为 local(僵尸脏值被清理)', () async {
      final store = CloudServiceStore();
      await store.saveAndActivate(_webdavCfg());
      final sp = await SharedPreferences.getInstance();
      expect(sp.getString(_kActiveTypeKey), 'webdav');

      await store.clearConfig(CloudBackendType.webdav);

      // 直接检查持久化标记:清掉激活的云配置后必须复位 local
      expect(sp.getString(_kActiveTypeKey), 'local',
          reason: '清掉激活的云配置后 _kActiveType 不得残留僵尸脏值(如 webdav)');
      expect((await store.loadActive()).type, CloudBackendType.local);
    });

    test('清除非激活配置不影响现有激活状态(回归保护)', () async {
      final store = CloudServiceStore();
      await store.saveAndActivate(_webdavCfg());

      // 清一个非激活的 supabase 配置:不得误伤当前激活的 webdav
      await store.clearConfig(CloudBackendType.supabase);

      expect((await store.loadActive()).type, CloudBackendType.webdav,
          reason: '清非激活配置不得改变现有激活状态');
      expect(await store.loadSupabase(), isNull);
      expect(await store.loadWebdav(), isNotNull);
    });

    test('clearConfig(local) 为 no-op,不影响激活状态', () async {
      final store = CloudServiceStore();
      await store.saveAndActivate(_webdavCfg());

      await store.clearConfig(CloudBackendType.local);

      expect((await store.loadActive()).type, CloudBackendType.webdav);
      expect(await store.loadWebdav(), isNotNull);
    });
  });
}
