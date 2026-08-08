import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class CurrencyInfo {
  final String code;
  final String name;
  const CurrencyInfo(this.code, this.name);
}

/// 货币定义：code + symbol + 英文名（单一数据源）。
/// 英文名来自 ISO 4217 / 汇率源（fawaz currency-api,覆盖全部 146 币),作为
/// 长尾币种的兜底显示名;主流币种另有本地化名覆盖(见 [_buildNameMap])。
/// symbol 长尾币种回退为 code。
class _Cur {
  final String code;
  final String symbol;
  final String enName;
  const _Cur(this.code, this.symbol, this.enName);
}

/// 所有支持的货币（唯一定义处,按地区分组;新增货币只需在此追加一行）。
/// 覆盖 ISO 4217 通行币种,全部在汇率源 fawaz currency-api 有报价。
/// 注意:仅收录有单一主权国家归属的币种——多国/地区共用货币(XAF/XOF/XCD/XPF)
/// 与无单一归属的货币(ANG)不在支持列表中,新增时遵循同一规则。
const List<_Cur> _kCurrencyDefs = [
  // eastAsia
  _Cur('CNY', '¥', 'Chinese Yuan'),
  // JPY 与 CNY 的 ISO 符号同为 ¥,为消除歧义（禁止统一渲染为单一 ¥）,
  // 采用 JP¥ 前缀消歧,与同表 HK$/S$/NT$ 的前缀模式保持一致。
  _Cur('JPY', 'JP¥', 'Japanese Yen'),
  _Cur('KRW', '₩', 'South Korean Won'),
  _Cur('HKD', 'HK\$', 'Hong Kong Dollar'),
  _Cur('TWD', 'NT\$', 'New Taiwan Dollar'),
  _Cur('MOP', 'MOP\$', 'Macau Pataca'),
  _Cur('MNT', '₮', 'Mongolian Tughrik'),
  _Cur('KPW', 'KPW', 'North Korean Won'),
  // southeastAsia
  _Cur('SGD', 'S\$', 'Singapore Dollar'),
  _Cur('MYR', 'RM', 'Malaysian Ringgit'),
  _Cur('THB', '฿', 'Thai Baht'),
  _Cur('IDR', 'Rp', 'Indonesian Rupiah'),
  _Cur('PHP', '₱', 'Philippine Peso'),
  _Cur('VND', '₫', 'Vietnamese Dong'),
  _Cur('MMK', 'K', 'Myanmar Kyat'),
  _Cur('KHR', '៛', 'Cambodian Riel'),
  _Cur('LAK', '₭', 'Lao Kip'),
  _Cur('BND', 'BND', 'Bruneian Dollar'),
  // southAsia
  _Cur('INR', '₹', 'Indian Rupee'),
  _Cur('PKR', '₨', 'Pakistani Rupee'),
  _Cur('BDT', '৳', 'Bangladeshi Taka'),
  _Cur('LKR', 'Rs', 'Sri Lankan Rupee'),
  _Cur('NPR', '₨', 'Nepalese Rupee'),
  _Cur('BTN', 'BTN', 'Bhutanese Ngultrum'),
  _Cur('MVR', 'MVR', 'Maldivian Rufiyaa'),
  _Cur('AFN', 'AFN', 'Afghan Afghani'),
  // centralAsia
  _Cur('KZT', '₸', 'Kazakhstani Tenge'),
  _Cur('UZS', 'UZS', 'Uzbekistani Som'),
  _Cur('TJS', 'TJS', 'Tajikistani Somoni'),
  _Cur('TMT', 'TMT', 'Turkmenistani Manat'),
  _Cur('KGS', 'KGS', 'Kyrgyzstani Som'),
  // middleEast
  _Cur('AED', 'د.إ', 'Emirati Dirham'),
  _Cur('SAR', '﷼', 'Saudi Arabian Riyal'),
  _Cur('ILS', '₪', 'Israeli Shekel'),
  _Cur('TRY', '₺', 'Turkish Lira'),
  _Cur('QAR', '﷼', 'Qatari Riyal'),
  _Cur('KWD', 'د.ك', 'Kuwaiti Dinar'),
  _Cur('BHD', '.د.ب', 'Bahraini Dinar'),
  _Cur('OMR', '﷼', 'Omani Rial'),
  _Cur('JOD', 'د.ا', 'Jordanian Dinar'),
  _Cur('LBP', 'LBP', 'Lebanese Pound'),
  _Cur('IQD', 'IQD', 'Iraqi Dinar'),
  _Cur('IRR', 'IRR', 'Iranian Rial'),
  _Cur('YER', 'YER', 'Yemeni Rial'),
  _Cur('SYP', 'SYP', 'Syrian Pound'),
  _Cur('GEL', '₾', 'Georgian Lari'),
  _Cur('AMD', '֏', 'Armenian Dram'),
  _Cur('AZN', '₼', 'Azerbaijan Manat'),
  // europe
  _Cur('EUR', '€', 'Euro'),
  _Cur('GBP', '£', 'British Pound'),
  _Cur('CHF', 'CHF', 'Swiss Franc'),
  _Cur('SEK', 'kr', 'Swedish Krona'),
  _Cur('NOK', 'kr', 'Norwegian Krone'),
  _Cur('DKK', 'kr', 'Danish Krone'),
  _Cur('PLN', 'zł', 'Polish Zloty'),
  _Cur('CZK', 'Kč', 'Czech Koruna'),
  _Cur('HUF', 'Ft', 'Hungarian Forint'),
  _Cur('RUB', '₽', 'Russian Ruble'),
  _Cur('BYN', 'Br', 'Belarusian Ruble'),
  _Cur('UAH', '₴', 'Ukrainian Hryvnia'),
  _Cur('RON', 'lei', 'Romanian Leu'),
  _Cur('BGN', 'лв', 'Bulgarian Lev'),
  _Cur('RSD', 'RSD', 'Serbian Dinar'),
  _Cur('ISK', 'kr', 'Icelandic Krona'),
  _Cur('MDL', 'MDL', 'Moldovan Leu'),
  _Cur('ALL', 'ALL', 'Albanian Lek'),
  _Cur('MKD', 'MKD', 'Macedonian Denar'),
  _Cur('BAM', 'BAM', 'Bosnian Convertible Mark'),
  _Cur('GIP', 'GIP', 'Gibraltar Pound'),
  // northAmerica
  _Cur('USD', '\$', 'US Dollar'),
  _Cur('CAD', 'C\$', 'Canadian Dollar'),
  _Cur('MXN', 'MX\$', 'Mexican Peso'),
  // centralAmericaCaribbean
  _Cur('GTQ', 'GTQ', 'Guatemalan Quetzal'),
  _Cur('HNL', 'HNL', 'Honduran Lempira'),
  _Cur('NIO', 'NIO', 'Nicaraguan Cordoba'),
  _Cur('CRC', 'CRC', 'Costa Rican Colon'),
  _Cur('PAB', 'PAB', 'Panamanian Balboa'),
  _Cur('DOP', 'DOP', 'Dominican Peso'),
  _Cur('CUP', 'CUP', 'Cuban Peso'),
  _Cur('JMD', 'J\$', 'Jamaican Dollar'),
  _Cur('TTD', 'TT\$', 'Trinidadian Dollar'),
  _Cur('BSD', 'BSD', 'Bahamian Dollar'),
  _Cur('BBD', 'BBD', 'Barbadian or Bajan Dollar'),
  _Cur('BZD', 'BZD', 'Belizean Dollar'),
  _Cur('HTG', 'HTG', 'Haitian Gourde'),
  _Cur('KYD', 'KYD', 'Caymanian Dollar'),
  _Cur('AWG', 'AWG', 'Aruban or Dutch Guilder'),
  _Cur('BMD', 'BMD', 'Bermudian Dollar'),
  // southAmerica
  _Cur('BRL', 'R\$', 'Brazilian Real'),
  _Cur('ARS', '\$', 'Argentine Peso'),
  _Cur('CLP', '\$', 'Chilean Peso'),
  _Cur('COP', '\$', 'Colombian Peso'),
  _Cur('PEN', 'S/', 'Peruvian Sol'),
  _Cur('UYU', '\$U', 'Uruguayan Peso'),
  _Cur('PYG', '₲', 'Paraguayan Guarani'),
  _Cur('BOB', 'Bs', 'Bolivian Bolíviano'),
  _Cur('VES', 'VES', 'Venezuelan Bolívar'),
  _Cur('GYD', 'GYD', 'Guyanese Dollar'),
  _Cur('SRD', 'SRD', 'Surinamese Dollar'),
  // oceania
  _Cur('AUD', 'A\$', 'Australian Dollar'),
  _Cur('NZD', 'NZ\$', 'New Zealand Dollar'),
  _Cur('FJD', 'FJ\$', 'Fijian Dollar'),
  _Cur('PGK', 'PGK', 'Papua New Guinean Kina'),
  _Cur('SBD', 'SBD', 'Solomon Islander Dollar'),
  _Cur('TOP', 'TOP', 'Tongan Pa\'anga'),
  _Cur('VUV', 'VUV', 'Ni-Vanuatu Vatu'),
  _Cur('WST', 'WST', 'Samoan Tala'),
  // africa
  _Cur('ZAR', 'R', 'South African Rand'),
  _Cur('EGP', 'E£', 'Egyptian Pound'),
  _Cur('NGN', '₦', 'Nigerian Naira'),
  _Cur('KES', 'KSh', 'Kenyan Shilling'),
  _Cur('GHS', '₵', 'Ghanaian Cedi'),
  _Cur('MAD', 'DH', 'Moroccan Dirham'),
  _Cur('DZD', 'DZD', 'Algerian Dinar'),
  _Cur('TND', 'TND', 'Tunisian Dinar'),
  _Cur('LYD', 'LYD', 'Libyan Dinar'),
  _Cur('ETB', 'ETB', 'Ethiopian Birr'),
  _Cur('UGX', 'USh', 'Ugandan Shilling'),
  _Cur('TZS', 'TSh', 'Tanzanian Shilling'),
  _Cur('RWF', 'RWF', 'Rwandan Franc'),
  _Cur('MUR', '₨', 'Mauritian Rupee'),
  _Cur('BWP', 'BWP', 'Botswana Pula'),
  _Cur('NAD', 'N\$', 'Namibian Dollar'),
  _Cur('ZMW', 'ZMW', 'Zambian Kwacha'),
  _Cur('MWK', 'MWK', 'Malawian Kwacha'),
  _Cur('MZN', 'MZN', 'Mozambican Metical'),
  _Cur('AOA', 'AOA', 'Angolan Kwanza'),
  _Cur('CDF', 'CDF', 'Congolese Franc'),
  _Cur('GMD', 'GMD', 'Gambian Dalasi'),
  _Cur('GNF', 'GNF', 'Guinean Franc'),
  _Cur('LRD', 'LRD', 'Liberian Dollar'),
  _Cur('SLE', 'SLE', 'Sierra Leonean Leone'),
  _Cur('SDG', 'SDG', 'Sudanese Pound'),
  _Cur('SSP', 'SSP', 'South Sudanese Pound'),
  _Cur('SOS', 'SOS', 'Somali Shilling'),
  _Cur('DJF', 'DJF', 'Djiboutian Franc'),
  _Cur('ERN', 'ERN', 'Eritrean Nakfa'),
  _Cur('BIF', 'BIF', 'Burundian Franc'),
  _Cur('CVE', 'CVE', 'Cape Verdean Escudo'),
  _Cur('STN', 'STN', 'Sao Tomean Dobra'),
  _Cur('SCR', 'SCR', 'Seychellois Rupee'),
  _Cur('KMF', 'KMF', 'Comorian Franc'),
  _Cur('LSL', 'LSL', 'Basotho Loti'),
  _Cur('SZL', 'SZL', 'Swazi Lilangeni'),
  _Cur('MGA', 'MGA', 'Malagasy Ariary'),
  _Cur('MRU', 'MRU', 'Mauritanian Ouguiya'),
];

