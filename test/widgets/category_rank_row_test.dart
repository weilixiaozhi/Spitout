/// CategoryRankRow（统计看板-父分类行）组件测试。
///
/// 重点覆盖本次「收起/展开指示箭头」改动：
/// - 父分类存在可展示子分类（预计算且金额>0）时，默认渲染向右箭头（收起态）。
/// - 点击内容区展开后，箭头旋转 90° 指向下方（展开态），并渲染子分类行。
/// - 再次点击内容区收起，箭头回到向右，子分类行移除。
/// - 父分类无子分类（null / 空列表 / 子分类金额均为0）时不渲染箭头，点击无副作用。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/widgets/category_rank_row.dart';

/// 构造一个测试账本，仅用于 AmountText 取币种符号（CNY → ¥）。
Ledger _buildLedger() => Ledger(
      id: 1,
      name: '测试账本',
      currency: 'CNY',
      type: 'personal',
      createdAt: DateTime(2026, 1, 1),
      myRole: 'owner',
      memberCount: 1,
      isShared: false,
      monthStartDay: 1,
      storageMode: 'local',
      aaEnabled: false,
    );

/// 用 ProviderScope + MaterialApp 包装待测的 CategoryRankRow。
/// 仅需 override currentLedgerProvider（AmountText 取币种符号用），其余 provider
/// CategoryRankRow 不直接依赖。
Widget _buildHost(CategoryRankRow row, Ledger ledger) => ProviderScope(
      overrides: [
        currentLedgerProvider
            .overrideWith((ref) => Stream<Ledger?>.value(ledger)),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(body: row),
      ),
    );

/// 构造一个父分类行。
/// [subCategories] 为预计算的子分类明细；传 null / 空 / 金额全 0 用于无子分类场景。
CategoryRankRow _buildParent({
  List<({int id, Category? category, String name, double total})>? subCategories,
}) =>
    CategoryRankRow(
      categoryId: 10,
      name: '餐饮',
      value: 1000,
      percent: 0.5,
      color: Colors.orange,
      subCategories: subCategories,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Ledger ledger;

  setUp(() => ledger = _buildLedger());

  testWidgets('默认收起态：渲染向右箭头，且不展示子分类', (tester) async {
    await tester.pumpWidget(_buildHost(
      _buildParent(
        subCategories: [
          (id: 101, category: null, name: '外卖', total: 400),
        ],
      ),
      ledger,
    ));
    await tester.pumpAndSettle();

    // 仅存在一个指示箭头，且默认向右（turns=0）。
    expect(find.byType(AnimatedRotation), findsOneWidget,
        reason: '有子分类时应渲染一个收起/展开指示箭头');
    final arrow =
        tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
    expect(arrow.turns, 0.0, reason: '收起态箭头应朝右(turns=0)');

    // 子分类内容不应渲染。
    expect(find.text('外卖'), findsNothing, reason: '收起态不应渲染子分类行');
  });

  testWidgets('点击内容区展开：箭头转向下方并展示子分类', (tester) async {
    await tester.pumpWidget(_buildHost(
      _buildParent(
        subCategories: [
          (id: 101, category: null, name: '外卖', total: 400),
          (id: 102, category: null, name: '聚餐', total: 600),
        ],
      ),
      ledger,
    ));
    await tester.pumpAndSettle();

    // 点击父分类内容区标题（命中 GestureDetector 内容区）触发展开。
    await tester.tap(find.text('餐饮'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // 展开态：箭头旋转 90° 指向下方（turns=0.25）。
    final arrow =
        tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
    expect(arrow.turns, 0.25, reason: '展开态箭头应朝下(turns=0.25)');

    // 子分类行应全部渲染。
    expect(find.text('外卖'), findsOneWidget, reason: '展开态应渲染子分类「外卖」');
    expect(find.text('聚餐'), findsOneWidget, reason: '展开态应渲染子分类「聚餐」');
  });

  testWidgets('再次点击内容区收起：箭头回正向右，移除子分类', (tester) async {
    await tester.pumpWidget(_buildHost(
      _buildParent(
        subCategories: [
          (id: 101, category: null, name: '外卖', total: 400),
        ],
      ),
      ledger,
    ));
    await tester.pumpAndSettle();

    // 展开
    await tester.tap(find.text('餐饮'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('外卖'), findsOneWidget, reason: '展开后应有子分类');

    // 收起
    await tester.tap(find.text('餐饮'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final arrow =
        tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
    expect(arrow.turns, 0.0, reason: '收起态箭头应回正朝右(turns=0)');
    expect(find.text('外卖'), findsNothing, reason: '收起后子分类应被移除');
  });

  testWidgets('无子分类（null）：不渲染箭头，点击无副作用', (tester) async {
    await tester.pumpWidget(_buildHost(_buildParent(subCategories: null), ledger));
    await tester.pumpAndSettle();

    expect(find.byType(AnimatedRotation), findsNothing,
        reason: '无子分类不应渲染箭头');

    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    // 无异常、无箭头即可（无子分类可展开）。
    expect(find.byType(AnimatedRotation), findsNothing);
  });

  testWidgets('空子分类列表：不渲染箭头', (tester) async {
    await tester.pumpWidget(_buildHost(_buildParent(subCategories: const []), ledger));
    await tester.pumpAndSettle();
    expect(find.byType(AnimatedRotation), findsNothing,
        reason: '空子分类列表不应渲染箭头');
  });

  testWidgets('子分类金额均为 0：不渲染箭头', (tester) async {
    await tester.pumpWidget(_buildHost(
      _buildParent(
        subCategories: [
          (id: 101, category: null, name: '外卖', total: 0),
        ],
      ),
      ledger,
    ));
    await tester.pumpAndSettle();
    expect(find.byType(AnimatedRotation), findsNothing,
        reason: '子分类金额均为0时不应渲染箭头（与展开判定保持一致）');
  });
}
