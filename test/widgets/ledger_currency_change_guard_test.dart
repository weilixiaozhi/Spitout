import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/widgets/ledger_currency_change.dart';

import '../helpers/test_isolation.dart';

/// [applyLedgerCurrencyChange] 中央权限守卫测试。
///
/// 设计意图：共享账本的「币种」属于账本元信息，仅 Owner 可改。
/// 该守卫同时覆盖「账本编辑页」与「汇率页」两个币种入口，是 UI 置灰之外的
/// 第二/三道防线（防绕过 UI 直接调用）。本测试验证：
///   - 协作者（isShared + myRole != owner）调用后返回 false、币种不变，且弹出只读提示 toast；
///   - Owner 调用后守卫放行（不弹只读提示 toast），未误伤合法用户。
/// 注：相同币种会命中「同值跳过」提前返回，既不触发下游拉汇率/同步（避免测试环境网络挂起），
/// 又能干净地区分「守卫是否拦截」——守卫拦截才会弹 toast。
void main() {
  late SpitoutDatabase db;
  late LocalRepository repo;

  setUp(() {
    resetGlobalTestState();
    TestWidgetsFlutterBinding.ensureInitialized();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() => db.close());

  /// 写入一个共享账本并返回其本地 id，currency 默认 CNY。
  Future<int> seedLedger(String myRole) async {
    return db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'L',
            currency: const Value('CNY'),
            syncId: const Value('ext-1'),
            isShared: const Value(true),
            myRole: Value(myRole),
          ),
        );
  }

  Future<bool> callGuard(
    WidgetTester tester,
    int ledgerId,
    String newCurrency,
  ) async {
    BuildContext? capturedContext;
    WidgetRef? capturedRef;
    late bool result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProviderScope(
          overrides: [
            repositoryProvider.overrideWith((ref) => repo),
            activeCloudConfigProvider.overrideWith((ref) async =>
                const CloudServiceConfig(
                  type: CloudBackendType.local,
                  name: 'Local',
                )),
            // 不覆盖 currentLedgerIdProvider：其默认值为 0，与真实 ledgerId(≥1) 不同，
            // 自然跳过「补入当前账本可见集合」分支，避免可见币种 provider 干扰本测试。
          ],
          // 用 Consumer 获取与 ProviderScope 绑定的 WidgetRef（BuildContext.ref 扩展在此环境不可用）
          child: Consumer(
            builder: (context, ref, _) {
              capturedContext = context;
              capturedRef = ref;
              return const Placeholder();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    result = await applyLedgerCurrencyChange(
      capturedContext!,
      capturedRef!,
      ledgerId: ledgerId,
      newCurrency: newCurrency,
    );
    return result;
  }

  Future<String> currencyOf(int ledgerId) async {
    final l = await repo.getLedgerById(ledgerId);
    return l!.currency;
  }

  testWidgets('协作者共享账本:守卫拦截,返回 false 且币种不变并弹只读提示',
      (tester) async {
    final ledgerId = await seedLedger('editor');
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

    final result = await callGuard(tester, ledgerId, 'USD');

    expect(result, isFalse);
    // 守卫在第 51 行提前返回，updateLedger 从未执行，币种保持 CNY
    expect(await currencyOf(ledgerId), 'CNY');
    // 守卫拦截路径弹出了只读提示 toast（推进一帧使其可见）
    await tester.pump();
    expect(find.text(l10n.ledgerMetaReadOnlyToast), findsOneWidget);
    // 让 toast 自动消失并清空定时器，否则遗留 Timer 会导致测试断言失败
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('Owner 共享账本:守卫放行,不弹只读提示', (tester) async {
    final ledgerId = await seedLedger('owner');
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

    // 相同币种：守卫放行（owner）后于「同值跳过」提前返回，不弹只读 toast、不触网络
    final result = await callGuard(tester, ledgerId, 'CNY');

    expect(result, isFalse);
    // 关键对照：协作者会弹 toast，Owner 不应弹 —— 证明守卫未误伤 Owner
    await tester.pump();
    expect(find.text(l10n.ledgerMetaReadOnlyToast), findsNothing);
  });
}
