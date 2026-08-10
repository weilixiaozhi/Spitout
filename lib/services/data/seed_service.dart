import 'dart:ui' show Locale;

import 'package:spitout/data/db.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/utils/default_category_keys.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// 种子数据服务
/// 负责生成应用初始化时的默认数据（账本、账户、分类等）
class SeedService {
  SeedService._();

  /// 首次初始化入口（原 `SpitoutDatabase.ensureSeed`，为拆除 db↔seed
  /// 循环依赖而上移到本服务；行为与日志输出保持不变）。
  ///
  /// [l10n] 国际化对象，如果为null则使用英文作为默认语言
  /// [currency] 货币代码
  ///
  /// 分类固定创建混合层次模板（一级+二级并存），无模式开关。
  /// 默认账本始终创建，无开关参数。
  /// 注意：此方法只应在真正的首次初始化时调用（欢迎页完成时）
  static Future<void> ensureSeed(
    SpitoutDatabase db, {
    AppLocalizations? l10n,
    String currency = 'CNY',
  }) async {
    logger.info('db', 'ensureSeed 被调用');
    logger.info('db', 'l10n 是否提供: ${l10n != null}');
    logger.info('db', '货币: $currency');

    // 如果没有提供l10n，使用Lookup创建默认的英文版本
    final effectiveL10n = l10n ?? lookupAppLocalizations(const Locale('en'));
    logger.info('db', '使用的语言环境: ${l10n != null ? "提供的l10n" : "默认英文"}');

    await SeedService.seedDatabase(
      db,
      effectiveL10n,
      currency: currency,
    );
    logger.info('db', '数据库初始化完成');
  }

  /// 固定命名空间,给默认 seed 数据生成**确定性** syncId(uuid v5)。
  /// ⚠️ 不要改这个常量 —— 改了会让同一份默认数据在新老版本算出不同 syncId,
  /// 反而制造重复。
  static const _seedSyncNamespace = 'b3e7c0de-0000-4000-8000-beec00000001';
  static const _seedUuid = Uuid();

  /// 默认分类的确定性 syncId。key 用**稳定的 seed key**(不是翻译后的名字),
  /// 这样任何设备、任何语言 seed 出来的同一个默认分类都得到同一个 syncId,
  /// 云端按 syncId 天然只留一份 —— 从源头杜绝多设备各自 seed 造成的重复。
  /// 收敛存量重复时的 keeper 规则见 data/repositories/entity_dedup.dart。
  static String deterministicCategorySyncId({
    required String kind,
    required int level,
    required String key,
  }) =>
      _seedUuid.v5(_seedSyncNamespace, 'cat:$kind:$level:$key');

  // ========== 一级/二级默认分类 key ==========

  /// 默认支出分类 key 列表（一级分类模式）。
  ///
  /// 定义于 utils/default_category_keys.dart（纯常量）——utils 层
  /// CategoryUtils 需按 key 取下标翻译，若由本服务直接持有会形成
  /// utils → services 上行依赖。此处 const 转发。
  static const List<String> flatExpenseCategoryKeys = kFlatExpenseCategoryKeys;

  /// 二级分类模式的默认支出分类（父分类 -> 子分类列表）。定义位置同上。
  static const Map<String, List<String>> hierarchicalExpenseCategories =
      kHierarchicalExpenseCategories;

  // ========== 混合层次分类模板（hybridhierarchy，新注册默认创建）==========

