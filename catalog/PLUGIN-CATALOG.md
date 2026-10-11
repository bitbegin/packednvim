# Neovim 发行版 · 插件选型目录

> 目标：Linux + Windows 双平台，**所有插件随包分发、运行时零联网**，目标 Neovim **0.13 nightly**（API 代际同 0.12）。
> 用法见 [`README.md`](./README.md)。勾选就是把 `- [ ]` 改成 `- [x]`。

## 需求 4 与 5 指定：这几项是硬要求，不是可选项

你追加的两条要求是「需要用 rg 搜索，且支持 fzf 或 telescope」和「支持搜索大文件、正则、结果按行显示在窗口里、点击能跳转」。落地方式如下，它**部分覆盖**了之前「只打包配置和插件」的选择——因为 `rg` 是外部程序，要保证开箱可用就必须随包分发：

| 能力 | 落地方式 | 随包分发 |
| --- | --- | --- |
| `rg` 全文搜索 | `ripgrep` 的可执行文件放进 `bin/`，启动脚本把它前置进 `PATH` | **是**（win-x64 / linux-x64 各约 2 MB） |
| 正则 + 按行结果窗口 + 点击跳转 | `grepprg` 指向 `rg --vimgrep`，结果进 quickfix，加一条 `<2-LeftMouse>` 映射即可点击跳转。**纯内置，零插件** | 仅需 `rg` |
| 模糊查找 | 在下面 E 类里至少选一个 picker。**已定用 `fzf-lua`**，故 `fzf` 二进制一并打包（约 2.3 MB） | 插件是；`fzf` 是 |
| 大文件不卡死 | 绝不能用内置 `:vimgrep`（会把整个文件读进内存）；走外部 `rg`，并给跳转后打开的大文件做降级 | 见 W 类 |

所以 E 类不是「随便挑挑」，请至少勾一个。`mini.pick` 与 `snacks.picker` 是纯 Lua、零外部依赖的备选，但在大仓库下速度不如 fzf 后端。

完整方案（含可直接粘贴的 `grepprg`、鼠标映射、大文件降级代码）见 [`../docs/SEARCH-WORKFLOW.md`](../docs/SEARCH-WORKFLOW.md)。

## 本目录的筛选口径

调研后有三条结论直接决定了下面的取舍，先说清楚，省得你勾完才发现不可行：

1. **不装插件管理器。** 插件直接放进 `pack/distro/start/`（自动加载）和 `pack/distro/opt/`（按需 `:packadd`），这是 Neovim 内置机制，运行时完全不碰网络。`vim.pack`（0.12+）虽然是内置的，但它默认要 `git` 联网 clone，且 `src` 与磁盘不一致时会删掉重克隆——对离线包是隐患。lazy.nvim 可以离线跑，但需要显式关掉 `install.missing` 和 `rocks.enabled`，属于额外风险面。
   好处是：**整个发行版可以完全不依赖 git**，解压即用。
2. **不装 mason.nvim。** mason 的注册表刷新、`:MasonInstall`、metadata provider 全部走网络，官方没有「完全离线模式」；`mason-lspconfig` 也明确只认自己装的服务器。离线方案是 `vim.lsp.config(name, { cmd = {...} })` + `vim.env.PATH` 注入，目录里所有 LSP 相关项都按这个前提写。
3. **「编译/下载」档是本目录的高危区。** 你要求不联网，所以每一项编译/下载都必须预先 vendor：要么把编译产物塞进插件目录并屏蔽 `build` 钩子，要么预先下载二进制。下面凡属此档我都写了「备注」说明要预先准备什么。

## 关于「只打包配置和插件」

你选了「只打包配置和插件，假设目标机器已有 nvim 和常用命令行工具」，所以：

- 插件层的「依赖」= 仓库本身，全部随包分发，零联网。
- 工具层的「依赖」= `rg`、`fd`、`git`、`fzf`、`stylua`、各种语言服务器等，**需要目标机器自备**。
- 目录里凡是标「外部工具」的条目，就是你的发行版前置条件。`tools/parse_selection.py` 会把它们汇总成一份清单。
- 如果哪天想连工具也一起打包，架构里已经预留了 `bin/` 注入点（见 `docs/ARCHITECTURE.md`），不需要重做设计。

## 档位说明

| 档位 | 含义 |
| --- | --- |
| `core` | 轻量核心 profile 就带。以「纯 Lua + 编辑刚需」为准，启动快、依赖少 |
| `ide` | 开箱即用 profile 在此基础上追加的功能件 |
| `extra` | 可选 / 小众 / 有风险（需编译、需额外二进制、维护停滞、许可待核），默认两套都不带，你单独勾 |

---

## A. 基础库 · 图标