/// 货币代码列表（自动派生,无需手动维护）
final List<String> kCurrencyCodes =
    _kCurrencyDefs.map((d) => d.code).toList();

/// 常用币种(置顶显示;顺序即展示顺序)。中国用户 + 出境/外贸高频币种。
/// TWD/MOP 紧随 HKD(大中华地区币种聚拢,便于港澳台用户快速选用)。
/// 该列表是币种 picker / 分类管理等多处共用的"完整常用币种"数据源，请勿改动顺序。
const List<String> kCommonCurrencyCodes = [
  'CNY', 'USD', 'EUR', 'JPY', 'HKD', 'TWD', 'MOP', 'GBP', 'KRW', 'AUD', 'CAD',
  'SGD', 'THB',
];

/// 欢迎页币种展示顺序（系统语言相关）。
///
/// 设计意图：新用户打开应用即看到与自身语言环境最相关的币种排在前面，
/// 且默认选中币种固定在第 0 位（由调用方取 [List.first] 作为默认选中项），
/// 解决"系统语言是英文却第一位还是人民币"的错位。
///
/// 规则：每种语言给出 6 个优先级币种（默认置顶 + 区域聚拢），
/// 其余常用币种(来自 [kCommonCurrencyCodes])按原顺序追在后面，
/// 列表仍为完整 13 个、可滚动，仅首屏高度调整为约可见 6 行。
const Map<String, List<String>> _kWelcomPriority = {
  'zh': ['CNY', 'HKD', 'MOP', 'TWD', 'USD', 'EUR'],
  'zh_TW': ['TWD', 'HKD', 'MOP', 'CNY', 'USD', 'EUR'],
  'ko': ['KRW', 'JPY', 'TWD', 'HKD', 'MOP', 'CNY'],
  'en': ['USD', 'GBP', 'EUR', 'CNY', 'HKD', 'TWD'],
};

