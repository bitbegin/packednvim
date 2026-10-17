# 已决策：每格一个答案

这份文档是 [`CHOOSING.md`](CHOOSING.md) 里那七步决策**真正跑一遍**的结果。数据在 [`../catalog/STACKS.toml`](../catalog/STACKS.toml)，已经写进插件目录。

```bash
python tools/parse_selection.py --stack recommended --apply   # 套用（默认已套用这套）
python tools/parse_selection.py --stack minimal     --apply   # 换成极简
python tools/parse_selection.py --stack full        --apply   # 换成全功能
```

`--apply` 会把勾选状态**整体重写**成该方案，不在清单里的一律取消，所以换方案就一条命令。

## 结果概览

数字都是实测的（`--stack` 试算输出），不是估算：

| 方案 | 勾选条目 | 需 vendor 的仓库 | 纯 Lua 条目 | 互斥格冲突 | 离线风险项 | 仍需自备的命令 |
| --- | --- | --- | --- | --- | --- | --- |
| `minimal` | 43 | 24 | 36 | 0 | 2 | 6 |
| **`recommended`（已套用）** | **59** | **43** | **48** | **0** | **3** | 6 |
| `full` | 103 | 85 | 79 | 0 | 4 | 20 |

**「互斥格冲突」这一列是机械校验出来的**，不是我说没有就没有：`tools/check-stack.py` 里有一张 30 个互斥格的表，逐个方案检查「同一格是否选了不止一个」。

```bash
python tools/check-stack.py          # 校验全部方案，有冲突则退出码 1
python tools/check-stack.py --list   # 打印所有互斥格及其成员
```

这个脚本的存在本身就是「方案取代档位」的原因：`档位` 是单项属性，无法表达互斥；方案能表达，但方案是手写的，所以需要机械校验兜住。

「离线风险项」指属「编译/下载」档的插件，**必须在打包时预置产物**，否则用户第一次离线启动就出问题：

| 方案 | 风险项 |
| --- | --- |
| `minimal` | `blink.cmp`、`nvim-treesitter` |
| `recommended` | 上面两个 + `jieba.vim` |
| `full` | 上面三个 + `markdown-preview.nvim` |

处理方式见 `ARCHITECTURE.md` 第 4、5 节。

**注意 `full` 档的性质变了**：它把调试适配器、测试运行器、数据库客户端、`curl`、`go`、`pytest`、`psql`、`mysql` 等一共 29 类外部命令都变成前置条件。这跟「所有依赖打包在一起、零联网」的目标冲突最大——那些工具要么得自己构建，要么得带 Node / Python 运行时进来。**所以 `recommended` 是这三套里最符合你原始要求的那个。**

## 逐格决策

「依据」一列写的是这七步里的哪一步起了决定作用：① 能用内置就不用 ② 同格只选一个 ③ 优先 mini 模块 ④ 需要专精能力时选单一职责插件 ⑤ 别让 mini 与 snacks 混当主心骨 ⑥ 跳过停更项 ⑦ 先控在 30 个仓库以内。

