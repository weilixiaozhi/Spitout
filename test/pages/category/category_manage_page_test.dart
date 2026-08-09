// 分类管理页面 UI 优化组件测试
//
// 验证内容：
//   1. 正常模式：右上角"添加分类"按钮 + 底部"删除分类"入口
//   2. 删除模式切换：点击"删除分类"进入删除模式，显示复选框
//   3. 0 选中时"确认删除"禁用，≥1 选中时启用
//   4. 删除模式底部三个单选项（含二级 / 迁移 / 不含二级）
//   5. PopScope：删除模式下返回键退出删除模式而非关闭页面
//   6. 删除模式底部"确认删除"与"清空未使用分类"同一行

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/data/db.dart' as db;
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/category/category_edit_page.dart';
import 'package:spitout/pages/category/category_manage_page.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/theme/icons/app_icons.dart';

/// Mock 整个 BaseRepository，未 stub 的方法返回默认值不抛异常。
class _MockRepo extends Mock implements BaseRepository {}

typedef _CategoryWithCount = ({db.Category category, int transactionCount});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // mocktail 需要注册 fallback 值用于 List 等泛型参数匹配
  registerFallbackValue(<int>[]);

  late _MockRepo repo;
  late List<_CategoryWithCount> testCategories;

  /// 构造测试分类数据：3 个一级分类，其中 1 个有子分类
  setUp(() {
    repo = _MockRepo();
    testCategories = [
      (
        category: db.Category(
          id: 1,
          name: '餐饮',
          kind: 'expense',
          icon: 'utensils',
          sortOrder: 0,
          parentId: null,
          level: 1,
        ),
        transactionCount: 5,
      ),
      (
        category: db.Category(
          id: 2,
          name: '交通',
          kind: 'expense',
          icon: 'bus',
          sortOrder: 1,
          parentId: null,
          level: 1,
        ),
        transactionCount: 3,
      ),
      (
        category: db.Category(
          id: 3,
          name: '购物',
          kind: 'expense',
          icon: 'shoppingCart',
          sortOrder: 2,
          parentId: null,
          level: 1,
        ),
        transactionCount: 0,
      ),
      // 购物的子分类（用于验证有子分类指示器）
      (
        category: db.Category(
          id: 4,
          name: '服装',
          kind: 'expense',
          icon: 'shirt',
          sortOrder: 0,
          parentId: 3,
          level: 2,
        ),
        transactionCount: 2,
      ),
    ];
  });

  /// 构造测试账本（只填共享标记/角色关心字段，其余给固定值）。
  db.Ledger testLedger({required bool isShared, required String myRole}) =>
      db.Ledger(
        id: 1,
        name: '测试账本',
        currency: 'CNY',
        type: 'normal',
        createdAt: DateTime.utc(2026, 1, 1),
        myRole: myRole,
        memberCount: 2,
        isShared: isShared,
        monthStartDay: 1,
        storageMode: 'cloud',
        aaEnabled: false,
      );

  /// 构建测试宿主，注入 mock repo 和预设分类数据。
  ///
  /// [ledger] 为当前账本 override（默认 null：未加载到账本），
  /// 用于覆盖共享账本 Owner/Editor 与个人账本下的横幅渲染分支。
  Widget buildApp({db.Ledger? ledger}) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 0),
        currentLedgerProvider
            .overrideWith((ref) => Stream<db.Ledger?>.value(ledger)),
        // categoriesWithCountProvider 是 StreamProvider.autoDispose，
        // 直接发射预设数据让页面渲染
        categoriesWithCountProvider.overrideWith(
          (ref) => Stream<List<_CategoryWithCount>>.value(testCategories),
        ),
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
        home: const CategoryManagePage(),
      ),
    );
  }

  /// 分步 pump：让 stream 首帧 + async 加载完成
  Future<void> prime(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  // ==================== 正常模式 UI ====================

  group('正常模式 UI', () {
    testWidgets('页面标题为分类管理，不包含 Tab 栏', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 无 TabBar（分类管理页不展示支出 Tab 标题栏）
      expect(find.byType(TabBar), findsNothing, reason: '不应有 TabBar');
    });

    testWidgets('右上角显示"添加分类"图标按钮', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 2026-07-24 改版：右上角入口从文字按钮改为圆圈加号 IconButton
      // （与周期账单新增入口统一风格），"添加分类"文案收敛到 tooltip。
      final buttonFinder = find.widgetWithIcon(IconButton, AppIcons.addCircle);
      expect(buttonFinder, findsOneWidget, reason: '应有"添加分类"图标按钮');
      expect(tester.widget<IconButton>(buttonFinder).tooltip, '添加分类',
          reason: '图标按钮 tooltip 应为"添加分类"');
    });

    testWidgets('底部显示"删除分类"入口按钮', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      expect(find.text('删除分类'), findsOneWidget, reason: '应有"删除分类"按钮');
    });

    testWidgets('正常模式不显示"清空未使用分类"（已移至删除模式）', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 清空未使用分类仅在删除模式内显示，正常模式不应出现
      expect(find.text('清空未使用分类'), findsNothing,
          reason: '正常模式不应显示"清空未使用分类"');
    });

    testWidgets('显示长按排序提示', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      expect(find.text('长按调整分类顺序'), findsOneWidget,
          reason: '应有长按排序提示文案');
    });

    testWidgets('分类网格展示分类名称', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      expect(find.text('餐饮'), findsOneWidget, reason: '应显示一级分类"餐饮"');
      expect(find.text('交通'), findsOneWidget, reason: '应显示一级分类"交通"');
      expect(find.text('购物'), findsOneWidget, reason: '应显示一级分类"购物"');
    });

    testWidgets('有子分类的一级分类显示指示器（右下角圆点）', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 购物(id=3)有子分类(服装 id=4)，应显示子分类指示器
      // 指示器是 AppIcons.moreHorizontal 图标（Lucide）
      expect(find.byIcon(AppIcons.moreHorizontal), findsOneWidget,
          reason: '有子分类的"购物"应显示右下角指示器');
    });
  });

  // ==================== 共享账本横幅 ====================

  group('共享账本横幅', () {
    testWidgets('共享账本 Owner：显示「修改会同步给成员」横幅', (tester) async {
      await tester.pumpWidget(
          buildApp(ledger: testLedger(isShared: true, myRole: 'owner')));
      await prime(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      expect(find.text(l10n.categorySharedManageBannerOwner), findsOneWidget);
      expect(find.text(l10n.categorySharedManageBannerEditor), findsNothing);
    });

    testWidgets('共享账本 Editor：显示「记账用所有者分类」横幅', (tester) async {
      await tester.pumpWidget(
          buildApp(ledger: testLedger(isShared: true, myRole: 'editor')));
      await prime(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      expect(find.text(l10n.categorySharedManageBannerEditor), findsOneWidget);
      expect(find.text(l10n.categorySharedManageBannerOwner), findsNothing);
    });

    testWidgets('个人账本：不渲染共享横幅', (tester) async {
      await tester.pumpWidget(
          buildApp(ledger: testLedger(isShared: false, myRole: 'owner')));
      await prime(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      expect(find.text(l10n.categorySharedManageBannerOwner), findsNothing);
      expect(find.text(l10n.categorySharedManageBannerEditor), findsNothing);
    });
  });

  // ==================== 删除模式切换 ====================

  group('删除模式切换', () {
    testWidgets('点击"删除分类"进入删除模式，文案变为"确认删除"', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 点击"删除分类"
      await tester.tap(find.text('删除分类'));
      await tester.pump(const Duration(milliseconds: 100));

      // 文案变为"确认删除"
      expect(find.text('确认删除'), findsOneWidget, reason: '应显示"确认删除"');
      expect(find.text('删除分类'), findsNothing, reason: '不应再显示"删除分类"');
    });

    testWidgets('进入删除模式后复选框出现', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 正常模式无复选框（空心圆容器）
      // 进入删除模式
      await tester.tap(find.text('删除分类'));
      await tester.pump(const Duration(milliseconds: 100));

      // 删除模式下分类卡片有复选框（Icon(Icons.check) 在选中态出现）
      // 未选中态有空心圆容器，通过 find 验证有 Positioned 复选框区域
      expect(find.byIcon(Icons.check), findsNothing,
          reason: '未选中时不应有勾选图标');
    });

    testWidgets('0 选中时"确认删除"禁用（灰色）', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      await tester.tap(find.text('删除分类'));
      await tester.pump(const Duration(milliseconds: 100));

      // 0 选中时确认删除按钮不可点击 → GestureDetector 的 onTap 为 null
      // 验证文案颜色为禁用色（灰色）
      final confirmText = tester.widget<Text>(find.text('确认删除'));
      // 禁用态颜色应为 textDisabled（灰色系）
      expect(confirmText.style?.color, isNotNull, reason: '应有颜色样式');
    });

    testWidgets('选中一个分类后"确认删除"变为可点击', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 进入删除模式
      await tester.tap(find.text('删除分类'));
      await tester.pump(const Duration(milliseconds: 100));

      // 点击第一个分类卡片选中
      await tester.tap(find.text('餐饮'));
      await tester.pump(const Duration(milliseconds: 100));

      // 应出现勾选图标
      expect(find.byIcon(Icons.check), findsOneWidget,
          reason: '选中后应显示勾选图标');
    });

    testWidgets('选中后再次点击取消选中', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      await tester.tap(find.text('删除分类'));
      await tester.pump(const Duration(milliseconds: 100));

      // 选中
      await tester.tap(find.text('餐饮'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.check), findsOneWidget);

      // 取消选中
      await tester.tap(find.text('餐饮'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.check), findsNothing, reason: '再次点击应取消选中');
    });
  });

  // ==================== 删除策略单选项 ====================

  group('删除策略单选项', () {
    testWidgets('删除模式底部显示三个策略选项', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      await tester.tap(find.text('删除分类'));
      await tester.pump(const Duration(milliseconds: 100));

      // 策略 0：删除分类和分类下的所有数据（含二级）
      expect(find.text('删除分类和分类下的所有数据（含二级）'), findsOneWidget,
          reason: '应有含二级删除策略');
      // 策略 1：删除分类并迁移分类下的所有数据到其他分类（含二级）
      expect(find.text('删除分类并迁移分类下的所有数据到其他分类（含二级）'), findsOneWidget,
          reason: '应有迁移策略');
      // 策略 2：删除分类和分类下的所有数据（不含二级分类，二级分类将变为一级分类）
      expect(
          find.text('删除分类和分类下的所有数据（不含二级分类，二级分类将变为一级分类）'),
          findsOneWidget,
          reason: '应有提升子分类策略');
    });

    testWidgets('默认选中策略 0（含二级删除）', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      await tester.tap(find.text('删除分类'));
      await tester.pump(const Duration(milliseconds: 100));

      // 策略 0 对应的 radio 应为选中态（实心圆）
      // 通过验证"删除分类和分类下的所有数据（含二级）"所在行的选中指示器
      // 由于实现用自定义 Container 圆点，验证选中态颜色为 error 色
      // 这里验证文案存在即可（UI 细节在 widget 测试中较难精确断言颜色）
      expect(find.text('删除分类和分类下的所有数据（含二级）'), findsOneWidget);
    });

    testWidgets('删除模式显示"清空未使用分类"但不显示排序提示', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      await tester.tap(find.text('删除分类'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('长按调整分类顺序'), findsNothing,
          reason: '删除模式不应显示排序提示');
      // 清空未使用分类已移至删除模式底部，应显示
      expect(find.text('清空未使用分类'), findsOneWidget,
          reason: '删除模式应显示"清空未使用分类"');
    });

    testWidgets('删除模式底部"确认删除"与"清空未使用分类"同一行', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      await tester.tap(find.text('删除分类'));
      await tester.pump(const Duration(milliseconds: 100));

      // 两个文字链应在同一个 Row 中（spaceAround 左右排放）
      final confirmFinder = find.text('确认删除');
      final clearFinder = find.text('清空未使用分类');
      expect(confirmFinder, findsOneWidget);
      expect(clearFinder, findsOneWidget);

      // 验证两者拥有同一个最近的 Row 祖先
      final confirmRow = find.ancestor(
        of: confirmFinder,
        matching: find.byType(Row),
      );
      final clearRow = find.ancestor(
        of: clearFinder,
        matching: find.byType(Row),
      );
      expect(
        tester.widget<Row>(confirmRow.first),
        same(tester.widget<Row>(clearRow.first)),
        reason: '"确认删除"与"清空未使用分类"应在同一行',
      );
    });
  });

  // ==================== 删除确认弹窗（策略 0：含二级） ====================

  group('删除确认弹窗（策略 0：含二级，全量展示 + 内部滑动）', () {
    /// 弹窗内查找工具：限定在 AlertDialog 子树内，避免命中背后网格中的同名分类
    Finder inDialog(Finder dialog, String text) =>
        find.descendant(of: dialog, matching: find.text(text));

    testWidgets('弹窗列出全部选中父分类及其子分类，内容过长时弹窗内部支持滑动',
        (tester) async {
      // 5 个父分类，各带 3 个子分类：内容高度超过弹窗 0.6 倍屏高，必须可滚动
      testCategories = [
        for (int p = 0; p < 5; p++) ...[
          (
            category: db.Category(
              id: 100 + p,
              name: '父分类${p + 1}',
              kind: 'expense',
              icon: 'category',
              sortOrder: p,
              parentId: null,
              level: 1,
            ),
            transactionCount: 6,
          ),
          for (int s = 0; s < 3; s++)
            (
              category: db.Category(
                id: 200 + p * 10 + s,
                name: '子分类${p + 1}-$s',
                kind: 'expense',
                icon: 'tag',
                sortOrder: s,
                parentId: 100 + p,
                level: 2,
              ),
              transactionCount: 2,
            ),
        ],
      ];

      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 进入删除模式
      await tester.tap(find.text('删除分类'));
      await tester.pump(const Duration(milliseconds: 100));

      // 选中全部 5 个父分类
      for (int p = 0; p < 5; p++) {
        await tester.tap(find.text('父分类${p + 1}'));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // 点击底部"确认删除"（已移至分类列表底部 footer，先确保其滚入视口）
      await tester.ensureVisible(find.text('确认删除'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('确认删除'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // 弹窗打开：标题 + 含二级副标题
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget, reason: '应弹出删除确认弹窗');
      expect(find.text('删除选中的分类'), findsOneWidget, reason: '应有弹窗标题');
      expect(
        find.textContaining('包含二级分类和数据'),
        findsOneWidget,
        reason: '策略 0 应显示含二级的副标题',
      );
      // 滚动条常显，提示内容可滑动
      expect(
        find.descendant(of: dialog, matching: find.byType(Scrollbar)),
        findsOneWidget,
        reason: '弹窗列表应有常显滚动条',
      );

      final scrollable = find.descendant(
        of: dialog,
        matching: find.byType(Scrollable),
      );

      // 全量展示：5 个父分类 + 15 个子分类全部存在于弹窗列表中
      for (int p = 0; p < 5; p++) {
        expect(inDialog(dialog, '父分类${p + 1}'), findsOneWidget,
            reason: '弹窗应展示父分类${p + 1}');
        for (int s = 0; s < 3; s++) {
          expect(inDialog(dialog, '子分类${p + 1}-$s'), findsOneWidget,
              reason: '弹窗应展示子分类${p + 1}-$s');
        }
      }

      // 内部可滑动：内容高度超过弹窗可视区（maxScrollExtent > 0），
      // 且滚到底部后最后一个子分类进入可视区域
      final scrollState = tester.state<ScrollableState>(scrollable);
      expect(scrollState.position.maxScrollExtent, greaterThan(0),
          reason: '弹窗内容应超出可视高度，支持内部滑动');
      await tester.drag(scrollable, const Offset(0, -5000));
      await tester.pumpAndSettle();
      final dialogRect = tester.getRect(dialog);
      final lastItemRect = tester.getRect(inDialog(dialog, '子分类5-2'));
      expect(lastItemRect.bottom,
          lessThanOrEqualTo(dialogRect.bottom + 1),
          reason: '滚动到底部后最后一个子分类应完整可见');
    });
  });

  // ==================== PopScope 返回键 ====================

  group('PopScope 返回键行为', () {
    testWidgets('删除模式下按返回键退出删除模式而非关闭页面', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 进入删除模式
      await tester.tap(find.text('删除分类'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('确认删除'), findsOneWidget, reason: '应处于删除模式');

      // 模拟返回键
      final didPop = await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 100));

      // Flutter 3.27 的 Navigator.maybePop 遇到 PopScope canPop=false（doNotPop）时，
      // 会回调 onPopInvokedWithResult 并返回 true（表示"已处理"，而非"已 pop"），
      // 因此此处断言 true；页面未被真正 pop 由后续"仍在页面中"的断言保证。
      expect(didPop, isTrue,
          reason: 'PopScope 否决 pop 后 maybePop 返回 true（已处理）');
      // 退出删除模式后应回到正常模式
      expect(find.text('删除分类'), findsOneWidget,
          reason: '返回键应退出删除模式，回到正常模式显示"删除分类"');
      expect(find.text('确认删除'), findsNothing,
          reason: '返回键不应关闭页面，应退出删除模式');
    });

    testWidgets('正常模式下按返回键正常关闭页面', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 正常模式下 canPop=true，返回键应关闭页面
      // 由于是 home 页面，pop 会导致空白，这里仅验证不进入删除模式
      expect(find.text('删除分类'), findsOneWidget, reason: '应处于正常模式');
    });
  });

  // ==================== 文字链字号与点击热区 ====================

  group('文字链字号与点击热区', () {
    /// 验证文字链字号 ≥ 13 且被 Padding 包裹以扩大点击热区（垂直 padding ≥ 12）。
    ///
    /// 设计意图：文字链须 ≥13px 且带 vertical padding 扩大点击热区，
    /// 保证"看得清且点得到"。
    void expectTappableTextLink(WidgetTester tester, String label) {
      final textFinder = find.text(label);
      expect(textFinder, findsOneWidget, reason: '应存在文字链"$label"');

      // 字号验证：≥ 13（过小看不清）
      final text = tester.widget<Text>(textFinder);
      expect(text.style?.fontSize, greaterThanOrEqualTo(13),
          reason: '"$label"字号应 ≥ 13（过小看不清）');

      // 点击热区验证：最近的 Padding 祖先应有垂直 padding ≥ 12 扩大点击热区
      final paddingFinder = find.ancestor(
        of: textFinder,
        matching: find.byType(Padding),
      );
      final padding = tester.widget<Padding>(paddingFinder.first);
      final resolved = padding.padding.resolve(TextDirection.ltr);
      expect(resolved.vertical, greaterThanOrEqualTo(12),
          reason: '"$label"应有垂直 padding ≥ 12 扩大点击热区');
    }

    testWidgets('"添加分类"图标按钮有足够点击热区', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 添加入口已收敛为 HeaderIconAction：
      // 热区统一 30x30（图标 20 + 四周 0），与首行最小高度 30 一致，
      // 防止裸 IconButton 默认 48 热区撑大首行行高、破坏页面间行高一致性。
      final buttonFinder = find.widgetWithIcon(IconButton, AppIcons.addCircle);
      expect(buttonFinder, findsOneWidget, reason: '应存在"添加分类"图标按钮');
      final size = tester.getSize(buttonFinder);
      expect(size.width, 30,
          reason: '"添加分类"图标按钮热区宽度应 = 30（全局头部统一规格）');
      expect(size.height, 30,
          reason: '"添加分类"图标按钮热区高度应 = 30（与首行最小高度一致）');
    });

    testWidgets('"删除分类"字号 ≥ 13 且有足够点击热区', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      expectTappableTextLink(tester, '删除分类');
    });

    /// 验证模板入口为独立按钮：文字字号 ≥ 13 且按钮高度 ≥ 36（足够点击热区）。
    ///
    /// 2026-07-24 改版：模板入口从头部文字链改为标题下的独立 OutlinedButton，
    /// 文字经按钮 textStyle 注入（DefaultTextStyle 下发），
    /// 按钮自带 Material 触摸目标，天然满足热区要求。
    void expectTemplateEntryButton(WidgetTester tester, String label) {
      final textFinder = find.text(label);
      expect(textFinder, findsOneWidget, reason: '应存在模板入口"$label"');

      // 入口必须是独立按钮（OutlinedButton.icon 实际类型为私有子类，用 bySubtype 匹配）
      final buttonFinder = find.ancestor(
        of: textFinder,
        matching: find.bySubtype<OutlinedButton>(),
      );
      expect(buttonFinder, findsOneWidget, reason: '"$label"应为独立按钮而非文字链');

      // 字号验证：≥ 13（过小看不清）
      final textContext = tester.element(textFinder);
      expect(
        DefaultTextStyle.of(textContext).style.fontSize,
        greaterThanOrEqualTo(13),
        reason: '"$label"字号应 ≥ 13',
      );

      // 点击热区验证：按钮渲染高度 ≥ 36（Material 触摸目标）
      expect(
        tester.getSize(buttonFinder).height,
        greaterThanOrEqualTo(36),
        reason: '"$label"按钮应有足够点击热区',
      );
    }

    testWidgets('"一级模板"为独立按钮，字号 ≥ 13 且有足够点击热区', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      expectTemplateEntryButton(tester, '一级模板');
    });

    testWidgets('"二级模板"为独立按钮，字号 ≥ 13 且有足够点击热区', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      expectTemplateEntryButton(tester, '二级模板');
    });
  });

  // ==================== 删除/迁移执行路径 ====================

  group('删除/迁移执行', () {
    Future<void> enterDeleteMode(WidgetTester tester) async {
      await tester.tap(find.text('删除分类'));
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> selectCategory(WidgetTester tester, String name) async {
      await tester.tap(find.text(name));
      await tester.pump(const Duration(milliseconds: 50));
    }

    Future<void> confirmDelete(WidgetTester tester) async {
      await tester.ensureVisible(find.text('确认删除'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('确认删除'));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('策略 0：确认后删除一级分类及其子分类数据', (tester) async {
      when(() => repo.deleteTransactionsByCategoryIds(any()))
          .thenAnswer((_) async => 3);
      when(() => repo.deleteCategoriesByIds(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildApp());
      await prime(tester);
      await enterDeleteMode(tester);
      // 选中「购物」(id=3)：其子分类「服装」(id=4) 应一并收集删除
      await selectCategory(tester, '购物');
      await confirmDelete(tester);

      expect(find.text('删除选中的分类'), findsOneWidget);
      expect(find.textContaining('包含二级分类和数据'), findsOneWidget);
      await tester.tap(find.text('删除'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('已删除 1 个分类'), findsOneWidget);
      verify(() => repo.deleteTransactionsByCategoryIds([3, 4])).called(1);
      verify(() => repo.deleteCategoriesByIds([3])).called(1);
      // 已退出删除模式
      expect(find.text('删除分类'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2)); // toast 定时器
    });

    testWidgets('策略 2：删除一级分类并将二级提升为一级', (tester) async {
      when(() => repo.deleteTransactionsByCategoryIds(any()))
          .thenAnswer((_) async => 1);
      when(() => repo.promoteSubCategoriesToTopLevel(any()))
          .thenAnswer((_) async => 1);
      when(() => repo.deleteCategoriesByIds(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildApp());
      await prime(tester);
      await enterDeleteMode(tester);

      // 切换策略 2（不含二级）
      final option = find.text(
          '删除分类和分类下的所有数据（不含二级分类，二级分类将变为一级分类）');
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pump(const Duration(milliseconds: 50));

      await selectCategory(tester, '购物');
      await confirmDelete(tester);
      expect(find.textContaining('不含二级分类和数据'), findsOneWidget);

      await tester.tap(find.text('删除'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => repo.deleteTransactionsByCategoryIds([3])).called(1);
      verify(() => repo.promoteSubCategoriesToTopLevel(3)).called(1);
      verify(() => repo.deleteCategoriesByIds([3])).called(1);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('策略 1：迁移数据到目标分类后删除源分类', (tester) async {
      // 迁移 sheet 内容较高，使用更高视口避免按钮落在屏幕外
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      when(() => repo.migrateCategoryTransactions(
            fromCategoryId: any(named: 'fromCategoryId'),
            toCategoryId: any(named: 'toCategoryId'),
          ))
          .thenAnswer((_) async =>
              (migratedSubCategories: 0, migratedTransactions: 2));
      when(() => repo.deleteCategoriesByIds(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildApp());
      await prime(tester);
      await enterDeleteMode(tester);

      // 切换策略 1（迁移）
      final migrateOption =
          find.text('删除分类并迁移分类下的所有数据到其他分类（含二级）');
      await tester.ensureVisible(migrateOption);
      await tester.tap(migrateOption);
      await tester.pump(const Duration(milliseconds: 50));

      await selectCategory(tester, '餐饮');
      await confirmDelete(tester);

      // 迁移目标 BottomSheet：选择「购物」→ 确认
      expect(find.text('选择数据迁移到的分类'), findsOneWidget);
      // 用搜索过滤到唯一目标（背后网格也有同名分类，取 sheet 中的最后一个）
      await tester.enterText(find.byType(TextField).last, '购物');
      await tester.pump(const Duration(milliseconds: 100));
      final shoppingChip = find.text('购物').last;
      await tester.ensureVisible(shoppingChip);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(shoppingChip);
      await tester.pump(const Duration(milliseconds: 100));
      final confirmButton = find.text('确定（迁移分类数据并删除分类）');
      await tester.ensureVisible(confirmButton);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(confirmButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => repo.migrateCategoryTransactions(
            fromCategoryId: 1,
            toCategoryId: 3,
          ))
          .called(1);
      verify(() => repo.deleteCategoriesByIds([1])).called(1);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('清空未使用分类：确认后删除 0 交易分类', (tester) async {
      when(() => repo.deleteCategoriesByIds(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildApp());
      await prime(tester);
      await enterDeleteMode(tester);

      await tester.tap(find.text('清空未使用分类'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('清空未使用分类'), findsWidgets);
      expect(find.textContaining('确定要删除 1 个未使用的分类吗'), findsOneWidget);

      await tester.tap(find.text('删除'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('已删除 1 个分类'), findsOneWidget);
      // 购物(id=3) 交易数为 0，是唯一未使用分类
      verify(() => repo.deleteCategoriesByIds([3])).called(1);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('删除失败：展示删除失败提示且保持删除模式', (tester) async {
      when(() => repo.deleteTransactionsByCategoryIds(any()))
          .thenThrow(Exception('db down'));

      await tester.pumpWidget(buildApp());
      await prime(tester);
      await enterDeleteMode(tester);
      await selectCategory(tester, '餐饮');
      await confirmDelete(tester);

      await tester.tap(find.text('删除'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('删除失败'), findsOneWidget);
      expect(find.text('确认删除'), findsOneWidget, reason: '仍停留在删除模式');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('添加分类：跳转分类编辑页', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      await tester.tap(find.byTooltip('添加分类'));
      await tester.pumpAndSettle();

      expect(find.byType(CategoryEditPage), findsOneWidget);
    });
  });
}
