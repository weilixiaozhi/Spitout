# 统一测试入口（Windows / PowerShell）
# ──────────────────────────────────────────────────────────────────
# 设计意图：
#   1. 默认开启 --test-randomize-ordering-seed=random，每次运行都在随机用例
#      顺序下执行，持续暴露"用例间顺序依赖"这类隐藏隐患。
#      （无失败 ≠ 无隐患：顺序依赖只在特定排列下才暴露，固定顺序会掩盖它。）
#   2. 优先使用项目约定的 fvm flutter，本地缺失 fvm 时回退到系统 flutter。
#
# 用法：
#   .\scripts\run_tests.ps1                            # 全量测试（随机顺序）
#   .\scripts\run_tests.ps1 test/path/to_x_test.dart   # 只跑指定文件

if (Get-Command fvm -ErrorAction SilentlyContinue) {
    # 优先使用项目约定的 fvm 管理的 Flutter SDK。
    fvm flutter test --test-randomize-ordering-seed=random @args
} else {
    # 本地无 fvm 时回退到 PATH 中的 flutter（与 CI 行为一致）。
    flutter test --test-randomize-ordering-seed=random @args
}
