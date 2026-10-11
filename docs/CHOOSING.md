# 怎么选：重叠分析与推荐组合

## 先回答「为什么每个功能都有好多可选项」

三个原因，都不是我为了凑数：

1. **Neovim 没有官方插件层。** 核心只自带引擎（LSP 客户端、tree-sitter、诊断框架、补全协议、`vim.pack`），具体功能全靠社区。同一个需求通常有 3–6 个成熟实现长期并存，因为大家对「该带多少默认行为」的看法不一样。
2. **设计哲学分三派：**
   - **极简派**（`mini.nvim` 各模块、内置能力）：只做一件事、零默认行为，接线自己来。
   - **专精派**（`flash.nvim`、`oil.nvim`、`conform.nvim`）：一块功能做到极致，不管别的。
   - **全家桶派**（`snacks.nvim`、`noice.nvim`）：一个插件吃掉 6–10 块功能，开箱即用但难以拆开。
3. **我故意没替你先砍。** 你说「插件我来选择集成」，所以同一格的候选我都列上了。代价就是目录看着像一堆选择题，而不是一份答案。

如果你更想要「每格一个答案」的版本，说一声，我把下面推荐栈里选定的那套直接勾进目录。

## 真正要紧的是：哪些互斥，哪些能叠

### A. 互斥簇 —— 每格只选一个

选了多个通常不是功能更多，而是**键位打架、启动变慢、UI 风格分裂**。

| # | 功能格 | 候选 | 推荐 | 一句话理由 |
| --- | --- | --- | --- | --- |
| 1 | 模糊查找 picker | telescope / fzf-lua / mini.pick / snacks.picker | **fzf-lua**（已定） | 大仓库最快；fzf 原生鼠标双击，直接满足需求 5 的「点击跳转」 |
| 2 | 补全引擎 | blink.cmp / nvim-cmp / coq_nvim | **blink.cmp** | nvim-cmp 已进维护模式；代价是要预置 Rust 二进制（或退回 `fuzzy.implementation = "lua"`） |
| 3 | 状态栏 | lualine / mini.statusline | **lualine** | 主题与组件生态最广；走极简路线就换 mini.statusline |
| 4 | 标签栏 | bufferline / barbar / mini.tabline | **mini.tabline** | 纯 Lua 零配置；`bufferline` 长期未更新、`barbar` 无 LICENSE 文件（**已移出目录**） |
| 5 | 文件浏览器 | neo-tree / nvim-tree / oil / mini.files | **oil.nvim** | 把目录当普通 buffer 编辑，和 Neovim 操作模型一致；想要侧栏树就选 `neo-tree`（`nvim-tree` 许可不清，**已移出目录**） |
| 6 | 启动页 | dashboard-nvim / alpha-nvim / mini.starter / snacks.dashboard | **mini.starter** | 纯 Lua 可完全自绘；不太在意启动页也可以不要 |
| 7 | 配色主题 | tokyonight / catppuccin / kanagawa / nightfox / … | **tokyonight** | 插件适配最广、维护最勤；18 个候选里挑 1–2 个即可，多装只是占地方 |
| 8 | 片段引擎 | LuaSnip / mini.snippets / nvim-snippy | **LuaSnip** | 兼容 VSCode 与 LSP 两种片段格式，生态最大 |
| 9 | 环绕字符 | mini.surround / nvim-surround | **mini.surround** | 纯 Lua 且顺手少一个仓库；键位习惯改不过来就用 nvim-surround |
| 10 | 自动配对 | mini.pairs / nvim-autopairs | **mini.pairs** | 同理；需要复杂规则的场景才用 nvim-autopairs |
| 11 | 注释 | 内置（0.10+）/ mini.comment / Comment.nvim / ts-comments | **内置 + ts-comments** | 0.10 起已内置注释；只有 JSX 这类混合语言才需要 ts-comments 决定注释符 |
| 12 | 快速跳转 | flash / hop / leap / mini.jump / mini.jump2d | **flash.nvim** | 覆盖最全，能直接跳 tree-sitter 节点 |
| 13 | 键位提示 | which-key / mini.clue | **which-key** | 预设丰富、上手即用；mini.clue 适合想常驻提示的极简派 |
| 14 | 通知 | mini.notify / nvim-notify / snacks.notifier / noice | **mini.notify** | nvim-notify 已停更；小、纯 Lua、无依赖 |
| 15 | 命令行 / 输入 UI | noice / dressing / snacks.input | **dressing**（轻）或 **noice**（重） | noice 覆盖面最大但更新放缓且依赖 nui；只要美化 `vim.ui` 就用 dressing |
| 16 | Git 操作界面 | neogit / fugitive / lazygit / mini.git | **neogit** | 类 Magit，功能完整；只想要 `:Git` / `:Gdiffsplit` 就用 fugitive |
| 17 | Git 行内标记 | gitsigns / mini.diff | **gitsigns** | **与上面的 Git 界面不冲突**，是叠加关系，不是二选一 |
| 18 | diff 视图 | diffview / mini.diff / fugitive | **diffview** | 已停更但稳定且无替代品 |
| 19 | 终端 | toggleterm / snacks.terminal / 内置 `:terminal` | **内置 或 snacks** | toggleterm 长期未更新；内置 `:terminal` 零依赖 |
| 20 | 诊断面板 | trouble / quicker | **trouble** | 诊断、引用、quickfix 一网打尽；只想增强 quickfix 就用 quicker |
| 21 | 符号大纲 | aerial / outline | **aerial** | LSP 与 tree-sitter 双支持 |
| 22 | 格式化 | conform / formatter.nvim / none-ls | **conform** | 调度最灵活，能回退到 LSP 格式化 |
| 23 | 静态检查 | nvim-lint / none-ls | **nvim-lint** | 单一职责，配 conform 正好；none-ls 是「什么都想走 LSP」的选择 |
| 24 | 大文件降级 | **本仓库已自写** / snacks.bigfile / bigfile.nvim | **已自写** | 见 `lua/distro/search.lua`，已测试，不需要额外插件 |
| 25 | 会话管理 | persistence / mini.sessions | **mini.sessions** | 纯 Lua；要退出自动存就用 persistence |
| 26 | 书签 / 最近文件 | harpoon / arrow / mini.visits | **mini.visits** 或 harpoon | mini.visits 零依赖；harpoon 的菜单式交互更直观 |
| 27 | 项目根识别 | project.nvim / **内置 `vim.fs.root`** | **内置** | 0.12 已有 `vim.fs.root()`，project.nvim 已停更 |
| 28 | 输入法切换 | im-select / auto-input-switch / im-autoswitch | **im-select** | 双平台最省事的方案（Windows 用 im-select.exe，Linux 用 fcitx5-remote/ibus） |
| 29 | 多光标 | multicursor / multiple-cursors / 不选 | **先不选** | 宏与 `:norm` 更符合 Vim 习惯，且少一个要维护的插件 |

