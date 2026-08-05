// AA 结算统计页共享「(我)」后缀渲染测试：
// 验证分摊明细行与转账方案卡基于 isSelf / fromIsSelf / toIsSelf 追加
// 统一后缀（含前导空格），非本人保持纯名不拼接。
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/router.dart';
import 'package:spitout/pages/statistics/aa_statistics_page.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/services/statistics/aa_member_detail_models.dart';
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
          // 成员账单详情页数据：固定返回一笔账单，验证点击进入详情。
          aaMemberDetailProvider.overrideWith((ref, args) async {
            return AaMemberDetailData(
              ledgerName: '测试账本',
              member: stats.participants.first,
              bills: [
                AaMemberBill(
                  tx: Transaction(
                    id: 1,
                    ledgerId: 1,
                    type: 'expense',
                    amount: 16800,
                    happenedAt: DateTime(2026, 8, 3, 19, 15),
                    note: '昱阳米粉 晚餐',
                    excludeFromStats: false,
                    currencyCode: 'CNY',
                    nativeAmount: 16800,
                    version: 1,
                    paidByUserId: 'u1',
                    aaMode: 0,
                    aaParticipants: '["u1"]',
                    aaSplits: '',
                  ),
                  mode: AaMode.perPerson,
                  totalAmount: 168,
                  myShare: 56,
                  payerName: '张三',
                  splits: [
                    AaMemberSplit(
                      participantId: 'u1',
                      displayName: '张三',
                      amount: 56,
                      isSelf: true,
                    ),
                  ],
                ),
              ],
            );
          }),
          // 固定统计数据，不依赖真实账本/交易查询。
          aaStatisticsProvider.overrideWith((ref, ledgerId) async => stats),
          // 空头像上下文：全部参与人走占位头像。
          aaParticipantAvatarContextProvider.overrideWith(
            (ref, ledgerId) async => const AaParticipantAvatarContext(),
          ),
        ],
        child: MaterialApp(
          // 强制 zh 以渲染「(我)」等中文文案。
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateRoute: appRoute,
          home: const AaStatisticsPage(ledgerId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('本人参与人在分摊明细行与转账方案卡追加「(我)」后缀，非本人保持纯名', (tester) async {
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

  testWidgets('点击分摊详情成员模块进入成员账单详情页并展示账单', (tester) async {
    final stats = AaLedgerStatistics(
      participants: [
        AaParticipantSummary(
          participantId: 'u1',
          displayName: '张三',
          totalPaid: 168,
          totalShouldPay: 56,
          isSelf: true,
        ),
      ],
      transfers: const [],
    );

    await pumpPage(tester, stats);

    // 点击成员模块的「查看详情」徽章，路由到成员账单详情页。
    await tester.tap(find.text('查看详情'));
    await tester.pumpAndSettle();

    // 详情页头部（账本名副标题）与汇总卡标题。
    expect(find.text('测试账本'), findsOneWidget);
    expect(find.text('账单汇总'), findsOneWidget);
    // 账单主行：分类名 + 备注 + 分摊明细区。
    expect(find.text('昱阳米粉 晚餐'), findsOneWidget);
    expect(find.text('分摊明细'), findsOneWidget);
    // 本人应摊 / 账单总额按项目金额口径渲染。
    expect(find.text('- ¥ 56'), findsOneWidget);
    expect(find.text('共 ¥ 168'), findsOneWidget);
    // 分摊明细中的本人追加「(我)」后缀。
    expect(find.text('张三 (我)', findRichText: true), findsWidgets);

    await unmountPage(tester);
  });

  testWidgets('仅有不分摊支出的成员仍出现在分摊详情表', (tester) async {
    // 外键约束：交易必须先有账本存在（与 Provider 测试同口径）。
    await repo.createLedger(
      name: '测试账本',
      storageMode: 'local',
      ownerUserId: 'u1',
      aaEnabled: true,
    );
    final stats = AaLedgerStatistics(
      participants: [
        AaParticipantSummary(
          participantId: 'u1',
          displayName: '张三',
          totalPaid: 100,
          totalShouldPay: 50,
          isSelf: true,
        ),
        // 李四无 AA 活动：只有一笔「不分摊」支出。
        AaParticipantSummary(
          participantId: 'u2',
          displayName: '李四',
          totalPaid: 0,
          totalShouldPay: 0,
          isSelf: false,
        ),
      ],
      transfers: const [],
    );
    // 写库插入李四垫付的不分摊支出：不进 AA 统计，
    // 但成员详情页本质是「首页支出列表按成员筛选」，必须可进入查看。
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: 700,
            happenedAt: Value(DateTime(2026, 8, 1, 8, 0)),
            paidByUserId: Value('u2'),
            aaMode: Value(1),
          ),
        );

    await pumpPage(tester, stats);

    expect(find.text('李四', findRichText: true), findsOneWidget);

    await unmountPage(tester);
  });
}
