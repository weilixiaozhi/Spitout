# 应用图标生成与修改指南

本文说明 Spitout 应用**启动图标**（Android，含自适应前景层 / 单色层 / 旧版整图标）的生成流程、产物清单，以及后续更换图标与调整留白的操作步骤。

> 本文档涵盖**两条相互独立的链路**：① 应用启动图标（launcher icon，见第一～六节）；② 应用内品牌 Logo（SpitoutIcon，见第七节）。二者互不影响，切换时需分别处理。

## 一、核心约束（为什么有两步）

`flutter_launcher_icons`（当前锁定 `^0.14.4`）内部使用 `image` 包解码图片，**只支持位图（PNG 等），读不了 SVG 源文件**。

而图标的设计源是 SVG（矢量，可无损缩放、易修改）。因此流程被拆成两步：

1. **SVG → PNG**：先把矢量源栅格化成 `flutter_launcher_icons` 能吃的位图（桥接）。
2. **PNG → 各平台尺寸**：再交给 `flutter_launcher_icons` 生成所有密度的启动图标。

> 之所以第 1 步用 `flutter test` 命令（而不是 `dart run`）：
> 栅格化脚本依赖 `dart:ui` 的 `Picture.toImage()` 把矢量渲染成位图，而 `dart:ui` 的渲染能力只在 Flutter 运行环境里可用。`flutter test` 会通过 `TestWidgetsFlutterBinding.ensureInitialized()` 初始化无头渲染环境，脚本才能正常绘图；裸跑 `dart run` 没有渲染引擎会直接崩溃。此外 `flutter test` 必须至少有一个 `test()` 用例才会执行 `main`，因此脚本逻辑包在 `test(...)` 内。

## 二、文件角色

| 文件 | 角色 | 是否需要手动维护 |
| --- | --- | --- |
| `assets/brand/ic_launcher_spitout.svg` | 图标**唯一设计源**（矢量，192×192 视图，多色图形 + 透明背景，图形已居中并预留安全留白） | ✅ 换图标/调大小只改这个 |
| `scripts/launcher_icons/rasterize_svg.dart` | SVG→PNG 桥接脚本 | 一般不动 |
| `assets/flutter_launcher_icons/*.png` | 栅格化生成的**中间产物** | 自动生成，可忽略 |
| `pubspec.yaml` 末尾 `flutter_launcher_icons:` | 生成配置（含背景色、前景内缩 inset 等） | 换背景色 / 调安全留白时改 |
| `android/app/src/main/res/...` | 最终落盘的启动图标 | 自动生成，勿手改 |

## 三、完整流程

### 第 1 步：SVG 栅格化为 PNG

```powershell
flutter test scripts/launcher_icons/rasterize_svg.dart
```

脚本用项目已有的 `flutter_svg` 渲染源 SVG，输出 3 张 1024px 中间产物到 `assets/flutter_launcher_icons/`：

- `adaptive_foreground.png` —— 透明底多色图标（灰 + 黄，自适应前景层）
- `adaptive_monochrome.png` —— 透明底多色图标（与前景层同源，作为 Android 13+ 主题图标层输入，由系统着色）
- `launcher_legacy.png` —— **白底**多色图标（旧版整图标，保证深/浅色桌面都可见）

### 第 2 步：生成各平台尺寸图标

```powershell
flutter pub run flutter_launcher_icons
```

使用 `flutter pub run` 而非 `dart run`，确保用 Flutter SDK 内置的 Dart 解析依赖（避免系统 Dart 与 Flutter SDK 的 `intl` 版本不一致导致解析失败）。

读取 `pubspec.yaml` 末尾配置，生成 Android 全部密度的启动图标、自适应图标 XML 及背景色。

> 若首次或从零开始，请先执行 `flutter pub get` 拉取 `flutter_launcher_icons` 依赖。

## 四、生成产物（落盘在 Android 工程中）