  /// 混合层次模板：按展示顺序定义的有序分类清单。
  ///
  /// 设计意图：把「独立一级」与「父子组」合并为单一有序列表，使二者可交错
  /// 排列。`children == null` 表示独立一级分类，否则为父子组（父 + 其子分类列表）。
  ///
  /// 顺序即新注册用户的默认分类 sortOrder（一级全局递增，二级在父内从 0 起）。
  /// ⚠️ 父 key 与子 key 都必须存在于 hierarchicalExpenseCategories：
  /// getTranslatedSubCategoryName 按 key 在 hierarchical map 中的真实下标取翻译，
  /// 查不到会 fallback 成 snake_case key；独立一级 key 必须存在于
  /// flatExpenseCategoryKeys（getTranslatedCategoryName 按下标取翻译）。
  static const List<({String key, List<String>? children})> hybridCategoryTemplate = [
    (key: 'dining', children: ['dining_breakfast', 'dining_lunch', 'dining_dinner']),
    (key: 'beverage', children: ['beverage_milk_tea', 'beverage_coffee', 'beverage_juice', 'beverage_soda', 'beverage_water']),
    (key: 'shopping', children: ['shopping_supermarket', 'shopping_clothing', 'shopping_shoes', 'shopping_bag']),
    (key: 'transport', children: ['transport_transitcard', 'transport_taxi', 'transport_parking', 'transport_fuel']),
    // 通讯：独立一级分类（话费/网费等），模板库 flat 清单已有该 key，翻译/图标直接复用
    (key: 'communication', children: null),
    (key: 'fruit', children: null),
    (key: 'snacks', children: null),
    (key: 'sports', children: null),
    (key: 'pets', children: ['pets_food', 'pets_supplies', 'pets_medical', 'pets_grooming']),
    (key: 'housing', children: ['housing_utilities', 'housing_property', 'housing_rent', 'housing_mortgage', 'housing_broadband']),
    (key: 'transfer', children: ['transfer_livingcost', 'transfer_family', 'transfer_parents', 'transfer_lover', 'transfer_borrowmoney']),
    (key: 'subscription', children: ['subscription_video', 'subscription_music']),
    (key: 'entertainment', children: ['entertainment_movie', 'entertainment_ktv', 'entertainment_amusement']),
    (key: 'education', children: ['education_books', 'education_learning']),
    (key: 'gift', children: null),
    (key: 'game', children: null),
    (key: 'beauty', children: ['beauty_skincare', 'beauty_cosmetics', 'beauty_salon', 'beauty_nail']),
    (key: 'medical', children: null),
    (key: 'digital', children: null),
    (key: 'other', children: null),
  ];

  // ========== 分类图标映射 ==========

