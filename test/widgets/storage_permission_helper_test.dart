// 公共导出目录权限引导 helper 测试。
//
// 需求锚点：非 Android 平台不存在「公共 Download 授权」流程，直接返回 null
// （由调用方各自平台分支决定降级策略），且不触碰 providers/services。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/widgets/storage_permission_helper.dart';

void main() {
  testWidgets('非 Android 平台 ensureExportDirAccess 返回 null', (tester) async {
    if (Platform.isAndroid) return;

    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return const Placeholder();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Consumer));
    expect(await ensureExportDirAccess(context, captured), isNull);
  });
}