- `android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher*.png` —— 各分辨率启动图标
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` —— 自适应图标描述（引用 `ic_launcher_background` + `ic_launcher_foreground`）
- `android/app/src/main/res/values/colors.xml` —— `ic_launcher_background = #FFFFFF`（白底）
- `android/app/src/main/res/drawable-{h,..,xxxh}dpi/ic_launcher_monochrome.png` —— 单色层

## 五、以后更换图标的步骤

1. **替换** `assets/brand/ic_launcher_spitout.svg`（唯一需要改的源文件）。该 SVG 已 authored 为 `viewBox="0 0 192 192"`、图形居中且预留安全留白，直接改其内部的图形尺寸/位置即可（仍需重跑下面两步命令）。
2. 执行两步命令：
   ```powershell
   flutter test scripts/launcher_icons/rasterize_svg.dart
   flutter pub run flutter_launcher_icons
   ```
3. 若桌面仍显示异常，清一次构建缓存避免旧资源冲突：
   ```powershell
   flutter clean
   ```

### 可选配置修改

- 换图标的**背景色**：改 `pubspec.yaml` 里的 `adaptive_icon_background`（当前 `#FFFFFF`）。
- 调整图标大小/留白（两种方式，当前采用第二种）：
  - **改 SVG 源**：直接编辑 `ic_launcher_spitout.svg` 内部的图形尺寸即可。
    该源文件已 authored 为 `viewBox="0 0 192 192"`，图形本身居中、占据约 128×128、
    四周空白约 30px。若要整体放大/缩小图标，按比例缩放图形并重新居中即可（保持 `viewBox` 仍为 `0 0 192 192`）。
    > ⚠️ **注意**：SVG 的 30px 留白并非直接等同于 Android 66dp 安全圆区。按比例换算：
    > 图形占 128/192 ≈ 66.7%，而 Android 自适应图标安全圆区仅占 66/108 ≈ 61.1%。
    > 即仅靠 SVG 留白不足以让图形完全落入安全圆区，**需配合下面的 `inset` 配置才能避免四边裁切**。
  - **改配置（当前采用）**：编辑 `pubspec.yaml` 末尾的 `adaptive_icon_foreground_inset` / `adaptive_icon_monochrome_inset`（当前 `13`），
    单位为百分比，数值越大前景/单色层在遮罩内缩得越小。当前 `13%` 内缩使得图形实际占比降至约 49.4%（66.7% × 74%），
    远小于 Android 66dp 安全圆区（61.1%），确保四边均不被系统遮罩裁切。

## 六、备注

- `assets/flutter_launcher_icons/*.png` 当前**未加入 `.gitignore`**，因此 `flutter pub run flutter_launcher_icons` 可直接运行。若希望仓库严格「只保留 SVG+XML 源文件」，可将这些中间 PNG 加入 `.gitignore`，改为每次依赖栅格脚本现生成。
- 配置块位置（`pubspec.yaml` 末尾）：

```yaml
# 重新生成应用启动图标（修改 pubspec 的 flutter_launcher_icons 配置后执行）
#   flutter pub run flutter_launcher_icons
# 说明：flutter_launcher_icons 仅支持位图，源 SVG 需先栅格化：
#   flutter test scripts/launcher_icons/rasterize_svg.dart
flutter_launcher_icons:
  android: true
  image_path: assets/flutter_launcher_icons/launcher_legacy.png
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: assets/flutter_launcher_icons/adaptive_foreground.png
  # 13% 内缩使图形实际占比降至 ~49.4%，充分落入 Android 66dp 安全圆区（66/108≈61.1%）
  adaptive_icon_foreground_inset: 13
  adaptive_icon_monochrome: assets/flutter_launcher_icons/adaptive_monochrome.png
  adaptive_icon_monochrome_inset: 13
```

## 七、应用内品牌 Logo（SpitoutIcon）更换流程

> 本节独立于「启动图标」链路。应用内展示的品牌 Logo（欢迎页、锁屏页、我的页头像占位、无头像预览）由 `lib/widgets/spitout_icon.dart` 的 `SpitoutIcon` 组件渲染，**不**经过 `flutter_launcher_icons`。

### 1. 当前状态

