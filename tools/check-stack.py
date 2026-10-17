#!/usr/bin/env python3
"""校验方案里没有「同格多选」。

为什么需要这个工具
------------------
选型目录给每个插件标了 `档位`（core / ide / extra），那只是「推荐强度」这一个维度。
按档位勾选（`--preset`）无法表达「这几项互相替代、只能选一个」——实测 `--preset core`
会同时勾上 telescope + mini.pick + oil + mini.files（两个 picker、两个文件管理器）、
lualine + mini.statusline（两个状态栏）、mini.icons + devicons（两个图标集）。

`catalog/STACKS.toml` 里的方案是「逐格决策的结果」，天然能表达互斥。但方案是人手写的，
所以还需要一个机械校验：下面 SLOTS 里每一格的成员，在同一个方案里最多命中一个。

用法：
    python tools/check-stack.py                # 校验全部方案
    python tools/check-stack.py recommended    # 只校验指定方案
    python tools/check-stack.py --list         # 打印所有互斥格及其成员

有任何冲突以退出码 1 结束，可直接接进打包前的检查。
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from parse_selection import DEFAULT_CATALOG_DIR, load_stacks, parse_file  # noqa: E402

# 互斥格：同一格里的插件互相替代，一个方案里最多选一个。
# 注意区分「互斥」与「可叠加」——mini.ai 与 treesitter-textobjects 各管一类文本对象，
# 键位空间不重叠，所以它们不在同一格里；gitsigns / neogit / diffview 同理。
SLOTS: dict[str, list[str]] = {
    "模糊查找": ["nvim-telescope/telescope.nvim", "ibhagwan/fzf-lua", "nvim-mini/mini.nvim#mini.pick", "folke/snacks.nvim"],
    "文件浏览器": ["stevearc/oil.nvim", "nvim-mini/mini.nvim#mini.files", "nvim-neo-tree/neo-tree.nvim"],
    "状态栏": ["nvim-lualine/lualine.nvim", "nvim-mini/mini.nvim#mini.statusline"],
    "标签栏": ["akinsho/bufferline.nvim", "nvim-mini/mini.nvim#mini.tabline"],
    "图标": ["nvim-tree/nvim-web-devicons", "nvim-mini/mini.nvim#mini.icons"],
    "键位提示": ["folke/which-key.nvim", "nvim-mini/mini.nvim#mini.clue"],
    "面包屑": ["Bekaboo/dropbar.nvim", "SmiteshP/nvim-navic"],
    "补全引擎": ["saghen/blink.cmp", "hrsh7th/nvim-cmp", "ms-jpq/coq_nvim"],
    "片段引擎": ["L3MON4D3/LuaSnip", "nvim-mini/mini.nvim#mini.snippets", "dcampos/nvim-snippy"],
    "环绕": ["nvim-mini/mini.nvim#mini.surround", "kylechui/nvim-surround"],
    "自动配对": ["nvim-mini/mini.nvim#mini.pairs", "windwp/nvim-autopairs"],
    "注释": ["nvim-mini/mini.nvim#mini.comment", "numToStr/Comment.nvim"],
    "快速跳转": ["folke/flash.nvim", "smoka7/hop.nvim", "ggandor/leap.nvim",
                 "nvim-mini/mini.nvim#mini.jump", "nvim-mini/mini.nvim#mini.jump2d"],
    "通知": ["nvim-mini/mini.nvim#mini.notify", "rcarriga/nvim-notify"],
    "命令行 UI": ["stevearc/dressing.nvim", "folke/noice.nvim"],
    "诊断面板": ["folke/trouble.nvim", "stevearc/quicker.nvim"],
    "符号大纲": ["stevearc/aerial.nvim", "hedyhli/outline.nvim"],
    "格式化": ["stevearc/conform.nvim", "mhartington/formatter.nvim"],
    "静态检查": ["mfussenegger/nvim-lint", "nvimtools/none-ls.nvim"],
    "Git 操作界面": ["NeogitOrg/neogit", "tpope/vim-fugitive", "kdheepak/lazygit.nvim"],
    "diff 视图": ["sindrets/diffview.nvim", "nvim-mini/mini.nvim#mini.diff"],
    "会话": ["nvim-mini/mini.nvim#mini.sessions", "folke/persistence.nvim"],
    "书签 / 最近文件": ["ThePrimeagen/harpoon", "otavioschwanck/arrow.nvim", "nvim-mini/mini.nvim#mini.visits"],
    "输入法切换": ["keaising/im-select.nvim", "amekusa/auto-input-switch.nvim", "Old-Farmer/im-autoswitch.nvim"],
    "HTTP 客户端": ["mistweaverco/kulala.nvim", "rest-nvim/rest.nvim"],
    "测试框架": ["nvim-neotest/neotest", "vim-test/vim-test"],
    "搜索替换": ["MagicDuck/grug-far.nvim", "nvim-pack/nvim-spectre"],
    "大文件降级": ["LunarVim/bigfile.nvim", "ouuan/nvim-bigfile"],
    "终端管理": ["akinsho/toggleterm.nvim", "chomosuke/term-edit.nvim"],
    "LSP 安装器": ["neovim/nvim-lspconfig", "mason-org/mason.nvim"],
    # 两者都在缓冲区里**内联**渲染 Markdown，同时开会互相覆盖虚拟文本
    # （表现为表格错位、标题符号重复），所以互斥。
    # 注意 markdown-preview.nvim 不在本格：它渲染到浏览器，不与内联渲染
    # 争同一批 extmark，可以和它们共存。
    "Markdown 内联渲染": ["OXY2DEV/markview.nvim", "MeanderingProgrammer/render-markdown.nvim"],
}


def load_catalog() -> dict[str, dict]:
    entries: dict[str, dict] = {}
    for path in sorted(p for p in DEFAULT_CATALOG_DIR.glob("*.md") if p.name not in ("README.md", "OVERVIEW.md")):
        for entry in parse_file(path)[0]:
            entries[entry["id"]] = entry
    return entries


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="校验方案里没有同格多选")
    parser.add_argument("stacks", nargs="*", help="要校验的方案名（默认全部）")
    parser.add_argument("--list", action="store_true", help="打印所有互斥格及成员后退出")
    args = parser.parse_args(argv)

    if args.list:
        for name, members in SLOTS.items():
            print(f"{name}（{len(members)} 选 1）")
            for m in members:
                print(f"    {m}")
        return 0

    catalog = load_catalog()
    stacks = load_stacks()
    if not stacks:
        print(f"读不到方案，检查 {DEFAULT_CATALOG_DIR / 'STACKS.toml'}", file=sys.stderr)
        return 2

    wanted = args.stacks or list(stacks)
    total_conflicts = 0

    for name in wanted:
        if name not in stacks:
            print(f"没有方案 {name!r}；可用：{', '.join(stacks)}", file=sys.stderr)
            return 2
        ids = set(stacks[name].get("plugins", []))
        unknown = sorted(ids - set(catalog))
        selected = [catalog[i] for i in ids if i in catalog]

        repos = {e["repo"] for e in selected}
        risky = [e["id"] for e in selected if e["dep_class"] in ("编译/下载", "联网")]
        conflicts: list[tuple[str, list[str]]] = []
        for slot, members in SLOTS.items():
            hit = [m for m in members if m in ids]
            if len(hit) > 1:
                conflicts.append((slot, hit))

        print(f"=== {name} ===")
        if "desc" in stacks[name]:
            print(f"  {stacks[name]['desc']}")
        print(f"  条目 {len(selected)} 个 / 仓库 {len(repos)} 个")
        print(f"  互斥格检查：{len(SLOTS)} 格，冲突 {len(conflicts)} 个")
        for slot, hit in conflicts:
            print(f"    ✗ {slot}：{', '.join(hit)}")
        if risky:
            print(f"  离线风险项（必须在打包时预置产物）：")
            for r in risky:
                print(f"    - {r}")
        if unknown:
            print(f"  ✗ 清单里有目录中不存在的 id：{', '.join(unknown)}")
        print()

        total_conflicts += len(conflicts) + len(unknown)

    if total_conflicts:
        print(f"发现 {total_conflicts} 个问题", file=sys.stderr)
        return 1
    print(f"全部通过：{len(wanted)} 套方案都没有同格多选")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