  /// 获取分类的默认图标（Lucide 图标名，须存在于 lucideIconLibrary）
  /// 注意：这里只提供默认图标，不做名称匹配
  static String getDefaultIcon(String categoryKey) {
    // 支出分类图标（值均为 Lucide 图标名，与 app_icons.dart 注册表一致）
    const expenseIcons = {
      // 一级分类
      'dining': 'utensils',
      'transport': 'bus',
      'shopping': 'shoppingCart',
      'entertainment': 'partyPopper',
      'home': 'home',
      'family': 'users',
      'communication': 'phone',
      'utilities': 'zap',
      'housing': 'building2',
      'medical': 'cross',
      'education': 'graduationCap',
      'pets': 'dog',
      'sports': 'dumbbell',
      'digital': 'smartphone',
      'travel': 'plane',
      'alcohol_tobacco': 'beer',
      'baby_care': 'baby',
      'beauty': 'sparkles',
      'repair': 'wrench',
      'social': 'users2',
      'learning': 'library',
      'car': 'car',
      // Lucide 无出租车专用图标，以汽车近似
      'taxi': 'car',
      // Lucide 无地铁专用图标，以火车近似
      'subway': 'train',
      'delivery': 'bike',
      'property': 'building',
      'parking': 'parkingCircle',
      'donation': 'heartHandshake',
      'gift': 'gift',
      'tax': 'receipt',
      'beverage': 'milk',
      'clothing': 'shirt',
      'snacks': 'lollipop',
      'red_packet': 'wallet',
      'fruit': 'apple',
      'pastry': 'cake',
      'cooking': 'chefHat',
      'game': 'gamepad2',
      'book': 'bookOpen',
      'invest_loss': 'trendingDown',
      'health_products': 'pill',
      'subscription': 'calendarClock',
      'lover': 'heart',
      'decoration': 'paintbrush',
      'daily_goods': 'package',
      'lottery': 'ticket',
      'stock': 'trendingUp',
      'social_security': 'shieldCheck',
      'express': 'truck',
      'work': 'briefcase',
      // 兜底独立一级分类「其他」
      'other': 'package',

      // 餐饮二级分类
      'dining_breakfast': 'sandwich',
      'dining_lunch': 'salad',
      'dining_dinner': 'soup',
      'dining_meituan': 'bike',
      'dining_eleme': 'bike',
      'dining_jd': 'bike',
      'dining_restaurant': 'utensils',
      'dining_food': 'pizza',

      // 零食二级分类
      'snacks_biscuit': 'cookie',
      'snacks_chips': 'popcorn',
      'snacks_candy': 'candy',
      'snacks_chocolate': 'candy',
      'snacks_nuts': 'wheat',

      // 水果二级分类
      'fruit_apple': 'apple',
      'fruit_banana': 'banana',
      'fruit_orange': 'citrus',
      'fruit_grape': 'grape',
      // Lucide 无西瓜图标，以圆形水果柑橘近似
      'fruit_watermelon': 'citrus',
      'fruit_other': 'cherry',

      // 饮品二级分类
      'beverage_milk_tea': 'cupSoda',
      'beverage_coffee': 'coffee',
      'beverage_juice': 'glassWater',
      'beverage_soda': 'beer',
      'beverage_water': 'glassWater',

      // 糕点二级分类
      'pastry_cake': 'cakeSlice',
      'pastry_bread': 'croissant',
      'pastry_dessert': 'iceCream',
      'pastry_biscuit': 'cookie',

      // 做饭食材二级分类
      'cooking_vegetable': 'carrot',
      'cooking_meat': 'beef',
      'cooking_seafood': 'fish',
      // Lucide 无调料图标，以汤品近似（同属厨房烹饪）
      'cooking_seasoning': 'soup',
      'cooking_grain': 'wheat',

      // 购物二级分类
      'shopping_supermarket': 'shoppingCart',
      'shopping_clothing': 'shirt',
      // Lucide 无鞋子图标，以脚印近似
      'shopping_shoes': 'footprints',
      'shopping_bag': 'shoppingBag',
      'shopping_daily': 'shoppingCart',

      // 宠物二级分类
      'pets_food': 'bone',
      'pets_supplies': 'boxes',
      'pets_medical': 'stethoscope',
      'pets_grooming': 'showerHead',

      // 交通二级分类
      'transport_transitcard': 'walletCards',
      'transport_taxi': 'car',
      'transport_parking': 'parkingCircle',
      'transport_fuel': 'fuel',

      // 汽车二级分类
      'car_maintenance': 'hammer',
      'car_repair': 'wrench',
      'car_insurance': 'shield',
      'car_wash': 'droplets',
      'car_fine': 'alertTriangle',

      // 服饰二级分类
      'clothing_top': 'shirt',
      // Lucide 无裤子图标，以上衣近似
      'clothing_pants': 'shirt',
      'clothing_skirt': 'sparkle',
      'clothing_shoes': 'footprints',
      'clothing_accessory': 'watch',

      // 日用品二级分类
      'daily_toiletries': 'sprayCan',
      'daily_paper': 'scroll',
      'daily_cleaning': 'brush',
      'daily_kitchen': 'refrigerator',

      // 教育二级分类
      'education_tuition': 'graduationCap',
      'education_training': 'presentation',
      'education_books': 'bookOpen',
      'education_stationery': 'pencil',
      'education_office': 'briefcase',
      'education_learning': 'library',

      // 投资亏损二级分类
      'invest_loss_stock': 'trendingDown',
      'invest_loss_fund': 'lineChart',
      'invest_loss_other': 'banknote',

      // 娱乐二级分类
      'entertainment_movie': 'clapperboard',
      'entertainment_ktv': 'mic',
      'entertainment_amusement': 'ferrisWheel',
      'entertainment_bar': 'martini',
      'entertainment_other': 'partyPopper',

      // 游戏二级分类
      'game_recharge': 'coins',
      'game_equipment': 'headphones',
      'game_membership': 'crown',

      // 保健品二级分类
      'health_vitamin': 'pill',
      'health_food': 'salad',
      'health_nutrition': 'heartPulse',

      // 订阅服务二级分类
      'subscription_video': 'playCircle',
      'subscription_music': 'music',
      'subscription_cloud': 'cloud',
      'subscription_other': 'repeat',

      // 转账一级与二级分类
      'transfer': 'handCoins',
      'transfer_livingcost': 'heartHandshake',
      'transfer_family': 'users',
      'transfer_parents': 'users2',
      'transfer_lover': 'heart',
      'transfer_borrowmoney': 'coins',

      // 运动二级分类
      'sports_gym': 'dumbbell',
      'sports_equipment': 'medal',
      'sports_course': 'target',
      'sports_outdoor': 'mountain',

      // 住房二级分类
      'housing_utilities': 'zap',
      'housing_rent': 'key',
      'housing_property': 'building',
      'housing_mortgage': 'landmark',
      'housing_decoration': 'paintbrush',
      // 宽带使用 wifi 图标（Lucide 无宽带专用图标，wifi 语义最贴近）
      'housing_broadband': 'wifi',

      // 居家二级分类
      'home_furniture': 'sofa',
      'home_appliance': 'tv',
      'home_decor': 'palette',
      'home_bedding': 'bed',

      // 美容二级分类
      'beauty_skincare': 'smile',
      'beauty_cosmetics': 'palette',
      'beauty_salon': 'scissors',
      'beauty_nail': 'hand',
    };

    return expenseIcons[categoryKey] ?? 'category';
  }