- [x] **nvim-lua/plenary.nvim** · 作用：公共 Lua 工具库，telescope 等一批插件的硬依赖 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [ ] **MunifTanjim/nui.nvim** · 作用：UI 组件库，noice / dressing 依赖 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [ ] **nvim-mini/mini.nvim#mini.icons** · 作用：轻量图标集，无 Nerd Font 时有 ASCII 回退 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [x] **nvim-tree/nvim-web-devicons** · 作用：使用最广的文件类型图标集 · 依赖：纯 Lua · 档位：core · 备注：需 Nerd Font，否则显示方块
- [ ] **nvim-mini/mini.nvim#mini.misc** · 作用：杂项工具，含 safely / statustime / put 等 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [ ] **folke/snacks.nvim** · 作用：一体化工具集 · 依赖：纯 Lua · 档位：ide · 许可：Apache-2.0 · 备注：模块 picker / explorer / terminal / notifier / input / bigfile / dashboard / profiler，按需启用，可替代本目录里多个单项
- [ ] **nvim-mini/mini.nvim#mini.doc** · 作用：从 Lua 注释生成帮助文档，写发行版文档时有用 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **nvim-mini/mini.nvim#mini.test** · 作用：测试框架，给发行版自己的配置写回归测试 · 依赖：纯 Lua · 档位：extra · 许可：MIT

## B. 配色主题

- [x] **folke/tokyonight.nvim** · 作用：深色主题，四种风格变体 · 依赖：纯 Lua · 档位：core · 许可：Apache-2.0
- [x] **catppuccin/nvim** · 作用：柔和粉彩主题，第三方插件适配最广 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [x] **rebelot/kanagawa.nvim** · 作用：浮世绘风格深色主题 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [x] **sainnhe/gruvbox-material** · 作用：gruvbox 改良版，对比度与背景可调 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [ ] **ellisonleao/gruvbox.nvim** · 作用：gruvbox 的官方 Lua 移植 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [ ] **sainnhe/everforest** · 作用：低对比护眼绿色主题 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [x] **EdenEast/nightfox.nvim** · 作用：多风格可深度定制的主题集 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [x] **rose-pine/neovim** · 作用：玫瑰松主题，三套风格统一 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [ ] **Mofiqul/vscode.nvim** · 作用：VS Code 配色，迁移用户友好 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **navarasu/onedark.nvim** · 作用：Atom One Dark 移植，风格多样 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **scottmckendry/cyberdream.nvim** · 作用：高对比霓虹风格 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **AlexvZyl/nordic.nvim** · 作用：Nord 改良，冷色调 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **savq/melange-nvim** · 作用：暖色低饱和主题 · 依赖：纯 Lua · 档位：ide
- [ ] **olivercederborg/poimandres.nvim** · 作用：poimandres 移植，冷灰蓝 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **craftzdog/solarized-osaka.nvim** · 作用：日系 solarized 变体 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **mcchrish/zenbones.nvim** · 作用：极简高可读主题集，附配色生成器 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **nvim-mini/mini.nvim#mini.hues** · 作用：主题生成器，从背景色与强调色推导整套配色 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **sainnhe/sonokai** · 作用：高饱和暖色主题 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **vague-theme/vague.nvim** · 作用：低对比灰紫主题 · 依赖：纯 Lua · 档位：extra · 许可：MIT

## C. 状态栏 · 标签栏 · 面包屑

- [x] **nvim-lualine/lualine.nvim** · 作用：状态栏 / 顶栏，主题与组件生态最广 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [ ] **nvim-mini/mini.nvim#mini.statusline** · 作用：极简状态栏，零配置可用 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [x] **nvim-mini/mini.nvim#mini.tabline** · 作用：极简 buffer 标签栏 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [ ] **akinsho/bufferline.nvim** · 作用：功能最全的 buffer 标签栏 · 依赖：纯 Lua · 档位：ide · 许可：GPL-3.0 · 备注：上游已一年未更新，功能稳定
- [ ] **SmiteshP/nvim-navic** · 作用：LSP 面包屑，供顶栏显示当前符号路径 · 依赖：纯 Lua · 档位：ide · 许可：Apache-2.0
- [ ] **Bekaboo/dropbar.nvim** · 作用：类 IDE 面包屑，不依赖 LSP 也能用 · 依赖：纯 Lua · 档位：ide · 许可：GPL-3.0
- [ ] **luukvbaal/statuscol.nvim** · 作用：可定制的 statuscolumn，含折叠列与点击 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **petertriho/nvim-scrollbar** · 作用：带诊断与 git 标记的滚动条 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **b0o/incline.nvim** · 作用：浮动窗口标题栏 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **utilyre/barbecue.nvim** · 作用：另一款面包屑 · 依赖：纯 Lua · 档位：extra · 备注：已归档（2024-08），留档对比用

## D. 启动页

- [x] **nvim-mini/mini.nvim#mini.starter** · 作用：极简启动页，纯 Lua 可完全自绘 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [ ] **nvimdev/dashboard-nvim** · 作用：经典启动页，快捷入口与最近文件 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **goolord/alpha-nvim** · 作用：主题化启动页，布局灵活 · 依赖：纯 Lua · 档位：ide · 许可：MIT

## E. 文件浏览与模糊查找

