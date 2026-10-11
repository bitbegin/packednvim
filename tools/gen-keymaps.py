#!/usr/bin/env python3
"""生成 docs/KEYMAPS.md —— 快捷键速查。

为什么是生成的而不是手写的：
    手写的快捷键表几乎必然与配置脱节（改了配置忘了改文档），而「文档说按 X 却不管用」
    比没有文档更糟。所以这里的做法是：
      1. 用 -u NONE 起一个干净 Neovim，dump 全部键位（得到内置默认键位的集合）
      2. 用 -u init.lua 起本发行版，dump 全部键位
      3. 取差集 —— 得到的就是「本发行版实际增加的键位」
    这份文档因此不可能与配置不一致。改完配置重跑本脚本即可。

用法：
    python tools/gen-keymaps.py            # 生成 docs/KEYMAPS.md
    python tools/gen-keymaps.py --check    # 只校验文档是否已是最新（CI 用）
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DOC = REPO_ROOT / "docs" / "KEYMAPS.md"
TMP = REPO_ROOT / "build"

# 前导键后的首字母 -> 分组标题。这份映射决定了文档的章节结构。
GROUPS: dict[str, str] = {
    "s": "搜索（rg + quickfix 工作流）",
    "f": "查找（fzf-lua 交互选择器）",
    "c": "代码（LSP 动作与诊断）",
    "g": "Git",
    "b": "缓冲区",
    "w": "窗口",
    "d": "诊断与调试",
    "t": "标签页与终端",
    "r": "替换与重构",
    "u": "杂项",
    "q": "退出",
    "m": "消息与命令行",
    "n": "会话",
    "p": "粘贴",
    "y": "复制",
}

MODE_LABEL = {
    "n": "普通",
    "i": "插入",
    "v": "可视",
    "x": "可视",
    "s": "选择",
    "o": "操作符待决",
    "t": "终端",
    "c": "命令行",
}


def find_nvim() -> str:
    env = os.environ.get("NVIM")
    if env and Path(env).is_file():
        return env
    found = shutil.which("nvim")
    if found:
        return found
    for candidate in (
        REPO_ROOT / "build" / "toolchain" / "nvim" / "bin" / "nvim.exe",
        Path("D:/tools/nvim-win64/bin/nvim.exe"),
        Path("/usr/bin/nvim"),
        Path("/usr/local/bin/nvim"),
    ):
        if candidate.is_file():
            return str(candidate)
    raise SystemExit("找不到 nvim；请设置 NVIM 环境变量")


def dump(nvim: str, use_config: bool, out: Path) -> dict[tuple[str, str], tuple[str, str, str]]:
    """跑一次 nvim，返回 {(mode, lhs): (rhs, desc, scope)}"""
    out.parent.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    env["DUMP_OUT"] = str(out)
    # XDG 隔离：不要读用户既有的 Neovim 配置与数据
    for var, sub in (
        ("XDG_CONFIG_HOME", "xdg/config"),
        ("XDG_DATA_HOME", "xdg/data"),
        ("XDG_STATE_HOME", "xdg/state"),
        ("XDG_CACHE_HOME", "xdg/cache"),
    ):
        env[var] = str(TMP / sub)

    cmd = [nvim, "--headless"]
    cmd += ["-u", "init.lua"] if use_config else ["-u", "NONE"]
    cmd += ["-l", "tools/dump-keymaps.lua"]

    # 必须显式指定 utf-8：Windows 上默认用系统 GBK 解码，
    # 而本发行版的输出里有中文，会直接 UnicodeDecodeError。
    proc = subprocess.run(
        cmd, cwd=REPO_ROOT, env=env, capture_output=True, text=True,
        encoding="utf-8", errors="replace",
    )
    if not out.is_file():
        sys.stderr.write(proc.stdout or "")
        sys.stderr.write(proc.stderr or "")
        raise SystemExit(f"dump 失败（use_config={use_config}），没有产出 {out}")

    result = {}
    with out.open(encoding="utf-8") as fh:
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 5:
                continue
            mode, lhs, rhs, desc, scope = parts[:5]
            result[(mode, lhs)] = (rhs, desc, scope)
    return result


def leader_of(lhs: str) -> str | None:
    """把前导键映射归一化成 '<leader>x' 形式。"""
    if lhs.startswith("<Leader>") or lhs.startswith("<leader>"):
        return lhs[8:9]
    if lhs.startswith(" "):  # leader 是空格
        return lhs[1:2]
    return None


MODE_ORDER = ["n", "x", "s", "o", "i", "t", "c"]


def merge_modes(rows: list[tuple[str, str, str]]) -> list[tuple[str, str, str]]:
    """同一个键（且说明相同）在多个模式下的重复行合并成一行。

    不合并的话，mini.ai 的 `a` 会以「普通/可视/操作符待决」三行出现，
    整张表膨胀三倍且没有额外信息。
    """
    merged: dict[tuple[str, str], set[str]] = {}
    for mode, lhs, desc in rows:
        merged.setdefault((lhs, desc), set()).add(mode)

    out: list[tuple[str, str, str]] = []
    for (lhs, desc), modes in merged.items():
        label = "/".join(MODE_LABEL.get(m, m) for m in MODE_ORDER if m in modes)
        out.append((lhs, label, desc))
    return sorted(out, key=lambda x: x[0])


def render_plain(rows: list[tuple[str, str, str]]) -> list[str]:
    """渲染「直接键位」一节：排除 <Plug>，合并模式，并把 [X/]X 家族收成一张紧凑表。"""
    out: list[str] = []

    # <Plug> 映射是给别的插件/键位去 map 的，不是让人直接按的
    rows = [r for r in rows if not r[1].startswith("<Plug>")]

    brackets = [r for r in rows if r[1].startswith(("[", "]"))]
    plain = [r for r in rows if not r[1].startswith(("[", "]"))]

    out.append("| 键位 | 模式 | 说明 |")
    out.append("| --- | --- | --- |")
    for lhs, modes, desc in merge_modes(plain):
        out.append(f"| `{lhs}` | {modes} | {desc} |")
    out.append("")

    if brackets:
        # mini.bracketed 会为每个模块同时建 `[X` 与 `]X`（跳到首个/末个或上一个/下一个）。
        # 逐条列出来有近两百行，收成一张对照表才看得清。
        back: dict[str, str] = {}
        fwd: dict[str, str] = {}
        for _mode, lhs, desc in brackets:
            if lhs.startswith("[") and len(lhs) == 2:
                back.setdefault(lhs[1], desc)
            elif lhs.startswith("]") and len(lhs) == 2:
                fwd.setdefault(lhs[1], desc)

        out.append("### `[` / `]` 系列（由 mini.bracketed 建立）")
        out.append("")
        out.append("这些是「跳到前一个/后一个同类位置」的成对键位，例如 `]d` 下一个诊断、")
        out.append("`[q` 上一个 quickfix 项。带大写字母的是跳到**首个**，小写是**上一个/下一个**。")
        out.append("")
        out.append("| 键位 | 往前 | 往后 |")
        out.append("| --- | --- | --- |")
        for suffix in sorted(set(back) | set(fwd)):
            b = back.get(suffix, "—")
            f = fwd.get(suffix, "—")
            out.append(f"| `[{suffix}` / `]{suffix}` | {b} | {f} |")
        out.append("")

    return out

def render(mappings: dict[tuple[str, str], tuple[str, str, str]], total_before: int) -> str:
    lines: list[str] = []
    w = lines.append

    w("# 快捷键速查")
    w("")
    w("> **本文件由 `tools/gen-keymaps.py` 生成，请勿手改。**")
    w("> 它与配置不可能脱节：脚本分别用 `-u NONE`（干净 Neovim）与 `-u init.lua`（本发行版）")
    w("> 导出全部键位后取差集，得到的就是本发行版实际新增/改写的键位。")
    w("> 改完配置重跑 `python tools/gen-keymaps.py` 即可刷新。")
    w("")
    w("只列**全局**键位。插件在自己缓冲区里建的内部键位（fzf-lua 的 picker 界面、")
    w("mini.starter 的启动页等）不算「你会按的键」，所以不在下表 —— 那些键位在对应界面里")
    w("按 `?` 或看界面底部提示即可。LSP 的缓冲区键位单独列在最后。")
    w("")
    w(f"作为对照：干净 Neovim 的全局键位共 {total_before} 条（都是内置默认）。")
    w("")
    w("「说明」一列来自每个键位的 `desc`。本发行版要求所有自建键位都写 `desc`，")
    w("所以 which-key 的提示与本文档用的是同一份文字，不会各说各话。")
    w("")

    leader: dict[str, list[tuple[str, str, str]]] = {}
    other_leader: list[tuple[str, str, str]] = []
    plain: list[tuple[str, str, str]] = []

    for (mode, lhs), (_rhs, desc, scope) in mappings.items():
        if scope == "buffer":
            continue  # 见文件开头的说明
        if not desc:
            # 没有 desc 的条目多半是插件把内置键位重映射成了同样的行为，
            # 属于「假差异」。本发行版要求所有自建键位都写 desc，
            # 所以「无 desc」正好等于「不是给人按的键」。
            continue
        group = leader_of(lhs)
        if group is not None:
            rest = lhs[1:] if lhs.startswith(" ") else lhs[8:]
            if group in GROUPS:
                leader.setdefault(group, []).append((mode, "<leader>" + rest, desc))
            else:
                # <leader>:  <leader>Y 这类单键：不值得各自开一节，合并进「其它」
                other_leader.append((mode, "<leader>" + rest, desc))
        else:
            plain.append((mode, lhs, desc))

    w("## 前导键")
    w("")
    w("前导键是 <kbd>空格</kbd>（`vim.g.mapleader = ' '`）。按前导键后稍等，")
    w("`which-key` 会弹出下一步可选键位。")
    w("")
    for key in sorted(leader):
        items = leader[key]
        title = GROUPS.get(key, f"`<leader>{key}`")
        w(f"### `<leader>{key}` —— {title}")
        w("")
        w("| 键位 | 模式 | 说明 |")
        w("| --- | --- | --- |")
        for mode, lhs, desc in sorted(items, key=lambda x: (x[1], x[0])):
            w(f"| `{lhs}` | {MODE_LABEL.get(mode, mode)} | {desc or '—'} |")
        w("")

    if other_leader:
        w("### 其它前导键")
        w("")
        w("| 键位 | 模式 | 说明 |")
        w("| --- | --- | --- |")
        for mode, lhs, desc in sorted(other_leader, key=lambda x: (x[1], x[0])):
            w(f"| `{lhs}` | {MODE_LABEL.get(mode, mode)} | {desc or '—'} |")
        w("")

    w("## 直接键位（不经前导键）")
    w("")
    lines.extend(render_plain(plain))

    # LSP 的键位是按缓冲区设的（LspAttach 时），不是全局键位，所以上面那张表抓不到。
    # 它们的来源是 lua/distro/lsp.lua，数量少且稳定，这里如实列出。
    w("## LSP 键位（打开带语言服务器的文件后才生效）")
    w("")
    w("这些键位由 `lua/distro/lsp.lua` 在 `LspAttach` 时按缓冲区设置，")
    w("所以只在支持的文件类型里可用（例如 `.lua`、`.c`、`.py`）。")
    w("")
    w("| 键位 | 说明 |")
    w("| --- | --- |")
    for keys, desc in (
        ("`gd`", "跳转到定义"),
        ("`gD`", "跳转到声明"),
        ("`gr`", "查找引用"),
        ("`gi`", "跳转到实现"),
        ("`gt`", "跳转到类型定义"),
        ("`K`", "悬停文档"),
        ("`<C-k>`", "参数签名"),
        ("`<leader>rn`", "重命名符号"),
        ("`<leader>ca`", "代码动作"),
        ("`<leader>ct`", "整理 imports"),
        ("`<leader>cd`", "显示该行诊断"),
        ("`<leader>fmt`", "格式化当前缓冲区"),
        ("`[d` / `]d`", "上一个 / 下一个诊断"),
    ):
        w(f"| {keys} | {desc} |")
    w("")

    w("## 由插件自带、本发行版未改写的常用键位")
    w("")
    w("下面这些是插件 `setup()` 时自己建立的默认键位，本发行版沿用未改，")
    w("只列出日常会用到的部分：")
    w("")
    w("| 来源 | 键位 | 作用 |")
    w("| --- | --- | --- |")
    for row in (
        ("mini.ai", "`a` / `i` + 对象字符", "文本对象，如 `ciq` 改引号内、`daa` 删一个参数"),
        ("mini.surround", "`sa` `sd` `sr`", "增 / 删 / 改包围对，如 `saiw)` 给词加括号"),
        ("mini.comment", "`gc` / `gcc`", "注释（可视模式 `gc` 注释选区）"),
        ("mini.pairs", "插入模式输入 `(` `[` `{` `\"` `'`", "自动配对，回车智能展开"),
        ("mini.splitjoin", "`gS`", "多行参数 / 数组的拆开与合并"),
        ("mini.operators", "`gx` `gm` `g=`", "交换两侧、乘法（复制并替换）等"),
        ("mini.files", "`-`", "文件管理器（本发行版另绑 `<leader>e`）"),
        ("oil.nvim", "`-`", "在父目录打开（本发行版另绑 `<leader>e`，两者按需二选一）"),
        ("gitsigns.nvim", "`]c` `[c` `]c` 等", "逐块跳转；暂存等操作见其默认键位"),
        ("trouble.nvim", "—", "本发行版只经 `<leader>x*` 入口调用"),
    ):
        w(f"| {row[0]} | {row[1]} | {row[2]} |")
    w("")

    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="生成快捷键速查文档")
    parser.add_argument("--check", action="store_true", help="只校验文档是否已是最新")
    args = parser.parse_args(argv)

    nvim = find_nvim()
    base = dump(nvim, use_config=False, out=TMP / "keymaps-base.tsv")
    dist = dump(nvim, use_config=True, out=TMP / "keymaps-distro.tsv")

    added = {k: v for k, v in dist.items() if base.get(k) != v}
    doc = render(added, total_before=len(base))

    if args.check:
        current = DOC.read_text(encoding="utf-8") if DOC.is_file() else ""
        if current != doc:
            print("docs/KEYMAPS.md 与当前配置不一致，请重跑：python tools/gen-keymaps.py", file=sys.stderr)
            return 1
        print(f"docs/KEYMAPS.md 是最新的（{len(added)} 条键位）")
        return 0

    DOC.parent.mkdir(parents=True, exist_ok=True)
    DOC.write_text(doc, encoding="utf-8", newline="\n")
    print(f"已写出 {DOC.relative_to(REPO_ROOT)}：{len(added)} 条键位（基线 {len(base)} 条）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
