/// 本地账本未登录云时的自我占位标识。
///
/// 仅在"账本无 ownerUserId 且未登录云"时用于保证 paidByUserId /
/// 参与人标识字段非空。它不是真实 userId、不是昵称、也不是数据库里的
/// 特殊用户。展示层遇到此值必须统一映射为"我"(本地昵称或 l10n.aaMe),
/// 禁止直接展示字面量。
const String kLocalSelfUserId = 'me';
