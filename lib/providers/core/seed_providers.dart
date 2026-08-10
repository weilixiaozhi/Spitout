import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/l10n/app_localizations.dart';

import 'package:spitout/services/data/seed_service.dart';
import 'database_providers.dart';

/// 首次初始化种子服务的 provider 门面。
///
/// 设计意图：页面只依赖 providers 层；SeedService 是纯静态服务，
/// 通过函数型 provider 暴露，便于测试替换。
final ensureSeedProvider =
    Provider<Future<void> Function({AppLocalizations? l10n, String currency})>((
      ref,
    ) {
      return ({AppLocalizations? l10n, String currency = 'CNY'}) =>
          SeedService.ensureSeed(
            ref.read(databaseProvider),
            l10n: l10n,
            currency: currency,
          );
    });
