import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/core/identity/local_user_identity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('并发 getOrCreate 返回同一个身份', () async {
    final results = await Future.wait([
      LocalSelfId.getOrCreate(),
      LocalSelfId.getOrCreate(),
      LocalSelfId.getOrCreate(),
    ]);

    expect(results.toSet(), hasLength(1));
  });

  test('restoreIfAbsent 拒绝非法 UUID，不写入 prefs', () async {
    SharedPreferences.setMockInitialValues({
      LocalSelfId.prefsKey: 'not-a-uuid',
    });

    await LocalSelfId.restoreIfAbsent('still-not-a-uuid');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(LocalSelfId.prefsKey), 'not-a-uuid');
  });

  test('restoreIfAbsent 写入合法 UUID v4', () async {
    const id = '123e4567-e89b-42d3-a456-426614174000';

    await LocalSelfId.restoreIfAbsent(id);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(LocalSelfId.prefsKey), id);
  });
}
