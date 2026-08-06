import 'package:flutter/material.dart';
import '../theme/icons/app_icons.dart';
import '../theme/colors.dart';

typedef SearchableDropdownItemBuilder<T> = Widget Function(T item);
typedef SearchableDropdownFilter<T> = bool Function(T item, String query);
typedef SearchableDropdownLabelExtractor<T> = String Function(T item);

class SearchableDropdown<T> extends StatefulWidget {
  final List<T> items;
  final T? value;
  final ValueChanged<T?> onChanged;
  final SearchableDropdownItemBuilder<T> itemBuilder;
  final SearchableDropdownFilter<T> filter;
  final SearchableDropdownLabelExtractor<T> labelExtractor;
  final String hintText;
  final bool enabled;
  final Widget? prefixIcon;
  
  const SearchableDropdown({
    super.key,
    required this.items,
    required this.onChanged,
    required this.itemBuilder,
    required this.filter,
    required this.labelExtractor,
    this.value,
    this.hintText = '请选择',
    this.enabled = true,
    this.prefixIcon,
  });
  
  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  late TextEditingController _searchController;
  late FocusNode _focusNode;
  // 锚点链接：浮层经 CompositedTransformFollower 跟随触发框，滚动 / 键盘 /
  // 方向变化时自动跟随，不依赖打开瞬间的静态坐标。
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  
  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _focusNode = FocusNode();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _closeDropdown();
    super.dispose();
  }
  
  void _openDropdown() {
    if (_isOpen || !widget.enabled) return;
    
    setState(() => _isOpen = true);
    _searchController.clear();
    
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }
  
  void _closeDropdown() {
    if (!_isOpen) return;
    
    _isOpen = false;
    final entry = _overlayEntry;
    _overlayEntry = null;
    // 判活后移除：Overlay 销毁 / 重建竞态下 remove 会抛异常。
    if (entry != null && entry.mounted) entry.remove();
    _focusNode.unfocus();
  }
  
  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    // 下方空间不足 240px（浮层最小高度）时向上展开，避免菜单溢出屏幕底部。
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final belowSpace = overlayBox.size.height - (offset.dy + size.height + 4);
    final verticalOffset = belowSpace >= 240
        ? size.height + 4
        : -(size.height + 4);
    
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // 全屏透明 barrier：点击浮层外任意位置直接关闭（选中项 / barrier /
          // 返回键三条关闭路径统一收敛到 _closeDropdown）。
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _closeDropdown();
                if (mounted) setState(() {});
              },
            ),
          ),
          // 浮层锚定在 Overlay 左上原点（与 LayerLink 的全局坐标一致），
          // 由 follower 依据触发框实时位移。
          Positioned(
            left: 0,
            top: 0,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, verticalOffset),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: size.width,
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            hintText: '搜索...',
                            prefixIcon: const Icon(AppIcons.search),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (value) {
                            setState(() {});
                          },
                        ),
                      ),
                      Flexible(
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _searchController,
                          builder: (context, value, child) {
                            final query = value.text.toLowerCase();
                            final filteredItems = widget.items.where((item) => 
                              widget.filter(item, query)
                            ).toList();
                            
                            if (filteredItems.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('无匹配项', textAlign: TextAlign.center),
                              );
                            }
                            
                            return ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                return InkWell(
                                  onTap: () {
                                    widget.onChanged(item);
                                    _closeDropdown();
                                    if (mounted) setState(() {});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: widget.itemBuilder(item),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // 下拉选择框，纯动作（展开选项），无选中态，按统一原则补 Material+InkWell 涟漪
    // 触发框经 CompositedTransformTarget 与浮层锚定，滚动时浮层跟随。
    return CompositedTransformTarget(
      link: _layerLink,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _openDropdown,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
              color: widget.enabled 
                ? Theme.of(context).colorScheme.surface 
                : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
            ),
            child: Row(
              children: [
                if (widget.prefixIcon != null) ...[
                  widget.prefixIcon!,
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    widget.value != null 
                      ? widget.labelExtractor(widget.value as T)
                      : widget.hintText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: widget.value != null 
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Icon(
                  _isOpen ? AppIcons.chevronUp : AppIcons.chevronDown,
                  color: widget.enabled
                      ? SpitoutTokens.iconTertiary(context)
                      : SpitoutTokens.iconTertiary(context).withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
