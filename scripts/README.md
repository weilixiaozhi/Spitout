# 项目工具脚本

本目录包含项目的各种开发工具脚本。

## 📁 目录结构

```
scripts/
├── android_keystore/   # Android 发布签名 keystore 生成工具
│   ├── generate_android_keystore.ps1   # Windows (PowerShell)
│   ├── generate_android_keystore.sh    # macOS / Linux (Bash)
│   └── README.md
├── i18n/               # 国际化翻译管理工具
│   ├── align_arb.dart      # ARB 对齐（键序/元数据/缩进）
│   ├── check_status.dart   # 检查与清理
│   └── README.md
├── launcher_icons/     # 启动图标生成工具
│   ├── rasterize_svg.dart
│   └── README.md
└── README.md           # 本文件
```

## 🛠️ 工具分类

### 🔑 android_keystore — keystore 生成

一键生成 Android 发布 keystore 并写入 `android/key.properties`：

- **generate_android_keystore.ps1** — Windows 版（PowerShell）
- **generate_android_keystore.sh** — macOS / Linux 版（Bash），与 .ps1 等价

详见 [android_keystore/README.md](android_keystore/README.md)。

### 📝 i18n — 国际化翻译管理

- **align_arb.dart** — 对齐三个 ARB 文件：键顺序、`@` 元数据、`@@locale`、4 空格缩进
- **check_status.dart** — 综合检查与清理：翻译完整性、多余 keys、未使用 keys

详见 [i18n/README.md](i18n/README.md)。

### 🖼️ launcher_icons — 启动图标生成

- **rasterize_svg.dart** — 将 SVG 源图标栅格化为 flutter_launcher_icons 所需的 PNG

详见 [launcher_icons/README.md](launcher_icons/README.md)。

## 🚀 快速开始

```bash
# 生成 Android 发布 keystore（Windows）
powershell -ExecutionPolicy Bypass -File scripts/android_keystore/generate_android_keystore.ps1

# 生成 Android 发布 keystore（macOS / Linux）
bash scripts/android_keystore/generate_android_keystore.sh

# i18n 检查与清理
dart scripts/i18n/check_status.dart

# i18n 对齐（新增/删除翻译键后运行）
dart scripts/i18n/align_arb.dart

# 图标栅格化（先改 SVG，再执行）
flutter test scripts/launcher_icons/rasterize_svg.dart
```

## 💡 添加新工具

如果要添加新的工具分类，建议的结构：

```
scripts/
├── category_name1/
│   ├── tool.dart
│   └── README.md
├── category_name2/
│   ├── tool.dart
│   └── README.md
└── README.md
```

每个工具目录应包含：
1. 工具脚本文件
2. README.md 说明文档
3. 必要的配置文件