- [ ] **nvim-telescope/telescope.nvim** · 作用：生态最大的模糊查找框架 · 依赖：外部工具（rg、fd、git） · 档位：core · 许可：MIT · 备注：本身纯 Lua，仅 grep / find / git 类 picker 需要上述命令
- [ ] **nvim-mini/mini.nvim#mini.pick** · 作用：极简 picker，纯 Lua，无需任何外部命令 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [x] **stevearc/oil.nvim** · 作用：把目录当普通 buffer 编辑，改文件名即改盘上文件名 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [ ] **nvim-mini/mini.nvim#mini.files** · 作用：分栏式文件管理器，可预览改动 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [x] **ibhagwan/fzf-lua** · 作用：基于 fzf 的 picker，大仓库下最快 · 依赖：外部工具（fzf、rg、fd、git） · 档位：ide · 许可：MIT · 备注：fzf 是硬依赖，缺失则完全不可用
- [ ] **nvim-neo-tree/neo-tree.nvim** · 作用：带 git 与诊断信息的文件树 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **nvim-telescope/telescope-fzf-native.nvim** · 作用：给 telescope 的 C 语言模糊排序器，显著提速 · 依赖：编译/下载 · 档位：ide · 许可：MIT · 备注：需要 make 与 C 编译器；离线包必须预置编译产物
- [ ] **nvim-telescope/telescope-ui-select.nvim** · 作用：把 LSP code action 等选择项交给 telescope 渲染 · 依赖：纯 Lua · 档位：ide · 许可：MIT

## F. 补全 · 代码片段

- [x] **saghen/blink.cmp** · 作用：高性能补全引擎，当前主流选择 · 依赖：编译/下载 · 档位：core · 许可：MIT · 备注：**钉在 tag `v1.10.2`**（最新正式发布版）。main 上的 v2 尚未发布，且额外依赖 `saghen/blink.lib`；v1 有官方分平台原生库与 sha256，更适合发行版
- [x] **L3MON4D3/LuaSnip** · 作用：片段引擎，兼容 VSCode 与 LSP 片段格式 · 依赖：纯 Lua · 档位：core · 许可：Apache-2.0 · 备注：`jsregexp` 为可选的 C 加速库，缺失时自动降级
- [x] **rafamadriz/friendly-snippets** · 作用：覆盖大量语言的现成片段集合 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [ ] **hrsh7th/nvim-cmp** · 作用：模块化补全框架，稳定但已进入维护模式 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **hrsh7th/cmp-nvim-lsp** · 作用：nvim-cmp 的 LSP 补全源 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **hrsh7th/cmp-buffer** · 作用：nvim-cmp 的当前缓冲区词汇源 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **hrsh7th/cmp-path** · 作用：nvim-cmp 的文件路径源 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **hrsh7th/cmp-cmdline** · 作用：nvim-cmp 的命令行补全源 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **saadparwaiz1/cmp_luasnip** · 作用：把 LuaSnip 接入 nvim-cmp · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **onsails/lspkind.nvim** · 作用：给补全项加类型图标 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **dcampos/nvim-snippy** · 作用：轻量 vim-snippet 引擎，纯 Lua 无编译 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **nvim-mini/mini.nvim#mini.snippets** · 作用：mini 的极简片段模块 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **chrisgrieser/nvim-scissors** · 作用：片段创建与编辑 UI · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **ms-jpq/coq_nvim** · 作用：基于 SQLite 的补全引擎，开箱即用 · 依赖：纯 Lua · 档位：extra · 许可：GPL-3.0

## G. LSP 与语言服务

- [x] **neovim/nvim-lspconfig** · 作用：官方 LSP 服务器配置集合，架在内置 vim.lsp 之上 · 依赖：纯 Lua · 档位：core · 许可：Apache-2.0 · 备注：纯配置数据、零联网；要求 Neovim ≥ 0.11.3
- [x] **folke/lazydev.nvim** · 作用：为 lua_ls 补全 Neovim API 与你的配置源码，写发行版自身必需 · 依赖：纯 Lua · 档位：core · 许可：Apache-2.0
- [ ] **stevearc/aerial.nvim** · 作用：符号大纲侧栏，支持 LSP 与 treesitter · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [x] **ray-x/lsp_signature.nvim** · 作用：输入函数参数时显示签名 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **aznhe21/actions-preview.nvim** · 作用：code action 预览后再应用 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [x] **antosha417/nvim-lsp-file-operations** · 作用：重命名文件时自动更新 import 路径 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **nvimtools/none-ls.nvim** · 作用：通过 LSP 协议注入诊断与格式化 · 依赖：纯 Lua · 档位：ide · 许可：Unlicense · 备注：是已归档的 null-ls 的活跃继任者
- [ ] **hedyhli/outline.nvim** · 作用：树形符号大纲，可视化并导航代码符号 · 依赖：纯 Lua · 档位：extra
- [ ] **chrisgrieser/nvim-lsp-endhints** · 作用：行尾显示推断类型与参数名 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **kosayoda/nvim-lightbulb** · 作用：可用的 code action 处显示提示灯 · 依赖：纯 Lua · 档位：extra · 许可：MIT · 备注：上游已不活跃；功能简单，也可以自己监听 LSP code action 事件实现
- [ ] **mason-org/mason.nvim** · 作用：LSP / DAP / linter / formatter 安装器 · 依赖：联网 · 档位：extra · 许可：Apache-2.0 · 备注：注册表刷新与所有安装动作都走网络，官方无离线模式，与你的要求冲突；列出仅供你知情决策
- [ ] **mason-org/mason-lspconfig.nvim** · 作用：mason 与 lspconfig 的桥接 · 依赖：纯 Lua · 档位：extra · 许可：Apache-2.0 · 备注：明确只识别 mason 自己装的服务器，离线场景没有意义