/// 根据系统语言返回欢迎页币种顺序（共 13 个，前 6 个为语言相关优先级币种）。
///
/// [languageCode] 如 'zh'/'en'/'ko'；[countryCode] 如 'TW'，用于区分繁体中文。
/// 未知语言回退到英语顺序（USD 置顶）。
List<String> welcomeCurrencyOrder(String languageCode, String countryCode) {
  // 繁体中文（台湾）单独成组，其余以 languageCode 直接查表
  final key = languageCode == 'zh' && countryCode == 'TW' ? 'zh_TW' : languageCode;
  final priority = _kWelcomPriority[key] ?? _kWelcomPriority['en']!;
  // 优先级币种在前，其余常用币种保持原顺序追加在后（去重，避免优先级币种重复出现）
  final rest = kCommonCurrencyCodes.where((c) => !priority.contains(c));
  return [...priority, ...rest];
}

/// 对币种列表做统一排序：主币种常驻置顶 + 常用币种按系统语言排序 + 其余按原顺序。
///
/// 设计意图（主币种置顶，并与欢迎页排序口径统一）：
/// 1. [pinned] 中的币种（如账本主币种 rateBase、当前选中值 selected）强制置顶，
///    顺序即传入顺序——主币种应放最前。无论该币种是否常用，都常驻置顶，
///    确保"主币种永远在第一位"。
///    去重处理避免 selected == 主币种 时出现重复项。
/// 2. 常用币种([kCommonCurrencyCodes])按系统语言重排（复用 [welcomeCurrencyOrder]），
///    解决"英文用户首屏第一位还是人民币"的错位，与欢迎页行为一致。
/// 3. 非常用且未置顶的币种，保持 [source] 传入的原始地区顺序追加在最后。
///
/// [locale] 取系统 locale（与欢迎页一致，用 platformDispatcher.locale 而非
/// Localizations.localeOf），以正确区分繁体中文（TW）并避免被应用语言归并到 zh。
List<CurrencyInfo> orderCurrencies(
  List<CurrencyInfo> source,
  Locale locale, {
  List<String> pinned = const [],
}) {
  final commonOrder =
      welcomeCurrencyOrder(locale.languageCode, locale.countryCode ?? '');
  final commonSet = kCommonCurrencyCodes.toSet();
  // 去重并保持传入顺序(主币种优先);即使调用方传入重复码也不会产生重复行。
  final upPins = pinned.map((c) => c.toUpperCase()).toSet().toList();

  final ordered = <CurrencyInfo>[];
  // 1) 置顶的「主币种 / 选中值」（主币种优先，已去重）
  for (final code in upPins) {
    final hit = source.where((c) => c.code == code);
    if (hit.isNotEmpty) ordered.add(hit.first);
  }
  // 2) 常用币种按系统语言排序（与欢迎页一致）
  // 注意:跳过已在置顶区出现的币种,否则常用主币种(如 USD)会既置顶又出现在常用
  // 列表中,导致同一币种出现两条记录(两个勾选态)。
  for (final code in commonOrder) {
    if (upPins.contains(code)) continue;
    final hit = source.where((c) => c.code == code);
    if (hit.isNotEmpty) ordered.add(hit.first);
  }
  // 3) 其余（非常用）币种按地区原顺序追加
  ordered.addAll(source.where(
      (c) => !upPins.contains(c.code) && !commonSet.contains(c.code)));
  return ordered;
}