| 功能格 | 选定 | 依据 | 落选及原因 |
| --- | --- | --- | --- |
| 模糊查找 | `fzf-lua` | ② 你已定 | telescope（结果窗口鼠标支持弱）、`mini.pick`（大仓库慢）、`snacks.picker`（⑤） |
| 补全引擎 | `blink.cmp` | ⑥ | `nvim-cmp`（官方已进维护模式）、`coq_nvim`（GPL + 重） |
| 状态栏 | minimal 用 `mini.statusline`；其余用 `lualine` | ③ / ④ | — |
| 标签栏 | `mini.tabline` | ⑥ | `bufferline`（长期未更新）、`barbar`（仓库无 LICENSE 文件，**已按决定移出目录**） |
| 文件浏览器 | minimal/推荐用 `oil.nvim`；full 用 `neo-tree.nvim` | ④ | `mini.files`（与 oil 功能重复，已剔除）、`nvim-tree`（许可不清，**已移出目录**） |
| 启动页 | `mini.starter` | ③ | `dashboard-nvim`、`alpha-nvim` |
| 配色主题 | 保留 6 个：`tokyonight`（默认）、`catppuccin`、`kanagawa`、`gruvbox-material`、`nightfox`、`rose-pine` | ② 的**有意例外** | 其余 13 个。配色在激活前不占运行成本，留几个供切换 |
| 片段引擎 | `LuaSnip` + `friendly-snippets` | ⑥ | `mini.snippets`、`nvim-snippy`、`vim-vsnip`（停更） |
| 环绕字符 | `mini.surround` | ③ | `nvim-surround` |
| 自动配对 | `mini.pairs` | ③ | `nvim-autopairs` |
| 注释 | 内置（0.10+）；full 档加 `ts-comments` | ① | `Comment.nvim`（停更，且内置已覆盖） |
| 快速跳转 | `flash.nvim` | ④ | `hop`、`leap`、`mini.jump`、`mini.jump2d` |
| 键位提示 | minimal 用 `mini.clue`；其余用 `which-key` | ③ / ④ | `hawtkeys`（活跃度低） |
| 通知 | `mini.notify` | ⑥ | `nvim-notify`（停更）。full 档另有 `noice`，但它与 `mini.notify` 是「UI + 通知后端」的关系，不是替代 |
| 命令行 / 输入 UI | minimal/推荐用 `dressing.nvim`；full 用 `noice.nvim` | ④ | `snacks.input` |
| Git 行内标记 | `gitsigns.nvim` | ⑥ | `mini.diff`（能力不足以替代 blame 与 hunk 预览） |
| Git 操作界面 | `neogit` | ④ | `fugitive`（VimScript）、`lazygit`（要额外二进制）、`mini.git`（full 档） |
| diff 视图 | `diffview` | ⑥ 的例外 | 已停更但**无可替代品**，所以保留 |
| Git 联网功能 | 全部排除 | ① / 需求 3 | `octo.nvim` |
| 诊断面板 | `trouble.nvim` | ④ | `quicker`（与 trouble 在 quickfix 增强上重叠，三套都不选） |
| 符号大纲 | 只在 full 档用 `aerial` | ④ | `outline.nvim`（与 aerial 重复，已剔除） |
| 面包屑 | 只在 full 档用 `dropbar` | ④ | `nvim-navic`（与 dropbar 重复，已剔除）、`barbecue`（已归档） |
| 格式化 | `conform.nvim` | ④ | `formatter.nvim`、`none-ls`（与 conform + nvim-lint 重叠，已剔除） |
| 静态检查 | `nvim-lint` | ④ | `none-ls`（想把一切都走 LSP 的人才需要；与 nvim-lint 重叠，已剔除） |
| 大文件降级 | **本仓库自写**（`lua/distro/search.lua`） | ① | `snacks.bigfile`、`bigfile.nvim`（停更）、`nvim-bigfile`（停更） |
| 会话管理 | `mini.sessions` | ③ | `persistence` |
| 书签 / 最近文件 | `mini.visits` | ③ | `harpoon`（未选）、`arrow.nvim`（与 mini.visits 重复，已剔除） |
| 项目根识别 | 内置 `vim.fs.root` | ① | `project.nvim`（停更，功能已被内置取代） |
| 终端 | 内置 `:terminal` | ①⑥ | `toggleterm`（停更）、`snacks.terminal` |
| 多光标 | 不选 | ⑦ | `multicursor`、`multiple-cursors`——宏与 `:norm` 更符合 Vim 习惯 |
| 输入法切换 | `im-select.nvim` | ⑥ | `auto-input-switch`、`im-autoswitch`（与 im-select 重复，已剔除）、`fcitx5.nvim`（停更且仅 Linux） |
| 中文分词 | `jieba.vim` | 需求 | 无替代品；需预编译 Rust 产物 |
| 图标 | minimal 用 `mini.icons`；其余用 `devicons` | ③ / 已定 Nerd Font | — |
| 搜索替换 | `grug-far.nvim` | ④ | `nvim-spectre` |
| 公共依赖 | `plenary.nvim` | ② 的例外 | `nui.nvim` 只在 full 档（仅 `noice` 需要） |
| 插件管理器 | 不选 | 架构决定 | `lazy.nvim`、`vim.pack`、`packer` |
| LSP 安装器 | 不选 | 需求 3 | `mason.nvim`、`mason-lspconfig`、`mason-nvim-dap` |
| AI 助手 | 全部排除 | 需求 3 | `codecompanion`、`avante`、`copilot.lua`、`minuet`、`gen` |
| HTTP 客户端 | 只在 full 档用 `kulala.nvim` | ④ | `rest.nvim`（与 kulala 重复且是 GPL-3.0，已剔除） |
| 调试 / 测试 / 数据库 | 只在 full 档 | ⑦ | `vim-test`（与 neotest 重复）、`glow.nvim`（与 render-markdown 重复） |