## H. Tree-sitter

- [x] **nvim-treesitter/nvim-treesitter** · 作用：语法高亮、缩进、折叠的解析器管理 · 依赖：编译/下载 · 档位：core · 许可：Apache-2.0 · 备注：`main` 分支要求 Neovim ≥ 0.12，安装解析器需要 curl + tar + tree-sitter-cli + C 编译器；离线做法是预置 `parser/*.dll` 与 `parser/*.so` 加 `queries/`。注意解析器 ABI 必须与 Neovim 自身的 tree-sitter 版本匹配，nightly 升级后要重新构建
- [x] **nvim-treesitter/nvim-treesitter-textobjects** · 作用：语法感知的文本对象与跳转动作 · 依赖：纯 Lua · 档位：ide · 许可：Apache-2.0
- [x] **nvim-treesitter/nvim-treesitter-context** · 作用：顶部固定显示当前函数 / 类的作用域头 · 依赖：纯 Lua · 档位：ide · 许可：Apache-2.0
- [ ] **windwp/nvim-ts-autotag** · 作用：HTML / JSX 标签自动闭合与重命名 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [x] **folke/ts-comments.nvim** · 作用：用语法树决定注释符，解决 JSX 等混合语言注释 · 依赖：纯 Lua · 档位：ide · 许可：Apache-2.0

## I. 格式化

- [x] **stevearc/conform.nvim** · 作用：格式化器统一调度，可回退到 LSP 格式化 · 依赖：外部工具（stylua、shfmt、clang-format） · 档位：core · 许可：MIT · 备注：插件本身纯 Lua；只列本发行版选定语言需要的格式化器，prettier / black / gofumpt 等按需自配。应先探测命令是否存在，缺失时静默跳过而不是报错
- [ ] **mhartington/formatter.nvim** · 作用：配置式异步格式化器 · 依赖：外部工具（stylua、shfmt、clang-format） · 档位：extra · 许可：MIT

## J. 静态检查

- [x] **mfussenegger/nvim-lint** · 作用：异步 linter 调度，结果进诊断系统 · 依赖：外部工具（shellcheck、clang-tidy、luacheck） · 档位：core · 许可：GPL-3.0 · 备注：GPL 许可，打包时与其他 MIT 代码保持可分离；同样只列本发行版语言需要的 linter

## K. 诊断与问题面板

- [x] **folke/trouble.nvim** · 作用：诊断 / 引用 / quickfix 统一面板 · 依赖：纯 Lua · 档位：core · 许可：Apache-2.0
- [ ] **stevearc/quicker.nvim** · 作用：让 quickfix 缓冲区可编辑，带预览与过滤 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **rachartier/tiny-inline-diagnostic.nvim** · 作用：更精致的行内诊断渲染 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **dgagn/diagflow.nvim** · 作用：光标处浮窗显示完整诊断 · 依赖：纯 Lua · 档位：extra · 许可：MIT

## L. Git 集成

- [x] **lewis6991/gitsigns.nvim** · 作用：行内变更标记、按 hunk 暂存与回退、行内 blame · 依赖：外部工具（git） · 档位：core · 许可：MIT
- [x] **NeogitOrg/neogit** · 作用：Magit 风格的完整 git 操作界面 · 依赖：外部工具（git） · 档位：ide · 许可：MIT
- [ ] **tpope/vim-fugitive** · 作用：经典 Git 包装，:Git / :Gdiffsplit / :GBrowse · 依赖：外部工具（git） · 档位：ide · 许可：Vim license
- [x] **sindrets/diffview.nvim** · 作用：全屏 diff 与三方合并界面 · 依赖：外部工具（git） · 档位：ide · 备注：2024-08 后停更，功能稳定
- [ ] **nvim-mini/mini.nvim#mini.git** · 作用：mini 的 git 集成，含 blame、diff、hunk 操作 · 依赖：外部工具（git） · 档位：extra · 许可：MIT
- [ ] **nvim-mini/mini.nvim#mini.diff** · 作用：缓冲区与参考版本对比，自带 hunk 操作 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **FabijanZulj/blame.nvim** · 作用：全屏 blame 视图 · 依赖：外部工具（git） · 档位：extra · 许可：MIT
- [ ] **kdheepak/lazygit.nvim** · 作用：在浮动窗口里嵌入 lazygit · 依赖：外部工具（lazygit、git） · 档位：extra · 许可：MIT
- [ ] **pwntester/octo.nvim** · 作用：在编辑器里处理 GitHub PR 与 issue · 依赖：联网 · 档位：extra · 备注：必须联网，离线发行版建议排除

