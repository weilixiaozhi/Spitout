import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import 'package:spitout/providers/core/database_providers.dart';

/// 记录编辑历史:某条交易的编辑历史列表,按版本号倒序。
///
/// 对应记录详情 Bottom Sheet 的"编辑记录(仅供查看)"区块。
/// 编辑历史是本地展示数据(不参与云同步),Provider 仅做读缓存;
/// 交易被编辑后由调用方主动 invalidate 此 provider 触发刷新。
final recordEditHistoryProvider = FutureProvider.family
    .autoDispose<List<RecordEditHistory>, int>((ref, recordId) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getEditHistories(recordId);
});