### B. 可以放心叠加的 —— 别怕多选

这些看着像重叠，其实各管一摊：

- **语法层**：`nvim-treesitter` + `textobjects` + `context` + `ts-autotag` + `ts-comments`
- **LSP 增强**：`lazydev`（Lua 专用）+ `lsp_signature`（参数提示）+ `actions-preview`（code action 预览）+ `navic`/`dropbar`（面包屑）+ `aerial`（大纲）
- **编辑动作**：`mini.ai`（管 `a`/`i` 对象）+ `nvim-treesitter-textobjects`（管函数/类对象）+ `nvim-various-textobjs`（管 URL、缩进块）——键位空间不重叠
- **Git 三件套**：`gitsigns`（行内标记）+ `neogit`（暂存提交）+ `diffview`（看 diff），同时装是常见组合

### C. 「覆盖」的重灾区：`mini.nvim` 与 `snacks.nvim`

这一节最值得看，它直接决定你要 vendor 多少个仓库。

**`mini.nvim` = 45+ 个独立模块，一个仓库。** 勾它一个等于同时砍掉十几个仓库：

```
mini.ai  mini.surround  mini.pairs  mini.comment  mini.statusline  mini.tabline
mini.starter  mini.pick  mini.files  mini.sessions  mini.visits  mini.notify
mini.clue  mini.icons  mini.indentscope  mini.bracketed  mini.move  mini.operators
mini.bufremove  mini.hipatterns  mini.align  mini.splitjoin  mini.trailspace
mini.cursorword  mini.jump  mini.jump2d  mini.diff  mini.git  mini.snippets
mini.extra  mini.basics  mini.hues  mini.misc  mini.doc  mini.test
```

对一个**离线发行版**来说这是最优解：纯 Lua、零外部依赖、一个仓库、上游极稳定、模块之间互不干扰。目录里我用 `#模块名` 的形式把它们拆开，方便你逐个勾——注意 vendor 时按仓库去重，勾 18 个模块也只会克隆一次。

