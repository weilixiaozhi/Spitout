/// 成员账单详情页组件测试。
///
/// 需求锚点（设计稿）：
/// - 头部：成员名 + 账本名；
/// - 汇总卡：账单汇总（总笔数 / 总金额）+ 应收（应付）金额；
/// - 分摊方式：人均分摊 / 指定金额 / 不分摊 笔数三卡；
/// - 账单列表：分类名、备注、时间·付款人、账单总额、分摊明细；
/// - 无账单时展示空态。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/statistics/aa_member_detail_page.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/services/statistics/aa_member_detail_models.dart';
import 'package:spitout/services/statistics/aa_statistics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  /// 构造一笔账单（分类为空，展示兜底分类名）。
  AaMemberBill makeBill({
    required int id,
    required int amountCents,
    required double myShare,
    required AaMode mode,
    required DateTime happenedAt,
    String? note,
    String? paidByUserId = 'u1',
    List<AaMemberSplit>? splits,
  }) {
    return AaMemberBill(
      tx: Transaction(
        id: id,
        ledgerId: 1,
        type: 'expense',
        amount: amountCents,
        happenedAt: happenedAt,
        note: note,
        excludeFromStats: false,
        currencyCode: 'CNY',
        nativeAmount: amountCents,
        version: 1,
        paidByUserId: paidByUserId,
        aaMode: mode == AaMode.custom ? 2 : (mode == AaMode.noSplit ? 1 : 0),
        aaParticipants: null,
        aaSplits: null,
      ),
      mode: mode,
      totalAmount: amountCents / 100,
      myShare: myShare,
      payerName: '张三',
      splits:
          splits ??
          [
            AaMemberSplit(
              participantId: 'u1',
              displayName: '张三',
              amount: myShare,
              isSelf: true,
            ),
          ],
    );
  }

  Future<void> pumpPage(WidgetTester tester, AaMemberDetailData data) async {
    // 列表内容较长（3 个日期分组），放大视口避免懒加载导致屏外项未构建。
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aaMemberDetailProvider.overrideWith((ref, args) async => data),
          currentLedgerProvider.overrideWith((ref) => Stream.value(null)),
          aaParticipantAvatarContextProvider.overrideWith(
            (ref, ledgerId) async => const AaParticipantAvatarContext(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AaMemberDetailPage(
            args: const AaMemberDetailArgs(
              ledgerId: 1,
              participantId: 'u1',
              displayName: '张三',
              isSelf: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmountPage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets('详情页渲染汇总卡、分摊方式与按日期分组的账单明细', (tester) async {
    final data = AaMemberDetailData(
      ledgerName: '测试账本',
      member: AaParticipantSummary(
        participantId: 'u1',
        displayName: '张三',
        totalPaid: 168,
        totalShouldPay: 56,
        isSelf: true,
      ),
      bills: [
        makeBill(
          id: 1,
          amountCents: 16800,
          myShare: 56,
          mode: AaMode.perPerson,
          happenedAt: DateTime(2026, 8, 3, 19, 15),
          note: '昱阳米粉 晚餐',
        ),
        makeBill(
          id: 2,
          amountCents: 800,
          myShare: 4,
          mode: AaMode.custom,
          happenedAt: DateTime(2026, 7, 30, 20, 0),
          note: '指定金额分摊',
        ),
        makeBill(
          id: 3,
          amountCents: 700,
          myShare: 7,
          mode: AaMode.noSplit,
          happenedAt: DateTime(2026, 8, 1, 8, 0),
          note: '个人物品',
          splits: const [],
        ),
      ],
    );

    await pumpPage(tester, data);

    // 头部：成员名 + 账本名。
    expect(find.text('张三'), findsWidgets);
    expect(find.text('测试账本'), findsOneWidget);
    // 汇总卡：标题 + 总笔数标签 + 应收金额（净额 > 0）。
    expect(find.text('账单汇总'), findsOneWidget);
    expect(find.text('总笔数'), findsOneWidget);
    expect(find.text('应收金额'), findsOneWidget);
    // 分摊方式：人均分摊 / 指定金额 / 不分摊 各一笔；
    // 文案同时出现在「分摊方式卡」与账单行「分摊方式徽标」上。
    expect(find.text('人均分摊'), findsNWidgets(2));
    expect(find.text('指定金额'), findsNWidgets(2));
    expect(find.text('不分摊'), findsNWidgets(2));
    expect(find.text('1'), findsNWidgets(3));
    // 汇总卡不展示平均金额。
    expect(find.text('平均金额'), findsNothing);
    // 账单行：备注、账单总额（红色总额；应摊金额只出现在分摊明细中）。
    expect(find.text('昱阳米粉 晚餐'), findsOneWidget);
    expect(find.text('个人物品'), findsOneWidget);
    expect(find.text('¥ 168'), findsOneWidget);
    expect(find.text('¥ 8'), findsOneWidget);
    expect(find.text('¥ 7'), findsOneWidget);
    expect(find.text('共 ¥ 168'), findsNothing);
    expect(find.text('- ¥ 56'), findsNothing);
    // 分摊明细区：仅 AA 账单展示，不分摊账单不渲染。
    expect(find.text('分摊明细'), findsNWidgets(2));

    await unmountPage(tester);
  });

  testWidgets('无垫付账单时展示空态', (tester) async {
    final data = AaMemberDetailData(
      ledgerName: '测试账本',
      member: AaParticipantSummary(
        participantId: 'u1',
        displayName: '张三',
        totalPaid: 0,
        totalShouldPay: 0,
        isSelf: true,
      ),
      bills: const [],
    );

    await pumpPage(tester, data);

    expect(find.text('暂无该成员的账单'), findsOneWidget);
    expect(find.text('已结清'), findsOneWidget);

    await unmountPage(tester);
  });
}
