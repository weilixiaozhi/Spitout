// 云服务帮助弹窗与同步预览弹窗测试。
// 覆盖 cloud_help_dialogs 的五个帮助弹窗（多设备/Supabase/Spitout Cloud/
// WebDAV/S3）与 sync_preview_dialog 的分组展示、全选/取消、确认返回选中集。

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/sync/sync_diff_service.dart';
import 'package:spitout/data/models.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/cloud/cloud_help_dialogs.dart';
import 'package:spitout/pages/cloud/sync_preview_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<BuildContext> pumpHost(
    WidgetTester tester,
  ) async {
    late BuildContext captured;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: Builder(
                  builder: (buttonContext) {
                    captured = buttonContext;
                    return ElevatedButton(
                      onPressed: () {},
                      child: const Text('打开'),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return captured;
  }

  group('云服务帮助弹窗', () {
    final dialogs = <String, void Function(BuildContext)>{
      '多设备': showMultiDeviceDetailDialog,
      'Supabase': showSupabaseHelpDialog,
      'Spitout': showSpitoutCloudHelpDialog,
      'WebDAV': showWebdavHelpDialog,
      'S3': showS3HelpDialog,
    };

    dialogs.forEach((name, show) {
      testWidgets('$name 帮助弹窗可打开并关闭', (tester) async {
        final ctx = await pumpHost(tester);
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        show(ctx);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        // 点击遮罩关闭
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      });
    });
  });

  group('同步预览弹窗', () {
    testWidgets('分组展示 + 全选/取消 + 确认返回选中集', (tester) async {
      final completer = Completer<List<SyncChange>?>();
      final preview = SyncPreview(changes: [
        SyncChange(
          type: SyncChangeType.added,
          cloudTransaction: ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('12.50'),
            categoryName: '餐饮',
            happenedAt: DateTime(2026, 6, 10),
            currencyCode: 'CNY',
          ),
        ),
        SyncChange(
          type: SyncChangeType.modified,
          cloudTransaction: ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('8.00'),
            categoryName: '交通',
            happenedAt: DateTime(2026, 6, 11),
            currencyCode: 'CNY',
          ),
          diffDetails: ['金额 10.00 → 8.00'],
        ),
      ]);

      final ctx = await pumpHost(tester);
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      showSyncPreviewDialog(
        ctx,
        preview: preview,
        primaryColor: Colors.blue,
      ).then(completer.complete);
      await tester.pumpAndSettle();

      // 标题 + 分区
      expect(find.text('同步预览'), findsOneWidget);
      expect(find.text('新增'), findsOneWidget);
      expect(find.text('修改'), findsOneWidget);
      expect(find.textContaining('餐饮'), findsOneWidget);
      expect(find.textContaining('交通'), findsOneWidget);

      // 取消全选 → 应用按钮禁用（显示 0 项）
      await tester.tap(find.text('取消全选'));
      await tester.pump();
      final applyButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.textContaining('应用'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(applyButton.onPressed, isNull, reason: '未选中任何变更时应用应禁用');

      // 重新全选 → 应用返回全部选中变更
      await tester.tap(find.text('全选'));
      await tester.pump();
      await tester.tap(find.textContaining('应用'));
      await tester.pumpAndSettle();

      final result = await completer.future;
      expect(result, hasLength(2));
      expect(result!.every((c) => c.selected), isTrue);
    });
  });
}