  // ========== 种子数据生成方法 ==========

  /// 生成默认账本
  static Future<int> createDefaultLedger(
    SpitoutDatabase db,
    AppLocalizations l10n,
    String currency,
  ) async {
    final ledgerId = await db.into(db.ledgers).insert(
      LedgersCompanion.insert(
        name: l10n.ledgerDefaultName,
        currency: Value(currency),
      ),
    );
    return ledgerId;
  }

  /// 获取翻译后的分类名称（用于一级分类模式）
  /// 公开原因：模板库页面（category_template_logic）按 key 取同一翻译。
  static String getTranslatedCategoryName(
    String key,
    String kind,
    AppLocalizations l10n,
  ) {
    final translationString = l10n.categoryExpenseList; // 全局仅支出模式，kind 值固定为 expense
    final names = translationString.split('-');
    final keys = flatExpenseCategoryKeys;

    final index = keys.indexOf(key);
    if (index >= 0 && index < names.length) {
      final name = names[index].trim();
      // 多语言清单缺段时回退到 key，避免创建空名分类。
      if (name.isNotEmpty) return name;
    }

    return key; // fallback
  }

  /// 获取翻译后的父分类名称（用于二级分类模式）
  /// 公开原因：模板库页面（category_template_logic）按 key 取同一翻译。
  static String getTranslatedParentCategoryName(
    String key,
    String kind,
    AppLocalizations l10n,
  ) {
    // 全局仅支出模式，kind 值固定为 expense，直接 switch expense 分支
    switch (key) {
      case 'dining': return l10n.categoryExpenseDining.split('-')[0].trim();
      case 'snacks': return l10n.categoryExpenseSnacks.split('-')[0].trim();
      case 'fruit': return l10n.categoryExpenseFruit.split('-')[0].trim();
      case 'beverage': return l10n.categoryExpenseBeverage.split('-')[0].trim();
      case 'pastry': return l10n.categoryExpensePastry.split('-')[0].trim();
      case 'cooking': return l10n.categoryExpenseCooking.split('-')[0].trim();
      case 'shopping': return l10n.categoryExpenseShopping.split('-')[0].trim();
      case 'pets': return l10n.categoryExpensePets.split('-')[0].trim();
      case 'transport': return l10n.categoryExpenseTransport.split('-')[0].trim();
      case 'car': return l10n.categoryExpenseCar.split('-')[0].trim();
      case 'clothing': return l10n.categoryExpenseClothing.split('-')[0].trim();
      case 'daily_goods': return l10n.categoryExpenseDailyGoods.split('-')[0].trim();
      case 'education': return l10n.categoryExpenseEducation.split('-')[0].trim();
      case 'invest_loss': return l10n.categoryExpenseInvestLoss.split('-')[0].trim();
      case 'entertainment': return l10n.categoryExpenseEntertainment.split('-')[0].trim();
      case 'game': return l10n.categoryExpenseGame.split('-')[0].trim();
      case 'health_products': return l10n.categoryExpenseHealthProducts.split('-')[0].trim();
      case 'subscription': return l10n.categoryExpenseSubscription.split('-')[0].trim();
      case 'sports': return l10n.categoryExpenseSports.split('-')[0].trim();
      case 'housing': return l10n.categoryExpenseHousing.split('-')[0].trim();
      case 'home': return l10n.categoryExpenseHome.split('-')[0].trim();
      case 'beauty': return l10n.categoryExpenseBeauty.split('-')[0].trim();
      case 'transfer': return l10n.categoryExpenseTransfer.split('-')[0].trim();
      default: return key;
    }
  }