## M. 编辑增强

- [x] **nvim-mini/mini.nvim#mini.ai** · 作用：增强 a / i 文本对象，支持成对符号与语法树 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [x] **nvim-mini/mini.nvim#mini.surround** · 作用：增删改环绕字符 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [x] **nvim-mini/mini.nvim#mini.pairs** · 作用：自动配对 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [x] **nvim-mini/mini.nvim#mini.comment** · 作用：gc / gcc 注释，识别注释符 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [x] **nvim-mini/mini.nvim#mini.bracketed** · 作用：一整套 [ / ] 前缀跳转（buffer、诊断、git、缩进等） · 依赖：纯 Lua · 档位：core · 许可：MIT
- [x] **nvim-mini/mini.nvim#mini.move** · 作用：移动行与选区 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [x] **nvim-mini/mini.nvim#mini.operators** · 作用：让操作符支持复制、替换、排序、求值等 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [x] **nvim-mini/mini.nvim#mini.indentscope** · 作用：缩进范围可视化 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [x] **folke/flash.nvim** · 作用：标签式快速跳转，可绑定语法树节点 · 依赖：纯 Lua · 档位：core · 许可：Apache-2.0
- [x] **tpope/vim-repeat** · 作用：让插件的操作也能用 `.` 重复 · 依赖：纯 Lua · 档位：core · 许可：Vim license
- [ ] **kylechui/nvim-surround** · 作用：另一套环绕操作，键位贴合原 vim-surround · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **windwp/nvim-autopairs** · 作用：自动配对，规则可编程 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **chrisgrieser/nvim-spider** · 作用：更符合直觉的 w / e / b 词移动（擅长 camelCase / snake_case）· 依赖：纯 Lua · 档位：ide · 许可：MIT · 备注：**与 `jieba.vim` 键位冲突，已从方案中移除**：它没有任何关闭默认键位的选项，必然接管 w/e/b/ge/gg；中文分词是本发行版的差异点，所以让 jieba 胜出。看重 camelCase 的用户可自行启用它并放弃 jieba 的键位

- [ ] **Wansmer/treesj** · 作用：按语法树拆分与合并代码块 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [x] **mbbill/undotree** · 作用：撤销树可视化 · 依赖：纯 Lua · 档位：ide · 许可：GPL-2.0
- [ ] **kevinhwang91/nvim-ufo** · 作用：现代化折叠，基于 LSP 与语法树 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [x] **RRethy/vim-illuminate** · 作用：高亮光标下符号的所有出现 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [x] **NMAC427/guess-indent.nvim** · 作用：自动推断并设置缩进 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **folke/zen-mode.nvim** · 作用：专注模式，隐藏所有干扰元素 · 依赖：纯 Lua · 档位：ide · 许可：Apache-2.0
- [x] **nvim-mini/mini.nvim#mini.cursorword** · 作用：高亮光标下单词 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [x] **nvim-mini/mini.nvim#mini.hipatterns** · 作用：高亮 TODO、颜色码、十六进制色值等自定义模式 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [x] **nvim-mini/mini.nvim#mini.align** · 作用：交互式文本对齐 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [x] **nvim-mini/mini.nvim#mini.splitjoin** · 作用：拆分与合并参数列表 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [x] **nvim-mini/mini.nvim#mini.trailspace** · 作用：高亮并一键清除行尾空白 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [x] **nvim-mini/mini.nvim#mini.bufremove** · 作用：关闭 buffer 但保留窗口布局 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **nvim-mini/mini.nvim#mini.jump** · 作用：增强 f / t / F / T 跳转 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **nvim-mini/mini.nvim#mini.jump2d** · 作用：二维目标跳转 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **smoka7/hop.nvim** · 作用：标签跳转，原 phaazon/hop 的活跃继任者 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **ggandor/leap.nvim** · 作用：两字符即时跳转 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **chrisgrieser/nvim-various-textobjs** · 作用：一批额外的文本对象（整文件、缩进块、URL 等） · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **numToStr/Comment.nvim** · 作用：gc / gb 注释 · 依赖：纯 Lua · 档位：extra · 许可：MIT · 备注：2024-08 后停更；Neovim 0.10+ 已内置注释，优先用内置或 ts-comments
- [ ] **jake-stewart/multicursor.nvim** · 作用：多光标编辑 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **brenton-leighton/multiple-cursors.nvim** · 作用：另一款多光标实现 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **folke/twilight.nvim** · 作用：变暗非当前代码块 · 依赖：纯 Lua · 档位：extra · 许可：Apache-2.0
- [ ] **karb94/neoscroll.nvim** · 作用：平滑滚动 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **folke/edgy.nvim** · 作用：侧栏与底栏窗口的布局管理 · 依赖：纯 Lua · 档位：extra · 许可：Apache-2.0
- [ ] **smjonas/live-command.nvim** · 作用：实时预览 :norm / :g 等命令的效果 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **m4xshen/hardtime.nvim** · 作用：阻止低效的重复按键，帮你改掉坏习惯 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **tris203/precognition.nvim** · 作用：提示当前可用的移动键位 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **chentoast/marks.nvim** · 作用：增强 mark 的管理与可视化 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **gbprod/yanky.nvim** · 作用：增强的 yank 历史与粘贴 · 依赖：纯 Lua · 档位：extra · 许可：MIT

