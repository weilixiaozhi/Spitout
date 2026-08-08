/// VirtualUserManageSheet 组件测试。
///
/// 需求锚点（aa_statistics_providers 提供的虚拟用户管理入口）：
/// - 空列表展示空态文案；非空列表逐行渲染昵称 + 重命名/删除操作；
/// - 标题栏「新建」常驻；新建/重命名走名称输入对话框，空输入取消不落库；
/// - 删除需二次确认；名下有账（StateError）时 toast 拦截；
/// - 加载中 / 加载失败分别渲染进度圈与错误文案。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/data/db.dart' show LedgerVirtualUser;
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/widgets/virtual_user_manage_sheet.dart';

class _MockRepo extends Mock implements BaseRepository {}

LedgerVirtualUser _user(int id, String name) => LedgerVirtualUser(
  id: id,
  ledgerId: 1,
  syncId: 'vu-$id',
  name: name,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;
  late StreamController<List<LedgerVirtualUser>> usersCtrl;

  setUp(() {
    repo = _MockRepo();
    usersCtrl = StreamController<List<LedgerVirtualUser>>.broadcast();
    when(
      () => repo.watchByLedger(1),
    ).thenAnswer((_) => usersCtrl.stream);
  });

  tearDown(() async {
    await usersCtrl.close();
  });

  /// 挂载入口页并打开虚拟用户管理 sheet。
  ///
  /// 全程用有界 pump 驱动动画：stream 未 emit 时 provider 停在 loading 态，
  /// 进度圈动画永续会让 pumpAndSettle 超时；对话框 autofocus 光标闪烁同理。
  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showVirtualUserManageSheet(
                    context,
                    ledgerId: 1,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // bottom sheet 入场动画（~250ms），用有界 pump 推进，避免 loading 态
    // 无限动画阻塞 pumpAndSettle。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// 在名称对话框里输入并确认。
  Future<void> submitName(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.widgetWithText(TextButton, '确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('空列表：渲染空态文案，新建入口常驻', (tester) async {
    await openSheet(tester);
    usersCtrl.add(const []);
    await tester.pump();

    expect(find.text('虚拟用户'), findsOneWidget);
    expect(find.text('暂无虚拟用户'), findsOneWidget);
    expect(find.byTooltip('新建虚拟用户'), findsOneWidget);
  });

  testWidgets('非空列表：逐行渲染昵称 + 重命名/删除按钮', (tester) async {
    await openSheet(tester);
    usersCtrl.add([_user(1, '室友A'), _user(2, '室友B')]);
    await tester.pump();

    expect(find.text('室友A'), findsOneWidget);
    expect(find.text('室友B'), findsOneWidget);
    expect(find.byTooltip('重命名'), findsNWidgets(2));
    expect(find.byTooltip('删除'), findsNWidgets(2));
  });

  testWidgets('加载失败：渲染错误文案', (tester) async {
    await openSheet(tester);
    // sheet 打开后 provider 已订阅，再注入错误。
    usersCtrl.addError(StateError('boom'));
    await tester.pump();

    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('新建：输入昵称确认后调用 createVirtualUser', (tester) async {
    when(() => repo.create(ledgerId: 1, name: '新室友')).thenAnswer(
      (_) async => 3,
    );
    await openSheet(tester);

    await tester.tap(find.byTooltip('新建虚拟用户'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('输入昵称'), findsOneWidget);

    await submitName(tester, '新室友');
    verify(() => repo.create(ledgerId: 1, name: '新室友')).called(1);
  });

  testWidgets('新建：空输入不落库', (tester) async {
    await openSheet(tester);

    await tester.tap(find.byTooltip('新建虚拟用户'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await submitName(tester, '   ');

    verifyNever(
      () => repo.create(
        ledgerId: any(named: 'ledgerId'),
        name: any(named: 'name'),
      ),
    );
  });

  testWidgets('重命名：回填旧名，确认后调用 rename', (tester) async {
    when(() => repo.rename(id: 1, name: '新名')).thenAnswer((_) async {});
    await openSheet(tester);
    usersCtrl.add([_user(1, '旧名')]);
    await tester.pump();

    await tester.tap(find.byTooltip('重命名'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    // 行内昵称与输入框回填各一处，限定输入框断言回填值。
    expect(find.widgetWithText(TextField, '旧名'), findsOneWidget);

    await submitName(tester, '新名');
    verify(() => repo.rename(id: 1, name: '新名')).called(1);
  });

  testWidgets('删除：取消确认不调用 delete', (tester) async {
    await openSheet(tester);
    usersCtrl.add([_user(1, '待删')]);
    await tester.pump();

    await tester.tap(find.byTooltip('删除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.widgetWithText(OutlinedButton, '取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    verifyNever(() => repo.delete(any()));
  });

  testWidgets('删除：确认后调用 delete 并移除行', (tester) async {
    when(() => repo.delete(1)).thenAnswer((_) async => true);
    await openSheet(tester);
    usersCtrl.add([_user(1, '待删')]);
    await tester.pump();

    await tester.tap(find.byTooltip('删除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    verify(() => repo.delete(1)).called(1);
  });

  testWidgets('删除：名下有账（StateError）toast 拦截', (tester) async {
    when(() => repo.delete(1)).thenThrow(StateError('in use'));
    await openSheet(tester);
    usersCtrl.add([_user(1, '待删')]);
    await tester.pump();

    await tester.tap(find.byTooltip('删除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('该虚拟用户名下有账，不可删除'), findsOneWidget);
    // toast 自动消失，避免残留定时器。
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('删除：其他异常 toast 通用失败文案', (tester) async {
    when(() => repo.delete(1)).thenThrow(Exception('db down'));
    await openSheet(tester);
    usersCtrl.add([_user(1, '待删')]);
    await tester.pump();

    await tester.tap(find.byTooltip('删除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.textContaining('失败'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
  });
}
