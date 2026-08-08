// LocalSelfId 补充测试。
//
// 单独文件的原因：`_cached` 是进程级静态缓存，getOrCreate 首次调用后
// 后续调用直接命中缓存；本文件所在 isolate 内仅此一个 getOrCreate 用例，
// 且其运行顺序被随机化也不影响——无论先后，唯一一次 getOrCreate 调用面对
// 的都是空缓存，因此能确定性地覆盖「已有合法值直接返回」分支。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/core/identity/local_user_identity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocalSelfId.resetForTest();
    SharedPreferences.setMockInitialValues({});
  });

  test('getOrCreate：已有合法 UUID 直接返回且不重写', () async {
    const id = '123e4567-e89b-42d3-a456-426614174000';
    SharedPreferences.setMockInitialValues({LocalSelfId.prefsKey: id});

    expect(await LocalSelfId.getOrCreate(), id);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(LocalSelfId.prefsKey), id);
  });

  test('restoreIfAbsent：已有非法值用备份值覆盖', () async {
    const incoming = '223e4567-e89b-42d3-a456-426614174000';
    SharedPreferences.setMockInitialValues({
      LocalSelfId.prefsKey: 'corrupted-id',
    });

    await LocalSelfId.restoreIfAbsent(incoming);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(LocalSelfId.prefsKey), incoming);
    expect(await LocalSelfId.read(), incoming);
  });

  test('restoreIfAbsent：大写合法 UUID 也接受', () async {
    const upper = '123E4567-E89B-42D3-A456-426614174000';
    await LocalSelfId.restoreIfAbsent(upper);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(LocalSelfId.prefsKey), upper);
  });
}