## N. 会话 · 项目 · 工作区

- [x] **nvim-mini/mini.nvim#mini.sessions** · 作用：会话的读写与删除 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [x] **nvim-mini/mini.nvim#mini.visits** · 作用：记录并复用访问过的文件（最近文件、标签、跳回） · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **folke/persistence.nvim** · 作用：退出时自动保存会话，进入时恢复 · 依赖：纯 Lua · 档位：ide · 许可：Apache-2.0
- [ ] **ThePrimeagen/harpoon** · 作用：按项目标记常用文件并一键跳转 · 依赖：纯 Lua · 档位：ide · 许可：MIT · 备注：使用 harpoon2 分支
- [ ] **otavioschwanck/arrow.nvim** · 作用：书签式文件跳转，带可视化界面 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **nvim-mini/mini.nvim#mini.basics** · 作用：一批合理的默认选项与键位预设，适合当发行版基线 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **ahmedkhalf/project.nvim** · 作用：为 picker 提供项目根识别（含 git / LSP 模式） · 依赖：纯 Lua · 档位：extra · 备注：2024-08 后停更；Neovim 0.12 的 vim.fs.root 可平替

## O. 通知 · 命令行 · UI 润色

- [x] **j-hui/fidget.nvim** · 作用：右下角显示 LSP 加载进度 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [x] **nvim-mini/mini.nvim#mini.notify** · 作用：极简通知系统，统一收集 :messages · 依赖：纯 Lua · 档位：core · 许可：MIT
- [ ] **folke/noice.nvim** · 作用：重构命令行、消息、通知与悬浮窗的整套 UI · 依赖：纯 Lua · 档位：ide · 许可：Apache-2.0 · 备注：依赖 nui.nvim；上游更新放缓
- [x] **stevearc/dressing.nvim** · 作用：美化 vim.ui.input 与 vim.ui.select · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **rcarriga/nvim-notify** · 作用：可堆叠的通知管理器 · 依赖：纯 Lua · 档位：extra · 许可：MIT · 备注：2025-09 后停更，mini.notify 或 snacks.notifier 可替代

## P. 快捷键提示

- [x] **folke/which-key.nvim** · 作用：按下前缀键后弹出可用键位，预设丰富 · 依赖：纯 Lua · 档位：core · 许可：Apache-2.0 · 备注：上游更新放缓
- [ ] **nvim-mini/mini.nvim#mini.clue** · 作用：常驻键位提示 HUD，可自定义触发前缀 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [ ] **tris203/hawtkeys.nvim** · 作用：扫描出尚未被占用的键位 · 依赖：纯 Lua · 档位：extra · 备注：活跃度低，选用前先确认

## Q. 终端 · 任务 · 数据库 · HTTP

- [ ] **akinsho/toggleterm.nvim** · 作用：浮动与分屏终端管理 · 依赖：纯 Lua · 档位：ide · 许可：GPL-3.0 · 备注：2025-03 后未更新；snacks.terminal 或内置 :terminal 可替代
- [ ] **stevearc/overseer.nvim** · 作用：任务运行器，把 build / test / lint 收成统一入口 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **chomosuke/term-edit.nvim** · 作用：在终端缓冲区里使用命令行式的编辑键位 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **CRAG666/code_runner.nvim** · 作用：一键编译并运行当前文件 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **mrcjkb/rustaceanvim** · 作用：Rust 专用增强，整合 rust-analyzer 与 codelldb · 依赖：外部工具（rust-analyzer、codelldb） · 档位：extra · 备注：只有 Rust 工作流需要
- [ ] **tpope/vim-dadbod** · 作用：把各种数据库 CLI 统一成一个接口 · 依赖：外部工具（psql、mysql、sqlite3） · 档位：extra · 备注：每种数据库都要自备客户端
- [ ] **kristijanhusak/vim-dadbod-ui** · 作用：dadbod 的图形化界面 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **kristijanhusak/vim-dadbod-completion** · 作用：表名与列名补全 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **mistweaverco/kulala.nvim** · 作用：HTTP 请求客户端，直接跑 .http 文件 · 依赖：外部工具（curl） · 档位：extra · 许可：MIT
- [ ] **rest-nvim/rest.nvim** · 作用：另一款 HTTP 请求客户端 · 依赖：外部工具（curl） · 档位：extra · 许可：GPL-3.0 · 备注：GPL 许可，与 MIT 代码需保持可分离
- [ ] **folke/neoconf.nvim** · 作用：按项目落地 LSP 与工具配置 · 依赖：纯 Lua · 档位：extra · 许可：Apache-2.0
- [ ] **chrisgrieser/nvim-genghis** · 作用：文件与目录的常用操作（移动、重命名、复制路径、改权限） · 依赖：纯 Lua · 档位：extra · 许可：MIT