/// symbol 查找表（自动派生）
final Map<String, String> _symbolMap = {
  for (final d in _kCurrencyDefs) d.code: d.symbol,
};

/// 英文名查找表（自动派生,长尾币种的兜底显示名）
final Map<String, String> _enNameMap = {
  for (final d in _kCurrencyDefs) d.code: d.enName,
};



/// 获取本地化的货币信息列表。
/// 名称优先用本地化覆盖(主流币种,见 [_buildNameMap]),长尾币种回退英文名。
List<CurrencyInfo> getCurrencies(BuildContext context) {
  final overrides = _buildNameMap(context);
  return _kCurrencyDefs
      .map((d) => CurrencyInfo(d.code, overrides[d.code] ?? d.enName))
      .toList();
}

String displayCurrency(String code, BuildContext context) {
  final name = getCurrencyName(code, context);
  return '$name ($code)';
}

/// 获取指定货币代码的本地化名称(无本地化覆盖时回退英文名,再回退 code)。
String getCurrencyName(String code, BuildContext context) {
  final overrides = _buildNameMap(context);
  final upper = code.toUpperCase();
  return overrides[upper] ?? _enNameMap[upper] ?? code;
}

/// 获取币种的英文名(不依赖 context;长尾币种兜底名)。未知 code 回退自身。
String currencyEnglishName(String code) =>
    _enNameMap[code.toUpperCase()] ?? code;