  /// 获取翻译后的子分类名称
  /// 公开原因：模板库页面（category_template_logic）按 key 取同一翻译。
  static String getTranslatedSubCategoryName(
    String key,
    String kind,
    AppLocalizations l10n,
  ) {
    // 全局仅支出模式，直接从支出分类 map 查找父分类
    final categoryMap = hierarchicalExpenseCategories;

    String? parentKey;
    for (final entry in categoryMap.entries) {
      if (entry.value.contains(key)) {
        parentKey = entry.key;
        break;
      }
    }

    if (parentKey == null) return key;

    // 获取父分类的翻译字符串
    String translationString;
    switch (parentKey) {
      case 'dining': translationString = l10n.categoryExpenseDining; break;
      case 'snacks': translationString = l10n.categoryExpenseSnacks; break;
      case 'fruit': translationString = l10n.categoryExpenseFruit; break;
      case 'beverage': translationString = l10n.categoryExpenseBeverage; break;
      case 'pastry': translationString = l10n.categoryExpensePastry; break;
      case 'cooking': translationString = l10n.categoryExpenseCooking; break;
      case 'shopping': translationString = l10n.categoryExpenseShopping; break;
      case 'pets': translationString = l10n.categoryExpensePets; break;
      case 'transport': translationString = l10n.categoryExpenseTransport; break;
      case 'car': translationString = l10n.categoryExpenseCar; break;
      case 'clothing': translationString = l10n.categoryExpenseClothing; break;
      case 'daily_goods': translationString = l10n.categoryExpenseDailyGoods; break;
      case 'education': translationString = l10n.categoryExpenseEducation; break;
      case 'invest_loss': translationString = l10n.categoryExpenseInvestLoss; break;
      case 'entertainment': translationString = l10n.categoryExpenseEntertainment; break;
      case 'game': translationString = l10n.categoryExpenseGame; break;
      case 'health_products': translationString = l10n.categoryExpenseHealthProducts; break;
      case 'subscription': translationString = l10n.categoryExpenseSubscription; break;
      case 'sports': translationString = l10n.categoryExpenseSports; break;
      case 'housing': translationString = l10n.categoryExpenseHousing; break;
      case 'home': translationString = l10n.categoryExpenseHome; break;
      case 'beauty': translationString = l10n.categoryExpenseBeauty; break;
      case 'transfer': translationString = l10n.categoryExpenseTransfer; break;
      default: return key;
    }

    final names = translationString.split('-');
    final childKeys = hierarchicalExpenseCategories[parentKey] ?? [];

    final index = childKeys.indexOf(key);
    // names[0] is parent name, child names start from names[1]
    if (index >= 0 && index + 1 < names.length) {
      return names[index + 1].trim();
    }

    return key; // fallback
  }

