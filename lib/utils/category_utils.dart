import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'default_category_keys.dart';

/// 分类工具类
/// 负责处理分类名称的显示、翻译等
class CategoryUtils {
  CategoryUtils._();

  /// 分隔符：用于在翻译字符串中分隔多个分类名称
  static const String separator = '-';

  /// 判断分类名称是否为key格式（新系统）
  /// 如果包含下划线或在默认分类列表中，则认为是key
  static bool isCategoryKey(String name) {
    // 包含下划线的肯定是key（如 dining_breakfast）
    if (name.contains('_')) return true;

    // 检查是否在默认分类key列表中（全局仅支出模式）
    return kFlatExpenseCategoryKeys.contains(name) ||
           kHierarchicalExpenseCategories.containsKey(name);
  }

  /// 获取分类的显示名称
  ///
  /// - 如果是key格式（新系统），通过 l10n 翻译
  /// - 否则直接返回分类名称（老用户或自定义分类）
  static String getDisplayName(String? categoryName, BuildContext context, {String kind = 'expense'}) {
    if (categoryName == null || categoryName.isEmpty) {
      return AppLocalizations.of(context).categoryDefaultTitle;
    }

    final l10n = AppLocalizations.of(context);

    // 如果是key格式（新系统），进行翻译
    if (isCategoryKey(categoryName)) {
      return _translateCategoryKey(categoryName, kind, l10n);
    }

    // 直接返回分类名称（老用户或自定义分类）
    return categoryName;
  }

  /// 翻译分类key为显示名称
  static String _translateCategoryKey(String key, String kind, AppLocalizations l10n) {
    // 获取对应的翻译字符串
    final translationString = _getCategoryTranslationString(key, kind, l10n);

    if (translationString.isEmpty) {
      // 如果没有找到翻译，返回key本身
      return key;
    }

    // 解析翻译字符串
    return _parseCategoryName(key, kind, translationString);
  }

  /// 获取分类的翻译字符串
  static String _getCategoryTranslationString(String key, String kind, AppLocalizations l10n) {
    // 全局仅支出模式，kind 恒为 'expense'，因此直接走支出翻译（保留 kind 参数以维持调用签名稳定）
    if (key.contains('_')) {
      // 二级分类：key格式为 parent_child，如 dining_breakfast
      final parts = key.split('_');
      if (parts.length >= 2) {
        final parentKey = parts[0];
        return _getExpenseSubcategoryTranslation(parentKey, l10n);
      }
    } else {
      // 一级分类
      return l10n.categoryExpense;
    }

    return '';
  }

  /// 获取支出类二级分类的翻译字符串
  static String _getExpenseSubcategoryTranslation(String parentKey, AppLocalizations l10n) {
    switch (parentKey) {
      case 'dining': return l10n.categoryExpenseDining;
      case 'snacks': return l10n.categoryExpenseSnacks;
      case 'fruit': return l10n.categoryExpenseFruit;
      case 'beverage': return l10n.categoryExpenseBeverage;
      case 'pastry': return l10n.categoryExpensePastry;
      case 'cooking': return l10n.categoryExpenseCooking;
      case 'shopping': return l10n.categoryExpenseShopping;
      case 'pets': return l10n.categoryExpensePets;
      case 'transport': return l10n.categoryExpenseTransport;
      case 'car': return l10n.categoryExpenseCar;
      case 'clothing': return l10n.categoryExpenseClothing;
      case 'daily_goods': return l10n.categoryExpenseDailyGoods;
      case 'education': return l10n.categoryExpenseEducation;
      case 'invest_loss': return l10n.categoryExpenseInvestLoss;
      case 'entertainment': return l10n.categoryExpenseEntertainment;
      case 'game': return l10n.categoryExpenseGame;
      case 'health_products': return l10n.categoryExpenseHealthProducts;
      case 'subscription': return l10n.categoryExpenseSubscription;
      case 'sports': return l10n.categoryExpenseSports;
      case 'housing': return l10n.categoryExpenseHousing;
      case 'home': return l10n.categoryExpenseHome;
      case 'beauty': return l10n.categoryExpenseBeauty;
      case 'transfer': return l10n.categoryExpenseTransfer;
      default: return '';
    }
  }

  /// 从翻译字符串中解析出对应的分类名称
  ///
  /// 例如：
  /// - key = "dining", kind = "expense", translationString = "餐饮-交通-购物-..." -> "餐饮"
  /// - key = "dining_breakfast", kind = "expense", translationString = "早餐-午餐-晚餐-..." -> "早餐"
  static String _parseCategoryName(String key, String kind, String translationString) {
    final names = translationString.split(separator);

    if (key.contains('_')) {
      // 二级分类：需要找到对应的索引
      final parts = key.split('_');
      if (parts.length >= 2) {
        final parentKey = parts[0];
        final childKey = key; // 完整的key，如 dining_breakfast

        // 获取父分类的子分类列表（全局仅支出模式）
        final childKeys = kHierarchicalExpenseCategories[parentKey] ?? [];

        // 找到当前key在列表中的索引
        final index = childKeys.indexOf(childKey);
        if (index >= 0 && index < names.length) {
          return names[index].trim();
        }
      }
    } else {
      // 一级分类：需要找到对应的索引（全局仅支出模式）
      final keys = kFlatExpenseCategoryKeys;

      final index = keys.indexOf(key);
      if (index >= 0 && index < names.length) {
        return names[index].trim();
      }
    }

    // 如果找不到，返回key本身
    return key;
  }

  /// 获取所有一级分类的显示名称列表（全局仅支出模式）
  static List<String> getAllCategoryDisplayNames(String kind, AppLocalizations l10n) {
    // kind 参数保留用于接口兼容，实际始终使用支出分类
    final translationString = l10n.categoryExpense;

    return translationString.split(separator).map((e) => e.trim()).toList();
  }

  /// 获取指定父分类的所有子分类显示名称列表
  static List<String> getSubcategoryDisplayNames(String parentKey, String kind, AppLocalizations l10n) {
    final translationString = _getCategoryTranslationString('${parentKey}_', kind, l10n);

    if (translationString.isEmpty) {
      return [];
    }

    return translationString.split(separator).map((e) => e.trim()).toList();
  }
}
