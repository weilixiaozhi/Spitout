<#
.SYNOPSIS
    Windows 下一键生成 Android 发布 keystore，并写入 android/key.properties。

.DESCRIPTION
    与同目录 generate_android_keystore.sh（macOS/Linux）等价，使用 PowerShell 实现。
    生成的 keystore 用于正式发布签名：**丢失后无法给老用户推送升级包，务必多重备份**。

.PARAMETER OutFile
    keystore 输出路径，默认 android/app/release.keystore（相对仓库根目录解析）。

.PARAMETER Alias
    密钥别名，默认 release。

.PARAMETER Validity
    证书有效期（天），默认 3650（约 10 年）。

.PARAMETER DName
    证书持有者信息（CN/OU/O/L/S/C）。请替换为你的真实信息，勿用默认占位。

.EXAMPLE
    .\generate_android_keystore.ps1
    交互式生成，全部使用默认值/随机值。

.EXAMPLE
    .\generate_android_keystore.ps1 -Alias spitout-release -Validity 7300
    指定别名与 20 年有效期。
#>
param(
    [string]$OutFile = "",
    [string]$Alias = "",
    [int]$Validity = 3650,
    [string]$DName = "CN=Unknown, OU=Dev, O=Org, L=City, S=State, C=CN"
)

$ErrorActionPreference = 'Stop'

# 仓库根目录：脚本位于 scripts/android_keystore，向上两级即为仓库根
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
# Join-Path 在 PowerShell 5.1 仅接受「父路径 + 单个子路径」两个参数，
# 多段路径需嵌套调用；这里用 (Join-Path 父 子) 再拼下一段，保证各版本兼容。
$AppDir = Join-Path (Join-Path $RepoRoot "android") "app"
# 默认 keystore 放在 android/app 下，这样 key.properties 里 storeFile 可直接用相对文件名
# "release.keystore"，与 Gradle 中 file() 相对于 app 模块解析的规则一致。
$KeystoreDefault = Join-Path $AppDir "release.keystore"

# ---------- 解析输出路径 ----------
if (-not $OutFile) {
    # Read-Host 在非交互终端下可能返回 $null，直接对 $null 调 .Trim() 会报
    # MethodArgumentConversionInvalidCastArgument，因此先判空再清洗。
    $inputPath = Read-Host "输出 keystore 路径 [$KeystoreDefault]"
    if ($inputPath) {
        $inputPath = $inputPath.Trim().Replace([char]0xFEFF, '')
    }
    if (-not $inputPath) { $OutFile = $KeystoreDefault } else { $OutFile = $inputPath }
}
if (-not [System.IO.Path]::IsPathRooted($OutFile)) {
    $OutFile = Join-Path $RepoRoot $OutFile
}
$OutFile = [System.IO.Path]::GetFullPath($OutFile)
$OutDir = Split-Path -Parent $OutFile
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

# ---------- 已存在则确认覆盖 ----------
if (Test-Path $OutFile) {
    $ans = Read-Host "检测到已存在 keystore: $OutFile`n是否覆盖? (y/N)"
    if ($ans -notmatch '^[Yy]$') {
        Write-Error "已取消。请使用 -OutFile 指定新路径，或删除现有文件后重试。"
        exit 1
    }
    Remove-Item -Force $OutFile
}

# ---------- 别名 ----------
if (-not $Alias) {
    $a = Read-Host "Key Alias [release]"
    $Alias = if ($a) { $a } else { "release" }
}

# ---------- 密码（优先环境变量，其次交互，再其次随机生成） ----------
$StorePass = $env:KEYSTORE_PASSWORD
if (-not $StorePass) {
    $sp = Read-Host -Prompt "Keystore 密码 [留空则自动生成 16 位随机密码]"
    if ($sp) {
        $StorePass = $sp
    } else {
        # 16 位 数字/大写/小写 随机密码
        $chars = (48..57) + (65..90) + (97..122)
        $StorePass = -join ($chars | Get-Random -Count 16 | ForEach-Object { [char]$_ })
        Write-Host "已生成随机 Keystore 密码: $StorePass"
    }
}

