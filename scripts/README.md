# 项目工具脚本

本目录包含项目的各种开发工具脚本。

## 📁 目录结构

```
scripts/
├── i18n/              # 国际化翻译管理工具
│   ├── check_unused_i18n.dart
│   ├── clean_unused_i18n.dart
│   └── verify_translations.dart
├── run_tests.sh       # 统一测试入口（bash，默认随机顺序）
├── run_tests.ps1      # 统一测试入口（PowerShell，Windows 原生）
└── README.md          # 本文件
```

## 🛠️ 工具分类

### 📝 i18n 管理工具

- **check_unused_i18n.dart** - 检测未使用的翻译 keys
- **clean_unused_i18n.dart** - 清理未使用的翻译 keys
- **verify_translations.dart** - 验证中英文翻译完整性

### 🧪 测试运行工具

- **run_tests.sh / run_tests.ps1** - 统一测试入口，默认开启 `--test-randomize-ordering-seed=random`，
  让每次运行都在随机用例顺序下执行，持续暴露"用例间顺序依赖"隐患（直接使用 PATH 中的系统 `flutter`，不依赖 fvm）。

## 🚀 快速开始

### i18n 工具使用

```bash
# 验证中英文翻译完整性
dart scripts/i18n/verify_translations.dart

# 检测未使用的 keys
dart scripts/i18n/check_unused_i18n.dart

# 清理未使用的 keys
dart scripts/i18n/clean_unused_i18n.dart
```

### 测试运行（随机顺序）

```bash
# 全量测试（随机用例顺序，持续暴露顺序依赖）
./scripts/run_tests.sh              # macOS / Linux / 任意带 bash 环境
.\scripts\run_tests.ps1             # Windows PowerShell 原生

# 只跑指定文件（参数原样透传给 flutter test）
./scripts/run_tests.sh test/pages/category/category_template_logic_test.dart
```

> CI 中对应的 `.github/workflows/test.yml` 已默认以随机顺序运行全量测试，
> 无需手动指定参数。

## 💡 添加新工具

如果要添加新的工具分类，建议的结构：

```
scripts/
├── category_name/
│   ├── tool1.dart
│   ├── tool2.dart
│   └── README.md
└── README.md
```

每个工具目录应包含：
1. 工具脚本文件（.dart）
2. README.md 说明文档
3. 必要的配置文件