## R. 调试（DAP）

- [ ] **mfussenegger/nvim-dap** · 作用：DAP 客户端，断点、单步、调用栈 · 依赖：外部工具（各语言调试适配器） · 档位：ide · 许可：GPL-3.0 · 备注：插件纯 Lua，适配器必须自备；mason-nvim-dap 走网络不可用
- [ ] **rcarriga/nvim-dap-ui** · 作用：调试界面，变量、断点、栈帧、REPL 四个面板 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **nvim-neotest/nvim-nio** · 作用：异步 IO 库，nvim-dap-ui 的依赖 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **theHamsta/nvim-dap-virtual-text** · 作用：在行内显示变量当前值 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **mfussenegger/nvim-dap-python** · 作用：Python 调试接入 debugpy · 依赖：外部工具（debugpy） · 档位：ide · 许可：GPL-3.0
- [ ] **leoluz/nvim-dap-go** · 作用：Go 调试接入 delve · 依赖：外部工具（dlv） · 档位：extra · 许可：MIT
- [ ] **jay-babu/mason-nvim-dap.nvim** · 作用：用 mason 安装调试适配器 · 依赖：联网 · 档位：extra · 备注：依赖 mason，离线场景排除

## S. 测试

- [ ] **nvim-neotest/neotest** · 作用：可扩展的测试运行框架，带结果树 · 依赖：外部工具（各语言测试运行器） · 档位：ide · 许可：MIT
- [ ] **nvim-neotest/neotest-python** · 作用：neotest 的 Python 适配器 · 依赖：外部工具（pytest、unittest） · 档位：extra · 许可：MIT
- [ ] **nvim-neotest/neotest-go** · 作用：neotest 的 Go 适配器 · 依赖：外部工具（go test） · 档位：extra · 许可：MIT
- [ ] **nvim-neotest/neotest-plenary** · 作用：neotest 的 plenary 适配器，用来测 Lua 与插件本身 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **vim-test/vim-test** · 作用：另一款多框架测试执行器，覆盖面广 · 依赖：外部工具（项目自带测试工具） · 档位：extra · 许可：MIT
- [ ] **andythigpen/nvim-coverage** · 作用：显示测试覆盖率 · 依赖：外部工具（各语言覆盖率工具） · 档位：extra · 许可：MIT

## T. 标记语言 · 写作 · 笔记

- [x] **folke/todo-comments.nvim** · 作用：高亮并可全局搜索 TODO / FIXME / NOTE / HACK · 依赖：纯 Lua · 档位：core · 许可：Apache-2.0
- [ ] **dhruvasagar/vim-table-mode** · 作用：Markdown 与 org 表格自动对齐、公式计算 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [x] **MeanderingProgrammer/render-markdown.nvim** · 作用：在缓冲区里渲染 Markdown 的标题、表格、代码块、勾选框 · 依赖：纯 Lua · 档位：ide · 许可：MIT · 备注：需要 Nerd Font 与正确的字符宽度设置，否则表格错位
- [ ] **nvim-orgmode/orgmode** · 作用：org-mode 复刻，待办、日程、导出 · 依赖：纯 Lua · 档位：extra · 许可：MIT · 备注：要求 Neovim ≥ 0.12
- [ ] **obsidian-nvim/obsidian.nvim** · 作用：Obsidian 仓库的笔记、双向链接、模板 · 依赖：纯 Lua · 档位：extra · 许可：Apache-2.0 · 备注：原 epwalsh/obsidian.nvim 的活跃继任者
- [ ] **iamcco/markdown-preview.nvim** · 作用：浏览器中的实时 Markdown 预览 · 依赖：编译/下载 · 档位：extra · 许可：MIT · 备注：默认需要 node + yarn，或首次运行时下载预编译产物；离线包必须预先放入
- [ ] **ellisonleao/glow.nvim** · 作用：用 glow 在终端内渲染 Markdown · 依赖：外部工具（glow） · 档位：extra · 许可：MIT

## U. 中文 / CJK

这一档是你作为中文用户最容易被开源发行版忽略的部分。调研结论：**不存在仍在维护的东亚字符宽度插件**，字符宽度只能靠 `set ambiwidth=double` 加上终端字体设置来解决；输入法切换则必须依赖一个外部命令行工具。

