# Spitout Design Token 系统

> 文件位置：`lib/theme/colors.dart`（核心）、`lib/theme/typography.dart`、`lib/theme/dimens.dart`、
> `lib/theme/shadows.dart`、`lib/theme/chart_tokens.dart`
>
> 统一的 Design Token 系统，包含颜色、尺寸、阴影、字体等所有设计令牌。
> 所有 UI 组件都应该使用 Token 而非直接使用颜色值，以确保亮暗模式正确适配。
>
> `SpitoutTokens` 类（`colors.dart`）为核心颜色/卡片/分割线令牌，其余按职责拆分：
> 间距/圆角见 `dimens.dart`，文本样式见 `typography.dart`，图表色见 `chart_tokens.dart`。
>
> **设计基底**：颜色体系基于 [shadcn/ui](https://ui.shadcn.com/) 调色板，
> 亮色与暗色模式分别对应 shadcn 的 light / dark 语义色，保证视觉一致性。

## Token 使用方式

```dart
import '../theme/colors.dart';

// 在 Widget 中使用
Container(
  color: SpitoutTokens.surface(context),
  child: Text(
    'Hello',
    style: TextStyle(color: SpitoutTokens.textPrimary(context)),
  ),
)
```

---

## 1. 背景色 Token (Surface)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `scaffoldBackground` | 页面背景（Scaffold） | `#F9F7F7` | `#111827` |
| `surface` | 卡片背景 | `#FFFFFF` 白色 | `#1F2937` |
| `surfaceSecondary` | 次级背景（嵌套卡片、输入框） | `#EDF2F7` | `#374151` |
| `surfaceElevated` | 悬浮卡片（Dialog、BottomSheet、Dropdown） | `#FFFFFF` 白色 | `#1F2937` |
| `surfaceSheet` | BottomSheet 背景（金额输入等） | `#FFFFFF` 白色 | `#1F2937` |
| `keypadBackground` | 记账键盘容器背景 | `#EDF2F7`（= surfaceSecondary） | `#1F2937`（= surface） |
| `keyDigit` | 键盘数字/运算符/日期按键背景 | `#FFFFFF` 白色 | `#374151` |
| `surfaceInput` | 输入框背景 | `#F3F4F6` 浅灰 | `#374151` |
| `surfaceChip` | 标签/Chip 背景（未选中） | `Colors.grey.shade200` | `#374151` |
| `surfaceCapsule` | 胶囊切换器背景（不透明，避免悬浮透色） | `Colors.grey.shade200` | `#374151` |
| `surfaceCategoryIcon` | 分类图标背景（未选中） | `Colors.grey.shade200` | `#48484A` 中灰 |
| `surfaceCategoryIconLight` | 分类图标背景（浅色/二级） | `Colors.grey.shade100` | `#3A3A3C` 深灰 |
| `surfaceSelected` | 选中状态背景 | 主题色 8% | 主题色 15% |
| `surfaceInverse` | 反转背景（FAB、浮动按钮等"反色"组件） | `#000000` 纯黑 | `#FFFFFF` 纯白 |

> **扁平化 Header 说明**：`PrimaryHeader` 直接复用页面底色
> （`Theme.of(context).scaffoldBackgroundColor`），与页面融为一体；
> Header 内文字使用 `textPrimary` / `textSecondary` 而非白色。

> **首页头部汇总卡**：首页「本月支出」汇总卡为主色背景 + 白字
> （`Theme.of(context).colorScheme.primary` + `SpitoutTokens.textOnPrimary(context)`）。

---

## 2. 文字颜色 Token (Text)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `textPrimary` | 主要文字（标题、正文） | `#333333` | `#F3F4F6` |
| `textSecondary` | 次要文字（副标题、说明） | `#6B7280` | `#9CA3AF` |
| `textTertiary` | 提示文字（placeholder、hint） | `#9CA3AF` 灰400 | `rgba(255,255,255,0.54)` |
| `textDisabled` | 禁用文字 | `rgba(0,0,0,0.26)` | `rgba(255,255,255,0.38)` |
| `textOnPrimary` | 反色文字（深色背景上） | `#FFFFFF` | `#FFFFFF` |
| `textLink` | 链接文字 | `#3B82F6` 蓝色 | `#60A5FA` 亮蓝色 |
| `onSurfaceInverse` | 反转背景上的前景色（放在 surfaceInverse 上的图标/文字） | `#FFFFFF` 纯白 | `#000000` 纯黑 |

---

## 3. 图标颜色 Token (Icon)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `iconPrimary` | 主要图标 | `Colors.black87` | `#FFFFFF` 白色 |
| `iconSecondary` | 次要图标 | `rgba(0,0,0,0.54)` | `rgba(255,255,255,0.7)` |
| `iconTertiary` | 提示图标 | `rgba(0,0,0,0.38)` | `rgba(255,255,255,0.54)` |
| `iconCategory` | 分类图标（未选中） | `Colors.grey.shade700` (`#616161`) | `#AEAEB2` 浅灰 |

---

## 4. 边框/分割线 Token (Border)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `divider` | 分割线 | `rgba(0,0,0,0.06)` | `rgba(243,244,246,0.10)` |
| `border` | 卡片边框 | `transparent`（使用阴影） | `rgba(243,244,246,0.10)` |
| `borderStrong` | 强调边框 | `rgba(0,0,0,0.12)` | `rgba(243,244,246,0.10)` |
| `grabHandleColor` | 底部弹层拖拽条（shadcn muted） | `rgba(0,0,0,0.15)` | `rgba(255,255,255,0.20)` |

> 暗黑模式下常规边框统一使用 shadcn border dark（`#F3F4F6` 10% 透明度），
> 亮色模式使用阴影替代边框。

---

## 5. 卡片边框/分割线 Token (Card Border)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `cardOuterBorderColor` | 卡片外边框颜色 | `transparent` | `transparent` |
| `cardOuterBorderWidth` | 卡片外边框宽度 | `0` | `0` |
| `cardInnerDividerColor` | 卡片内分割线颜色 | `rgba(0,0,0,0.06)` | `transparent`（去掉分割线） |
| `cardInnerDividerHeight` | 卡片内分割线高度 | `1` | `0` |

### 卡片内分割线组件

```dart
// 卡片内分割线（默认左缩进 48，对齐 AppListTile 内容：icon 容器 36 + 间距 12）
// section 顶部 / 卡片外等需要全宽的场景传 indent: 0
SpitoutTokens.cardDivider(context)
SpitoutTokens.cardDivider(context, indent: 0)
```

---

## 6. 主题色 Token (Theme)

| Token 名称 | 用途 | 说明 |
|-----------|------|------|
| `primary` | 主题色（自动适配用户选择） | 亮色模式为用户选择色，暗黑模式为深色版本 |

---

## 7. 语义色 Token (Semantic)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `success` | 成功状态 | `#22C55E` 绿色 | `#34D399` 亮绿 |
| `warning` | 警告状态 | `#F59E0B` 橙色 | `#FBBF24` 亮橙 |
| `error` | 错误状态（shadcn destructive） | `#D94A5B` | `#F87171` 亮红 |
| `info` | 信息提示 | `#3B82F6` 蓝色 | `#60A5FA` 亮蓝 |

```dart
// 各语义色为独立方法：success / warning / error / info
final color = SpitoutTokens.success(context);
```

---

## 8. 交互色 Token (Interactive)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `buttonPrimary` | 主按钮背景 | 主题色 | 主题色 |
| `buttonPrimaryText` | 主按钮文字 | `#FFFFFF` | `#FFFFFF` |
| `buttonDisabled` | 禁用按钮背景 | `#E5E7EB` | `#3C3C3E` |
| `switchInactiveTrack` | Switch 关闭轨道 | `#E5E7EB` | `#3C3C3E` |

---

## 9. 品牌图标色 Token (Brand Icons)

这些颜色是各服务的品牌色，在亮暗模式下保持一致（静态常量，无需 context）。

| Token 名称 | 用途 | 颜色值 |
|-----------|------|--------|
| `brandLocal` | 本地存储图标 | `#9E9E9E` 灰色 |
| `brandSupabase` | Supabase 图标 | `#3ECF8E` 绿色 |
| `brandWebdav` | WebDAV 图标 | `#FF9800` 橙色 |
| `brandS3` | S3 存储图标 | `#8B5CF6` 紫色 |
| `brandCloud` | 云服务通用图标 | `#2196F3` 蓝色 |

---

## 10. 状态指示器 Token (Status Indicators)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `statusOnline` | 在线/连接成功 | `= success` (`#22C55E`) | `= success` (`#34D399`) |
| `statusOffline` | 离线/断开连接 | `#9CA3AF` | `rgba(255,255,255,0.38)` |
| `statusPending` | 待处理/等待中 | `= warning` (`#F59E0B`) | `= warning` (`#FBBF24`) |

---

## 11. 图表/统计色 Token (Chart Colors)

> 项目为**全局仅支出模式**，仅保留支出相关 token。

| Token 名称 | 用途 | 说明 |
|-----------|------|------|
| `chartExpense` | 支出趋势线颜色 | 委托 `primary(context)`（主题主色，亮暗跟随主题） |

> 统计页支出趋势折线图（`AnalyticsLineChart`）的数据线与数据点使用 `chartExpense`。
> 折线是统计展示，不使用 error 语义色，避免与金额的支出语义色混淆。

**方案感知的支出颜色**（非 Token，需订阅 `expenseColorSchemeProvider`）：

```dart
// import '../../providers/theme_providers.dart' show expenseColorSchemeProvider;
// 必须用 ref.watch 订阅方案，切换红绿方案时金额颜色才会刷新
final color = ref.watch(expenseColorSchemeProvider) == 'green'
    ? SpitoutTokens.success(context)
    : SpitoutTokens.error(context);
```

> `expenseColorSchemeProvider` 定义在 `lib/providers/theme_providers.dart`，取值 `'red'`（默认，支出为红色）或 `'green'`（支出为绿色）。
> 若改用 `ref.read` 则不会订阅方案变化，开关切换后金额颜色不更新。

---

## 12. 遮罩层 Token (Overlay)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `overlay` | 模态遮罩层 | `rgba(0,0,0,0.5)` | `rgba(0,0,0,0.7)` |

---

## 13. 悬浮 Tab 栏 Token (Floating Tab Bar)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `tabBarBackground` | 底部导航栏背景（带模糊） | 白色 95% 不透明 | `#1F2937` 95% 不透明 |
| `tabBarShadow` | 悬浮 Tab 栏阴影 | `rgba(0,0,0,0.08)` blur 20 offset (0,4) | 同左 |

---

## 14. 静态常量（无 context 场景）

用于 `CustomPainter`、主题定义等无法访问 `BuildContext` 的场景。以下为常用静态常量，
完整定义见 `SpitoutColors` 类（`lib/theme/colors.dart`）。

| 亮色常量 | 暗黑常量 | 值 | 用途 |
|---------|---------|-----|------|
| `lightScaffold` | `darkScaffold` | `#F9F7F7` / `#111827` | 页面背景 |
| `lightSurface` | `darkSurface` | `#FFFFFF` / `#1F2937` | 主卡片/容器背景 |
| `lightSurfaceSecondary` | `darkSurfaceSecondary` | `#EDF2F7` / `#374151` | 次级容器背景 |
| `lightTextPrimary` | `darkTextPrimary` | `#333333` / `#F3F4F6` | 主要文字 |
| `lightTextSecondary` | `darkTextSecondary` | `#6B7280` / `#9CA3AF` | 次要文字 |
| `lightTextTertiary` | — | `#9CA3AF` | 提示文字（暗黑模式由 `textTertiary` 动态计算 `rgba(255,255,255,0.54)`） |
| `lightInputBg` | — | `#F3F4F6` | 输入框背景 |
| `lightChip` | — | `#EEEEEE` | Chip 背景 |
| `lightDisabledControl` | `darkDisabledControl` | `#E5E7EB` / `#3C3C3E` | 禁用控件背景 |
| `seed` | — | `#3F72AF` | 主色种子 |
| `lightLink` | `darkLink` | `#3B82F6` / `#60A5FA` | 链接 / info 色 |
| `lightCategoryIcon` | — | `#616161`（grey.shade700） | 分类图标色 |
| `lightCategoryIconLight` | — | `#F5F5F5`（grey.shade100） | 二级分类图标底 |
| — | `darkSurfaceMid` | `#3A3A3C` | 二级分类图标底（暗） |
| — | `darkCategoryIcon` | `#48484A` | 分类图标背景 |
| — | `darkIconCategory` | `#AEAEB2` | 分类图标色 |
| `lightKeypadBackground` | `darkKeypadBackground` | `#EDF2F7` / `#1F2937` | 记账键盘容器 |
| `lightKeyDigit` | `darkKeyDigit` | `#FFFFFF` / `#374151` | 记账键盘按键 |
| `toastBackground` | — | `#D9000000`（黑 85%） | Toast 背景（亮暗一致） |
| `greetingMorning` | — | `= warningLight`（`#F59E0B`） | 早间问候图标 |
| `greetingNoon` | — | `= warningLight`（`#F59E0B`） | 午间问候图标 |
| `greetingAfternoon` | — | `#F97316` | 午后问候图标 |
| `greetingEvening` | — | `= brandS3`（`#8B5CF6`） | 晚间问候图标 |
| `greetingNight` | — | `#818CF8` | 夜间问候图标 |

---

## 15. 尺寸令牌 (SpitoutDimens)

统一间距、圆角等尺寸（静态常量）。

| Token 名称 | 值 | 用途 |
|-----------|-----|------|
| `SpitoutDimens.p4` | `4` | 最小间距 |
| `SpitoutDimens.p8` | `8` | 小间距 |
| `SpitoutDimens.p12` | `12` | 中间距 |
| `SpitoutDimens.p16` | `16` | 大间距 |
| `SpitoutDimens.p20` | `20` | 特大间距 |
| `SpitoutDimens.p32` | `32` | 区块间距 |
| `SpitoutDimens.p40` | `40` | 大区块间距 |
| `SpitoutDimens.radius4` | `4` | 极小圆角 |
| `SpitoutDimens.radius8` | `8` | 小圆角 |
| `SpitoutDimens.radius12` | `12` | 中间圆角 |
| `SpitoutDimens.radius16` | `16` | 大圆角 |
| `SpitoutDimens.radius20` | `20` | 特大圆角 |
| `SpitoutDimens.radius28` | `28` | 大卡片圆角 |
| `SpitoutDimens.radius44` | `44` | 超大圆角 |
| `SpitoutDimens.icon12` | `12` | 小图标 |
| `SpitoutDimens.icon16` | `16` | 常规图标 |
| `SpitoutDimens.icon20` | `20` | 头部/功能图标 |
| `SpitoutDimens.icon22` | `22` | 强调图标 |
| `SpitoutDimens.icon28` | `28` | 大图标 |
| `SpitoutDimens.icon40` | `40` | 特大图标 |
| `SpitoutDimens.listHeaderVertical` | `6` | 列表头垂直内边距 |
| `SpitoutDimens.listRowVertical` | `8` | 列表行垂直内边距 |

> 启动页 Logo、空态与头像大尺寸（64/88/120）为组件级尺寸，暂不入 token。

> 页面头部规范由 `PrimaryHeader` 组件内置承载（不设独立令牌）：
> 留白 `padding` 上 8、下 0、左/右 12、**首行最小高度 30**（`ConstrainedBox`，无 action 与含 action 页面行高一致）、
> 首行标题 `SpitoutTextTokens.strongTitle` 字重 + 字号 14（w600 / 14px）、返回键与 action 图标 20px / **热区 30x30**
> （`HeaderIconAction`，与首行高度一致）、文字链 14px/w600/主题主色（`HeaderTextAction`）、
> 标题下拉箭头 20px（由 `PrimaryHeader` 内部以 `IconData` 渲染，调用方只传图标、不可指定 size，与功能键统一）。
> 所有页面（含四个底部 tab 与二级页）统一调用 `PrimaryHeader`，仅传内容参数即可保证头部全局一致；
> 唯一例外为「我的」页 `MinePageHeader`（头像居中布局，走 content 模式保留私有 padding）。

---

## 16. 阴影令牌 (SpitoutShadows)

```dart
// 卡片阴影
boxShadow: SpitoutShadows.card,
// 值：rgba(0,0,0,0.04) blur 8 offset (0,2)

// 中央记账 FAB 阴影（比卡片更重，凸起于悬浮栏）
boxShadow: SpitoutShadows.fab,
// 值：rgba(0,0,0,0.15) blur 8 offset (0,2)

// Toast 阴影（仅暗黑模式，白色提亮）
boxShadow: SpitoutTokens.toastShadow,
// 值：rgba(255,255,255,0.2) blur 8 spread 1
// Toast 背景走 SpitoutTokens.toastBackground，文字走 textOnPrimary
```

---

## 17. 图表令牌 (SpitoutChartTokens)

| Token 名称 | 值 | 用途 |
|-----------|-----|------|
| `SpitoutChartTokens.lineWidth` | `2.0` | 折线宽度 |
| `SpitoutChartTokens.dotRadius` | `2.5` | 数据点半径 |
| `SpitoutChartTokens.xLabelFontSize` | `10.0` | X轴标签字号 |
| `SpitoutChartTokens.yLabelFontSize` | `10.0` | Y轴标签字号 |

---

## 18. 文本样式令牌 (SpitoutTextTokens)

**注意：** 这些方法已自动适配暗黑模式文字颜色。

```dart
// 标题样式（列表主标题）- 16px w400
SpitoutTextTokens.title(context)

// 强调标题（统计数字）- 16px w600
SpitoutTextTokens.strongTitle(context)

// 加粗标题（大额数字）- 18px w800
SpitoutTextTokens.boldTitle(context)

// 正文样式 - 14px w400
SpitoutTextTokens.body(context)

// 标签/说明样式 - 12px，颜色取 textSecondary
SpitoutTextTokens.label(context)

// 小字/角标 - 10px，颜色取 textSecondary
SpitoutTextTokens.caption(context)

// 大额数字 display 系列 - 22 / 26 / 32px，w800
SpitoutTextTokens.display1(context)
SpitoutTextTokens.display2(context)
SpitoutTextTokens.display3(context)
```

---

## 19. 字体令牌 (SpitoutTypography)

用于构建主题的基础文本样式。

```dart
// 构建文本主题
final textTheme = SpitoutTypography.buildBase(
  Theme.of(context).textTheme,
  isIOS: Platform.isIOS,
);
```

### 字体配置常量

| 常量 | 值 | 说明 |
|------|-----|------|
| `useBundledFonts` | `false` | 已禁用打包字体，使用系统字体 |
| `bundledLatin` | `'Inter'` | 打包时的 Latin 字体族 |
| `bundledCJK` | `'NotoSansSC'` | 打包时的中文字体族 |
| `systemCJKiOS` | `'PingFang SC'` | iOS 系统中文字体 |

> `buildBase` 会根据 `useBundledFonts` 与 `isIOS` 决定最终字体族：
> - iOS：Latin 用 `Helvetica Neue`，CJK 用 `PingFang SC`
> - 非 iOS 且未打包：Latin 用 `Roboto`，CJK 用 `NotoSans`
> - 非 iOS 且打包：Latin 用 `Inter`，CJK 用 `NotoSansSC`

---

## 辅助方法

```dart
// 判断当前是否为暗黑模式
final isDark = SpitoutTokens.isDark(context);
```

---

## 暗黑模式设计原则

Spitout 暗黑模式基于 **shadcn dark 调色板**，通过不同深度的灰色区分层级：

1. **页面背景**：`#111827`（shadcn background dark，非纯黑）
2. **卡片背景**：`#1F2937`（shadcn card dark）
3. **次级背景**：`#374151`（shadcn secondary dark，嵌套卡片/输入框/Chip 等）
4. **二级分类图标底（暗）**：`#3A3A3C`（`surfaceCategoryIconLight`）
5. **分类图标背景**：`#48484A`（未选中状态）
6. **边框**：常规边框统一 `#F3F4F6` 10% 透明度；亮色模式用阴影替代边框
7. **去除卡片内分割线**：暗黑模式下 `cardInnerDividerHeight` 为 0
8. **反转色**：FAB 等反色组件用 `surfaceInverse`（暗黑=白）+ `onSurfaceInverse`（暗黑=黑）

---

## 使用检查清单

在替换颜色时，请按以下顺序检查：

- [ ] `Scaffold.backgroundColor` → `SpitoutTokens.scaffoldBackground(context)`
- [ ] 卡片/容器背景 → `SpitoutTokens.surface(context)`
- [ ] 首页头部汇总卡 → `Theme.of(context).colorScheme.primary` + `SpitoutTokens.textOnPrimary(context)`
- [ ] BottomSheet 背景 → `SpitoutTokens.surfaceSheet(context)`
- [ ] 键盘容器 → `SpitoutTokens.keypadBackground(context)`；键盘按键 → `SpitoutTokens.keyDigit(context)`
- [ ] 输入框背景 → `SpitoutTokens.surfaceInput(context)`
- [ ] Chip/标签背景 → `SpitoutTokens.surfaceChip(context)`
- [ ] FAB/浮动按钮背景 → `SpitoutTokens.surfaceInverse(context)` + `onSurfaceInverse(context)`
- [ ] 文字颜色 → `textPrimary` / `textSecondary` / `textTertiary`
- [ ] 图标颜色 → `iconPrimary` / `iconSecondary` / `iconTertiary` / `iconCategory`
- [ ] 分割线 → 使用 `SpitoutTokens.cardDivider(context)`
- [ ] 状态颜色 → `success` / `warning` / `error` / `info`；在线/离线/待处理 → `statusOnline` / `statusOffline` / `statusPending`
- [ ] 支出金额颜色 → 订阅 `expenseColorSchemeProvider`：`== 'green' ? SpitoutTokens.success(context) : SpitoutTokens.error(context)`（必须 `ref.watch`，`ref.read` 不生效）
- [ ] 品牌图标 → `brandLocal` / `brandSupabase` / `brandWebdav` / `brandS3` / `brandCloud`
- [ ] 底部导航栏 → `SpitoutTokens.tabBarBackground(context)`
- [ ] 底部弹层拖拽条 → `SpitoutTokens.grabHandleColor(context)`
- [ ] 折线图数据线/点 → `SpitoutTokens.chartExpense(context)`
