import 'dart:convert';

import '../../data/db.dart';
import '../../core/logging/logger_service.dart';
import 'aa_decimal_util.dart';

/// AA 分摊模式枚举。
///
/// 与 [Transactions.aaMode] 列对齐:
/// - [perPerson] (null/0):人均分摊
/// - [noSplit] (1):不分摊,跳过 AA 统计
/// - [custom] (2):指定金额分摊
enum AaMode {
  perPerson,
  noSplit,
  custom;

  /// 从数据库列值(int?)解析为枚举。null/0 → perPerson(R6)。
  static AaMode fromDb(int? v) {
    switch (v) {
      case 1:
        return AaMode.noSplit;
      case 2:
        return AaMode.custom;
      default:
        return AaMode.perPerson;
    }
  }
}

/// 单条交易的 AA 分摊结果。
///
/// [shares] key=参与人标识(userId 或虚拟用户 syncId),value=应摊金额(double)。
/// 支出人实付与应摊的差额归支出人,保证 sum(应摊) == 实付(§10.2)。
class AaSettlementTxResult {
  /// 交易 syncId(跨设备标识,本地展示用 tx.id)。
  final String? syncId;

  /// 交易本地 id。
  final int txId;

  /// 实付金额。
  final double paidAmount;

  /// 支出人标识(userId 或虚拟用户 syncId)。
  final String paidBy;

  /// 分摊模式。
  final AaMode mode;

  /// 每人应摊金额。key=参与人标识,value=应摊金额(double)。
  final Map<String, double> shares;

  const AaSettlementTxResult({
    required this.syncId,
    required this.txId,
    required this.paidAmount,
    required this.paidBy,
    required this.mode,
    required this.shares,
  });
}

/// 单个参与人的 AA 汇总。
class AaParticipantSummary {
  /// 参与人标识(userId 或虚拟用户 syncId)。
  final String participantId;

  /// 参与人显示名(真实用户取 displayName,虚拟用户取 name)。
  final String displayName;

  /// 该参与人总共实付金额(作为支出人)。
  final double totalPaid;

  /// 该参与人总共应摊金额(所有参与交易的分摊合计)。
  final double totalShouldPay;

  /// 净额 = 实付 - 应摊。正数表示该参与人应收(别人欠他),
  /// 负数表示该参与人应付(他欠别人)。
  double get net => totalPaid - totalShouldPay;

  AaParticipantSummary({
    required this.participantId,
    required this.displayName,
    required this.totalPaid,
    required this.totalShouldPay,
  });

  /// 累加实付金额。
  AaParticipantSummary addPaid(double amount) => AaParticipantSummary(
        participantId: participantId,
        displayName: displayName,
        totalPaid: totalPaid + amount,
        totalShouldPay: totalShouldPay,
      );

  /// 累加应摊金额。
  AaParticipantSummary addShouldPay(double amount) => AaParticipantSummary(
        participantId: participantId,
        displayName: displayName,
        totalPaid: totalPaid,
        totalShouldPay: totalShouldPay + amount,
      );
}

/// 转账方案(结算建议)。
///
/// 净额>0 的人应收,净额<0 的人应付。本结构表示一笔转账:
/// [from] 应付给 [to] 金额 [amount]。
class AaTransfer {
  final String from;
  final String fromName;
  final String to;
  final String toName;
  final double amount;

  const AaTransfer({
    required this.from,
    required this.fromName,
    required this.to,
    required this.toName,
    required this.amount,
  });
}

/// 账本级 AA 分摊汇总结果。
class AaLedgerSettlement {
  /// 参与人汇总(含真实成员 + 虚拟用户)。
  final List<AaParticipantSummary> participants;

  /// 结算转账方案。
  final List<AaTransfer> transfers;

  AaLedgerSettlement({
    required this.participants,
    required this.transfers,
  });
}

/// AA 分摊计算服务(纯计算层,不写库)。
///
/// 入口:账本的全部 AA 交易 + 账本全部参与人(真实成员 + 虚拟用户)。
/// 输出:每人汇总(实付/应摊/净额)+ 转账方案(贪心结算,净额最小化转账笔数)。
///
/// 分摊规则(§4.1):
/// - 人均(null/0):全部参与人(aaParticipants 空则运行时展开为账本全部成员)
///   均分;每人应摊 = floor(实付×100/n)/100;支出人实付差归支出人(§10.2)。
/// - 不分摊(1):跳过,不进入 AA 统计。
/// - 指定(2):aaSplits 即最终应摊,按分校验 sum == 实付。
///
/// 参与人解析:真实成员取 userId,虚拟用户取 syncId;身份映射由调用方
/// (Provider 层)从 LedgerMembers + LedgerVirtualUsers 组装后传入。
class AaSettlementService {
  AaSettlementService._();

