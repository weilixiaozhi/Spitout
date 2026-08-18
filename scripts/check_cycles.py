#!/usr/bin/env python3
"""静态依赖环检测（业务代码 fileCycles == []）。

规则：
- 只扫描 lib/ 下业务源码，排除 l10n 生成文件（gen-l10n 固有环）与
  *.g.dart / *.freezed.dart 生成文件；
- part 文件并入其所属 library 再参与构图，不把「主库 ↔ part」误判为环；
- 存在任何非平凡强连通分量（SCC）即失败，并列出环内文件。
"""

import re
import posixpath
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
PKG_PREFIX = "package:spitout/"
EXCLUDE_REL_PREFIX = "l10n/"
IGNORE_SUFFIXES = (".g.dart", ".freezed.dart")

import_re = re.compile(r"^\s*(?:import|export)\s+'([^']+)'", re.MULTILINE)
part_re = re.compile(r"^\s*part\s+'([^']+)'", re.MULTILINE)
part_of_re = re.compile(r"^\s*part of\s+'([^']+)'", re.MULTILINE)


def rel(path: Path) -> str:
    return path.relative_to(LIB).as_posix()


def resolve_target(current_rel: str, uri: str) -> str | None:
    if uri.startswith("package:"):
        if not uri.startswith(PKG_PREFIX):
            return None
        return uri[len(PKG_PREFIX) :]
    if uri.startswith("dart:"):
        return None
    base = posixpath.dirname(current_rel)
    return posixpath.normpath(posixpath.join(base, uri))


def main() -> int:
    all_files = [
        p
        for p in LIB.rglob("*.dart")
        if not p.name.endswith(IGNORE_SUFFIXES)
        and not rel(p).startswith(EXCLUDE_REL_PREFIX)
    ]
    if not all_files:
        print("No source files found under lib", file=sys.stderr)
        return 1

    libraries = [p for p in all_files if not part_of_re.search(p.read_text(encoding="utf-8"))]
    lib_ids = {rel(p) for p in libraries}

    # part 文件归属主库：part 'x.dart' 与主库同目录。
    part_to_lib: dict[str, str] = {}
    for lib_file in libraries:
        lib_rel = rel(lib_file)
        text = lib_file.read_text(encoding="utf-8")
        for m in part_re.finditer(text):
            part_rel = resolve_target(lib_rel, m.group(1))
            if part_rel is not None and part_rel in {rel(p) for p in all_files}:
                part_to_lib[part_rel] = lib_rel

    graph: dict[str, set[str]] = {lib_id: set() for lib_id in lib_ids}
    for lib_file in libraries:
        lib_rel = rel(lib_file)
        sources = [lib_file]
        for part_rel, owner in part_to_lib.items():
            if owner == lib_rel:
                sources.append(LIB / part_rel)
        for source in sources:
            if not source.exists():
                continue
            for m in import_re.finditer(source.read_text(encoding="utf-8")):
                target = resolve_target(lib_rel, m.group(1))
                if target is None:
                    continue
                if target.startswith(EXCLUDE_REL_PREFIX):
                    continue
                owner = part_to_lib.get(target, target)
                if owner in lib_ids and owner != lib_rel:
                    graph[lib_rel].add(owner)

    # Tarjan SCC
    index = 0
    stack: list[str] = []
    on_stack: set[str] = set()
    indices: dict[str, int] = {}
    lowlink: dict[str, int] = {}
    cycles: list[list[str]] = []

    def strongconnect(v: str) -> None:
        nonlocal index
        indices[v] = index
        lowlink[v] = index
        index += 1
        stack.append(v)
        on_stack.add(v)
        for w in graph[v]:
            if w not in indices:
                strongconnect(w)
                lowlink[v] = min(lowlink[v], lowlink[w])
            elif w in on_stack:
                lowlink[v] = min(lowlink[v], indices[w])
        if lowlink[v] == indices[v]:
            scc = []
            while True:
                w = stack.pop()
                on_stack.remove(w)
                scc.append(w)
                if w == v:
                    break
            if len(scc) > 1:
                cycles.append(sorted(scc))

    for node in lib_ids:
        if node not in indices:
            strongconnect(node)

    if cycles:
        print("Detected dependency cycles:", file=sys.stderr)
        for cycle in cycles:
            print("  " + " -> ".join(cycle), file=sys.stderr)
        return 1
    print(f"OK: no cycles across {len(lib_ids)} libraries (l10n/generated excluded)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
