#!/usr/bin/env python3
"""依赖环检测脚本的指令解析回归测试。"""

import unittest

import check_cycles


class DirectiveParsingTest(unittest.TestCase):
    """确保文件头与多条声明不会让依赖扫描漏边。"""

    def test_reads_imports_and_exports_from_every_line(self) -> None:
        """注释后的多条 import/export 都必须进入依赖图。"""
        source = """// 文件说明
import 'first.dart';
import 'second.dart';
export 'facade.dart';
"""

        self.assertEqual(
            ["first.dart", "second.dart", "facade.dart"],
            [match.group(1) for match in check_cycles.import_re.finditer(source)],
        )

    def test_reads_part_directives_after_headers(self) -> None:
        """library 注释后的 part 与 part of 必须被正确归并。"""
        library_source = """// 主库说明
part 'first_part.dart';
part 'second_part.dart';
"""
        part_source = """// 分片说明
part of 'owner.dart';
"""

        self.assertEqual(
            ["first_part.dart", "second_part.dart"],
            [match.group(1) for match in check_cycles.part_re.finditer(library_source)],
        )
        self.assertIsNotNone(check_cycles.part_of_re.search(part_source))


if __name__ == "__main__":
    unittest.main()
