#!/usr/bin/env python3
"""把插件目录里的勾选结果解析成机器可读的 selection.json。

目录文件本身既是给人读的表格，也是唯一数据源：勾选就是把 `- [ ]` 改成 `- [x]`。

约定的行格式（必须严格保持，否则本脚本会报错并指出行号）：

    - [ ] **owner/repo** · 作用：一句话说明 · 依赖：纯 Lua · 许可：MIT

可选字段：作用 / 依赖 / 许可 / 档位 / 备注 / 平台。
字段之间用 ` · ` 分隔，键值之间用全角或半角冒号。

条目的 id 允许写成 `owner/repo#module`，用来勾选 mini.nvim 这类一个仓库包含多个
独立模块的项目；解析结果会额外给出 repo 与 module 两个字段，vendor 时按 repo 去重。

依赖字段的取值会被归一化成四类，用于统计"离线纯度"：
    纯 Lua        插件自身不含任何外部可执行文件依赖
    外部工具     需要目标机器上已有某个命令行程序（括号里列出）
    编译/下载     安装或首次运行时会编译源码 / 下载产物，离线包必须预先 vendor
    联网          功能本身要求网络（本发行版默认排除，仅作记录）

用法：
    python tools/parse_selection.py                 # 解析 catalog/*.md，写 build/selection.json
    python tools/parse_selection.py --check         # 只校验格式，不写文件
    python tools/parse_selection.py catalog/01-*.md # 只解析指定文件
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import tomllib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CATALOG_DIR = REPO_ROOT / "catalog"
DEFAULT_OUT = REPO_ROOT / "build" / "selection.json"
OVERVIEW_OUT = REPO_ROOT / "catalog" / "OVERVIEW.md"
STACKS_FILE = REPO_ROOT / "catalog" / "STACKS.toml"

ENTRY_RE = re.compile(r"^\s*-\s*\[(?P<mark>[ xX])\]\s*\*\*(?P<pid>[^*]+?)\*\*\s*(?P<rest>.*)$")
HEADING_RE = re.compile(r"^(?P<level>#{2,4})\s+(?P<title>.+?)\s*$")
FIELD_RE = re.compile(r"^(?P<key>[^:：]+)[:：]\s*(?P<value>.*)$")
TOOLS_RE = re.compile(r"[（(](?P<tools>[^）)]*)[）)]")

DEP_CLASSES = ("纯 Lua", "外部工具", "编译/下载", "联网")
DEP_ALIASES = {
    "纯lua": "纯 Lua",
    "纯 lua": "纯 Lua",
    "pure": "纯 Lua",
    "外部": "外部工具",
    "外部工具": "外部工具",
    "tool": "外部工具",
    "编译": "编译/下载",
    "下载": "编译/下载",
    "编译/下载": "编译/下载",
    "compile": "编译/下载",
    "联网": "联网",
    "网络": "联网",
    "net": "联网",
}

KNOWN_KEYS = ("作用", "依赖", "许可", "档位", "备注", "平台")
PROFILES = ("core", "ide", "extra")
# 预设：勾选哪些档位
PRESET_SETS = {
    "core": {"core"},
    "ide": {"core", "ide"},
    "all": {"core", "ide", "extra"},
}
CHECKBOX_RE = re.compile(r"^(\s*-\s*\[)[ xX](\])")


class Problem(Exception):
    pass


def normalize_dep(raw: str) -> str:
    key = raw.strip().lower()
    if key in DEP_ALIASES:
        return DEP_ALIASES[key]
    for prefix, cls in DEP_ALIASES.items():
        if key.startswith(prefix):
            return cls
    raise Problem(f"依赖字段无法识别：{raw!r}（允许：{'、'.join(DEP_CLASSES)}）")


def extract_tools(raw: str) -> list[str]:
    match = TOOLS_RE.search(raw)
    if not match:
        return []
    parts = re.split(r"[,，、/]", match.group("tools"))
    return [p.strip() for p in parts if p.strip()]


def parse_file(path: Path) -> tuple[list[dict], list[str]]:
    entries: list[dict] = []
    problems: list[str] = []
    category: str | None = None
    group: str | None = None

    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        heading = HEADING_RE.match(line)
        if heading:
            level = len(heading.group("level"))
            title = heading.group("title")
            if level == 2:
                category, group = title, None
            elif level == 3:
                group = title
            continue

        if not line.lstrip().startswith("- ["):
            continue

        entry = ENTRY_RE.match(line)
        if not entry:
            problems.append(f"{path.name}:{lineno} 条目格式不对：{line.strip()[:80]}")
            continue

        pid = entry.group("pid").strip()
        fields: dict[str, str] = {}
        for chunk in entry.group("rest").split("·"):
            chunk = chunk.strip()
            if not chunk:
                continue
            field = FIELD_RE.match(chunk)
            if not field:
                problems.append(f"{path.name}:{lineno} 字段格式不对：{chunk[:60]}")
                continue
            fields[field.group("key").strip()] = field.group("value").strip()

        unknown = set(fields) - set(KNOWN_KEYS)
        if unknown:
            problems.append(f"{path.name}:{lineno} 未知字段 {sorted(unknown)}")

        dep_raw = fields.get("依赖", "")
        dep_class = ""
        if dep_raw:
            try:
                dep_class = normalize_dep(dep_raw)
            except Problem as exc:
                problems.append(f"{path.name}:{lineno} {exc}")

        repo, _, module = pid.partition("#")
        if not repo or "/" not in repo:
            problems.append(f"{path.name}:{lineno} id 不像 owner/repo：{pid}")
        if "作用" not in fields:
            problems.append(f"{path.name}:{lineno} 缺少「作用」字段：{pid}")
        if "依赖" not in fields:
            problems.append(f"{path.name}:{lineno} 缺少「依赖」字段：{pid}")

        profile = fields.get("档位", "").strip().lower()
        if profile and profile not in PROFILES:
            problems.append(f"{path.name}:{lineno} 档位取值非法：{profile!r}（允许：{'、'.join(PROFILES)}）")

        entries.append(
            {
                "id": pid,
                "repo": repo,
                "module": module or None,
                "enabled": entry.group("mark").lower() == "x",
                "category": category,
                "group": group,
                "desc": fields.get("作用", ""),
                "dep_raw": dep_raw,
                "dep_class": dep_class,
                "tools": extract_tools(dep_raw),
                "profile": profile,
                "license": fields.get("许可", ""),
                "platform": fields.get("平台", "win+linux"),
                "note": fields.get("备注", ""),
                "source": f"{path.name}:{lineno}",
                "line": lineno,
            }
        )
    return entries, problems


def apply_preset(path: Path, preset: str) -> int:
    """按预设把勾选状态写回目录文件，返回改动的条目数。"""
    allowed = PRESET_SETS[preset]
    entries, _ = parse_file(path)
    lines = path.read_text(encoding="utf-8").splitlines()
    changed = 0
    for entry in entries:
        if not entry["profile"]:
            continue
        want = "x" if entry["profile"] in allowed else " "
        idx = entry["line"] - 1
        old = lines[idx]
        new = CHECKBOX_RE.sub(lambda m: m.group(1) + want + m.group(2), old, count=1)
        if new != old:
            lines[idx] = new
            changed += 1
    # newline="\n" 是必须的：Windows 上 write_text 默认会把 \n 翻成 \r\n，
    # 而这是跨平台仓库，混入 CRLF 会让 git diff 变成整文件改动。
    path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    return changed


def load_stacks() -> dict:
    """读 catalog/STACKS.toml 里的已决策方案。"""
    if not STACKS_FILE.is_file():
        return {}
    with STACKS_FILE.open("rb") as fh:
        data = tomllib.load(fh)
    return {name: cfg for name, cfg in data.items() if isinstance(cfg, dict)}


def apply_stack(path: Path, ids: set[str]) -> tuple[int, int]:
    """按方案重写勾选状态：清单内的勾上，其余一律取消。"""
    entries, _ = parse_file(path)
    lines = path.read_text(encoding="utf-8").splitlines()
    for entry in entries:
        want = "x" if entry["id"] in ids else " "
        idx = entry["line"] - 1
        old = lines[idx]
        new = CHECKBOX_RE.sub(lambda m: m.group(1) + want + m.group(2), old, count=1)
        if new != old:
            lines[idx] = new
    # 同上：显式 LF，避免在 Windows 上写出 CRLF
    path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    ticked = sum(1 for e in entries if e["id"] in ids)
    return ticked, len(entries) - ticked


def write_overview(entries: list[dict], path: Path) -> None:
    """把目录渲染成一张可扫的速查表。内容全部来自目录本身，避免两处脱节。"""
    by_dep: dict[str, int] = {}
    by_profile: dict[str, int] = {}
    by_category: dict[str, int] = {}
    for e in entries:
        by_dep[e["dep_class"] or "未填"] = by_dep.get(e["dep_class"] or "未填", 0) + 1
        by_profile[e["profile"] or "未填"] = by_profile.get(e["profile"] or "未填", 0) + 1
        by_category[e["category"] or "(未分类)"] = by_category.get(e["category"] or "(未分类)", 0) + 1

    out: list[str] = [
        "# 插件目录速查",
        "",
        "> 本文件由 `tools/parse_selection.py --overview` 从 `PLUGIN-CATALOG.md` 自动生成，**别手工编辑**。",
        "> 每条的作用说明、取舍理由、许可与风险备注在 `PLUGIN-CATALOG.md`；怎么选见 `../docs/CHOOSING.md`。",
        "",
        f"共 **{len(entries)}** 个条目，分 **{len(by_category)}** 类。",
        "",
        "- 依赖分级：" + "、".join(f"{k} {v}" for k, v in sorted(by_dep.items())),
        "- 档位分布：" + "、".join(f"{k} {v}" for k, v in sorted(by_profile.items())),
        "- 分类条目数：" + "、".join(f"{k} {v}" for k, v in sorted(by_category.items())),
        "",
        "☐ 未勾选 / ☑ 已勾选。",
        "",
    ]

    current: str | None = None
    for e in entries:
        if e["category"] != current:
            current = e["category"]
            out += [
                "",
                f"## {current}",
                "",
                "| | 插件 | 作用 | 依赖 | 档位 |",
                "| --- | --- | --- | --- | --- |",
            ]
        box = "☑" if e["enabled"] else "☐"
        out.append(
            f"| {box} | `{e['id']}` | {e['desc']} | {e['dep_class'] or '-'} | {e['profile'] or '-'} |"
        )
        if e["note"]:
            out.append(f"| | | ↳ {e['note']} | | |")

    path.write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="解析插件目录的勾选结果")
    parser.add_argument("files", nargs="*", help="要解析的 markdown 文件（默认 catalog/*.md）")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="输出 JSON 路径")
    parser.add_argument("--check", action="store_true", help="只校验格式，不写文件")
    parser.add_argument(
        "--preset",
        choices=sorted(PRESET_SETS),
        help="按档位预选：core=只勾 core；ide=core+ide；all=全勾。配合 --apply 才写回目录",
    )
    parser.add_argument(
        "--stack",
        help="按 catalog/STACKS.toml 里的已决策方案预选（minimal / recommended / full）。配合 --apply 写回",
    )
    parser.add_argument("--apply", action="store_true", help="配合 --preset，把勾选状态写回目录文件")
    parser.add_argument("--overview", action="store_true", help="顺便生成 catalog/OVERVIEW.md 速查表")
    parser.add_argument("--overview-only", action="store_true", help="只生成速查表，不写 selection.json")
    args = parser.parse_args(argv)

    if args.files:
        paths = [Path(f) for f in args.files]
    else:
        paths = sorted(
            p
            for p in DEFAULT_CATALOG_DIR.glob("*.md")
            if p.name not in ("README.md", "OVERVIEW.md")
        )

    if not paths:
        print("没有找到任何目录文件", file=sys.stderr)
        return 2

    if args.stack and args.apply:
        stacks = load_stacks()
        if args.stack not in stacks:
            print(
                f"STACKS.toml 里没有方案 {args.stack!r}；可用：{', '.join(stacks) or '(文件不存在)'}",
                file=sys.stderr,
            )
            return 2
        ids = set(stacks[args.stack].get("plugins", []))
        ticked = unticked = 0
        for path in paths:
            if path.is_file():
                t, u = apply_stack(path, ids)
                ticked += t
                unticked += u
        print(f"已按方案 {args.stack} 重写勾选：选中 {ticked} 项，其余 {unticked} 项取消勾选\n")

    if args.preset and args.apply:
        total = 0
        for path in paths:
            if path.is_file():
                total += apply_preset(path, args.preset)
        print(f"已按预设 {args.preset} 更新 {total} 个条目的勾选状态\n")

    all_entries: list[dict] = []
    all_problems: list[str] = []
    for path in paths:
        if not path.is_file():
            all_problems.append(f"文件不存在：{path}")
            continue
        entries, problems = parse_file(path)
        all_entries.extend(entries)
        all_problems.extend(problems)

    if args.preset and not args.apply:
        allowed = PRESET_SETS[args.preset]
        for entry in all_entries:
            entry["enabled"] = bool(entry["profile"]) and entry["profile"] in allowed
        print(f"（按预设 {args.preset} 试算，未写回文件；加 --apply 才会真正勾上）\n")

    if args.stack:
        stacks = load_stacks()
        stack_ids = set(stacks.get(args.stack, {}).get("plugins", []))
        known_ids = {e["id"] for e in all_entries}
        missing = sorted(stack_ids - known_ids)
        if missing:
            all_problems.append(
                f"STACKS.toml 的方案 {args.stack} 里有 {len(missing)} 个 id 在目录中不存在（拼错了？）："
                + "、".join(missing)
            )
        if not args.apply:
            for entry in all_entries:
                entry["enabled"] = entry["id"] in stack_ids
            print(f"（按方案 {args.stack} 试算，未写回文件；加 --apply 才会真正勾上）\n")

    seen: dict[str, str] = {}
    for entry in all_entries:
        if entry["id"] in seen:
            all_problems.append(f"{entry['source']} 重复条目：{entry['id']}（首次出现于 {seen[entry['id']]}）")
        else:
            seen[entry["id"]] = entry["source"]

    selected = [e for e in all_entries if e["enabled"]]

    by_category: dict[str, int] = {}
    by_dep: dict[str, int] = {}
    for entry in all_entries:
        by_category[entry["category"] or "(未分类)"] = by_category.get(entry["category"] or "(未分类)", 0) + 1
        by_dep[entry["dep_class"] or "(未填)"] = by_dep.get(entry["dep_class"] or "(未填)", 0) + 1

    sel_dep: dict[str, int] = {}
    sel_profile: dict[str, int] = {}
    tools: set[str] = set()
    repos: dict[str, dict] = {}
    risky: list[str] = []
    for entry in selected:
        sel_dep[entry["dep_class"] or "(未填)"] = sel_dep.get(entry["dep_class"] or "(未填)", 0) + 1
        sel_profile[entry["profile"] or "(未填)"] = sel_profile.get(entry["profile"] or "(未填)", 0) + 1
        tools.update(entry["tools"])
        repos.setdefault(entry["repo"], {"repo": entry["repo"], "modules": [], "profiles": set()})
        if entry["module"]:
            repos[entry["repo"]]["modules"].append(entry["module"])
        if entry["profile"]:
            repos[entry["repo"]]["profiles"].add(entry["profile"])
        if entry["dep_class"] in ("编译/下载", "联网"):
            risky.append(f"{entry['id']}（{entry['dep_class']}）")

    # 已经在 bin/ 里随包分发的工具，不该再算成「需要目标机器自备」。
    # 从 bin/manifest.json 读，避免两处各说一套。
    bundled: set[str] = set()
    manifest_path = REPO_ROOT / "bin" / "manifest.json"
    if manifest_path.is_file():
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            bundled = {Path(e["file"]).stem for e in manifest.get("tools", [])}
        except (json.JSONDecodeError, KeyError, OSError):
            pass
    bundled_used = sorted(tools & bundled)
    still_needed = sorted(tools - bundled)

    plan = [
        {
            "repo": info["repo"],
            "modules": sorted(info["modules"]),
            "profiles": sorted(info["profiles"]),
            "clone_url": f"https://github.com/{info['repo']}.git",
        }
        for info in sorted(repos.values(), key=lambda i: i["repo"])
    ]

    payload = {
        "sources": [str(p) for p in paths],
        "selection_source": (
            f"stack:{args.stack}（已写回目录）"
            if (args.stack and args.apply)
            else f"preset:{args.preset}（已写回目录）"
            if (args.preset and args.apply)
            else "catalog（直接读目录里的勾选状态）"
        ),
        "counts": {
            "total": len(all_entries),
            "selected": len(selected),
            "by_category": dict(sorted(by_category.items())),
            "by_dep_all": dict(sorted(by_dep.items())),
            "by_dep_selected": dict(sorted(sel_dep.items())),
            "by_profile_selected": dict(sorted(sel_profile.items())),
        },
        "required_external_tools": sorted(tools),
        "bundled_tools": bundled_used,
        "tools_needed_on_system": still_needed,
        "vendoring_risk": risky,
        "repos_to_vendor": plan,
        "selected": selected,
        "all": all_entries,
        "problems": all_problems,
    }

    print(f"目录条目 {len(all_entries)} 个，其中已勾选 {len(selected)} 个")
    for prof in PROFILES:
        n = sel_profile.get(prof, 0)
        if n:
            print(f"  已勾选 · 档位 {prof}：{n}")
    for cls in DEP_CLASSES:
        n = sel_dep.get(cls, 0)
        if n:
            print(f"  已勾选 · {cls}：{n}")
    if bundled_used:
        print(f"  已在 bin/ 随包分发（无需自备）：{', '.join(bundled_used)}")
    if still_needed:
        print(f"  仍需目标机器自备的命令：{', '.join(still_needed)}")
    print(f"  需要 vendor 的仓库：{len(plan)} 个（含 {sum(len(p['modules']) for p in plan)} 个模块勾选）")
    if risky:
        print(f"  离线风险项 {len(risky)} 个，必须预先处理好：")
        for item in risky:
            print(f"    - {item}")
    if all_problems:
        print(f"\n发现 {len(all_problems)} 个问题：", file=sys.stderr)
        for problem in all_problems:
            print(f"  - {problem}", file=sys.stderr)

    # 预览（--stack/--preset 不带 --apply）绝不落盘。
    # 否则 build/selection.json 会留下与目录勾选不一致的选型，
    # 而 vendoring 读的正是这个文件 —— 会静默拉错插件集合。
    preview = bool((args.stack or args.preset) and not args.apply)
    if not args.check and not args.overview_only:
        if preview:
            print("\n（预览模式不写 build/selection.json，避免留下与目录不一致的选型）")
        else:
            args.out.parent.mkdir(parents=True, exist_ok=True)
            args.out.write_text(
                json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
                newline="\n",
            )
            print(f"\n已写出 {args.out}")

    if args.overview or args.overview_only:
        write_overview(all_entries, OVERVIEW_OUT)
        print(f"已写出 {OVERVIEW_OUT}")

    return 1 if all_problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
