# Android keystore 生成工具

一键生成 Android 发布签名 keystore，并自动写入 `android/key.properties`，用于正式发布签名。

> ⚠️ **keystore 丢失后无法给老用户推送升级包，且永远无法恢复，务必多重备份。**

## 📋 工具说明

| 平台 | 脚本 | 说明 |
|------|------|------|
| Windows | generate_android_keystore.ps1 | PowerShell 实现 |
| macOS / Linux | generate_android_keystore.sh | Bash 实现，与 .ps1 等价 |

两个脚本功能一致：

1. **生成 keystore** — 调用 JDK `keytool` 生成 RSA 2048 位、默认 10 年有效期的发布签名
2. **写入 key.properties** — 自动写入路径和密码，`storeFile` 为相对 `android/app` 的路径（与 Gradle 解析规则一致）
3. **备份提醒** — 输出密码、异地备份和 GitHub Actions Secret 配置指引

## 🚀 使用方法

### Windows（PowerShell）

```powershell
# 交互式生成，全部使用默认值/随机值
.\scripts\android_keystore\generate_android_keystore.ps1

# 指定别名与 20 年有效期
.\scripts\android_keystore\generate_android_keystore.ps1 -Alias spitout-release -Validity 7300
```

参数：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| OutFile | android/app/release.keystore | keystore 输出路径 |
| Alias | release | 密钥别名 |
| Validity | 3650（约 10 年） | 证书有效期（天） |
| DName | CN=Unknown, ... | 证书持有者信息，**请替换为真实信息** |

### macOS / Linux（Bash）

```bash
# 交互式
bash scripts/android_keystore/generate_android_keystore.sh

# 非交互指定参数
bash scripts/android_keystore/generate_android_keystore.sh \
    -o android/app/release.keystore \
    -a spitout-release \
    -p my-store-pass \
    -k my-key-pass \
    -d "CN=Your Name, OU=Dev, O=Company, L=City, S=State, C=CN" \
    -v 7300
```

参数：`-o` 输出路径，`-a` 别名，`-p` store 密码，`-k` key 密码，`-d` DName，`-v` 有效期（天）。

## 🔐 密码处理

- 优先使用环境变量 `KEYSTORE_PASSWORD` / `KEY_PASSWORD`
- 其次交互输入
- 留空则自动生成 16 位随机密码（会打印在终端，请注意保存）

## 💡 最佳实践

1. **生成后立即备份**：keystore 文件 + 密码做异地多重备份（另一硬盘 + 云盘加密 + U 盘离线）
2. **DName 填真实信息**：不要使用默认占位
3. **key.properties 已加入 .gitignore**（含所有 `.keystore`），不会入库；提交前可再确认
4. **CI 签名**：将 keystore 转为 base64 存入 GitHub Secrets：

```powershell
[Convert]::ToBase64String([System.IO.File]::ReadAllBytes('android/app/release.keystore'))
```

然后在 GitHub 仓库 Settings → Secrets → Actions 添加：`KEYSTORE_BASE64` / `KEYSTORE_PASSWORD` / `KEY_ALIAS` / `KEY_PASSWORD`

## ⚠️ 注意事项

1. 需要安装 Java JDK 17+（包含 keytool），或通过 `JAVA_HOME` / PATH 可用
2. 目标 keystore 已存在时会询问是否覆盖，覆盖操作不可恢复
3. 密码只写入 `android/key.properties`，不会写入脚本文件
