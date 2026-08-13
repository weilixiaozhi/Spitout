import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/typography.dart';
import 'package:spitout/utils/file_picker_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/utils/currency/currencies.dart';
import 'package:spitout/widgets/widgets.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/theme/colors.dart';

/// 首次启动欢迎页面
///
/// 引导流程为单屏：币种选择（默认跟随系统语言选中对应币种）。
/// 点击完成后静默 seed 混合层次分类（一级+二级并存），不让用户选择分类模式；
/// flat / hierarchical 两套清单作为模板库常量，可在「分类管理 → 模板库」中挑选添加。
///
/// 语言默认跟随系统，不单独设页选择；用户可在「设置 → 语言」中手动切换。
/// 应用首次启动时的欢迎页（新用户引导）。
///
/// 职责：让用户选择"记账货币"并完成首次进入的初始化（创建默认账本/分类模板）。
/// 采用"始终创建默认账本 + 混合层次分类模板"，保证首次启动后记账流程开箱即用；
/// seed 流程无关闭默认账本的开关。
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  /// 欢迎页币种列表首屏可见行数（约 6 行，其余滚动查看，不改滚动逻辑）
  static const double _kWelcomeRowHeight = 54.0;
  static const int _kWelcomeVisibleRows = 6;
  static const double _kWelcomeListPeek = 8.0; // 让第 7 行微微露出，提示可滚动

  String _selectedCurrency = 'CNY'; // 默认货币（initState 中按系统语言修正）
  late List<String> _currencyOrder; // 按系统语言定制的 13 币种顺序（首项是默认选中）
  // 无"创建默认账本"开关：默认账本由 seed 流程无条件预置。
  bool _isInitializing = false; // 初始化状态
  bool _isImporting = false; // 导入状态

  @override
  void initState() {
    super.initState();
    // 根据系统语言推导币种顺序，默认选中项 = 顺序首项，
    // 保证"选中的币种一定排在第一位"（如英文→USD 置顶）。
    _currencyOrder = _systemCurrencyOrder();
    _selectedCurrency = _currencyOrder.first;
  }

  /// 读取系统 locale 推导欢迎页币种顺序（默认选中项恒为首项）。
  ///
  /// 设计意图：让列表首行即用户最可能使用的币种（与系统语言相关），
  /// 且默认选中项 = 顺序首项，消除"语言是英文却第一位还是人民币"的错位。
  /// 读取 Flutter 侧的 platformDispatcher.locale（生产环境即系统语言，
  /// 测试环境可通过 localeTestValue 注入，保证用例确定性）。
  List<String> _systemCurrencyOrder() {
    try {
      // platformDispatcher.locale 格式如 zh_CN / en_US / ko_KR
      final locale = WidgetsBinding.instance.platformDispatcher.locale;
      final parts = locale.toString().split('_');
      final languageCode = parts.isNotEmpty ? parts[0] : 'en';
      final countryCode = parts.length > 1 ? parts[1] : '';
      return welcomeCurrencyOrder(languageCode, countryCode);
    } catch (_) {
      // 获取系统 locale 失败时回退到英语顺序
      return welcomeCurrencyOrder('en', '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // 新用户流程：单屏（币种选择），点击完成即静默初始化
    return Scaffold(
      backgroundColor: SpitoutTokens.scaffoldBackground(context),
      body: SafeArea(
        child: Column(
          children: [
            // 页面内容：币种选择屏
            Expanded(child: _buildCurrencyPage(context, l10n)),

            // 底部按钮区域：仅"完成"
            Padding(
              padding: const EdgeInsets.all(SpitoutDimens.p20),
              child: Row(
                children: [
                  const Spacer(),
                  FilledButton(
                    onPressed: _isInitializing
                        ? null
                        : () => _finishWelcome(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: SpitoutTokens.buttonPrimary(context),
                      foregroundColor: SpitoutTokens.buttonPrimaryText(context),
                    ),
                    child: _isInitializing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.commonFinish),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 第1屏：货币选择
  ///
  /// 布局：LOGO → 标题 → 币种列表(Expanded) → 底部描述文案 → 老用户导入入口 → 创建默认账本复选框
  Widget _buildCurrencyPage(BuildContext context, AppLocalizations l10n) {
    // 首次引导仅展示常用币种(13 个,按系统语言定制的顺序：前 6 个为语言相关优先级)。
    // 146 个全量列表对新用户选择负担过重;长尾币种可进应用后在
    // 「汇率 → 币种管理」中启用。仍保持可滚动，仅首屏高度调整为约可见 6 行。
    final all = getCurrencies(context);
    final currencies = <CurrencyInfo>[
      for (final code in _currencyOrder) ...all.where((c) => c.code == code),
    ];

    // 外层包 LayoutBuilder + SingleChildScrollView：在矮屏(如测试视口)下避免整页溢出；
    // 列表本身仍按固定高度(约 6 行)内部滚动展示 13 个币种。
    // 设计意图：用 ConstrainedBox 让内容在可用高度内垂直居中，解决“内容太靠上、
    // 下方留白过多”的问题——整体下移居中，logo/标题/列表/描述在可用高度内均衡展示。
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p20),
              // 垂直居中：整体内容下移，logo/标题/列表/描述在可用高度内居中
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: SpitoutDimens.p20),

                  // 品牌 LOGO（SVG 自带配色，不需主题色参数）
                  // 放大展示：图标 72 → 120、容器 96 → 160，提升首屏品牌辨识度与视觉重心
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: Center(child: SpitoutIcon(size: 120)),
                  ),
                  const SizedBox(height: 28),

                  // 标题：选择记账货币
                  Text(
                    l10n.welcomeSelectCurrencyTitle,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: SpitoutTokens.textPrimary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SpitoutDimens.p16),

                  // 首屏列表高度固定为约 6 行，保证"刚好能看到 6 个币种"；
                  // 仍是完整 13 个、可滚动，仅限制可视区域高度（不改变滚动逻辑）。
                  // 列表铺满横向宽度：父级 Column 为 stretch 会拉伸全宽，无需 Center 包裹，
                  // 也不限制 maxWidth，列表直接占满可用宽度。
                  Container(
                    width: double.infinity,
                    height:
                        _kWelcomeVisibleRows * _kWelcomeRowHeight +
                        _kWelcomeListPeek,
                    decoration: BoxDecoration(
                      color: SpitoutTokens.surface(context),
                      borderRadius: BorderRadius.circular(SpitoutDimens.radius12),
                    ),
                    child: ListView.separated(
                      key: const Key('currencyListView'), // 供测试精准定位币种列表
                      itemCount: currencies.length,
                      separatorBuilder: (context, index) =>
                          SpitoutTokens.cardDivider(context, indent: 0),
                      itemBuilder: (context, index) {
                        final currency = currencies[index];
                        final isSelected = _selectedCurrency == currency.code;

                        // 固定行高，使首屏"刚好可见 6 行"的高度精确可控
                        return SizedBox(
                          height: _kWelcomeRowHeight,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCurrency = currency.code;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: SpitoutDimens.p16,
                                vertical: SpitoutDimens.p12,
                              ),
                              child: Row(
                                children: [
                                  // 单选框：选中用主题色，未选用次要图标色（保留 Radio）
                                  Icon(
                                    isSelected
                                        ? AppIcons.radioChecked
                                        : AppIcons.radioUnchecked,
                                    color: isSelected
                                        ? SpitoutTokens.primary(context)
                                        : SpitoutTokens.iconSecondary(context),
                                    size: SpitoutDimens.icon22,
                                  ),
                                  const SizedBox(width: SpitoutDimens.p12),

                                  // 与币种选择弹窗同一布局：固定宽度符号列 + 名称 (ISO) 左对齐。
                                  // 符号长短不一（¥ 与 HK$），固定列宽保证名称列
                                  // 在所有行中对齐到同一 x 位置。
                                  currencySymbolColumn(
                                    currency.code,
                                    style: SpitoutTextTokens.title(context).copyWith(color: SpitoutTokens.textSecondary(
                                        context,
                                      )),
                                  ),
                                  // 与弹窗 ListTile 的图标-文字间距（horizontalTitleGap=16）一致
                                  const SizedBox(width: SpitoutDimens.p16),

                                  // 「名称 (ISO)」展示，例：人民币 (CNY)。
                                  // 用 Expanded 提供有界宽度，溢出以省略号收尾。
                                  Expanded(
                                    child: Text(
                                      '${currency.name} (${currency.code})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: SpitoutTextTokens.title(context).copyWith(color: SpitoutTokens.textPrimary(
                                          context,
                                        ),
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // 列表下方间距压缩 10px 让给列表区（列表 Expanded 因此加长 10px）
                  const SizedBox(height: SpitoutDimens.p4),

                  // 底部描述文案：选择您常用的货币，之后可以随时在设置中更改
                  Text(
                    l10n.welcomeCurrencyDescription,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SpitoutTokens.textSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: SpitoutDimens.p12),

                  // 导入配置入口（紧凑样式）
                  TextButton(
                    onPressed: _isImporting
                        ? null
                        : () => _importConfig(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isImporting)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            AppIcons.fileUpload,
                            size: SpitoutDimens.icon16,
                            color: SpitoutTokens.textLink(context),
                          ),
                        const SizedBox(width: SpitoutDimens.p4),
                        Text(
                          _isImporting
                              ? l10n.welcomeImportingConfig
                              : '${l10n.welcomeExistingUserTitle} ${l10n.welcomeExistingUserButton}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: SpitoutTokens.textLink(context),
                              ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: SpitoutDimens.p8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 完成欢迎页面
  ///
  /// 流程：保存偏好 → 创建默认账本+分类模板(ensureSeed) → 预加载首页数据 → 进入首页。
  ///
  /// 关键设计：所有耗时操作（建库 seed + 首屏数据预加载）都在本方法内完成，
  /// 期间「完成」按钮保持 loading 态（_isInitializing=true）。
  /// welcome_shown 必须在 seed 与账本选中全部成功后才写入，否则初始化失败
  /// 时重启会跳过欢迎页，用户进入残缺的空库且没有任何错误提示。
  /// 任一步失败都会走 catch 弹友好错误并保持欢迎页，允许用户重试。
  Future<void> _finishWelcome(BuildContext context) async {
    // 设置初始化状态：按钮立即切换为 loading 转圈，并禁用重复点击
    setState(() {
      _isInitializing = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      // 保存用户选择的货币（完成标记放到数据就绪之后统一写入）
      await prefs.setString('selected_currency', _selectedCurrency);

      // 初始化数据库（使用用户选择的语言和设置）
      if (context.mounted) {
        logger.info('welcome', '开始初始化数据库');
        logger.info('welcome', '货币: $_selectedCurrency');
        logger.info('welcome', '分类: 混合层次模板(静默创建)');

        final l10n = AppLocalizations.of(context);

        // 第一步：固定 seed 混合层次分类（一级+二级并存），并始终创建默认账本。
        // seed 入口在 services 层（经 ensureSeedProvider 门面），数据层 db 不
        // 反向依赖种子服务。
        await ref.read(ensureSeedProvider)(
          l10n: l10n,
          currency: _selectedCurrency,
        );

        logger.info('welcome', '数据库初始化完成');

        // 第二步：显式选中刚 seed 出的默认账本并写回 prefs。
        // 不能依赖 currentLedgerPersistProvider 的启动解析——它的 IIFE 在
        // main() 预加载阶段已对「空数据库」跑过一次且不会重跑，此刻若不显式
        // 选中，currentLedgerId 会停在哨兵 0，首页误判「无账本」空状态。
        await selectFirstLedger(ref.read);
        logger.info('welcome', '已选中默认账本');

        // 第三步：重新执行启屏预加载（appSplashInitProvider）。
        // 设计意图：appSplashInitProvider 在 main() 启动阶段已针对「空数据库」跑过一遍，
        // 预加载结果为空/陈旧。此处 seed 完成后 invalidate 触发重跑，使其针对已建好
        // 账本与分类的数据库重新预加载首屏数据（月度统计、交易列表、周期交易生成等）。
        // 等待其完成后再进入首页，保证首页首帧即有数据、可立即交互。
        logger.info('welcome', '开始预加载首页数据');
        try {
          ref.invalidate(appSplashInitProvider);
          await ref.read(appSplashInitProvider.future);
          logger.info('welcome', '首页数据预加载完成');
        } catch (e, st) {
          // 预加载失败不阻塞进入首页：首页各 provider 进入后仍会按需加载，
          // 仅体验略慢，不致功能缺失。
          logger.error('welcome', '首页数据预加载失败，将进入首页按需加载', e, st);
        }
      }

      // 数据全部就绪后才标记完成，保证下次启动不会跳过未完成的初始化。
      if (context.mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('welcome_shown', true);
        if (context.mounted) {
          // 触发重新构建进入主应用；此时首屏数据已预加载，首页可立即渲染。
          ref.read(shouldShowWelcomeProvider.notifier).set(false);
        }
      }
    } catch (e, st) {
      logger.error('welcome', '首次初始化失败', e, st);
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        await AppDialog.error(
          context,
          title: l10n.commonFailed,
          message: l10n.commonOperationFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  /// 导入配置文件（老用户）
  Future<void> _importConfig(BuildContext context) async {
    final l10n = AppLocalizations.of(context);

    setState(() {
      _isImporting = true;
    });

    try {
      // 选择文件（使用 FilePickerHelper 处理部分设备不支持扩展名过滤的情况）
      final result = await FilePickerHelper.pickYamlFile();

      if (result == null || result.files.isEmpty) {
        if (context.mounted) {
          showToast(context, l10n.welcomeImportNoFile);
        }
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        if (context.mounted) {
          showToast(context, l10n.welcomeImportNoFile);
        }
        return;
      }

      // 读取文件内容
      final file = File(filePath);
      final yamlContent = await file.readAsString();

      logger.info('welcome', '开始导入配置文件');

      // 导入配置
      await importConfigFromYaml(ref, yamlContent, ExportOptions.all);

      logger.info('welcome', '配置文件导入成功');

      // 不自动创建默认账本 — 即使配置不含账本也尊重用户意图(可能就是想从
      // 空状态开始)。没账本时进入应用,LedgersPage 空态会引导新建。
      final repo = ref.read(repositoryProvider);
      final ledgers = await repo.getAllLedgers();
      logger.info('welcome', '配置包含 ${ledgers.length} 个账本');

      // 导入配置后显式选中首个账本（与 _finishWelcome 同理：启动阶段的
      // 持久化解析 IIFE 已对空库跑过且不会重跑，必须在此显式选中）。
      // 配置不含账本时 selectFirstLedger 内部直接返回，保持哨兵 0 的
      // 真空状态，仍由 LedgersPage 空态引导新建，不改变既有产品语义。
      await selectFirstLedger(ref.read);

      // 刷新所有配置相关的 providers，使导入的配置立即生效
      ref.invalidate(themeModeInitProvider);
      ref.invalidate(languageProvider);

      // 重新执行启屏预加载（appSplashInitProvider），与 _finishWelcome 保持一致。
      // 设计意图：appSplashInitProvider 在 main() 启动阶段针对「空数据库」跑过一遍，
      // 预加载结果为空/陈旧。导入配置后账本/分类/周期账单已写入数据库，此处 invalidate
      // 触发重跑，使其针对导入后的数据重新预加载首屏数据（月度统计、交易列表、周期交易生成等）。
      // 等待其完成后再进入首页，保证首页首帧即有数据、可立即交互，
      // 避免「进首页后静默加载导致前几秒卡顿」。
      logger.info('welcome', '开始预加载首页数据');
      try {
        ref.invalidate(appSplashInitProvider);
        await ref.read(appSplashInitProvider.future);
        logger.info('welcome', '首页数据预加载完成');
      } catch (e, st) {
        // 预加载失败不阻塞进入首页：首页各 provider 进入后仍会按需加载，
        // 仅体验略慢，不致功能缺失。
        logger.error('welcome', '首页数据预加载失败，将进入首页按需加载', e, st);
      }

      // 导入与预加载均完成后才标记欢迎页面完成，避免中途失败后重启跳过欢迎页。
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('welcome_shown', true);

      if (context.mounted) {
        showToast(context, l10n.welcomeImportSuccess);
        // 直接完成导入流程，不引导附件导入
        ref.read(shouldShowWelcomeProvider.notifier).set(false);
      }
    } catch (e, st) {
      logger.error('welcome', '导入配置文件失败', e, st);
      if (context.mounted) {
        showToast(
          context,
          l10n.welcomeImportFailed(l10n.commonOperationFailed),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }
}