## 一个容易被忽略的点：mini 的模块是「免费」的

`nvim-mini/mini.nvim` 的 45+ 个模块共用**一个仓库**。所以：

- 勾 20 个 mini 模块 ≈ **1 个仓库**、一份 vendor 体积、一次 git clone。
- 替代方案是勾 20 个各自独立的插件 ≈ **20 个仓库**、20 份体积、20 次 clone，且启动时多 20 个 runtimepath 条目。

这是为什么 `recommended` 方案里 mini 模块列得这么大方——它们在仓库数、体积、离线风险三个维度上几乎不花钱。**这也是我最终没选 `snacks.nvim` 的原因**：snacks 一个仓库覆盖 8–12 块功能看着很划算，但它与 mini 及一批单项插件直接竞争，按第 ⑤ 步只能二选一，而 mini 在「纯 Lua、零外部依赖、模块可拆」这三点上更适合离线发行版。

## 本轮已定

| 事项 | 决定 |
| --- | --- |
| 语言服务器 | **暂不打包**。`lua-language-server` / `clangd` / `basedpyright` / `bash-language-server` 都自行安装；发行版用 `vim.fn.executable()` 探测，缺失时只在 `:checkhealth distro` 报告，不报错 |
| `ruff` | **不要。** 连带影响：Python 的格式化与检查不再自包含，要用得自己装 `ruff` 或 `black`（或走 LSP 格式化） |
| `shellcheck` | **加入 `bin/`。** 注意它是 **GPL-3.0**，是 `bin/` 里唯一的 copyleft 项，分发时要附源码或书面承诺 |
| 主题 | **保留 6 个**（见上表配色一行） |
| 主心骨 | **mini**（确认）。`snacks.nvim` 保持不选 |
| `im-select.exe` | **加入 `bin/`**。它没有 release 资源，是从仓库 `win/out/x64/` 直接取的裸文件，因此改用 **git blob 哈希**（`890b3eb1…`）固化内容。只在 Windows 上有意义，Linux 侧用系统的 `fcitx5-remote` / `ibus` |
| 方案 | **`recommended`**（59 项 / 43 仓库） |
| 两个许可待核项 | **不用。** `nvim-tree/nvim-tree.lua`（API 报 NOASSERTION）与 `romgrk/barbar.nvim`（无 LICENSE 文件）已从目录中删除，目录条目 208 → 206 |
| 打包方式 | **每个平台一个包**（linux64 / linux-arm64 / win64 / darwin-arm64），各自带该平台的 Neovim、工具与解析器。原「只打一个包、内含两平台二进制」已作废 —— 那样每个包都要带一半用不到的东西 |
| Python 工具链 | **不需要。** `bin/` 里没有 Python 格式化/检查工具 |

## 一个需要留意的体积事实

去掉 `ruff`（51.6 MB）换上 `shellcheck`（51.0 MB）后，**`bin/` 净体积几乎没变**：102.8 MB → 102.3 MB。

`shellcheck` 一点都不小——Windows 版 34.8 MB、Linux 版 16.2 MB，它是 Haskell 静态链接的产物。所以如果当初去掉 `ruff` 是为了省体积，这次替换并没有达到目的。另一个大头是 `stylua`（19.6 MB / 两平台）。不过**既然已定每平台一个包**，每个包只带自己平台那一份（约 51 MB），不必再为此纠结。

## 仍待你定

只剩两件小事，都不阻塞开工：

- **`luacheck`**：Lua 侧唯一没有随包的工具（`stylua` 已随包）。它**没有官方预编译产物**，要随包就得自己构建。这是目前「Lua 工作流完全自包含」的唯一缺口。
- **Python 工具链**已按决定留空，若日后想要，`ruff` 或 `black` 都可以加回 `bin/`。
