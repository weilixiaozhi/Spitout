/// 数据序列化抽象接口。
///
/// 由业务层实现，负责领域数据与字符串之间的互转，
/// 使云同步包与业务逻辑完全解耦。
abstract class DataSerializer<T> {
  /// 将业务数据序列化为字符串。
  ///
  /// [data] - 待序列化的领域数据。
  ///
  /// 返回序列化后的字符串（通常是 JSON）。
  ///
  /// 示例：
  /// ```dart
  /// @override
  /// Future<String> serialize(int ledgerId) async {
  ///   final transactions = await db.getTransactions(ledgerId);
  ///   return jsonEncode({'ledgerId': ledgerId, 'items': transactions});
  /// }
  /// ```
  Future<String> serialize(T data);

  /// 将字符串反序列化为业务数据。
  ///
  /// [data] - 序列化字符串。
  ///
  /// 返回反序列化后的领域数据。
  ///
  /// 示例：
  /// ```dart
  /// @override
  /// Future<int> deserialize(String data) async {
  ///   final json = jsonDecode(data);
  ///   return json['ledgerId'] as int;
  /// }
  /// ```
  Future<T> deserialize(String data);

  /// 计算数据指纹。
  ///
  /// [data] - 序列化字符串。
  ///
  /// 返回指纹（如 SHA256 哈希），用于判断本地与云端数据是否一致。
  ///
  /// 示例：
  /// ```dart
  /// @override
  /// String fingerprint(String data) {
  ///   final bytes = utf8.encode(data);
  ///   return sha256.convert(bytes).toString();
  /// }
  /// ```
  String fingerprint(String data);
}
