import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/widgets/widgets.dart';
import 'package:spitout/data/models.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/utils/category_utils.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/theme/colors.dart';

class RecurringTransactionEditPage extends ConsumerStatefulWidget {
  final RecurringTransaction? recurring;

  const RecurringTransactionEditPage({super.key, this.recurring});

  @override
  ConsumerState<RecurringTransactionEditPage> createState() =>
      _RecurringTransactionEditPageState();
}

class _RecurringTransactionEditPageState
    extends ConsumerState<RecurringTransactionEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late String _type;
  late RecurringFrequency _frequency;
  late int _interval;
  late DateTime _startDate;
  DateTime? _endDate;
  int? _dayOfMonth;
  Category? _selectedCategory;
  // 无账户选择，无 _selectedAccountId 字段
  late bool _enabled;
  bool _hasAttemptedSave = false; // 是否已尝试保存
  int? _selectedLedgerId; // 选中的账本ID
  bool _saving = false; // 保存进行中,防止连点重复建单/更新
  bool _deleting = false; // 删除进行中,防止连点

  bool get _isEditing => widget.recurring != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _type = widget.recurring!.type;
      _frequency = RecurringFrequency.fromString(widget.recurring!.frequency);
      _interval = widget.recurring!.interval;
      _startDate = widget.recurring!.startDate;
      _endDate = widget.recurring!.endDate;
      _dayOfMonth = widget.recurring!.dayOfMonth;
      _enabled = widget.recurring!.enabled;
      _selectedLedgerId = widget.recurring!.ledgerId;
      _amountController.text = (widget.recurring!.amount / 100).toStringAsFixed(
        2,
      );
      _noteController.text = widget.recurring!.note ?? '';
      _loadCategory();
    } else {
      _type = 'expense';
      _frequency = RecurringFrequency.monthly;
      _interval = 1;
      _startDate = DateTime.now();
      _dayOfMonth = DateTime.now().day;
      _enabled = true;
      // 新建时使用当前账本
      _selectedLedgerId = ref.read(currentLedgerIdProvider);
    }

    // 监听金额输入变化，更新按钮状态
    _amountController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _loadCategory() async {
    if (_isEditing && widget.recurring!.categoryId != null) {
      try {
        final repo = ref.read(repositoryProvider);
        final category = await repo.getCategoryById(
          widget.recurring!.categoryId!,
        );
        // 加载期间页面可能已销毁,且分类被删除时返回 null 无需回填。
        if (!mounted || category == null) return;
        setState(() {
          _selectedCategory = category;
        });
      } catch (e, st) {
        logger.warning('周期账单编辑', '加载分类失败', '$e\n$st');
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: _isEditing
                ? l10n.recurringTransactionEdit
                : l10n.recurringTransactionAdd,
            showBack: true,
            actions: _isEditing
                ? [
                    HeaderIconAction(
                      icon: AppIcons.delete,
                      onPressed: _deleteRecurringTransaction,
                    ),
                  ]
                : null,
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 全局仅支出模式，交易类型恒为支出（_type 固定为 'expense'）
                  const SizedBox(height: 16),

                  // Ledger selection
                  _buildLedgerSelector(l10n),
                  const SizedBox(height: 16),

                  // Amount
                  TextFormField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: l10n.importFieldAmount,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.commonError;
                      }
                      final cents = _parseAmountToCents(value);
                      if (cents == null || cents <= 0) {
                        return l10n.recurringTransactionAmountInvalid;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Category selection
                  _buildCategorySelector(l10n),
                  const SizedBox(height: 16),

                  // Frequency
                  _buildFrequencySelector(l10n),
                  const SizedBox(height: 16),

                  // Interval
                  if (_frequency != RecurringFrequency.daily)
                    _buildIntervalSelector(l10n),
                  if (_frequency != RecurringFrequency.daily)
                    const SizedBox(height: 16),

                  // Day of month (for monthly)
                  if (_frequency == RecurringFrequency.monthly)
                    _buildDayOfMonthSelector(l10n),
                  if (_frequency == RecurringFrequency.monthly)
                    const SizedBox(height: 16),

                  // Start date
                  _buildDateField(
                    label: l10n.recurringTransactionStartDate,
                    date: _startDate,
                    onTap: () => _selectDate(context, true),
                  ),
                  const SizedBox(height: 16),

                  // End date
                  _buildDateField(
                    label: l10n.recurringTransactionEndDate,
                    date: _endDate,
                    onTap: () => _selectDate(context, false),
                    allowClear: true,
                    onClear: () => setState(() => _endDate = null),
                  ),
                  const SizedBox(height: 16),

                  // Note
                  TextFormField(
                    controller: _noteController,
                    decoration: InputDecoration(labelText: l10n.commonNoteHint),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),

          // 底部保存按钮
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _isFormValid() && !_saving
                  ? _saveRecurringTransaction
                  : null,
              child: Text(l10n.commonSave),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(AppLocalizations l10n) {
    return InkWell(
      onTap: () => _selectCategory(),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.categoryTitle,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          errorText: _getCategoryErrorText(),
        ),
        child: Text(
          _selectedCategory != null
              ? CategoryUtils.getDisplayName(_selectedCategory!.name, context)
              : l10n.commonSearch,
        ),
      ),
    );
  }

  Widget _buildLedgerSelector(AppLocalizations l10n) {
    return InkWell(
      onTap: () => _selectLedger(),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.ledgerSelectTitle,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          errorText: _getLedgerErrorText(),
        ),
        child: Builder(
          builder: (context) {
            // 账本名走 FutureProvider.family 缓存,避免每次 build 重新查库。
            final ledgerName = _selectedLedgerId == null
                ? null
                : ref.watch(ledgerByIdProvider(_selectedLedgerId!)).value?.name;
            return Text(ledgerName ?? l10n.ledgerSelect);
          },
        ),
      ),
    );
  }

  String? _getLedgerErrorText() {
    if (!_hasAttemptedSave) return null;
    if (_selectedLedgerId == null) {
      return '请选择账本';
    }
    return null;
  }

  String? _getCategoryErrorText() {
    if (!_hasAttemptedSave) return null;
    if (_selectedCategory == null) {
      return '请选择分类';
    }
    return null;
  }

  bool _isFormValid() {
    // 检查金额:必须能解析且大于 0,0/负数周期账单无意义。
    final cents = _parseAmountToCents(_amountController.text);
    if (cents == null || cents <= 0) {
      return false;
    }

    // 检查账本
    if (_selectedLedgerId == null) {
      return false;
    }

    // 检查分类
    if (_selectedCategory == null) {
      return false;
    }

    return true;
  }

  Widget _buildFrequencySelector(AppLocalizations l10n) {
    String frequencyLabel;
    switch (_frequency) {
      case RecurringFrequency.daily:
        frequencyLabel = l10n.recurringTransactionDaily;
        break;
      case RecurringFrequency.weekly:
        frequencyLabel = l10n.recurringTransactionWeekly;
        break;
      case RecurringFrequency.monthly:
        frequencyLabel = l10n.recurringTransactionMonthly;
        break;
      case RecurringFrequency.yearly:
        frequencyLabel = l10n.recurringTransactionYearly;
        break;
    }

    return InkWell(
      onTap: () async {
        final result = await showWheelPicker<RecurringFrequency>(
          context,
          initial: _frequency,
          items: RecurringFrequency.values,
          labelBuilder: (freq) {
            switch (freq) {
              case RecurringFrequency.daily:
                return l10n.recurringTransactionDaily;
              case RecurringFrequency.weekly:
                return l10n.recurringTransactionWeekly;
              case RecurringFrequency.monthly:
                return l10n.recurringTransactionMonthly;
              case RecurringFrequency.yearly:
                return l10n.recurringTransactionYearly;
            }
          },
          title: l10n.recurringTransactionFrequency,
        );

        if (result != null) {
          setState(() {
            _frequency = result;
            if (_frequency == RecurringFrequency.daily) {
              _interval = 1;
            }
          });
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.recurringTransactionFrequency,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(frequencyLabel),
            Icon(
              AppIcons.chevronDown,
              size: 24,
              color: SpitoutTokens.iconTertiary(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalSelector(AppLocalizations l10n) {
    String intervalLabel;
    switch (_frequency) {
      case RecurringFrequency.daily:
        intervalLabel = l10n.recurringTransactionEveryNDays(_interval);
        break;
      case RecurringFrequency.weekly:
        intervalLabel = l10n.recurringTransactionEveryNWeeks(_interval);
        break;
      case RecurringFrequency.monthly:
        intervalLabel = l10n.recurringTransactionEveryNMonths(_interval);
        break;
      case RecurringFrequency.yearly:
        intervalLabel = l10n.recurringTransactionEveryNYears(_interval);
        break;
    }

    return InkWell(
      onTap: () async {
        final result = await showWheelPicker<int>(
          context,
          initial: _interval,
          items: List.generate(12, (index) => index + 1),
          labelBuilder: (i) {
            switch (_frequency) {
              case RecurringFrequency.daily:
                return l10n.recurringTransactionEveryNDays(i);
              case RecurringFrequency.weekly:
                return l10n.recurringTransactionEveryNWeeks(i);
              case RecurringFrequency.monthly:
                return l10n.recurringTransactionEveryNMonths(i);
              case RecurringFrequency.yearly:
                return l10n.recurringTransactionEveryNYears(i);
            }
          },
          title: l10n.recurringTransactionInterval,
        );

        if (result != null) {
          setState(() {
            _interval = result;
          });
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.recurringTransactionInterval,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(intervalLabel),
            Icon(
              AppIcons.chevronDown,
              size: 24,
              color: SpitoutTokens.iconTertiary(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayOfMonthSelector(AppLocalizations l10n) {
    return InkWell(
      onTap: () async {
        final result = await showWheelPicker<int>(
          context,
          initial: _dayOfMonth ?? 1,
          items: List.generate(31, (index) => index + 1),
          labelBuilder: (day) => '$day',
          title: l10n.recurringTransactionDayOfMonth,
        );

        if (result != null) {
          setState(() {
            _dayOfMonth = result;
          });
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.recurringTransactionDayOfMonth,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${_dayOfMonth ?? 1}'),
            Icon(
              AppIcons.chevronDown,
              size: 24,
              color: SpitoutTokens.iconTertiary(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    bool allowClear = false,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          suffixIcon: allowClear && date != null
              ? IconButton(icon: const Icon(AppIcons.close), onPressed: onClear)
              : null,
        ),
        child: Text(
          date != null
              ? DateFormat.yMd().format(date)
              : AppLocalizations.of(context).recurringTransactionNoEndDate,
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    // 开始日期最早只能是今天,禁止历史开始日期,避免回溯补生成;
    // 结束日期选择器以开始日期为下限。
    final minDate = isStartDate ? todayStart : _startDate;
    var initial = isStartDate ? _startDate : (_endDate ?? _startDate);
    if (initial.isBefore(minDate)) initial = minDate;

    final date = await showWheelDatePicker(
      context,
      initial: initial,
      minDate: minDate,
      maxDate: DateTime(2100),
    );

    if (date != null) {
      if (!context.mounted) return;
      // 先设结束日、再改开始日时,新开始日可能晚于结束日,这里阻断,
      // 保证区间始终合法(start <= end)。
      if (isStartDate && _endDate != null && date.isAfter(_endDate!)) {
        showToast(
          context,
          AppLocalizations.of(context).recurringTransactionEndBeforeStart,
        );
        return;
      }
      setState(() {
        if (isStartDate) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
    }
  }

  Future<void> _selectLedger() async {
    if (!mounted) return;

    final selected = await showLedgerSelector(
      context,
      currentLedgerId: _selectedLedgerId,
    );

    if (selected != null) {
      setState(() {
        _selectedLedgerId = selected;
      });
    }
  }

  Future<void> _selectCategory() async {
    if (!mounted) return;

    final selected = await showCategorySelector(
      context,
      type: _type,
      currentCategoryId: _selectedCategory?.id,
    );

    if (selected != null) {
      setState(() {
        _selectedCategory = selected;
      });
    }
  }

  Future<void> _saveRecurringTransaction() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);

    // 标记为已尝试保存，触发错误提示显示
    setState(() {
      _hasAttemptedSave = true;
      _saving = true;
    });

    try {
      if (!_formKey.currentState!.validate()) {
        return;
      }

      if (!_isFormValid()) {
        return;
      }

      // 最终兜底:结束日期不能早于开始日期(选择器已尽量防,这里拦截
      // 任何绕过路径,避免生成 start > end 的非法周期)。
      if (_endDate != null && _endDate!.isBefore(_startDate)) {
        showToast(context, l10n.recurringTransactionEndBeforeStart);
        return;
      }

      // 金额直接按字符串解析成分,不经 double 中间态,避免超大金额
      // 精度损失与 1e309 等极端输入在 round() 抛异常。
      final amountCents = _parseAmountToCents(_amountController.text);
      if (amountCents == null) {
        showToast(context, l10n.recurringTransactionAmountInvalid);
        return;
      }

      final repo = ref.read(repositoryProvider);
      if (_isEditing) {
        // 编辑模式：检查是否需要重置 lastGeneratedDate
        bool shouldResetLastGenerated = false;
        if (widget.recurring!.lastGeneratedDate != null &&
            _startDate.isBefore(widget.recurring!.lastGeneratedDate!)) {
          shouldResetLastGenerated = true;
          logger.info('周期账单', '开始日期早于最后生成日期，重置 lastGeneratedDate');
        }

        await repo.updateRecurringTransaction(
          id: widget.recurring!.id,
          ledgerId: _selectedLedgerId!,
          type: _type,
          amount: amountCents,
          categoryId: _selectedCategory!.id,

          note: _noteController.text.isEmpty ? null : _noteController.text,
          frequency: _frequency.value,
          interval: _interval,
          dayOfMonth: _dayOfMonth,
          dayOfWeek: null,
          monthOfYear: null,
          startDate: _startDate,
          endDate: _endDate,
          enabled: _enabled,
          clearLastGeneratedDate: shouldResetLastGenerated,
        );
      } else {
        // 新建模式
        await repo.addRecurringTransaction(
          ledgerId: _selectedLedgerId!,
          type: _type,
          amount: amountCents,
          categoryId: _selectedCategory!.id,

          note: _noteController.text.isEmpty ? null : _noteController.text,
          frequency: _frequency.value,
          interval: _interval,
          dayOfMonth: _dayOfMonth,
          dayOfWeek: null,
          monthOfYear: null,
          startDate: _startDate,
          endDate: _endDate,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true); // 返回 true 表示数据已更改
      }
    } catch (e, stackTrace) {
      // 使用 logger 记录详细错误信息
      logger.error('周期账单保存', '保存失败', e, stackTrace);
      if (mounted) {
        showToast(context, l10n.commonOperationFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteRecurringTransaction() async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).commonDelete),
        content: Text(
          AppLocalizations.of(context).recurringTransactionDeleteConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      _deleting = true;
      final l10n = AppLocalizations.of(context);
      try {
        final repo = ref.read(repositoryProvider);
        await repo.deleteRecurringTransaction(widget.recurring!.id);

        if (mounted) {
          Navigator.of(context).pop(true); // 返回 true 表示数据已更改
        }
      } catch (e, stackTrace) {
        // 删除失败不冒泡:记录日志并提示用户重试。
        logger.error('周期账单删除', '删除失败', e, stackTrace);
        if (mounted) {
          showToast(context, l10n.commonOperationFailed);
        }
      } finally {
        _deleting = false;
      }
    }
  }

  /// 把用户输入的金额字符串解析为整数分。
  ///
  /// 设计意图:直接按字符串解析(整数 + 最多两位小数),不经过 double
  /// 中间态,避免超大金额精度损失;格式非法(含科学计数法等)返回 null。
  int? _parseAmountToCents(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return null;
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
    if (match == null) return null;
    try {
      final yuan = int.parse(match.group(1)!);
      final frac = match.group(2) ?? '';
      return yuan * 100 + int.parse(frac.padRight(2, '0'));
    } on FormatException {
      // 超出 int64 范围等极端输入按非法处理,不抛到 UI。
      return null;
    }
  }
}