$KeyPass = $env:KEY_PASSWORD
if (-not $KeyPass) {
    $kp = Read-Host -Prompt "Key 密码 (回车同 Keystore 密码)"
    $KeyPass = if ($kp) { $kp } else { $StorePass }
}

# ---------- 定位 keytool ----------
$keytool = $null
if ($env:JAVA_HOME) {
    $candidate = Join-Path $env:JAVA_HOME "bin" "keytool.exe"
    if (Test-Path $candidate) { $keytool = $candidate }
}
if (-not $keytool) {
    $keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
}
if (-not $keytool) {
    Write-Error "未找到 keytool。请安装 Java JDK 17+ 并确保在 PATH 中，或设置 JAVA_HOME 环境变量。"
    exit 1
}
Write-Host "使用 keytool: $keytool"

# ---------- 调用 keytool 生成 keystore ----------
# 使用参数数组传递，避免 DName 中的空格/逗号被破坏（JDK 17+ 用 -genkeypair）
$argsList = @(
    '-genkeypair', '-noprompt',
    '-alias', $Alias,
    '-keystore', $OutFile,
    '-storepass', $StorePass,
    '-keypass', $KeyPass,
    '-dname', $DName,
    '-validity', $Validity.ToString(),
    '-keyalg', 'RSA',
    '-keysize', '2048'
)

Write-Host "正在生成 keystore: $OutFile"
& $keytool @argsList
if ($LASTEXITCODE -ne 0) {
    Write-Error "keytool 生成 keystore 失败 (exit=$LASTEXITCODE)"
    exit 1
}

# ---------- 计算相对路径并写入 key.properties ----------
# Gradle 的 file(storeFile) 相对于 android/app 目录解析，因此写入相对路径。
# 不使用 [System.IO.Path]::GetRelativePath（.NET Core 2.0+ 才有），
# 改用字符串前缀匹配，兼容 PowerShell 5.1 的旧版 .NET Framework。
$sep = [System.IO.Path]::DirectorySeparatorChar
if ($OutFile.StartsWith($AppDir + $sep, [System.StringComparison]::OrdinalIgnoreCase)) {
    $storeRel = $OutFile.Substring($AppDir.Length + 1).Replace('\', '/')
} else {
    # 若 keystore 不在 android/app 下（用户指定了自定义路径），直接写入绝对路径
    $storeRel = $OutFile.Replace('\', '/')
}
$keyPropsPath = Join-Path (Join-Path $RepoRoot "android") "key.properties"
$props = @(
    "storeFile=$storeRel"
    "storePassword=$StorePass"
    "keyAlias=$Alias"
    "keyPassword=$KeyPass"
) -join [Environment]::NewLine
Set-Content -Path $keyPropsPath -Value $props -Encoding UTF8
Write-Host "已写入 $keyPropsPath (storeFile=$storeRel)"

# ---------- 备份与后续步骤提醒 ----------
Write-Host ""
Write-Host "==================== 重要提醒 ===================="
Write-Host "1) keystore 文件: $OutFile"
Write-Host "2) 请立即将 keystore 与上方密码做【异地多重备份】（另一硬盘 + 云盘加密 + U 盘离线）。"
Write-Host "   密钥丢失 = 无法给老用户推送升级包，且永远无法恢复！"
Write-Host "3) 将 keystore 转为 base64 用于 GitHub Secret（不要粘贴到聊天中）："
Write-Host "   [Convert]::ToBase64String([System.IO.File]::ReadAllBytes('$OutFile'))"
Write-Host "4) 在 GitHub 仓库 Settings → Secrets → Actions 添加："
Write-Host "   KEYSTORE_BASE64 / KEYSTORE_PASSWORD / KEY_ALIAS / KEY_PASSWORD"
Write-Host "=================================================="