- 生效源：`assets/brand/ic_launcher_spitout.svg`（矢量图标，已就位）
- 渲染组件：`SpitoutIcon` 用 `SvgPicture.asset('assets/brand/ic_launcher_spitout.svg')`
- 备用源：`assets/brand/ic_launcher_spitout.png` 已被删除（如需换回 PNG 见第五节，并重新栅格化）
- 资源注册：`pubspec.yaml` 的 `flutter.assets` 仅含 `.svg`（PNG 注册已随文件删除一并移除）

### 2. 两种源格式取舍（先判断要不要切）

| 维度 | SVG（矢量） | PNG（位图） |
| --- | --- | --- |
| 放大清晰度 | 任意 size 都清晰 | 超过原生分辨率（≥1024px）会糊 |
| 源文件可编辑性 | 可直接改图形 | 二进制，需重新栅格化 |
| 兼容性风险 | 本 SVG 实际是「非矢量」（内嵌 base64 位图 + `<pattern>`+`<use>`），`flutter_svg` 解析偶有兼容坑 | 用 `Image.asset` 渲染最稳，绕开 `flutter_svg` |
| 与启动图标同源 | 同源于一份 SVG | 需先栅格化，同源但多一步 |

> 结论：追求清晰 / 可编辑选 **SVG**；遇到 `flutter_svg` 渲染异常或想彻底规避矢量解析风险选 **PNG**（但须保证 PNG ≥1024px）。

### 3. 切换操作总览

| 切换方向 | 要改的文件 | 要改的 pubspec | 要跑的命令 |
| --- | --- | --- | --- |
| PNG → SVG（第四节） | `spitout_icon.dart` 全文替换 | 移除 `.png` 注册 | `fvm flutter pub get` |
| SVG → PNG（第五节） | `spitout_icon.dart` 全文替换 + 生成 PNG | 新增 `.png` 注册 | 栅格化 + 复制 + `fvm flutter pub get` |

> ⚠️ **关键约束**：`pubspec.yaml` 的 `flutter.assets` 里，**写了但文件不存在的资产会直接导致构建失败**。因此「切到哪边」和「资产注册哪边」必须同步，缺一不可。下面每个流程都按此顺序给全。

### 4. PNG → SVG（改回矢量）完整步骤

适用：当前 `SpitoutIcon` 用 PNG（或想从位图切回矢量）。

#### 4.1 前置检查
确认源文件存在，否则先恢复 / 重新放置：
```
assets/brand/ic_launcher_spitout.svg
```

#### 4.2 用下面全文**整体替换** `lib/widgets/spitout_icon.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 应用品牌图标组件
///
/// 设计意图：品牌图以矢量 SVG（ic_launcher_spitout.svg）提供，可无损缩放、
/// 多色配色硬编码在图内，不随主题色变化，因此本组件不接受 color 参数。
/// 使用 [SvgPicture.asset] 渲染矢量源，相较 PNG 在任意 size 下均清晰、且
/// 源文件可直接编辑。注意：本 SVG 实际为「非矢量」（内嵌 base64 位图），
/// 但若后续替换为真正矢量源，此渲染方式同样适用。
class SpitoutIcon extends StatelessWidget {
  final double size;

  const SpitoutIcon({super.key, this.size = 256});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/brand/ic_launcher_spitout.svg',
      width: size,
      height: size,
    );
  }
}
```

> 要点：必须 `import 'package:flutter_svg/flutter_svg.dart';`，并在 `build` 里返回 `SvgPicture.asset(...)`。`size` 参数与对外接口保持不变，调用方无需改动。

#### 4.3 调整 `pubspec.yaml` 的资产注册

打开 `pubspec.yaml`，定位 `flutter.assets` 段（在 `flutter:` 下）。**删除** `.png` 那一行，只保留 `.svg`：

```yaml
  assets:
    - assets/brand/ic_launcher_spitout.svg
    # - assets/brand/ic_launcher_spitout.png   # ← 切到 SVG 时注释或删除此行
