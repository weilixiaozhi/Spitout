import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/colors.dart';

/// 分类占比环图（带四周引导标注）。
///
/// 设计意图：遵循「单一主色」规范，分类扇区使用主色的不同明暗层级
/// （100% / 75% / 52% / 28% / 15%），不使用多色体系；「其他」聚合扇区用
/// 中性灰区分。环图居中，中心显示「分类 / 支出占比」文案，四周用
/// 引导线 + 名称 + 百分比指向对应扇区。
///
/// 数据口径：上层（统计页）传入「Top5 分类 + 其他聚合」，各扇区 percent
/// 合计恒等于 100%（整圆真实切分），与下方完整分类排行榜口径一致；
/// 角度计算按同一归一化口径（percent/Σpercent），避免「只画 TopN 却被拉满整圆」。
///
/// 引导线对齐要点：
/// - 显式 startDegreeOffset=-90，扇区中点角度按同一起笔方向计算，线与扇区严格对齐。
/// - 先排定标签最终 y 槽位，再按最终槽位画线，线终点与标签垂直中心严格对齐。
/// - 空数据态：灰色镂空圆环 + 中心无任何文字。
class CategoryDonutChart extends StatelessWidget {
  /// 分类数据：name 名称，percent 占比(0..1)，isOther 其他聚合。
  /// 约定：上层保证合计 percent == 1.0（Top5 + 其他聚合），组件不截断。
  final List<DonutCategory> data;

  /// 总金额（单位：元；仅用于空态判定，不参与扇区渲染）。
  final double sum;

  const CategoryDonutChart({
    super.key,
    required this.data,
    required this.sum,
  });

  /// 环图中心空洞半径（内径）
  static const double _centerSpaceRadius = 52;

  /// 扇区厚度（外径 = 内径 + 厚度 = 78）
  static const double _sectionRadius = 26;

  /// 扇区外边缘半径
  static const double _sectionOuterR = _centerSpaceRadius + _sectionRadius;

  /// 引导线径向外延长度（扇区边缘 → 拐点）
  static const double _elbowLength = 12;

  /// 同侧标签最小垂直间距（小于该值会被排开）
  static const double _labelMinGap = 20;

  /// 标签垂直中心允许的范围（防止超出组件上下边界）
  static const double _labelTopLimit = 12;
  static const double _labelBottomMargin = 12;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bg = SpitoutTokens.scaffoldBackground(context);
    final l10n = AppLocalizations.of(context);

    // 为主色生成 5 级明暗：100% / 75% / 52% / 28% / 15%
    // （第 5 级较浅，与相邻的第 4 级和「其他」中性灰均可区分）
    final tonalColors = [
      primary,
      Color.lerp(primary, bg, 0.25)!,
      Color.lerp(primary, bg, 0.48)!,
      Color.lerp(primary, bg, 0.72)!,
      Color.lerp(primary, bg, 0.85)!,
    ];

    final isEmpty = (data.isEmpty || sum <= 0);
    // fl_chart 会过滤 value==0 的扇区，角度计算前必须用同一口径过滤，
    // 否则「扇区序列」与「角度序列」错位，引导线指错扇区。
    // 注意不做数量截断：上层已按「Top5 + 其他聚合」备好数据。
    final visible = isEmpty
        ? <DonutCategory>[]
        : data.where((e) => e.percent > 0).toList();

    // 扇区配色：分类用主色明暗层级，「其他」聚合用中性灰（与主色体系区分）
    final otherColor = SpitoutTokens.textTertiary(context);
    Color sectionColor(DonutCategory item, int i) =>
        item.isOther ? otherColor : tonalColors[i % tonalColors.length];

    final sections = <PieChartSectionData>[];
    if (isEmpty) {
      // 空态：单一灰色扇区铺满整圈，配合 centerSpaceRadius 呈镂空圆环
      sections.add(PieChartSectionData(
        color: SpitoutTokens.surfaceSecondary(context),
        value: 1,
        title: '',
        radius: _sectionRadius,
        titleStyle: const TextStyle(fontSize: 0),
      ));
    } else {
      for (var i = 0; i < visible.length; i++) {
        sections.add(PieChartSectionData(
          color: sectionColor(visible[i], i),
          value: visible[i].percent * 100,
          // 扇区内不显示文字，改由四周引导标注展示
          title: '',
          radius: _sectionRadius,
          titleStyle: const TextStyle(fontSize: 0),
        ));
      }
    }