/// 获取币种符号(长尾币种回退为 code)
String getCurrencySymbol(String code) {
  return _symbolMap[code.toUpperCase()] ?? code;
}

/// 汇率换算文案的统一格式化(全局唯一来源)。
///
/// 设计意图:统一各展示点对「1 quote = rate base」的文案输出。picker 弹窗
/// (符号化 / ISO 两分支)、汇率列表、手动编辑弹窗共用此函数,固定
/// 口径为「1 USD = 7.24 CNY」:
///   - 用 ISO 代号(USD / CNY)而非货币符号,规避多币种共用 $ 的歧义(代码里已专门用
///     JP¥ 消歧);不额外包裹括号,与手动编辑弹窗(1 USD = … CNY)视觉一致;
///   - 汇率值按 [ratePrecision] 有效位数格式化,并去掉尾随 0(7.24000 → 7.24),
///     既兼容 JPY 等小数值精度,又避免冗余结尾 0。
///
/// [quote] 报价币种(ISO 4217,大小写不敏感);[base] 基准币种(ISO 4217)。
/// [rate] 汇率字符串,代表「1 quote = rate base」方向;为 null / 空返回占位符。
/// [ratePrecision] 有效位数(默认 6,与汇率列表一致,足以表达 JPY 小数值)。
String formatExchangeRate(
  String quote,
  String base,
  String? rate, {
  int ratePrecision = 6,
}) {
  final q = quote.toUpperCase();
  final b = base.toUpperCase();
  if (rate == null || rate.isEmpty) return '—';
  // 统一精度并去掉尾随 0:既保证 JPY 等小数值精度,又避免「7.24000」这类冗余
  final trimmed = _trimRate(rate, ratePrecision);
  return '1 $q = $trimmed $b';
}

