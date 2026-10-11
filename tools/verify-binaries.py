#!/usr/bin/env python3
"""校验 bin/ 里的二进制与 bin/manifest.json 记录一致。

bin/ 是**提交进版本库**的（发行版要把工具随包带走），所以它会经历 clone、checkout、
各种文件系统搬运 —— 这些都是二进制被悄悄改坏的机会。manifest.json 里存着每个文件的
官方 SHA256，拿它逐条核对是最省事的完整性检查，也让「bin/ 里的东西没被动过」成为
可验证的事实而不是假设。

用法：
    python tools/verify-binaries.py              # 校验，全部一致则退出码 0
    python tools/verify-binaries.py --list       # 顺便打印清单
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BIN_DIR = REPO_ROOT / "bin"
MANIFEST = BIN_DIR / "manifest.json"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="校验 bin/ 与 manifest.json 一致")
    parser.add_argument("--list", action="store_true", help="打印每个文件的校验结果")
    args = parser.parse_args(argv)

    if not MANIFEST.is_file():
        print(f"找不到 {MANIFEST}", file=sys.stderr)
        return 2

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    tools = manifest.get("tools", [])
    if not tools:
        print("manifest.json 里没有 tools 条目", file=sys.stderr)
        return 2

    problems: list[str] = []
    for entry in tools:
        name = entry["file"]
        path = BIN_DIR / name
        want = entry["sha256"].upper()
        want_bytes = entry.get("bytes")

        if not path.is_file():
            problems.append(f"缺失：{name}")
            continue

        actual_bytes = path.stat().st_size
        actual = sha256(path)

        if actual_bytes != want_bytes:
            problems.append(f"大小不符：{name}  期望 {want_bytes:,} / 实际 {actual_bytes:,}")
        elif actual != want:
            problems.append(f"SHA256 不符：{name}\n    期望 {want}\n    实际 {actual}")
        elif args.list:
            print(f"  OK  {name:<18} {actual_bytes:>12,} 字节  {actual[:16]}…")

    # 反过来也查：bin/ 里有没有 manifest 没记录的可执行文件（漏记或残留）
    recorded = {e["file"] for e in tools}
    for path in sorted(BIN_DIR.iterdir()):
        if not path.is_file():
            continue
        if path.suffix.lower() in (".md", ".json"):
            continue
        if path.name not in recorded:
            problems.append(f"未记录：{path.name}（bin/ 里有，但 manifest.json 没记）")

    print()
    print("=" * 56)
    if problems:
        print(f"发现 {len(problems)} 个问题：", file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
        return 1

    total = sum(e.get("bytes", 0) for e in tools)
    print(f"通过：{len(tools)} 个文件全部与 manifest.json 一致，合计 {total / 1024 / 1024:.1f} MB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