    return SizedBox(
      height: 280,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 防御性检查：避免 constraints 为 infinity 导致坐标计算出现 infinity
          final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 300.0;
          final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 280.0;
          final center = Offset(w / 2, h / 2);

          // 扇区中点角度（与 fl_chart startDegreeOffset=-90、顺时针口径一致）。
          // 关键：fl_chart 会把扇区 value 归一化拉满整圆（value/Σvalues*360°），
          // 而 percent 是「占全部支出」的比例，Top4 合计通常 < 100%（月/年
          // 数据分类更多时偏差更大）。角度计算必须按同一口径归一化，
          // 否则引导线与实际扇区角度对不上（周数据 ≤4 分类时合计恰好
          // 100%，所以该问题只在月/年视图暴露）。
          //
          // sectionsSpace=2 会在相邻扇区间插入 2° 空隙：相对「连续扇区」的
          // 计算口径，各扇区实际起角会平移约 space/2 的累计偏差（单扇区
          // 中点偏差 ≤1°），引导线中点与真实扇区中点在此量级内轻微偏移，
          // 视觉可接受。若未来要求像素级严格对齐，需把每段起始角再按
          // sectionsSpace 逐段修正。
          final midAngles = <double>[];
          if (!isEmpty) {
            final shownTotal =
                visible.fold<double>(0, (a, e) => a + e.percent);
            double startAngle = -math.pi / 2;
            for (final item in visible) {
              final sweep = (item.percent / shownTotal) * 2 * math.pi;
              midAngles.add(startAngle + sweep / 2);
              startAngle += sweep;
            }
          }

          // 先排定每个标签的最终 y 槽位（分左/右两侧各自去重叠），
          // 引导线按最终槽位绘制，保证线终点 == 标签垂直中心。
          final labelYs = isEmpty
              ? <double>[]
              : _layoutLabelYs(midAngles, center, h);

          // 每个扇区的实际颜色（分类=主色层级，其他=中性灰），
          // 引导线圆点/标签色块必须与扇区同色，否则指向关系失真。
          final sectionColors = [
            for (var i = 0; i < visible.length; i++)
              sectionColor(visible[i], i),
          ];

          return Stack(
            alignment: Alignment.center,
            children: [
              // 1. 引导线层（最底层）：扇区边缘 → 径向外延 → 到标签锚点
              if (!isEmpty)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GuideLinePainter(
                      midAngles: midAngles,
                      labelYs: labelYs,
                      sectionColors: sectionColors,
                      center: center,
                      sectionOuterR: _sectionOuterR,
                      elbowLength: _elbowLength,
                      canvasW: w,
                      lineColor: SpitoutTokens.textSecondary(context)
                          .withValues(alpha: 0.45),
                    ),
                  ),
                ),
              // 2. 环图本体（空数据时为灰色镂空圆环）
              SizedBox(
                width: _sectionOuterR * 2 + 12,
                height: _sectionOuterR * 2 + 12,
                child: PieChart(
                  PieChartData(
                    // 关键：显式从 12 点方向起笔，与 midAngles 计算口径一致
                    startDegreeOffset: -90,
                    sectionsSpace: visible.isEmpty ? 0 : 2,
                    centerSpaceRadius: _centerSpaceRadius,
                    sections: sections,
                    // 环图本身不处理触摸，交互在下方列表
                    pieTouchData: PieTouchData(enabled: false),
                  ),
                ),
              ),
              // 3. 中心文案：有数据显示「分类 / 支出占比」；空数据不显示任何内容
              if (!isEmpty)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.analyticsCategoryLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: SpitoutTokens.textPrimary(context),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.analyticsExpenseRatio,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: SpitoutTokens.textSecondary(context),
                          ),
                    ),
                  ],
                ),
              // 4. 标签层：y 对齐到引导线终点（即各自最终槽位）
              if (!isEmpty)
                for (var i = 0; i < visible.length; i++)
                  _buildPositionedLabel(
                    context,
                    visible[i],
                    sectionColors[i],
                    midAngles[i],
                    labelYs[i],
                    w,
                  ),
            ],
          );
        },
      ),
    );
  }

  /// 标签 y 槽位布局：自然位置 = 径向外延点的 y；同侧（左/右）按自然 y
  /// 排序后做去重叠排开（最小间距 [_labelMinGap]），再映射回原扇区顺序。
  ///
  /// 为什么分侧处理：左右两侧标签分别贴组件左右边缘，互不占位，
  /// 只对同侧标签去重叠即可，避免跨侧误排导致的不必要位移。
  List<double> _layoutLabelYs(
      List<double> midAngles, Offset center, double canvasH) {
    final minY = _labelTopLimit;
    final maxY = canvasH - _labelBottomMargin;

    // 每个扇区的自然 y（径向外延点高度）
    final naturalYs = [
      for (final a in midAngles)
        center.dy + math.sin(a) * (_sectionOuterR + _elbowLength),
    ];

    final finalYs = List<double>.filled(midAngles.length, 0);
    // 分侧处理：isLeft = cos(angle) < 0
    for (final isLeft in [true, false]) {
      final sideIndices = [
        for (var i = 0; i < midAngles.length; i++)
          if ((math.cos(midAngles[i]) < 0) == isLeft) i,
      ]..sort((a, b) => naturalYs[a].compareTo(naturalYs[b]));

      final slots = _repelSlots(
        [for (final i in sideIndices) naturalYs[i]],
        minY,
        maxY,
      );
      for (var k = 0; k < sideIndices.length; k++) {
        finalYs[sideIndices[k]] = slots[k];
      }
    }
    return finalYs;
  }

  /// 一维去重叠：保持输入顺序（已按自然 y 升序），
  /// 每个槽位不小于前一个 + 最小间距；底部溢出则整体上移回收。
  List<double> _repelSlots(List<double> naturalYs, double minY, double maxY) {
    if (naturalYs.isEmpty) return const [];
    final ys = List<double>.from(naturalYs);
    ys[0] = ys[0].clamp(minY, maxY);
    for (var i = 1; i < ys.length; i++) {
      ys[i] = math.max(ys[i], ys[i - 1] + _labelMinGap);
    }
    if (ys.last > maxY) {
      // 底部溢出：从后往前回收，保持间距的前提下整体上移
      ys[ys.length - 1] = maxY;
      for (var i = ys.length - 2; i >= 0; i--) {
        ys[i] = math.min(ys[i], ys[i + 1] - _labelMinGap);
      }
      // 极端情况（标签过多空间不足）：顶部钉住后必然重叠，属可接受兜底
      if (ys.first < minY) {
        final shift = minY - ys.first;
        for (var i = 0; i < ys.length; i++) {
          ys[i] += shift;
        }
      }
    }
    return ys;
  }

  /// 单个引导标签：左侧「色块+名称+百分比」，右侧「百分比+名称+色块」（镜像）。
  ///
  /// 标签垂直中心 = [labelY]（= 引导线终点），通过 top = labelY - 半高 定位。
  Widget _buildPositionedLabel(
    BuildContext context,
    DonutCategory item,
    Color color,
    double midAngle,
    double labelY,
    double canvasW,
  ) {
    final isLeft = math.cos(midAngle) < 0;
    final pctStr = '${(item.percent * 100).toStringAsFixed(1)}%';

    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    final nameText = ConstrainedBox(
      // 名称过长时省略号截断，避免侵入环图区域压住引导线
      constraints: const BoxConstraints(maxWidth: 72),
      child: Text(
        item.name,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11,
              color: SpitoutTokens.textSecondary(context),
            ),
      ),
    );
    final pctText = Text(
      pctStr,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: SpitoutTokens.textPrimary(context),
          ),
    );

    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: isLeft
          ? [dot, const SizedBox(width: 4), nameText, const SizedBox(width: 4), pctText]
          : [pctText, const SizedBox(width: 4), nameText, const SizedBox(width: 4), dot],
    );

    return Positioned(
      left: isLeft ? 4.0 : null,
      right: isLeft ? null : 4.0,
      // 标签行高约 18px，垂直中心对齐引导线终点
      top: labelY - 9,
      child: label,
    );
  }
}