  /// 计算单条交易的 AA 分摊结果。
  ///
  /// [tx] 交易行(已过滤 aaMode != noSplit)。
  /// [allParticipants] 账本全部参与人列表(userId 或虚拟用户 syncId),
  ///   人均模式下 aaParticipants 为空时展开为此列表。
  /// [payerOverride] 支出人覆盖(默认取 tx.paidByUserId;为空时取参与人首个)。
  ///
  /// 返回 null 表示该交易无法计算(如指定分摊 aaSplits 解析失败、参与人为空)。
  static AaSettlementTxResult? computeTx({
    required Transaction tx,
    required List<String> allParticipants,
  }) {
    final mode = AaMode.fromDb(tx.aaMode);

    // 支出人:tx.paidByUserId 优先;为空时取参与人首个兜底(展示层空串降级"未知")。
    final paidBy = (tx.paidByUserId != null && tx.paidByUserId!.isNotEmpty)
        ? tx.paidByUserId!
        : (allParticipants.isNotEmpty ? allParticipants.first : '');

    // 解析参与人:aaParticipants 为空 → 展开为账本全部成员(运行时展开)。
    List<String> participants;
    if (tx.aaParticipants != null && tx.aaParticipants!.isNotEmpty) {
      try {
        final list = jsonDecode(tx.aaParticipants!) as List;
        participants = list.map((e) => e.toString()).toList();
      } catch (e, st) {
        logger.warning('AaSettlement',
            '解析 aaParticipants 失败 tx=${tx.id}', '$e\n$st');
        return null;
      }
    } else {
      participants = List.of(allParticipants);
    }
    if (participants.isEmpty) return null;

    final totalDecimal = toDecimal2(tx.amount);
    final shares = <String, double>{};

    switch (mode) {
      case AaMode.noSplit:
        // 不分摊:理论上调用方已过滤,此处兜底返回 null。
        return null;

      case AaMode.perPerson:
        // 人均:floor(实付×100/n)/100,支出人实付差归支出人。
        final payerIndex = participants.indexOf(paidBy);
        final splits = splitEvenly(
          total: totalDecimal,
          participantCount: participants.length,
          payerIndex: payerIndex >= 0 ? payerIndex : 0,
        );
        for (var i = 0; i < participants.length; i++) {
          shares[participants[i]] = toDouble(splits[i]);
        }
        break;

      case AaMode.custom:
        // 指定分摊:aaSplits JSON 对象,key=参与人,value=金额字符串。
        if (tx.aaSplits == null || tx.aaSplits!.isEmpty) {
          logger.warning('AaSettlement',
              '指定分摊 aaSplits 为空 tx=${tx.id}');
          return null;
        }
        try {
          final obj = jsonDecode(tx.aaSplits!) as Map<String, dynamic>;
          for (final entry in obj.entries) {
            final v = entry.value;
            if (v is num) {
              shares[entry.key] = v.toDouble();
            } else {
              shares[entry.key] = double.tryParse(v.toString()) ?? 0.0;
            }
          }
        } catch (e, st) {
          logger.warning('AaSettlement',
              '解析 aaSplits 失败 tx=${tx.id}', '$e\n$st');
          return null;
        }
        // 指定分摊不强制校验 sum==实付(用户可能未填完),由 UI 层校验引导。
        break;
    }

    return AaSettlementTxResult(
      syncId: tx.syncId,
      txId: tx.id,
      paidAmount: tx.amount,
      paidBy: paidBy,
      mode: mode,
      shares: shares,
    );
  }