**`snacks.nvim` = 一个仓库里的全家桶**，模块覆盖 picker / explorer / terminal / notifier / input / bigfile / dashboard / profiler / git / scope / statuscolumn / words……

它和 **mini 的对应模块以及一批单项插件直接竞争**。选了 `snacks.picker` 就别再选 `fzf-lua`/`mini.pick`；选了 `snacks.notifier` 就别再选 `mini.notify`。

**结论：mini 与 snacks 大量重叠，只选一个当主心骨。**

| 你更看重 | 主心骨 | 说明 |
| --- | --- | --- |
| 体积小、行为最可预测、零依赖 | **mini** | 纯 Lua 模块，一个仓库，最契合离线目标 |
| 少写配置、开箱即用的观感 | **snacks** | 但它的 picker 仍建议让位给 fzf-lua（需求 4 已定） |

两者混着当主心骨会出现两套键位和两套 UI 风格，这是最常见的后悔来源。

## 三套推荐组合

### ① 极简（约 20 个仓库）

以 mini 模块为骨干，只加必须的专精件。启动最快、行为最可预测。

```
mini.ai  mini.surround  mini.pairs  mini.comment  mini.bracketed
mini.move  mini.operators  mini.indentscope  mini.icons  mini.statusline
mini.tabline  mini.starter  mini.sessions  mini.visits  mini.notify
mini.clue  mini.snippets
+ fzf-lua          （需求 4 已定）
+ nvim-treesitter  + treesitter-textobjects
+ nvim-lspconfig   + lazydev
+ blink.cmp + LuaSnip + friendly-snippets + lazydev
+ conform.nvim + nvim-lint
+ gitsigns.nvim
+ tokyonight.nvim
+ im-select.nvim
```

### ② 推荐（约 35 个仓库）

在极简上把「体验件」换成专精实现，LSP / 格式化 / 诊断链路补齐。

```
极简的全部，再换成/加上：
+ flash.nvim       替代 mini.jump/jump2d，跳转能力更强
+ oil.nvim         替代 mini.files
+ lualine.nvim     替代 mini.statusline
+ which-key.nvim   替代 mini.clue
+ trouble.nvim     诊断面板
+ neogit.nvim      暂存与提交
+ aerial.nvim      符号大纲
+ mini.git / nvim-treesitter-context / ts-comments / nvim-ts-autotag
+ lazydev + lsp_signature + actions-preview
+ friendly-snippets + blink.cmp 的 LSP 源
+ render-markdown.nvim + todo-comments
+ grug-far.nvim    搜索替换（需求 5 的 <leader>sr）
```

### ③ 全功能（约 60 个仓库）

即 `--preset ide` 那一套，再加 DAP、测试、数据库、终端、Markdown 预览等。

**建议从 ① 或 ② 起步。** 先跑起来再加，比一次堆 60 个仓库再排查问题容易一个数量级——尤其是离线包里每个「编译/下载」档的插件都要单独预处理。

## 一条不会错的决策顺序

1. **能用内置就不用插件**：注释（0.10+）、`vim.lsp.config`（0.11+）、`vim.fs.root`、诊断 API、`:terminal`、`vim.pack`。内置的永远最稳、最省体积。
2. **同一格只选一个**，按上面 A 表的推荐。
3. **优先 mini 模块**：纯 Lua、一个仓库、没有外部依赖，天然适合离线。
4. **需要专精能力时选单一职责插件**：flash / oil / conform / trouble / grug-far。
5. **别让 mini 与 snacks 混着当主心骨。**
6. **跳过停更项**：目录里备注写「已停更」「已归档」的，除非没有替代品（如 diffview），否则不选。
7. **先控在 30 个仓库以内。**

## 在目录里怎么操作

```bash
# 先套一个基线，再手工增删
python tools/parse_selection.py --preset core --apply    # 轻量核心 50 项 / 33 仓库
python tools/parse_selection.py --preset ide  --apply    # 开箱即用 116 项 / 98 仓库

# 看看选完之后的结论
python tools/parse_selection.py
```

`--preset` 只按 `档位` 字段勾选，不理解上面 A 表的互斥关系。**如果你想要「每格一个答案」的精简目录，告诉我走哪套推荐组合（①/②/③），我直接把它固化进 `catalog/PLUGIN-CATALOG.md`，把同格的其他候选标成 `备选` 但不勾选。**
