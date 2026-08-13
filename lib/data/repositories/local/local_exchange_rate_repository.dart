import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/support/change_recorder.dart';

/// Drift 实现。tracker 用 getter 闭包注入:LocalRepository.changeTracker 是
/// 可变字段(构造后才赋值),直接传引用会捕获 null —— 2026-04 的 orphan-change
/// 坑就是这类时序问题,闭包取值规避。tracker 类型为 data 层抽象
/// [ChangeRecorder],不依赖 cloud 层具体实现。
class LocalExchangeRateRepository {
  static const _uuid = Uuid();
  final SpitoutDatabase db;
  final ChangeRecorder? Function() trackerGetter;

  LocalExchangeRateRepository(this.db, {required this.trackerGetter});

  Future<void> upsertAutoRates({
    required String base,
    required String rateDate,
    required Map<String, String> rates,
    required String source,
    required DateTime fetchedAt,
  }) async {
    final baseUp = base.toUpperCase();
    await db.batch((b) {
      for (final e in rates.entries) {
        b.insert(
          db.exchangeRates,
          ExchangeRatesCompanion.insert(
            baseCurrency: baseUp,
            quoteCurrency: e.key.toUpperCase(),
            rateDate: rateDate,
            rate: e.value,
            source: source,
            fetchedAt: fetchedAt,
          ),
          onConflict: d.DoUpdate(
            (_) => ExchangeRatesCompanion(
              rate: d.Value(e.value),
              source: d.Value(source),
              fetchedAt: d.Value(fetchedAt),
            ),
          ),
        );
      }
    });
    // 注意:自动汇率绝不记 change,测试有红线断言。
  }

  Future<List<ExchangeRate>> getLatestAutoRates(String base) async {
    final rows = await db
        .customSelect(
          'SELECT e.base_currency, e.quote_currency, e.rate_date, '
          'e.rate, e.source, e.fetched_at '
          'FROM exchange_rates e '
          'JOIN ('
          '  SELECT quote_currency, MAX(rate_date) AS max_date '
          '  FROM exchange_rates '
          '  WHERE base_currency = ?1 '
          '  GROUP BY quote_currency'
          ') latest '
          'ON latest.quote_currency = e.quote_currency '
          'AND latest.max_date = e.rate_date '
          'WHERE e.base_currency = ?1 '
          'ORDER BY e.quote_currency',
          variables: [d.Variable.withString(base.toUpperCase())],
          readsFrom: {db.exchangeRates},
        )
        .get();
    return rows
        .map(
          (row) => ExchangeRate(
            baseCurrency: row.read<String>('base_currency'),
            quoteCurrency: row.read<String>('quote_currency'),
            rateDate: row.read<String>('rate_date'),
            rate: row.read<String>('rate'),
            source: row.read<String>('source'),
            fetchedAt: row.read<DateTime>('fetched_at'),
          ),
        )
        .toList();
  }

  Future<DateTime?> getLastFetchedAt(String base) async {
    final row =
        await (db.select(db.exchangeRates)
              ..where((t) => t.baseCurrency.equals(base.toUpperCase()))
              ..orderBy([(t) => d.OrderingTerm.desc(t.fetchedAt)])
              ..limit(1))
            .getSingleOrNull();
    return row?.fetchedAt;
  }

  Future<List<ExchangeRateOverride>> getOverrides(String base) {
    return (db.select(db.exchangeRateOverrides)
          ..where((t) => t.baseCurrency.equals(base.toUpperCase()))
          ..orderBy([(t) => d.OrderingTerm.asc(t.quoteCurrency)]))
        .get();
  }

  Stream<List<ExchangeRateOverride>> watchOverrides(String base) {
    return (db.select(db.exchangeRateOverrides)
          ..where((t) => t.baseCurrency.equals(base.toUpperCase()))
          ..orderBy([(t) => d.OrderingTerm.asc(t.quoteCurrency)]))
        .watch();
  }

  Future<void> setOverride({
    required String base,
    required String quote,
    required String rate,
  }) async {
    final baseUp = base.toUpperCase();
    final quoteUp = quote.toUpperCase();
    // 写覆盖汇率与登记变更同事务:登记失败时回滚,避免本地已生效但云端漏推。
    await db.transaction(() async {
      final existing =
          await (db.select(db.exchangeRateOverrides)..where(
                (t) =>
                    t.baseCurrency.equals(baseUp) &
                    t.quoteCurrency.equals(quoteUp),
              ))
              .getSingleOrNull();
      final now = DateTime.now().toUtc();
      if (existing == null) {
        final syncId = _uuid.v4();
        final id = await db
            .into(db.exchangeRateOverrides)
            .insert(
              ExchangeRateOverridesCompanion.insert(
                baseCurrency: baseUp,
                quoteCurrency: quoteUp,
                rate: rate,
                syncId: d.Value(syncId),
                updatedAt: d.Value(now),
              ),
            );
        await trackerGetter()?.recordUserGlobalChange(
          entityType: 'exchange_rate_override',
          entityId: id,
          entitySyncId: syncId,
          action: 'create',
        );
      } else {
        final syncId = existing.syncId ?? _uuid.v4();
        await (db.update(
          db.exchangeRateOverrides,
        )..where((t) => t.id.equals(existing.id))).write(
          ExchangeRateOverridesCompanion(
            rate: d.Value(rate),
            syncId: d.Value(syncId),
            updatedAt: d.Value(now),
          ),
        );
        await trackerGetter()?.recordUserGlobalChange(
          entityType: 'exchange_rate_override',
          entityId: existing.id,
          entitySyncId: syncId,
          action: 'update',
        );
      }
    });
  }

  Future<void> removeOverride({
    required String base,
    required String quote,
  }) async {
    // 删除与登记变更同事务:登记失败时回滚,避免本地已删但云端仍持有投影。
    await db.transaction(() async {
      final existing =
          await (db.select(db.exchangeRateOverrides)..where(
                (t) =>
                    t.baseCurrency.equals(base.toUpperCase()) &
                    t.quoteCurrency.equals(quote.toUpperCase()),
              ))
              .getSingleOrNull();
      if (existing == null) return;
      await (db.delete(
        db.exchangeRateOverrides,
      )..where((t) => t.id.equals(existing.id))).go();
      final syncId = existing.syncId;
      if (syncId != null) {
        await trackerGetter()?.recordUserGlobalChange(
          entityType: 'exchange_rate_override',
          entityId: existing.id,
          entitySyncId: syncId,
          action: 'delete',
        );
      }
    });
  }
}