  /// 计算账本级 AA 分摊汇总。
  ///
  /// [transactions] 账本全部 AA 交易(aaMode != 1,已由 getAaTransactionsByLedger
  ///   过滤)。
  /// [allParticipants] 账本全部参与人标识列表。
  /// [displayNameMap] 参与人标识 → 显示名映射(真实成员取 displayName,
  ///   虚拟用户取 name)。
  static AaLedgerSettlement computeLedger({
    required List<Transaction> transactions,
    required List<String> allParticipants,
    required Map<String, String> displayNameMap,
  }) {
    // 每人汇总:实付 + 应摊
    final summaryMap = <String, AaParticipantSummary>{};
    for (final pid in allParticipants) {
      summaryMap[pid] = AaParticipantSummary(
        participantId: pid,
        displayName: displayNameMap[pid] ?? pid,
        totalPaid: 0.0,
        totalShouldPay: 0.0,
      );
    }

    for (final tx in transactions) {
      final result = computeTx(
        tx: tx,
        allParticipants: allParticipants,
      );
      if (result == null) continue;

      // 累加支出人实付
      final payer = result.paidBy;
      if (summaryMap.containsKey(payer)) {
        summaryMap[payer] = summaryMap[payer]!.addPaid(result.paidAmount);
      } else {
        // 支出人不在参与人列表(如虚拟用户已删但交易仍引用):兜底加入。
        summaryMap[payer] = AaParticipantSummary(
          participantId: payer,
          displayName: displayNameMap[payer] ?? '未知',
          totalPaid: result.paidAmount,
          totalShouldPay: 0.0,
        );
      }

      // 累加每人应摊
      for (final entry in result.shares.entries) {
        final pid = entry.key;
        final amount = entry.value;
        if (summaryMap.containsKey(pid)) {
          summaryMap[pid] = summaryMap[pid]!.addShouldPay(amount);
        } else {
          // 参与人不在列表(如虚拟用户已删):兜底加入。
          summaryMap[pid] = AaParticipantSummary(
            participantId: pid,
            displayName: displayNameMap[pid] ?? '未知',
            totalPaid: 0.0,
            totalShouldPay: amount,
          );
        }
      }
    }

    final participants = summaryMap.values.toList();

    // 生成转账方案:贪心结算,净额最小化转账笔数。
    final transfers = _buildTransfers(participants);

    return AaLedgerSettlement(
      participants: participants,
      transfers: transfers,
    );
  }

  /// 贪心结算:净额>0 的人(应收)与净额<0 的人(应付)配对,
  /// 每次取最大应收与最大应付配对,金额取较小者,直至所有净额归零。
  ///
  /// 输出转账方案:[from](应付) → [to](应收) 金额 [amount]。
  static List<AaTransfer> _buildTransfers(
      List<AaParticipantSummary> participants) {
    // 复制净额,避免修改原始汇总。
    final nets = <String, double>{};
    for (final p in participants) {
      // 容差:净额绝对值 < 0.005 视为 0(分摊精度 0.01,避免尾差)。
      final net = p.net;
      if (net.abs() >= 0.005) {
        nets[p.participantId] = net;
      }
    }

    final nameOf = <String, String>{
      for (final p in participants) p.participantId: p.displayName,
    };

    final result = <AaTransfer>[];
    // 最大迭代次数保护:正常 nets 长度有限,贪心每次至少归零一个,不会死循环。
    var guard = nets.length * 2 + 10;
    while (nets.isNotEmpty && guard-- > 0) {
      // 找最大应付(净额最小,负数)与最大应收(净额最大,正数)。
      String? maxDebtor; // 应付(净额<0)
      String? maxCreditor; // 应收(净额>0)
      for (final entry in nets.entries) {
        if (entry.value < 0) {
          if (maxDebtor == null || entry.value < nets[maxDebtor]!) {
            maxDebtor = entry.key;
          }
        } else if (entry.value > 0) {
          if (maxCreditor == null || entry.value > nets[maxCreditor]!) {
            maxCreditor = entry.key;
          }
        }
      }
      if (maxDebtor == null || maxCreditor == null) break;

      final debtorNet = nets[maxDebtor]!; // 负数
      final creditorNet = nets[maxCreditor]!; // 正数
      // 转账金额 = min(|debtorNet|, creditorNet)
      final amount = debtorNet.abs() < creditorNet
          ? debtorNet.abs()
          : creditorNet;

      result.add(AaTransfer(
        from: maxDebtor,
        fromName: nameOf[maxDebtor] ?? maxDebtor,
        to: maxCreditor,
        toName: nameOf[maxCreditor] ?? maxCreditor,
        amount: double.parse(amount.toStringAsFixed(2)),
      ));

      // 更新净额
      final newDebtorNet = debtorNet + amount;
      final newCreditorNet = creditorNet - amount;
      if (newDebtorNet.abs() < 0.005) {
        nets.remove(maxDebtor);
      } else {
        nets[maxDebtor] = newDebtorNet;
      }
      if (newCreditorNet.abs() < 0.005) {
        nets.remove(maxCreditor);
      } else {
        nets[maxCreditor] = newCreditorNet;
      }
    }
    return result;
  }
}
