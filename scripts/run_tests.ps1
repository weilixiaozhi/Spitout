# 统一测试入口（Windows / PowerShell）
# ──────────────────────────────────────────────────────────────────
# 设计意图：
#   1. 默认开启 --test-randomize-ordering-seed=random，每次运行都在随机用例
#      顺序下执行，持续暴露"用例间顺序依赖"这类隐藏隐患。
#      （无失败 ≠ 无隐患：顺序依赖只在特定排列下才暴露，固定顺序会掩盖它。）
#   2. 直接使用 PATH 中的系统 flutter（已弃用 fvm，不锁定 SDK 版本）。
#
# 用法：
#   .\scripts\run_tests.ps1                            # 全量测试（随机顺序）
#   .\scripts\run_tests.ps1 test/path/to_x_test.dart   # 只跑指定文件

flutter test --test-randomize-ordering-seed=random @args