- [x] **keaising/im-select.nvim** · 作用：离开插入模式时自动切回英文输入法，回来时切回中文 · 依赖：外部工具（im-select、fcitx5-remote、ibus） · 档位：core · 许可：MIT · 备注：双平台最省事的方案。Windows 用 im-select.exe，Linux 用 fcitx5-remote 或 ibus
- [x] **kkew3/jieba.vim** · 作用：中文按词移动（w / b / e）与中文文本对象 · 依赖：编译/下载 · 档位：core · 许可：Apache-2.0 · 备注：需要 Rust 编译或预编译二进制；离线包必须预置产物
- [ ] **amekusa/auto-input-switch.nvim** · 作用：按上下文切换输入法，中英混排场景更细 · 依赖：外部工具（输入法命令行工具） · 档位：extra · 许可：MIT
- [ ] **Old-Farmer/im-autoswitch.nvim** · 作用：另一款可配置的输入法自动切换 · 依赖：外部工具（输入法命令行工具） · 档位：extra · 许可：Apache-2.0
- [ ] **tonyfettes/fcitx5.nvim** · 作用：fcitx5 深度集成 · 依赖：纯 Lua · 档位：extra · 许可：GPL-3.0 · 备注：2022 年后停更，且仅支持 Linux

## V. AI 助手（默认排除）

你要求运行时零联网，而这一档**没有任何一个能在无网环境下工作**，除非把模型也放在本机。全部标为 `extra`，列出仅供你知情决策。

- [ ] **olimorris/codecompanion.nvim** · 作用：聊天与内联改写，支持接入本地模型服务 · 依赖：联网 · 档位：extra · 许可：Apache-2.0 · 备注：若指向本机 Ollama 或 llama.cpp，才勉强算离线
- [ ] **yetone/avante.nvim** · 作用：Cursor 风格的 AI 编辑体验 · 依赖：联网 · 档位：extra · 许可：Apache-2.0 · 备注：另有 curl 依赖与编译步骤
- [ ] **zbirenbaum/copilot.lua** · 作用：GitHub Copilot 内联补全 · 依赖：联网 · 档位：extra · 许可：MIT · 备注：需要 GitHub 账号认证
- [ ] **milanglacier/minuet-ai.nvim** · 作用：多后端补全，可指向本地服务 · 依赖：联网 · 档位：extra · 许可：MIT
- [ ] **David-Kunz/gen.nvim** · 作用：极简 LLM 调用，支持本地模型 · 依赖：联网 · 档位：extra · 备注：代码量极小，适合当自己写 AI 集成的参考

## W. 性能 · 大文件 · 启动分析

- [x] **dstein64/vim-startuptime** · 作用：图形化分析启动耗时，按插件排序 · 依赖：纯 Lua · 档位：core · 许可：MIT
- [ ] **nvim-mini/mini.nvim#mini.extra** · 作用：mini 的额外 picker 集合（注册表、颜色、诊断等） · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **LunarVim/bigfile.nvim** · 作用：超过阈值时自动关闭 treesitter / LSP / 折叠等重功能 · 依赖：纯 Lua · 档位：extra · 许可：Apache-2.0 · 备注：2024-08 后停更，snacks.bigfile 可替代
- [ ] **ouuan/nvim-bigfile** · 作用：按文件类型分别设置大小阈值 · 依赖：纯 Lua · 档位：extra · 许可：Apache-2.0 · 备注：2024-11 后停更

## X. 其它实用小件与备选方案

- [x] **MagicDuck/grug-far.nvim** · 作用：项目级搜索替换，带预览与逐条确认 · 依赖：外部工具（rg） · 档位：ide · 许可：MIT
- [x] **mrjones2014/smart-splits.nvim** · 作用：智能分屏切换与调整大小，可与 tmux 联动 · 依赖：纯 Lua · 档位：ide · 许可：MIT
- [ ] **nvim-pack/nvim-spectre** · 作用：另一款项目级搜索替换面板 · 依赖：外部工具（rg） · 档位：extra · 许可：MIT
- [ ] **numToStr/Navigator.nvim** · 作用：在 Neovim 与 tmux 分屏间无缝切换 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **christoomey/vim-tmux-navigator** · 作用：同上，VimScript 老牌实现，也支持 Windows Terminal · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **godlygeek/tabular** · 作用：按分隔符对齐文本块 · 依赖：纯 Lua · 档位：extra · 备注：VimScript 老牌插件
- [ ] **tpope/vim-speeddating** · 作用：让 Ctrl-A / Ctrl-X 认识日期与时间 · 依赖：纯 Lua · 档位：extra · 许可：Vim license
- [ ] **jbyuki/one-small-step-for-vimkind** · 作用：调试 Neovim 自身的 Lua 代码 · 依赖：纯 Lua · 档位：extra · 许可：MIT
- [ ] **folke/lazy.nvim** · 作用：功能最强的插件管理器 · 依赖：纯 Lua · 档位：extra · 许可：Apache-2.0 · 备注：与「不用管理器、pack/start 直接加载」的方案冲突，列出仅供你对比后再定；若选它必须设 `install.missing = false` 与 `rocks.enabled = false`