/// 汇率数字:按有效位数格式化并去掉尾随 0(7.24000 → 7.24,0.048000 → 0.048)。
String _trimRate(String rate, int precision) {
  final d = double.tryParse(rate);
  if (d == null) return rate;
  final s = d.toStringAsPrecision(precision);
  if (!s.contains('.')) return s;
  // 先去尾随 0,再去掉因去 0 残留的小数点
  return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

/// l10n 本地化名称覆盖映射(仅主流币种;长尾币种用英文名兜底,无需在此登记)。
Map<String, String> _buildNameMap(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  // 全部币种走 arb(三语);缺翻译由 l10n template(en)兜底为英文。
  return {
    'CNY': l10n.currencyCNY,
    'JPY': l10n.currencyJPY,
    'KRW': l10n.currencyKRW,
    'HKD': l10n.currencyHKD,
    'TWD': l10n.currencyTWD,
    'MOP': l10n.currencyMOP,
    'MNT': l10n.currencyMNT,
    'KPW': l10n.currencyKPW,
    'SGD': l10n.currencySGD,
    'MYR': l10n.currencyMYR,
    'THB': l10n.currencyTHB,
    'IDR': l10n.currencyIDR,
    'PHP': l10n.currencyPHP,
    'VND': l10n.currencyVND,
    'MMK': l10n.currencyMMK,
    'KHR': l10n.currencyKHR,
    'LAK': l10n.currencyLAK,
    'BND': l10n.currencyBND,
    'INR': l10n.currencyINR,
    'PKR': l10n.currencyPKR,
    'BDT': l10n.currencyBDT,
    'LKR': l10n.currencyLKR,
    'NPR': l10n.currencyNPR,
    'BTN': l10n.currencyBTN,
    'MVR': l10n.currencyMVR,
    'AFN': l10n.currencyAFN,
    'KZT': l10n.currencyKZT,
    'UZS': l10n.currencyUZS,
    'TJS': l10n.currencyTJS,
    'TMT': l10n.currencyTMT,
    'KGS': l10n.currencyKGS,
    'AED': l10n.currencyAED,
    'SAR': l10n.currencySAR,
    'ILS': l10n.currencyILS,
    'TRY': l10n.currencyTRY,
    'QAR': l10n.currencyQAR,
    'KWD': l10n.currencyKWD,
    'BHD': l10n.currencyBHD,
    'OMR': l10n.currencyOMR,
    'JOD': l10n.currencyJOD,
    'LBP': l10n.currencyLBP,
    'IQD': l10n.currencyIQD,
    'IRR': l10n.currencyIRR,
    'YER': l10n.currencyYER,
    'SYP': l10n.currencySYP,
    'GEL': l10n.currencyGEL,
    'AMD': l10n.currencyAMD,
    'AZN': l10n.currencyAZN,
    'EUR': l10n.currencyEUR,
    'GBP': l10n.currencyGBP,
    'CHF': l10n.currencyCHF,
    'SEK': l10n.currencySEK,
    'NOK': l10n.currencyNOK,
    'DKK': l10n.currencyDKK,
    'PLN': l10n.currencyPLN,
    'CZK': l10n.currencyCZK,
    'HUF': l10n.currencyHUF,
    'RUB': l10n.currencyRUB,
    'BYN': l10n.currencyBYN,
    'UAH': l10n.currencyUAH,
    'RON': l10n.currencyRON,
    'BGN': l10n.currencyBGN,
    'RSD': l10n.currencyRSD,
    'ISK': l10n.currencyISK,
    'MDL': l10n.currencyMDL,
    'ALL': l10n.currencyALL,
    'MKD': l10n.currencyMKD,
    'BAM': l10n.currencyBAM,
    'GIP': l10n.currencyGIP,
    'USD': l10n.currencyUSD,
    'CAD': l10n.currencyCAD,
    'MXN': l10n.currencyMXN,
    'GTQ': l10n.currencyGTQ,
    'HNL': l10n.currencyHNL,
    'NIO': l10n.currencyNIO,
    'CRC': l10n.currencyCRC,
    'PAB': l10n.currencyPAB,
    'DOP': l10n.currencyDOP,
    'CUP': l10n.currencyCUP,
    'JMD': l10n.currencyJMD,
    'TTD': l10n.currencyTTD,
    'BSD': l10n.currencyBSD,
    'BBD': l10n.currencyBBD,
    'BZD': l10n.currencyBZD,
    'HTG': l10n.currencyHTG,
    'KYD': l10n.currencyKYD,
    'AWG': l10n.currencyAWG,
    'BMD': l10n.currencyBMD,
    'BRL': l10n.currencyBRL,
    'ARS': l10n.currencyARS,
    'CLP': l10n.currencyCLP,
    'COP': l10n.currencyCOP,
    'PEN': l10n.currencyPEN,
    'UYU': l10n.currencyUYU,
    'PYG': l10n.currencyPYG,
    'BOB': l10n.currencyBOB,
    'VES': l10n.currencyVES,
    'GYD': l10n.currencyGYD,
    'SRD': l10n.currencySRD,
    'AUD': l10n.currencyAUD,
    'NZD': l10n.currencyNZD,
    'FJD': l10n.currencyFJD,
    'PGK': l10n.currencyPGK,
    'SBD': l10n.currencySBD,
    'TOP': l10n.currencyTOP,
    'VUV': l10n.currencyVUV,
    'WST': l10n.currencyWST,
    'ZAR': l10n.currencyZAR,
    'EGP': l10n.currencyEGP,
    'NGN': l10n.currencyNGN,
    'KES': l10n.currencyKES,
    'GHS': l10n.currencyGHS,
    'MAD': l10n.currencyMAD,
    'DZD': l10n.currencyDZD,
    'TND': l10n.currencyTND,
    'LYD': l10n.currencyLYD,
    'ETB': l10n.currencyETB,
    'UGX': l10n.currencyUGX,
    'TZS': l10n.currencyTZS,
    'RWF': l10n.currencyRWF,
    'MUR': l10n.currencyMUR,
    'BWP': l10n.currencyBWP,
    'NAD': l10n.currencyNAD,
    'ZMW': l10n.currencyZMW,
    'MWK': l10n.currencyMWK,
    'MZN': l10n.currencyMZN,
    'AOA': l10n.currencyAOA,
    'CDF': l10n.currencyCDF,
    'GMD': l10n.currencyGMD,
    'GNF': l10n.currencyGNF,
    'LRD': l10n.currencyLRD,
    'SLE': l10n.currencySLE,
    'SDG': l10n.currencySDG,
    'SSP': l10n.currencySSP,
    'SOS': l10n.currencySOS,
    'DJF': l10n.currencyDJF,
    'ERN': l10n.currencyERN,
    'BIF': l10n.currencyBIF,
    'CVE': l10n.currencyCVE,
    'STN': l10n.currencySTN,
    'SCR': l10n.currencySCR,
    'KMF': l10n.currencyKMF,
    'LSL': l10n.currencyLSL,
    'SZL': l10n.currencySZL,
    'MGA': l10n.currencyMGA,
    'MRU': l10n.currencyMRU,
  };
}
