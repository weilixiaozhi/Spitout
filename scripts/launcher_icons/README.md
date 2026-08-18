# 启动图标生成工具

将品牌源文件 `assets/brand/ic_launcher_spitout.svg` 栅格化为 `flutter_launcher_icons` 所需的 PNG。

## 📋 为什么需要这个脚本

`flutter_launcher_icons` 内部使用 `image` 包解码源图，仅支持位图（png/jpg），无法直接读取 SVG。本脚本借助项目已依赖的 `flutter_svg`，把矢量源图渲染成高分辨率 PNG，作为 flutter_launcher_icons 的输入。

**SVG 始终是唯一的设计源，PNG 为可再生的中间产物**，修改图标只需改 SVG 再重新运行本脚本。

## 🚀 使用方法

在项目根目录执行：

```bash
flutter test scripts/launcher_icons/rasterize_svg.dart
```

输出到 `assets/flutter_launcher_icons/`，均为 1024×1024：

| 文件 | 背景 | 用途 |
|------|------|------|
| adaptive_foreground.png | 透明 | 自适应图标前景层 |
| adaptive_monochrome.png | 透明 | 自适应单色层（主题化） |
| launcher_legacy.png | 白色 | 旧版整图标（深色桌面可见） |

## 🔄 修改图标流程

1. 修改 `assets/brand/ic_launcher_spitout.svg`
2. 重新运行本脚本生成 PNG
3. 运行 `flutter pub run flutter_launcher_icons` 生成各平台启动图标

## ⚠️ 注意事项

1. SVG 需为正方形 viewBox，图形居中并预留安全留白（自适应图标安全区）
2. 脚本按 SVG 真实尺寸等比 contain 缩放，不依赖固定视图大小
3. 需要项目已配置 `flutter_svg` 依赖（本仓库已包含）
