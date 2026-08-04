// AA 结算统计页共享「(我)」后缀渲染测试：
// 验证分摊明细行与转账方案卡基于 isSelf / fromIsSelf / toIsSelf 追加
// 统一后缀（含前导空格），非本人保持纯名不拼接。
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/statistics/aa_statistics_page.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/services/statistics/aa_statistics_service.dart';

import '../helpers/test_isolation.dart';

void main() {
  late SpitoutDatabase db;
  late LocalRepository repo;

  setUp(() {
    resetGlobalTestState();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async => db.close());

  /// 主动卸载页面并冲刷 drift 流式查询关闭时遗留的延迟 Timer，
  /// 避免 flutter_test 在测试体结束时校验到挂起 Timer 而报错。
  Future<void> unmountPage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  Future<void> pumpPage(WidgetTester tester, AaLedgerStatistics stats) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 内存库 + 真实 LocalRepository：支撑「不计入详单」区块的查询，
          // 空库返回空列表，页面各模块仍走固定统计数据的覆盖值。
          databaseProvider.overrideWithValue(db),
          repositoryProvider.overrideWithValue(repo),
          // 无当前账本：货币兜底默认值，避免真实 ledger 读取。
          currentLedgerProvider.overrideWith((ref) => Stream.value(null)),
          // 固定统计数据，不依赖真实账本/交易查询。
          aaStatisticsProvider.overrideWith((ref, ledgerId) async => stats),
          // 空头像上下文：全部参与人走占位头像。
          aaParticipantAvatarContextProvider.overrideWith(
              (ref, ledgerId) async => const AaParticipantAvatarContext()),
        ],
        child: MaterialApp(
          // 强制 zh 以渲染「(我)」等中文文案。
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AaStatisticsPage(ledgerId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('本人参与人在分摊明细行与转账方案卡追加「(我)」后缀，非本人保持纯名',
      (tester) async {
    final stats = AaLedgerStatistics(
      participants: [
        AaParticipantSummary(
          participantId: 'u1',
          displayName: '张三',
          totalPaid: 100,
          totalShouldPay: 50,
          isSelf: true,
        ),
        AaParticipantSummary(
          participantId: 'u2',
          displayName: '李四',
          totalPaid: 0,
          totalShouldPay: 50,
          isSelf: false,
        ),
        // 全零参与人：不进入详情表。
        AaParticipantSummary(
          participantId: 'u3',
          displayName: '王五',
          totalPaid: 0,
          totalShouldPay: 0,
        ),
      ],
      transfers: [
        // 应付方李四 → 应收方本人张三。
        AaTransfer(
          from: 'u2',
          fromName: '李四',
          to: 'u1',
          toName: '张三',
          amount: 50,
          fromIsSelf: false,
          toIsSelf: true,
        ),
      ],
    );

    await pumpPage(tester, stats);

    // 本人：明细行 + 转账方案卡均渲染「张三 (我)」。
    expect(find.text('张三 (我)', findRichText: true), findsWidgets);
    // 非本人：保持纯名，不追加后缀。
    expect(find.text('李四', findRichText: true), findsWidgets);
    expect(find.text('李四 (我)', findRichText: true), findsNothing);
    // 全零参与人不出现在详情表。
    expect(find.text('王五', findRichText: true), findsNothing);

    await unmountPage(tester);
  });

  testWidgets('付款方为本人时转账方案卡同样追加「(我)」后缀', (tester) async {
    final stats = AaLedgerStatistics(
      participants: [
        AaParticipantSummary(
          participantId: 'u1',
          displayName: '张三',
          totalPaid: 60,
          totalShouldPay: 30,
          isSelf: true,
        ),
        AaParticipantSummary(
          participantId: 'u2',
          displayName: '李四',
          totalPaid: 0,
          totalShouldPay: 30,
          isSelf: false,
        ),
      ],
      transfers: [
        // 付款方本人张三 → 应收方李四。
        AaTransfer(
          from: 'u1',
          fromName: '张三',
          to: 'u2',
          toName: '李四',
          amount: 30,
          fromIsSelf: true,
          toIsSelf: false,
        ),
      ],
    );

    await pumpPage(tester, stats);

    // 付款方本人：转账卡渲染「张三 (我)」；收款方非本人保持纯名。
    expect(find.text('张三 (我)', findRichText: true), findsWidgets);
    expect(find.text('李四 (我)', findRichText: true), findsNothing);

    await unmountPage(tester);
  });
}
