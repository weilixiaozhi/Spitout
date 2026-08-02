/// 账单解析器抽象接口
///
/// 仅提供实际被使用的两个能力：定位表头行与列→字段映射。
/// 无 `parseRow` / `validateBillType` / `ParseResult`，接口与实现保持一致。
abstract class BillParser {
  /// 查找表头所在行
  /// 返回表头行索引，如果未找到返回 -1
  int findHeaderRow(List<List<String>> rows);

  /// 自动映射列到字段
  /// 返回字段名到列索引的映射
  Map<String, int> mapColumns(List<String> headerRow);
}
