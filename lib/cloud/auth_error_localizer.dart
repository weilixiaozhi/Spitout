import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as s;
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

import '../l10n/app_localizations.dart';

/// 认证异常 → 用户友好文案的共享 helper。
///
/// 设计意图：集中做「类型判断式」分类，调用方只需一行
/// `friendlyAuthError(e, context)` 即可得到本地化文案，避免依赖
/// 异常字符串片段解析带来的脆弱性与重复。
///
/// 分类顺序（命中即返回，短路）：
/// 1. Supabase 账号鉴权异常（[s.AuthApiException]，携带干净的结构化 `.code`）；
/// 2. 纯网络层异常（Socket / Timeout / http.ClientException，跨平台可用）；
/// 3. 包内 [CloudAuthException]（含已清理的 `.message`，按语义细分账号/网络/其它）；
/// 4. 兜底：对异常字符串做关键词匹配，尽量区分类型，最终回落到通用登录失败文案。
///
/// 之所以把「账号鉴权失败」与「网络异常」分开，是因为调用方（详见
/// spitout_cloud_sync_section 的重新登录分支）对这两类失败的处理策略不同：
/// 账号失败是「纯账号问题」，不弹 toast、不弹窗，仅内联红字并隐藏按钮；
/// 网络失败通常短暂可重试，保留按钮并弹网络 toast。分类清晰才能驱动不同 UI 行为。
String friendlyAuthError(Object? e, BuildContext context) {
  final l10n = AppLocalizations.of(context);

  // 1. Supabase 账号鉴权：优先用干净的结构化 code，避免字符串解析。
  //    这是最可靠的类型判断路径，命中后直接映射文案，无需后续模糊匹配。
  if (e is s.AuthApiException) {
    switch (e.code) {
      case 'invalid_credentials':
        return l10n.authErrorInvalidCredentials;
      case 'email_address_not_confirmed':
      case 'email_not_confirmed':
        return l10n.authErrorEmailNotConfirmed;
      case 'over_email_send_rate_limit':
        return l10n.authErrorRateLimit;
    }
  }

  // 2. 纯网络层异常：与账号无关，单独归类。
  //    http.ClientException 跨平台（含 Web），SocketException / TimeoutException
  //    兜底移动端原生异常，确保「网络」分支在所有平台都能命中。
  if (e is SocketException ||
      e is TimeoutException ||
      e is http.ClientException) {
    return l10n.authErrorNetworkIssue;
  }

  // 3. 包内 CloudAuthException：message 已是清晰的英文/中文描述，按语义细分。
  if (e is CloudAuthException) {
    final lower = e.message.toLowerCase();
    // 账号相关：含 invalid + (email/password/credential)，或 not found。
    if ((lower.contains('invalid') &&
            (lower.contains('email') ||
                lower.contains('password') ||
                lower.contains('credential'))) ||
        lower.contains('not found')) {
      return l10n.authErrorInvalidCredentials;
    }
    // 限流。
    if (lower.contains('rate') || lower.contains('too many')) {
      return l10n.authErrorRateLimit;
    }
    // 邮箱未验证。
    if (lower.contains('email') &&
        lower.contains('not') &&
        lower.contains('confirm')) {
      return l10n.authErrorEmailNotConfirmed;
    }
    // 其余 CloudAuthException 视为通用登录失败。
    return l10n.authErrorLoginFailed;
  }

  // 4. 兜底：对异常字符串做关键词匹配，尽量区分类型后回落到通用文案。
  //    仅当上述类型判断都未命中时才走到这里（例如非 Supabase 的其它异常源）。
  final msg = (e?.toString() ?? '').toLowerCase();
  if (msg.contains('email') && msg.contains('not') && msg.contains('confirm')) {
    return l10n.authErrorEmailNotConfirmed;
  }
  if (msg.contains('invalid') &&
      (msg.contains('login') ||
          msg.contains('credential') ||
          msg.contains('password'))) {
    return l10n.authErrorInvalidCredentials;
  }
  if (msg.contains('rate') && msg.contains('limit')) {
    return l10n.authErrorRateLimit;
  }
  if (msg.contains('network') || msg.contains('timeout')) {
    return l10n.authErrorNetworkIssue;
  }
  return l10n.authErrorLoginFailed;
}
