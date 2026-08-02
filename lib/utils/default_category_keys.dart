/// 默认分类 key 常量（纯数据，零依赖）。
///
/// 设计意图：这两份清单同时被 services 层（SeedService 建种子数据）与
/// utils 层（CategoryUtils 按 key 取下标翻译）使用，故定义为纯常量文件，
/// 两方各自 import。SeedService 以同名 const 转发（`SeedService.flatExpenseCategoryKeys`）。
library;

/// 默认支出分类 key 列表（一级分类模式）
const List<String> kFlatExpenseCategoryKeys = [
  'dining', 'transport', 'shopping', 'entertainment', 'home', 'family',
  'communication', 'utilities', 'housing', 'medical', 'education',
  'pets', 'sports', 'digital', 'travel', 'alcohol_tobacco', 'baby_care',
  'beauty', 'repair', 'social', 'learning', 'car', 'taxi', 'subway',
  'delivery', 'property', 'parking', 'donation', 'gift', 'tax',
  'beverage', 'clothing', 'snacks', 'red_packet', 'fruit', 'game',
  'book', 'lover', 'decoration', 'daily_goods', 'lottery', 'stock',
  'social_security', 'express', 'work', 'transfer', 'other'
];

/// 二级分类模式的默认支出分类（父分类 -> 子分类列表）
const Map<String, List<String>> kHierarchicalExpenseCategories = {
  'dining': ['dining_breakfast', 'dining_lunch', 'dining_dinner', 'dining_meituan', 'dining_eleme', 'dining_jd', 'dining_restaurant', 'dining_food'],
  'snacks': ['snacks_biscuit', 'snacks_chips', 'snacks_candy', 'snacks_chocolate', 'snacks_nuts'],
  'fruit': ['fruit_apple', 'fruit_banana', 'fruit_orange', 'fruit_grape', 'fruit_watermelon', 'fruit_other'],
  'beverage': ['beverage_milk_tea', 'beverage_coffee', 'beverage_juice', 'beverage_soda', 'beverage_water'],
  'pastry': ['pastry_cake', 'pastry_bread', 'pastry_dessert', 'pastry_biscuit'],
  'cooking': ['cooking_vegetable', 'cooking_meat', 'cooking_seafood', 'cooking_seasoning', 'cooking_grain'],
  // 购物子分类顺序：超市→日用百货→服装→鞋子→包包（与 arb categoryExpenseShopping 段序一一对应）
  'shopping': ['shopping_supermarket', 'shopping_daily', 'shopping_clothing', 'shopping_shoes', 'shopping_bag'],
  'pets': ['pets_food', 'pets_supplies', 'pets_medical', 'pets_grooming'],
  // 交通子分类：交通卡充值→打车→停车费→加油
  'transport': ['transport_transitcard', 'transport_taxi', 'transport_parking', 'transport_fuel'],
  // 转账子分类：生活费→家庭→父母→恋人→借钱
  'transfer': ['transfer_livingcost', 'transfer_family', 'transfer_parents', 'transfer_lover', 'transfer_borrowmoney'],
  'car': ['car_maintenance', 'car_repair', 'car_insurance', 'car_wash', 'car_fine'],
  'clothing': ['clothing_top', 'clothing_pants', 'clothing_skirt', 'clothing_shoes', 'clothing_accessory'],
  'daily_goods': ['daily_toiletries', 'daily_paper', 'daily_cleaning', 'daily_kitchen'],
  'education': ['education_tuition', 'education_training', 'education_books', 'education_stationery', 'education_office', 'education_learning'],
  'invest_loss': ['invest_loss_stock', 'invest_loss_fund', 'invest_loss_other'],
  'entertainment': ['entertainment_movie', 'entertainment_ktv', 'entertainment_amusement', 'entertainment_bar', 'entertainment_other'],
  'game': ['game_recharge', 'game_equipment', 'game_membership'],
  'health_products': ['health_vitamin', 'health_food', 'health_nutrition'],
  'subscription': ['subscription_video', 'subscription_music', 'subscription_cloud', 'subscription_other'],
  'sports': ['sports_gym', 'sports_equipment', 'sports_course', 'sports_outdoor'],
  // housing 子类顺序（水电煤→物业费→房租→房贷→装修→宽带），
  // 与 4 个 arb 的 categoryExpenseHousing 翻译串顺序严格一一对应，改动需三处同步。
  // 注：住宅下无「通讯」子分类，由「宽带」承担其职能。
  'housing': ['housing_utilities', 'housing_property', 'housing_rent', 'housing_mortgage', 'housing_decoration', 'housing_broadband'],
  'home': ['home_furniture', 'home_appliance', 'home_decor', 'home_bedding'],
  'beauty': ['beauty_skincare', 'beauty_cosmetics', 'beauty_salon', 'beauty_nail'],
};
