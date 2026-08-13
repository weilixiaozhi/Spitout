// AnalyticsTestDataSeeder 纯逻辑测试：四种填充范围与空分类兜底。
//
// 覆盖点：
//   - year / month / week / day 四种 scope 各自生成的插入条数与时间范围
//   - 无可支出分类时自动建一个兜底分类
//   - 外币交易带 currencyCode / nativeAmount，本币交易两者为空
//   - paidByUserId 原样透传
// repository 用 mocktail 替身，避免依赖真实数据库。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/data/models.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/services/maintenance/analytics_test_data_seeder.dart';

class _MockRepo extends Mock implements LocalRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    when(() => repo.getUsableCategories('expense')).thenAnswer(
      (_) async => [
        const Category(
          id: 1,
          name: '餐饮',
          kind: 'expense',
          icon: 'x',
          sortOrder: 0,
          level: 0,
        ),
      ],
    );
    when(
      () => repo.addTransaction(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        amount: any(named: 'amount'),
        categoryId: any(named: 'categoryId'),
        happenedAt: any(named: 'happenedAt'),
        note: any(named: 'note'),
        paidByUserId: any(named: 'paidByUserId'),
        currencyCode: any(named: 'currencyCode'),
        nativeAmount: any(named: 'nativeAmount'),
      ),
    ).thenAnswer((_) async => 1);
  });

  Future<void> expectFill({
    required TestDataScope scope,
    required int expectedCount,
  }) async {
    final seeder = AnalyticsTestDataSeeder(repo);
    final inserted = await seeder.fill(
      ledgerId: 7,
      baseCurrency: 'CNY',
      scope: scope,
      paidByUserId: 'u-1',
    );

    expect(inserted, expectedCount);
    verify(
      () => repo.addTransaction(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        amount: any(named: 'amount'),
        categoryId: any(named: 'categoryId'),
        happenedAt: any(named: 'happenedAt'),
        note: any(named: 'note'),
        paidByUserId: any(named: 'paidByUserId'),
        currencyCode: any(named: 'currencyCode'),
        nativeAmount: any(named: 'nativeAmount'),
      ),
    ).called(expectedCount);
  }

  test('year 范围填充 96 条', () async {
    await expectFill(scope: TestDataScope.year, expectedCount: 96);
  });

  test('month 范围填充 40 条', () async {
    await expectFill(scope: TestDataScope.month, expectedCount: 40);
  });

  test('week 范围填充 28 条', () async {
    await expectFill(scope: TestDataScope.week, expectedCount: 28);
  });

  test('day 范围填充 12 条', () async {
    await expectFill(scope: TestDataScope.day, expectedCount: 12);
  });

  test('无可支出分类时自动创建兜底分类并继续填充', () async {
    when(() => repo.getUsableCategories('expense')).thenAnswer((_) async => []);
    when(
      () => repo.upsertCategory(name: any(named: 'name'), kind: any(named: 'kind')),
    ).thenAnswer(
      (_) async => (created: true, id: 99),
    );

    final seeder = AnalyticsTestDataSeeder(repo);
    final inserted = await seeder.fill(
      ledgerId: 7,
      baseCurrency: 'CNY',
      scope: TestDataScope.day,
    );

    expect(inserted, 12);
    verify(
      () => repo.upsertCategory(name: '测试填充', kind: 'expense'),
    ).called(1);
    verify(
      () => repo.addTransaction(
        ledgerId: 7,
        type: 'expense',
        amount: any(named: 'amount'),
        categoryId: 99,
        happenedAt: any(named: 'happenedAt'),
        note: '测试填充',
        paidByUserId: any(named: 'paidByUserId'),
        currencyCode: any(named: 'currencyCode'),
        nativeAmount: any(named: 'nativeAmount'),
      ),
    ).called(12);
  });

  test('外币与本币交易字段区分', () async {
    final calls = <Map<Symbol, Object?>>[];
    when(
      () => repo.addTransaction(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        amount: any(named: 'amount'),
        categoryId: any(named: 'categoryId'),
        happenedAt: any(named: 'happenedAt'),
        note: any(named: 'note'),
        paidByUserId: any(named: 'paidByUserId'),
        currencyCode: any(named: 'currencyCode'),
        nativeAmount: any(named: 'nativeAmount'),
      ),
    ).thenAnswer((invocation) async {
      calls.add(invocation.namedArguments);
      return 1;
    });

    final seeder = AnalyticsTestDataSeeder(repo);
    await seeder.fill(
      ledgerId: 7,
      baseCurrency: 'CNY',
      scope: TestDataScope.day,
    );

    expect(calls, hasLength(12));
    final anyForeign = calls.any(
      (c) => c[const Symbol('currencyCode')] != null,
    );
    final anyLocal = calls.any(
      (c) => c[const Symbol('currencyCode')] == null,
    );
    expect(anyForeign, isTrue);
    expect(anyLocal, isTrue);
  });
}
