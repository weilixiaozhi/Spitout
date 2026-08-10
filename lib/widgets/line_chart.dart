import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart' as fl;
import 'package:flutter/material.dart';

import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/chart_tokens.dart';

/// 数值标注格式化（单位=元）：>=10000 用 w，>=1000 用 k，否则取整。
///
/// 单独抽出并 `@visibleForTesting` 暴露，是为了用单测锁定「元」展示口径：
/// 上层若误传数据库整数分，12.5 会被显示成 1250（放大 100 倍）而无法从
/// 图表本身察觉，契约由测试兜底。
@visibleForTesting
String formatChartValueLabel(double v) {
  if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}w';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.toStringAsFixed(0);
}

/// 统计页支出趋势折线图（fl_chart 实现）。
///
/// 设计意图：
/// - 数据层（折线/数据点/虚线网格/刻度/常驻数值标注）交给 fl_chart 渲染，
///   避免手维护 700+ 行 CustomPainter 的几何/命中逻辑，降低回归风险。
/// - 坐标轴骨架（L 形轴线 + 末端箭头 + X 轴单位标签）fl_chart 无法表达，
///   由一个与 fl_chart 布局常量严格对齐的小 painter 绘制，保证视觉一致。
/// - 空数据态：只渲染轴骨架 + 虚线网格 + Y 刻度，不画任何折线
///   （空态底部无「0 值基线」蓝色线条）。
/// - 右侧安全区：数据区右端距 X 轴箭头 46px，
///   折线终点/数值标注/单位标签均不会遮盖箭头。
class AnalyticsLineChart extends StatelessWidget {
  /// 折线数值序列（空列表 = 空数据态）。
  ///
  /// 单位契约：**元（展示口径）**。数值标注按元取整 / k / w 缩写直接展示，
  /// 不在此处做分→元换算；上层调用方必须传元，禁止传数据库整数分，
  /// 否则标注会放大 100 倍（如 12.50 显示为 1250）。
  final List<double> values;

  /// X 轴刻度标签（与 [values] 一一对应；空数据态传空列表）
  final List<String> xLabels;

  /// 需要高亮的 X 轴下标（如「今天」），null 表示无高亮
  final int? highlightIndex;

  /// X 轴单位标签（周/月/年），绘制在 X 轴右端箭头下方；空/null 不绘制
  final String? xUnitLabel;

  const AnalyticsLineChart({
    super.key,
    required this.values,
    required this.xLabels,
    this.highlightIndex,
    this.xUnitLabel,
  });

  // ---- 布局常量：fl_chart 的 reservedSize 与 _AxisPainter 共用同一套数值，
  // 这是「自绘轴骨架」与「fl_chart 数据层」像素级对齐的关键，修改时必须同步 ----

  /// Y 轴刻度标签预留宽度（Y 轴线 x 坐标）
  static const double _leftReserved = 28.0;

  /// 顶部预留（Y 轴箭头 + 顶部数值标注的空间）
  static const double _topReserved = 24.0;

  /// 底部预留（X 轴刻度标签高度）
  static const double _bottomReserved = 24.0;

  /// X 轴箭头尖端距画布右缘的距离
  static const double _rightArrowMargin = 8.0;

  /// 数据区与 Y 轴的水平间距（首个数据点不贴轴）
  static const double _leftPlotInset = 16.0;

  /// 数据区右端安全区：原 16px，按需求 +30px = 46px，保证折线/标注不遮箭头
  static const double _rightSafeZone = 46.0;

  /// Y 轴段数（0..yMax 等距 5 段，共 6 个刻度）
  static const int _ySegments = 5;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final textPrimary = SpitoutTokens.textPrimary(context);
    final textSecondary = SpitoutTokens.textSecondary(context);
    final isEmpty = values.isEmpty;
    final yMax = _chooseYMax(isEmpty ? 0 : values.reduce(math.max));

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 300.0;

        // fl_chart 绘图区宽度 = 画布宽 - 左侧刻度预留
        final plotWidth = math.max(1.0, w - _leftReserved);

        // 通过扩展 minX/maxX 在数据坐标系内制造左右安全区：
        // 左边 16px（首点不贴 Y 轴），右边 46px（末点/标注不遮 X 轴箭头）。
        final n = values.length;
        double minX, maxX;
        if (isEmpty) {
          // 空态无数据点，给一个任意稳定范围即可（只画骨架）
          minX = 0;
          maxX = 6;
        } else if (n == 1) {
          minX = -0.5;
          maxX = 0.5;
        } else {
          final unitDx = (n - 1) / plotWidth; // 每像素对应的数据单位
          minX = -_leftPlotInset * unitDx;
          maxX = (n - 1) + _rightSafeZone * unitDx;
        }