  /// 生成默认分类（一级分类模式）
  /// 全局仅支出模式：只创建支出分类，不创建收入分类
  static Future<void> createFlatCategories(SpitoutDatabase db, AppLocalizations l10n) async {
    // 创建支出分类
    for (var i = 0; i < flatExpenseCategoryKeys.length; i++) {
      final key = flatExpenseCategoryKeys[i];
      final translatedName = getTranslatedCategoryName(key, 'expense', l10n);

      logger.info('seed_service', '创建支出分类: key=$key, name=$translatedName');

      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: translatedName, // 使用翻译后的名称
          kind: 'expense',
          icon: Value(getDefaultIcon(key)),
          sortOrder: Value(i),
          level: const Value(1),
          syncId: Value(
              deterministicCategorySyncId(kind: 'expense', level: 1, key: key)),
        ),
      );
    }
  }

  /// 生成默认分类（二级分类模式）
  static Future<void> createHierarchicalCategories(SpitoutDatabase db, AppLocalizations l10n) async {
    // 创建支出分类
    var sortOrder = 0;
    for (final entry in hierarchicalExpenseCategories.entries) {
      final parentKey = entry.key;
      final childKeys = entry.value;

      final parentTranslatedName = getTranslatedParentCategoryName(parentKey, 'expense', l10n);
      logger.info('seed_service', '创建支出父分类: key=$parentKey, name=$parentTranslatedName');

      // 创建父分类
      final parentId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: parentTranslatedName, // 使用翻译后的名称
          kind: 'expense',
          icon: Value(getDefaultIcon(parentKey)),
          sortOrder: Value(sortOrder++),
          level: const Value(1),
          syncId: Value(deterministicCategorySyncId(
              kind: 'expense', level: 1, key: parentKey)),
        ),
      );

      // 创建子分类
      for (var i = 0; i < childKeys.length; i++) {
        final childKey = childKeys[i];
        final childTranslatedName = getTranslatedSubCategoryName(childKey, 'expense', l10n);

        logger.info('seed_service', '创建支出子分类: key=$childKey, name=$childTranslatedName');

        await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: childTranslatedName, // 使用翻译后的名称
            kind: 'expense',
            icon: Value(getDefaultIcon(childKey)),
            sortOrder: Value(i),
            level: const Value(2),
            parentId: Value(parentId),
            syncId: Value(deterministicCategorySyncId(
                kind: 'expense', level: 2, key: childKey)),
          ),
        );
      }
    }
  }

  /// 生成默认分类（混合层次模式：一级 + 二级并存）
  ///
  /// 新注册静默创建的唯一分类清单（欢迎页无分类模式选择屏）。
  /// 遍历 [hybridCategoryTemplate] 单一有序清单：`children == null` 创建独立一级，
  /// 否则创建父分类并挂接其子分类。一级 sortOrder 全局递增，二级 sortOrder 在
  /// 父内从 0 起。syncId 全部走确定性 UUID，与模板库"已添加"判定共用同一套标识。
  static Future<void> createHybridCategories(SpitoutDatabase db, AppLocalizations l10n) async {
    var sortOrder = 0;

    for (final entry in hybridCategoryTemplate) {
      final key = entry.key;
      final children = entry.children;

      if (children == null) {
        // 独立一级分类：翻译复用 flat 清单（getTranslatedCategoryName 按下标取）
        final translatedName = getTranslatedCategoryName(key, 'expense', l10n);
        logger.info('seed_service', '创建支出分类(混合/一级): key=$key, name=$translatedName');

        await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: translatedName,
            kind: 'expense',
            icon: Value(getDefaultIcon(key)),
            sortOrder: Value(sortOrder++),
            level: const Value(1),
            syncId: Value(
                deterministicCategorySyncId(kind: 'expense', level: 1, key: key)),
          ),
        );
      } else {
        // 父子组：先插父拿 parentId，再插子
        final parentTranslatedName =
            getTranslatedParentCategoryName(key, 'expense', l10n);
        logger.info('seed_service', '创建支出父分类(混合): key=$key, name=$parentTranslatedName');

        final parentId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: parentTranslatedName,
            kind: 'expense',
            icon: Value(getDefaultIcon(key)),
            sortOrder: Value(sortOrder++),
            level: const Value(1),
            syncId: Value(deterministicCategorySyncId(
                kind: 'expense', level: 1, key: key)),
          ),
        );

        for (var i = 0; i < children.length; i++) {
          final childKey = children[i];
          final childTranslatedName =
              getTranslatedSubCategoryName(childKey, 'expense', l10n);
          logger.info('seed_service', '创建支出子分类(混合): key=$childKey, name=$childTranslatedName');

          await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: childTranslatedName,
              kind: 'expense',
              icon: Value(getDefaultIcon(childKey)),
              sortOrder: Value(i),
              level: const Value(2),
              parentId: Value(parentId),
              syncId: Value(deterministicCategorySyncId(
                  kind: 'expense', level: 2, key: childKey)),
            ),
          );
        }
      }
    }
  }

  /// 完整的种子数据初始化
  ///
  /// [l10n] 国际化对象，用于获取翻译后的名称
  /// [currency] 默认货币代码（如 'CNY', 'USD'）
  ///
  /// 分类固定创建混合层次模板（一级 + 二级并存）；flat / hierarchical
  /// 两套清单仅作为代码常量的模板库数据源，不在 seed 阶段写库。
  /// 默认账本始终创建，无开关参数。
  static Future<void> seedDatabase(
    SpitoutDatabase db,
    AppLocalizations l10n, {
    String currency = 'CNY',
  }) async {
    logger.info('seed', '开始初始化数据库');
    logger.info('seed', '货币: $currency');
    logger.info('seed', '账本名称: ${l10n.ledgerDefaultName}');

    // 1. 始终创建默认账本，保证首次启动后开箱即用
    final ledgerId = await SeedService.createDefaultLedger(db, l10n, currency);
    logger.info('seed', '已创建账本 ID: $ledgerId');

    // 2. 创建默认分类（固定混合层次模板）
    await createHybridCategories(db, l10n);
    logger.info('seed', '已创建混合层次分类');

    logger.info('seed', '数据库初始化完成');
  }
}


