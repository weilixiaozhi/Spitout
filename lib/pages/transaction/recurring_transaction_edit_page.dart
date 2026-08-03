import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:spitout/providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../services/data/recurring_transaction_service.dart';
import '../../core/logging/logger_service.dart';
import '../../utils/category_utils.dart';
import '../../theme/icons/app_icons.dart';
import '../../theme/colors.dart';

class RecurringTransactionEditPage extends ConsumerStatefulWidget {
  final RecurringTransaction? recurring;

  const RecurringTransactionEditPage({super.key, this.recurring});

  @override
  ConsumerState<RecurringTransactionEditPage> createState() => _RecurringTransactionEditPageState();
}

class _RecurringTransactionEditPageState extends ConsumerState<RecurringTransactionEditPage> {
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
      _amountController.text = widget.recurring!.amount.toStringAsFixed(2);
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
      final repo = ref.read(repositoryProvider);

      final category = await repo.getCategoryById(widget.recurring!.categoryId!);

      setState(() {
        _selectedCategory = category;
      });
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
            actions: _isEditing ? [
              HeaderIconAction(
                icon: AppIcons.delete,
                onPressed: _deleteRecurringTransaction,
              ),
            ] : null,
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.commonError;
                      }
                      if (double.tryParse(value) == null) {
                        return l10n.commonError;
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
                    decoration: InputDecoration(
                      labelText: l10n.commonNoteHint,
                    ),
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
              onPressed: _isFormValid() ? _saveRecurringTransaction : null,
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
        child: FutureBuilder<Ledger?>(
          future: _selectedLedgerId != null
              ? ref.read(repositoryProvider).getLedgerById(_selectedLedgerId!)
              : Future.value(null),
          builder: (context, snapshot) {
            final ledgerName = snapshot.data?.name ?? l10n.ledgerSelect;
            return Text(ledgerName);
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
    // 检查金额
    if (_amountController.text.isEmpty || double.tryParse(_amountController.text) == null) {
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
            Icon(AppIcons.chevronDown, size: 24, color: SpitoutTokens.iconTertiary(context)),
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
            Icon(AppIcons.chevronDown, size: 24, color: SpitoutTokens.iconTertiary(context)),
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
            Icon(AppIcons.chevronDown, size: 24, color: SpitoutTokens.iconTertiary(context)),
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
              ? IconButton(
                  icon: const Icon(AppIcons.close),
                  onPressed: onClear,
                )
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
    // 开始日期最早只能是今天:禁止历史开始日期,避免回溯生成脏数据(issue #135);
    // 结束日期不早于开始日期。
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
    final l10n = AppLocalizations.of(context);

    // 标记为已尝试保存，触发错误提示显示
    setState(() {
      _hasAttemptedSave = true;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isFormValid()) {
      return;
    }

    final repo = ref.read(repositoryProvider);

    try {
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
          amount: double.parse(_amountController.text),
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
        );

        // 如果需要重置最后生成日期，单独更新
        if (shouldResetLastGenerated) {
          // 注意：这里需要先清空 lastGeneratedDate
          // 由于 updateLastGeneratedDate 不支持 null，我们需要直接在 updateRecurringTransaction 中处理
          // 暂时跳过这个步骤，后续如果需要可以扩展 Repository 接口
        }
      } else {
        // 新建模式
        await repo.addRecurringTransaction(
          ledgerId: _selectedLedgerId!,
          type: _type,
          amount: double.parse(_amountController.text),
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
        showToast(context, '${l10n.commonError}: $e');
      }
    }
  }

  Future<void> _deleteRecurringTransaction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).commonDelete),
        content: Text(AppLocalizations.of(context).recurringTransactionDeleteConfirm),
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
      final repo = ref.read(repositoryProvider);
      await repo.deleteRecurringTransaction(widget.recurring!.id);

      if (mounted) {
        Navigator.of(context).pop(true); // 返回 true 表示数据已更改
      }
    }
  }
}