        final barData = fl.LineChartBarData(
          spots: [
            for (var i = 0; i < n; i++) fl.FlSpot(i.toDouble(), values[i]),
          ],
          color: primary,
          barWidth: SpitoutChartTokens.lineWidth,
          isCurved: false,
          // 0 值点不画圆点（0 值不参与标注/强调）
          dotData: fl.FlDotData(
            checkToShowDot: (spot, _) => spot.y != 0,
            getDotPainter: (spot, percent, bar, index) => fl.FlDotCirclePainter(
              radius: SpitoutChartTokens.dotRadius,
              color: primary,
              strokeWidth: 0,
              strokeColor: Colors.transparent,
            ),
          ),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. 轴骨架层（最底层）：L 形轴线 + 箭头 + X 轴单位标签
            CustomPaint(
              painter: _AxisPainter(
                axisColor: textSecondary.withValues(alpha: 0.6),
                unitLabel: xUnitLabel,
                unitLabelColor: textSecondary,
                leftReserved: _leftReserved,
                bottomReserved: _bottomReserved,
                topArrowY: 8.0,
                rightArrowMargin: _rightArrowMargin,
              ),
            ),
            // 2. fl_chart 数据层（网格/刻度/折线/点/常驻数值标注）
            fl.LineChart(
              fl.LineChartData(
                minX: minX,
                maxX: maxX,
                minY: 0,
                maxY: yMax,
                backgroundColor: Colors.transparent,
                // 关闭 fl_chart 自带边框，轴线由 _AxisPainter 绘制
                borderData: fl.FlBorderData(show: false),
                clipData: const fl.FlClipData.none(),
                gridData: fl.FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yMax / _ySegments,
                  // 底部（0）与顶部（yMax）不画虚线：底部是 X 轴，顶部是 Y 轴箭头位
                  checkToShowHorizontalLine: (v) => v > 0 && v < yMax,
                  getDrawingHorizontalLine: (v) => fl.FlLine(
                    color: textSecondary.withValues(alpha: 0.28),
                    strokeWidth: 1,
                    dashArray: const [3, 4],
                  ),
                ),
                titlesData: fl.FlTitlesData(
                  show: true,
                  leftTitles: fl.AxisTitles(
                    sideTitles: fl.SideTitles(
                      showTitles: true,
                      reservedSize: _leftReserved,
                      interval: yMax / _ySegments,
                      getTitlesWidget: (value, meta) =>
                          _buildYTitle(value, meta, yMax, textSecondary),
                    ),
                  ),
                  bottomTitles: fl.AxisTitles(
                    sideTitles: fl.SideTitles(
                      // 必须恒为 true：fl_chart 仅在 showTitles=true 时才预留
                      // reservedSize 空间；空数据态若无底部预留，自绘 X 轴线
                      // （固定在 height-24）会与 fl_chart 绘图区底边错位。
                      // 无标签时由 _buildXTitle 返回空 widget 兜底。
                      showTitles: true,
                      reservedSize: _bottomReserved,
                      interval: 1,
                      getTitlesWidget: (value, meta) =>
                          _buildXTitle(value, meta, textPrimary, textSecondary),
                    ),
                  ),
                  // 顶部用透明标题占住 24px，为 Y 轴箭头与顶部标注留位
                  topTitles: fl.AxisTitles(
                    sideTitles: fl.SideTitles(
                      showTitles: true,
                      reservedSize: _topReserved,
                      getTitlesWidget: (value, meta) => const SizedBox.shrink(),
                    ),
                  ),
                  rightTitles: const fl.AxisTitles(
                    sideTitles: fl.SideTitles(showTitles: false),
                  ),
                ),
                // 常驻数值标注：禁用触摸交互，用 showingTooltipIndicators
                // 把每个非零点的数值以「透明气泡」形式常驻在点上方。
                // 注意必须一个 ShowingTooltipIndicators 只包一个 spot，
                // 否则 fl_chart 会把整组合并为单个 tooltip 画在最高点上。
                lineTouchData: fl.LineTouchData(
                  enabled: false,
                  touchTooltipData: fl.LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.transparent,
                    // 圆角参数为 BorderRadius 类型
                    tooltipBorderRadius: BorderRadius.zero,
                    tooltipPadding: EdgeInsets.zero,
                    tooltipMargin: 10,
                    maxContentWidth: 60,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        fl.LineTooltipItem(
                          _fmt(s.y),
                          TextStyle(
                            fontSize: SpitoutChartTokens.yLabelFontSize - 1,
                            color: textPrimary,
                            height: 1.1,
                          ),
                        ),
                    ],
                  ),
                ),
                showingTooltipIndicators: isEmpty
                    ? const []
                    : [
                        for (var i = 0; i < n; i++)
                          if (values[i] != 0)
                            fl.ShowingTooltipIndicators([
                              fl.LineBarSpot(
                                barData,
                                0,
                                barData.spots[i],
                              ),
                            ]),
                      ],
                lineBarsData: isEmpty ? const [] : [barData],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Y 轴刻度标签：0..yMax 等距；跳过顶部 yMax（与 Y 轴箭头重叠）。
  Widget _buildYTitle(
      double value, fl.TitleMeta meta, double yMax, Color color) {
    if (value >= yMax) return const SizedBox.shrink();
    return fl.SideTitleWidget(
      meta: meta,
      space: 4,
      child: Text(
        '${value.round()}',
        style: TextStyle(
          fontSize: SpitoutChartTokens.yLabelFontSize,
          color: color,
        ),
      ),
    );
  }