```

#### 4.4 执行命令

```powershell
# 因增删了 pubspec 资产，必须刷新资源清单（否则运行期报 MissingAssetError）
fvm flutter pub get
```

#### 4.5 验证

```powershell
fvm flutter analyze        # 确认无编译/导入错误
fvm flutter run            # 观察欢迎页/锁屏页/我的页品牌图标正常显示
```

---

### 5. SVG → PNG（改为位图）完整步骤

适用：遇到 `flutter_svg` 渲染异常，或想规避矢量解析风险，改用位图。

#### 5.1 栅格化生成 PNG 中间产物

启动图标用的栅格化脚本会把 SVG 渲染成 PNG，并把产物写到 `assets/flutter_launcher_icons/`（**不是**品牌目录）。在仓库根目录执行：

```powershell
fvm flutter test scripts/launcher_icons/rasterize_svg.dart
```

执行后生成：
```
assets/flutter_launcher_icons/adaptive_foreground.png   # 透明底多色（与品牌图同源）
assets/flutter_launcher_icons/adaptive_monochrome.png   # 单色层
assets/flutter_launcher_icons/launcher_legacy.png       # 白底整图标
```

> 为什么用 `flutter test` 而非 `dart run`：脚本依赖 `dart:ui` 的 `Picture.toImage()` 渲染矢量，该能力只在 Flutter 运行环境可用；`flutter test` 通过 `TestWidgetsFlutterBinding` 初始化无头渲染环境才能绘图。详见本文第一节说明。

#### 5.2 复制产物到品牌目录（重命名为品牌文件名）

品牌 Logo 需要的是透明底、与 `SpitoutIcon` 同名的 PNG，直接复用 `adaptive_foreground.png` 即可（二者同源）：

```powershell
Copy-Item -Path assets/flutter_launcher_icons/adaptive_foreground.png `
         -Destination assets/brand/ic_launcher_spitout.png -Force
```

> 也可手动在文件管理器里把 `adaptive_foreground.png` 复制并重命名为 `ic_launcher_spitout.png` 放到 `assets/brand/`。PNG 已是 1024px，覆盖目前最大使用尺寸（256）绰绰有余。

#### 5.3 用下面全文**整体替换** `lib/widgets/spitout_icon.dart`

```dart
import 'package:flutter/material.dart';

/// 应用品牌图标组件
///
/// 设计意图：品牌图以 PNG（ic_launcher_spitout.png）提供，多色配色
/// 硬编码在图内，不随主题色变化，因此本组件不接受 color 参数。
/// 直接以 [Image.asset] 渲染，规避 flutter_svg 对非矢量 SVG
/// （内嵌位图）的潜在兼容风险，且与启动图标同源、结果更可控。
class SpitoutIcon extends StatelessWidget {
  final double size;

  const SpitoutIcon({super.key, this.size = 256});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/ic_launcher_spitout.png',
      width: size,
      height: size,
    );
  }
}
```

> 要点：PNG 模式**不需要** `flutter_svg` 导入，用 `Image.asset(...)` 即可。

#### 5.4 调整 `pubspec.yaml` 的资产注册

定位 `flutter.assets`，**确保** `.png` 注册存在（与 `.svg` 并存）：

```yaml
  assets:
    - assets/brand/ic_launcher_spitout.svg
    - assets/brand/ic_launcher_spitout.png   # ← 切到 PNG 时确保此行存在
```

#### 5.5 执行命令

```powershell
# 因新增了 .png 资产，必须刷新资源清单
fvm flutter pub get
```

#### 5.6 验证

```powershell
fvm flutter analyze        # 确认无编译/导入错误（注意 PNG 模式不应再 import flutter_svg）
fvm flutter run            # 观察品牌图标正常显示
```

### 6. 影响面（改动 SpitoutIcon 后无需改调用方）

`SpitoutIcon` 仅接收 `size` 参数、接口不变。当前调用点：

- `lib/pages/auth/welcome_page.dart`（size 120）
- `lib/pages/auth/app_lock_screen.dart`（size 64）
- `lib/widgets/mine_page_header.dart`（size 44）
- `lib/widgets/avatar_preview_page.dart`（size 120）