/// 环图引导线画笔：扇区边缘 → 径向外延 → 标签锚点的折线。
///
/// 折线终点直接取「标签最终 y 槽位」（[_GuideLinePainter.labelYs]），
/// 与标签垂直中心是同一个值，线始终连到标签。
class _GuideLinePainter extends CustomPainter {
  final List<double> midAngles;
  final List<double> labelYs;
  final List<Color> sectionColors;
  final Offset center;
  final double sectionOuterR;
  final double elbowLength;
  final double canvasW;
  final Color lineColor;

  _GuideLinePainter({
    required this.midAngles,
    required this.labelYs,
    required this.sectionColors,
    required this.center,
    required this.sectionOuterR,
    required this.elbowLength,
    required this.canvasW,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < midAngles.length && i < labelYs.length; i++) {
      final angle = midAngles[i];
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      // p1: 扇区外边缘起点
      final p1 = center + Offset(cosA * sectionOuterR, sinA * sectionOuterR);
      // p2: 径向外延拐点
      final p2 = center +
          Offset(cosA * (sectionOuterR + elbowLength),
              sinA * (sectionOuterR + elbowLength));
      // p3: 标签锚点（组件左/右边缘，y = 标签最终槽位）
      final isLeft = cosA < 0;
      final p3 = Offset(isLeft ? 4.0 : canvasW - 4.0, labelYs[i]);

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy);
      canvas.drawPath(path, guidePaint);

      // 扇区边缘起点画对应颜色小圆点，强调「这条线属于这个扇区」
      canvas.drawCircle(p1, 2.5, Paint()..color = sectionColors[i % sectionColors.length]);
    }
  }

  @override
  bool shouldRepaint(covariant _GuideLinePainter old) =>
      old.midAngles != midAngles ||
      old.labelYs != labelYs ||
      old.sectionColors != sectionColors ||
      old.center != center ||
      old.canvasW != canvasW ||
      old.lineColor != lineColor;
}

/// 环图分类数据
class DonutCategory {
  final String name;
  final double percent; // 0..1，占全部支出的比例

  /// 是否为「其他」聚合扇区（true 时用中性灰渲染，区别于主色层级）
  final bool isOther;

  const DonutCategory({
    required this.name,
    required this.percent,
    this.isOther = false,
  });
}