  /// X 轴刻度标签：按 ~8 格抽稀；highlightIndex 加粗高亮。
  Widget _buildXTitle(
    double value,
    fl.TitleMeta meta,
    Color textPrimary,
    Color textSecondary,
  ) {
    final n = xLabels.length;
    final idx = value.round();
    // minX/maxX 扩展后会产生非整数/越界刻度，一律不渲染
    if ((value - idx).abs() > 0.001 || idx < 0 || idx >= n) {
      return const SizedBox.shrink();
    }
    final step = math.max(1, (n / 8).ceil());
    if (idx % step != 0) return const SizedBox.shrink();
    final highlighted = highlightIndex != null && idx == highlightIndex;
    return fl.SideTitleWidget(
      meta: meta,
      space: 4,
      child: Text(
        xLabels[idx],
        style: TextStyle(
          fontSize: SpitoutChartTokens.xLabelFontSize,
          color: highlighted ? textPrimary : textSecondary,
          fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  /// 选择 Y 轴顶部刻度值：优先 100 的整数档，保证刻度标签为整数；
  /// 空数据兜底 100。
  static double _chooseYMax(double v) {
    if (v <= 100) return 100;
    if (v <= 200) return 200;
    if (v <= 500) return 500;
    if (v <= 1000) return 1000;
    return ((v / 100).ceil()) * 100.0;
  }

  /// 数值标注格式化（单位=元），委托给顶层纯函数 [formatChartValueLabel]。
  static String _fmt(double v) => formatChartValueLabel(v);
}

/// 坐标轴骨架画笔：L 形轴线 + 末端实心三角箭头 + X 轴单位标签。
///
/// 只负责「fl_chart 画不出来」的部分；轴线的几何常量与
/// AnalyticsLineChart 中 fl_chart 的 reservedSize 一一对应：
/// - Y 轴线 x = leftReserved（左侧刻度预留的右缘）
/// - X 轴线 y = height - bottomReserved（底部刻度预留的上缘）
/// 这样自绘骨架与 fl_chart 数据层永远像素级对齐，不会出现两轴错位。
class _AxisPainter extends CustomPainter {
  final Color axisColor;
  final String? unitLabel;
  final Color unitLabelColor;
  final double leftReserved;
  final double bottomReserved;
  final double topArrowY;
  final double rightArrowMargin;

  _AxisPainter({
    required this.axisColor,
    required this.unitLabel,
    required this.unitLabelColor,
    required this.leftReserved,
    required this.bottomReserved,
    required this.topArrowY,
    required this.rightArrowMargin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final axisX = leftReserved;
    final axisY = size.height - bottomReserved;
    final axisRight = size.width - rightArrowMargin;

    // X 轴（底部水平线）+ 右端箭头
    canvas.drawLine(Offset(axisX, axisY), Offset(axisRight, axisY), axisPaint);
    _drawArrowHead(canvas, Offset(axisRight, axisY),
        horizontal: true, color: axisColor);
    // Y 轴（左侧竖直线）+ 顶端箭头
    canvas.drawLine(Offset(axisX, axisY), Offset(axisX, topArrowY), axisPaint);
    _drawArrowHead(canvas, Offset(axisX, topArrowY),
        horizontal: false, color: axisColor);

    // X 轴单位标签（周/月/年）：绘制在箭头下方，与箭头垂直错开 4px，
    // 不会遮盖箭头本体；右侧 46px 安全区保证其不与最后一个 X 刻度重叠。
    if (unitLabel != null && unitLabel!.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: unitLabel,
          style: TextStyle(
            fontSize: SpitoutChartTokens.xLabelFontSize,
            color: unitLabelColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(axisRight - tp.width, axisY + 4));
    }
  }

  /// 绘制坐标轴末端的实心三角箭头。horizontal=true 指向右，false 指向上。
  void _drawArrowHead(Canvas canvas, Offset tip,
      {required bool horizontal, required Color color}) {
    const double s = 5.0;
    final path = Path();
    if (horizontal) {
      path.moveTo(tip.dx, tip.dy);
      path.lineTo(tip.dx - s, tip.dy - s * 0.6);
      path.lineTo(tip.dx - s, tip.dy + s * 0.6);
    } else {
      path.moveTo(tip.dx, tip.dy);
      path.lineTo(tip.dx - s * 0.6, tip.dy + s);
      path.lineTo(tip.dx + s * 0.6, tip.dy + s);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _AxisPainter old) =>
      old.axisColor != axisColor ||
      old.unitLabel != unitLabel ||
      old.unitLabelColor != unitLabelColor ||
      // 布局常量当前由调用方固定传入，但若未来参数化，缺比较会导致
      // 只改布局不重绘的 stale 画面，故一并纳入重绘条件。
      old.leftReserved != leftReserved ||
      old.bottomReserved != bottomReserved ||
      old.topArrowY != topArrowY ||
      old.rightArrowMargin != rightArrowMargin;
}
