#!/usr/bin/env bash
#
# 统一测试入口（本地 / CI 通用）
# ──────────────────────────────────────────────────────────────────
# 设计意图：
#   1. 默认开启 `--test-randomize-ordering-seed=random`，让每次运行都在
#      随机用例顺序下执行，持续暴露"用例间顺序依赖"这类隐藏隐患。
#      （无失败 ≠ 无隐患：顺序依赖只在特定排列下才暴露，固定顺序会掩盖它。）
#   2. 优先使用项目约定的 `fvm flutter`，本地缺失 fvm 时自动回退到系统
#      `flutter`，保证脚本在 CI（无 fvm）与本地（有 fvm）都能直接跑。
#
# 用法：
#   ./scripts/run_tests.sh                            # 全量测试（随机顺序）
#   ./scripts/run_tests.sh test/path/to_x_test.dart   # 只跑指定文件
#   ./scripts/run_tests.sh --help                     # 透传给 flutter test 的帮助

set -euo pipefail

# fvm 存在则用它（与本地开发约定一致），否则回退到 PATH 中的 flutter。
if command -v fvm >/dev/null 2>&1; then
  FLUTTER_BIN=(fvm flutter)
else
  FLUTTER_BIN=(flutter)
fi

# 始终随机化用例执行顺序：把"顺序依赖"变成一定会偶尔复现的失败，
# 从而推动各文件在 setUp/tearDown 中正确隔离跨用例的全局状态。
exec "${FLUTTER_BIN[@]}" test --test-randomize-ordering-seed=random "$@"
