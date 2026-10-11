# 插件目录速查

> 本文件由 `tools/parse_selection.py --overview` 从 `PLUGIN-CATALOG.md` 自动生成，**别手工编辑**。
> 每条的作用说明、取舍理由、许可与风险备注在 `PLUGIN-CATALOG.md`；怎么选见 `../docs/CHOOSING.md`。

共 **206** 个条目，分 **24** 类。

- 依赖分级：外部工具 30、纯 Lua 163、编译/下载 5、联网 8
- 档位分布：core 50、extra 91、ide 65
- 分类条目数：A. 基础库 · 图标 8、B. 配色主题 19、C. 状态栏 · 标签栏 · 面包屑 10、D. 启动页 3、E. 文件浏览与模糊查找 8、F. 补全 · 代码片段 14、G. LSP 与语言服务 12、H. Tree-sitter 5、I. 格式化 2、J. 静态检查 1、K. 诊断与问题面板 4、L. Git 集成 9、M. 编辑增强 41、N. 会话 · 项目 · 工作区 7、O. 通知 · 命令行 · UI 润色 5、P. 快捷键提示 3、Q. 终端 · 任务 · 数据库 · HTTP 12、R. 调试（DAP） 7、S. 测试 6、T. 标记语言 · 写作 · 笔记 7、U. 中文 / CJK 5、V. AI 助手（默认排除） 5、W. 性能 · 大文件 · 启动分析 4、X. 其它实用小件与备选方案 9

☐ 未勾选 / ☑ 已勾选。


## A. 基础库 · 图标

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `nvim-lua/plenary.nvim` | 公共 Lua 工具库，telescope 等一批插件的硬依赖 | 纯 Lua | core |
| ☐ | `MunifTanjim/nui.nvim` | UI 组件库，noice / dressing 依赖 | 纯 Lua | core |
| ☐ | `nvim-mini/mini.nvim#mini.icons` | 轻量图标集，无 Nerd Font 时有 ASCII 回退 | 纯 Lua | core |
| ☑ | `nvim-tree/nvim-web-devicons` | 使用最广的文件类型图标集 | 纯 Lua | core |
| | | ↳ 需 Nerd Font，否则显示方块 | | |
| ☐ | `nvim-mini/mini.nvim#mini.misc` | 杂项工具，含 safely / statustime / put 等 | 纯 Lua | core |
| ☐ | `folke/snacks.nvim` | 一体化工具集 | 纯 Lua | ide |
| | | ↳ 模块 picker / explorer / terminal / notifier / input / bigfile / dashboard / profiler，按需启用，可替代本目录里多个单项 | | |
| ☐ | `nvim-mini/mini.nvim#mini.doc` | 从 Lua 注释生成帮助文档，写发行版文档时有用 | 纯 Lua | extra |
| ☐ | `nvim-mini/mini.nvim#mini.test` | 测试框架，给发行版自己的配置写回归测试 | 纯 Lua | extra |

## B. 配色主题

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `folke/tokyonight.nvim` | 深色主题，四种风格变体 | 纯 Lua | core |
| ☑ | `catppuccin/nvim` | 柔和粉彩主题，第三方插件适配最广 | 纯 Lua | core |
| ☑ | `rebelot/kanagawa.nvim` | 浮世绘风格深色主题 | 纯 Lua | core |
| ☑ | `sainnhe/gruvbox-material` | gruvbox 改良版，对比度与背景可调 | 纯 Lua | core |
| ☐ | `ellisonleao/gruvbox.nvim` | gruvbox 的官方 Lua 移植 | 纯 Lua | core |
| ☐ | `sainnhe/everforest` | 低对比护眼绿色主题 | 纯 Lua | core |
| ☑ | `EdenEast/nightfox.nvim` | 多风格可深度定制的主题集 | 纯 Lua | core |
| ☑ | `rose-pine/neovim` | 玫瑰松主题，三套风格统一 | 纯 Lua | core |
| ☐ | `Mofiqul/vscode.nvim` | VS Code 配色，迁移用户友好 | 纯 Lua | ide |
| ☐ | `navarasu/onedark.nvim` | Atom One Dark 移植，风格多样 | 纯 Lua | ide |
| ☐ | `scottmckendry/cyberdream.nvim` | 高对比霓虹风格 | 纯 Lua | ide |
| ☐ | `AlexvZyl/nordic.nvim` | Nord 改良，冷色调 | 纯 Lua | ide |
| ☐ | `savq/melange-nvim` | 暖色低饱和主题 | 纯 Lua | ide |
| ☐ | `olivercederborg/poimandres.nvim` | poimandres 移植，冷灰蓝 | 纯 Lua | ide |
| ☐ | `craftzdog/solarized-osaka.nvim` | 日系 solarized 变体 | 纯 Lua | extra |
| ☐ | `mcchrish/zenbones.nvim` | 极简高可读主题集，附配色生成器 | 纯 Lua | extra |
| ☐ | `nvim-mini/mini.nvim#mini.hues` | 主题生成器，从背景色与强调色推导整套配色 | 纯 Lua | extra |
| ☐ | `sainnhe/sonokai` | 高饱和暖色主题 | 纯 Lua | extra |
| ☐ | `vague-theme/vague.nvim` | 低对比灰紫主题 | 纯 Lua | extra |

## C. 状态栏 · 标签栏 · 面包屑

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `nvim-lualine/lualine.nvim` | 状态栏 / 顶栏，主题与组件生态最广 | 纯 Lua | core |
| ☐ | `nvim-mini/mini.nvim#mini.statusline` | 极简状态栏，零配置可用 | 纯 Lua | core |
| ☑ | `nvim-mini/mini.nvim#mini.tabline` | 极简 buffer 标签栏 | 纯 Lua | core |
| ☐ | `akinsho/bufferline.nvim` | 功能最全的 buffer 标签栏 | 纯 Lua | ide |
| | | ↳ 上游已一年未更新，功能稳定 | | |
| ☐ | `SmiteshP/nvim-navic` | LSP 面包屑，供顶栏显示当前符号路径 | 纯 Lua | ide |
| ☐ | `Bekaboo/dropbar.nvim` | 类 IDE 面包屑，不依赖 LSP 也能用 | 纯 Lua | ide |
| ☐ | `luukvbaal/statuscol.nvim` | 可定制的 statuscolumn，含折叠列与点击 | 纯 Lua | ide |
| ☐ | `petertriho/nvim-scrollbar` | 带诊断与 git 标记的滚动条 | 纯 Lua | ide |
| ☐ | `b0o/incline.nvim` | 浮动窗口标题栏 | 纯 Lua | extra |
| ☐ | `utilyre/barbecue.nvim` | 另一款面包屑 | 纯 Lua | extra |
| | | ↳ 已归档（2024-08），留档对比用 | | |

## D. 启动页

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `nvim-mini/mini.nvim#mini.starter` | 极简启动页，纯 Lua 可完全自绘 | 纯 Lua | core |
| ☐ | `nvimdev/dashboard-nvim` | 经典启动页，快捷入口与最近文件 | 纯 Lua | ide |
| ☐ | `goolord/alpha-nvim` | 主题化启动页，布局灵活 | 纯 Lua | ide |

## E. 文件浏览与模糊查找

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☐ | `nvim-telescope/telescope.nvim` | 生态最大的模糊查找框架 | 外部工具 | core |
| | | ↳ 本身纯 Lua，仅 grep / find / git 类 picker 需要上述命令 | | |
| ☐ | `nvim-mini/mini.nvim#mini.pick` | 极简 picker，纯 Lua，无需任何外部命令 | 纯 Lua | core |
| ☑ | `stevearc/oil.nvim` | 把目录当普通 buffer 编辑，改文件名即改盘上文件名 | 纯 Lua | core |
| ☐ | `nvim-mini/mini.nvim#mini.files` | 分栏式文件管理器，可预览改动 | 纯 Lua | core |
| ☑ | `ibhagwan/fzf-lua` | 基于 fzf 的 picker，大仓库下最快 | 外部工具 | ide |
| | | ↳ fzf 是硬依赖，缺失则完全不可用 | | |
| ☐ | `nvim-neo-tree/neo-tree.nvim` | 带 git 与诊断信息的文件树 | 纯 Lua | ide |
| ☐ | `nvim-telescope/telescope-fzf-native.nvim` | 给 telescope 的 C 语言模糊排序器，显著提速 | 编译/下载 | ide |
| | | ↳ 需要 make 与 C 编译器；离线包必须预置编译产物 | | |
| ☐ | `nvim-telescope/telescope-ui-select.nvim` | 把 LSP code action 等选择项交给 telescope 渲染 | 纯 Lua | ide |

## F. 补全 · 代码片段

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `saghen/blink.cmp` | 高性能补全引擎，当前主流选择 | 编译/下载 | core |
| | | ↳ Rust 模糊匹配器首次使用会联网下载；离线须预置二进制，或设 `fuzzy.implementation = "lua"` 退回纯 Lua（性能下降） | | |
| ☑ | `L3MON4D3/LuaSnip` | 片段引擎，兼容 VSCode 与 LSP 片段格式 | 纯 Lua | core |
| | | ↳ `jsregexp` 为可选的 C 加速库，缺失时自动降级 | | |
| ☑ | `rafamadriz/friendly-snippets` | 覆盖大量语言的现成片段集合 | 纯 Lua | core |
| ☐ | `hrsh7th/nvim-cmp` | 模块化补全框架，稳定但已进入维护模式 | 纯 Lua | ide |
| ☐ | `hrsh7th/cmp-nvim-lsp` | nvim-cmp 的 LSP 补全源 | 纯 Lua | ide |
| ☐ | `hrsh7th/cmp-buffer` | nvim-cmp 的当前缓冲区词汇源 | 纯 Lua | ide |
| ☐ | `hrsh7th/cmp-path` | nvim-cmp 的文件路径源 | 纯 Lua | ide |
| ☐ | `hrsh7th/cmp-cmdline` | nvim-cmp 的命令行补全源 | 纯 Lua | ide |
| ☐ | `saadparwaiz1/cmp_luasnip` | 把 LuaSnip 接入 nvim-cmp | 纯 Lua | ide |
| ☐ | `onsails/lspkind.nvim` | 给补全项加类型图标 | 纯 Lua | ide |
| ☐ | `dcampos/nvim-snippy` | 轻量 vim-snippet 引擎，纯 Lua 无编译 | 纯 Lua | extra |
| ☐ | `nvim-mini/mini.nvim#mini.snippets` | mini 的极简片段模块 | 纯 Lua | extra |
| ☐ | `chrisgrieser/nvim-scissors` | 片段创建与编辑 UI | 纯 Lua | extra |
| ☐ | `ms-jpq/coq_nvim` | 基于 SQLite 的补全引擎，开箱即用 | 纯 Lua | extra |

## G. LSP 与语言服务

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `neovim/nvim-lspconfig` | 官方 LSP 服务器配置集合，架在内置 vim.lsp 之上 | 纯 Lua | core |
| | | ↳ 纯配置数据、零联网；要求 Neovim ≥ 0.11.3 | | |
| ☑ | `folke/lazydev.nvim` | 为 lua_ls 补全 Neovim API 与你的配置源码，写发行版自身必需 | 纯 Lua | core |
| ☐ | `stevearc/aerial.nvim` | 符号大纲侧栏，支持 LSP 与 treesitter | 纯 Lua | ide |
| ☑ | `ray-x/lsp_signature.nvim` | 输入函数参数时显示签名 | 纯 Lua | ide |
| ☐ | `aznhe21/actions-preview.nvim` | code action 预览后再应用 | 纯 Lua | ide |
| ☑ | `antosha417/nvim-lsp-file-operations` | 重命名文件时自动更新 import 路径 | 纯 Lua | ide |
| ☐ | `nvimtools/none-ls.nvim` | 通过 LSP 协议注入诊断与格式化 | 纯 Lua | ide |
| | | ↳ 是已归档的 null-ls 的活跃继任者 | | |
| ☐ | `hedyhli/outline.nvim` | 树形符号大纲，可视化并导航代码符号 | 纯 Lua | extra |
| ☐ | `chrisgrieser/nvim-lsp-endhints` | 行尾显示推断类型与参数名 | 纯 Lua | extra |
| ☐ | `kosayoda/nvim-lightbulb` | 可用的 code action 处显示提示灯 | 纯 Lua | extra |
| | | ↳ 上游已不活跃；功能简单，也可以自己监听 LSP code action 事件实现 | | |
| ☐ | `mason-org/mason.nvim` | LSP / DAP / linter / formatter 安装器 | 联网 | extra |
| | | ↳ 注册表刷新与所有安装动作都走网络，官方无离线模式，与你的要求冲突；列出仅供你知情决策 | | |
| ☐ | `mason-org/mason-lspconfig.nvim` | mason 与 lspconfig 的桥接 | 纯 Lua | extra |
| | | ↳ 明确只识别 mason 自己装的服务器，离线场景没有意义 | | |

## H. Tree-sitter

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `nvim-treesitter/nvim-treesitter` | 语法高亮、缩进、折叠的解析器管理 | 编译/下载 | core |
| | | ↳ `main` 分支要求 Neovim ≥ 0.12，安装解析器需要 curl + tar + tree-sitter-cli + C 编译器；离线做法是预置 `parser/*.dll` 与 `parser/*.so` 加 `queries/`。注意解析器 ABI 必须与 Neovim 自身的 tree-sitter 版本匹配，nightly 升级后要重新构建 | | |
| ☑ | `nvim-treesitter/nvim-treesitter-textobjects` | 语法感知的文本对象与跳转动作 | 纯 Lua | ide |
| ☑ | `nvim-treesitter/nvim-treesitter-context` | 顶部固定显示当前函数 / 类的作用域头 | 纯 Lua | ide |
| ☐ | `windwp/nvim-ts-autotag` | HTML / JSX 标签自动闭合与重命名 | 纯 Lua | ide |
| ☑ | `folke/ts-comments.nvim` | 用语法树决定注释符，解决 JSX 等混合语言注释 | 纯 Lua | ide |

## I. 格式化

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `stevearc/conform.nvim` | 格式化器统一调度，可回退到 LSP 格式化 | 外部工具 | core |
| | | ↳ 插件本身纯 Lua；只列本发行版选定语言需要的格式化器，prettier / black / gofumpt 等按需自配。应先探测命令是否存在，缺失时静默跳过而不是报错 | | |
| ☐ | `mhartington/formatter.nvim` | 配置式异步格式化器 | 外部工具 | extra |

## J. 静态检查

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `mfussenegger/nvim-lint` | 异步 linter 调度，结果进诊断系统 | 外部工具 | core |
| | | ↳ GPL 许可，打包时与其他 MIT 代码保持可分离；同样只列本发行版语言需要的 linter | | |

## K. 诊断与问题面板

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `folke/trouble.nvim` | 诊断 / 引用 / quickfix 统一面板 | 纯 Lua | core |
| ☐ | `stevearc/quicker.nvim` | 让 quickfix 缓冲区可编辑，带预览与过滤 | 纯 Lua | ide |
| ☐ | `rachartier/tiny-inline-diagnostic.nvim` | 更精致的行内诊断渲染 | 纯 Lua | ide |
| ☐ | `dgagn/diagflow.nvim` | 光标处浮窗显示完整诊断 | 纯 Lua | extra |

## L. Git 集成

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `lewis6991/gitsigns.nvim` | 行内变更标记、按 hunk 暂存与回退、行内 blame | 外部工具 | core |
| ☑ | `NeogitOrg/neogit` | Magit 风格的完整 git 操作界面 | 外部工具 | ide |
| ☐ | `tpope/vim-fugitive` | 经典 Git 包装，:Git / :Gdiffsplit / :GBrowse | 外部工具 | ide |
| ☑ | `sindrets/diffview.nvim` | 全屏 diff 与三方合并界面 | 外部工具 | ide |
| | | ↳ 2024-08 后停更，功能稳定 | | |
| ☐ | `nvim-mini/mini.nvim#mini.git` | mini 的 git 集成，含 blame、diff、hunk 操作 | 外部工具 | extra |
| ☐ | `nvim-mini/mini.nvim#mini.diff` | 缓冲区与参考版本对比，自带 hunk 操作 | 纯 Lua | extra |
| ☐ | `FabijanZulj/blame.nvim` | 全屏 blame 视图 | 外部工具 | extra |
| ☐ | `kdheepak/lazygit.nvim` | 在浮动窗口里嵌入 lazygit | 外部工具 | extra |
| ☐ | `pwntester/octo.nvim` | 在编辑器里处理 GitHub PR 与 issue | 联网 | extra |
| | | ↳ 必须联网，离线发行版建议排除 | | |

## M. 编辑增强

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `nvim-mini/mini.nvim#mini.ai` | 增强 a / i 文本对象，支持成对符号与语法树 | 纯 Lua | core |
| ☑ | `nvim-mini/mini.nvim#mini.surround` | 增删改环绕字符 | 纯 Lua | core |
| ☑ | `nvim-mini/mini.nvim#mini.pairs` | 自动配对 | 纯 Lua | core |
| ☑ | `nvim-mini/mini.nvim#mini.comment` | gc / gcc 注释，识别注释符 | 纯 Lua | core |
| ☑ | `nvim-mini/mini.nvim#mini.bracketed` | 一整套 [ / ] 前缀跳转（buffer、诊断、git、缩进等） | 纯 Lua | core |
| ☑ | `nvim-mini/mini.nvim#mini.move` | 移动行与选区 | 纯 Lua | core |
| ☑ | `nvim-mini/mini.nvim#mini.operators` | 让操作符支持复制、替换、排序、求值等 | 纯 Lua | core |
| ☑ | `nvim-mini/mini.nvim#mini.indentscope` | 缩进范围可视化 | 纯 Lua | core |
| ☑ | `folke/flash.nvim` | 标签式快速跳转，可绑定语法树节点 | 纯 Lua | core |
| ☑ | `tpope/vim-repeat` | 让插件的操作也能用 `.` 重复 | 纯 Lua | core |
| ☐ | `kylechui/nvim-surround` | 另一套环绕操作，键位贴合原 vim-surround | 纯 Lua | ide |
| ☐ | `windwp/nvim-autopairs` | 自动配对，规则可编程 | 纯 Lua | ide |
| ☑ | `chrisgrieser/nvim-spider` | 更符合直觉的 w / e / b 词移动 | 纯 Lua | ide |
| ☐ | `Wansmer/treesj` | 按语法树拆分与合并代码块 | 纯 Lua | ide |
| ☑ | `mbbill/undotree` | 撤销树可视化 | 纯 Lua | ide |
| ☐ | `kevinhwang91/nvim-ufo` | 现代化折叠，基于 LSP 与语法树 | 纯 Lua | ide |
| ☑ | `RRethy/vim-illuminate` | 高亮光标下符号的所有出现 | 纯 Lua | ide |
| ☑ | `NMAC427/guess-indent.nvim` | 自动推断并设置缩进 | 纯 Lua | ide |
| ☐ | `folke/zen-mode.nvim` | 专注模式，隐藏所有干扰元素 | 纯 Lua | ide |
| ☑ | `nvim-mini/mini.nvim#mini.cursorword` | 高亮光标下单词 | 纯 Lua | extra |
| ☑ | `nvim-mini/mini.nvim#mini.hipatterns` | 高亮 TODO、颜色码、十六进制色值等自定义模式 | 纯 Lua | extra |
| ☑ | `nvim-mini/mini.nvim#mini.align` | 交互式文本对齐 | 纯 Lua | extra |
| ☑ | `nvim-mini/mini.nvim#mini.splitjoin` | 拆分与合并参数列表 | 纯 Lua | extra |
| ☑ | `nvim-mini/mini.nvim#mini.trailspace` | 高亮并一键清除行尾空白 | 纯 Lua | extra |
| ☑ | `nvim-mini/mini.nvim#mini.bufremove` | 关闭 buffer 但保留窗口布局 | 纯 Lua | extra |
| ☐ | `nvim-mini/mini.nvim#mini.jump` | 增强 f / t / F / T 跳转 | 纯 Lua | extra |
| ☐ | `nvim-mini/mini.nvim#mini.jump2d` | 二维目标跳转 | 纯 Lua | extra |
| ☐ | `smoka7/hop.nvim` | 标签跳转，原 phaazon/hop 的活跃继任者 | 纯 Lua | extra |
| ☐ | `ggandor/leap.nvim` | 两字符即时跳转 | 纯 Lua | extra |
| ☐ | `chrisgrieser/nvim-various-textobjs` | 一批额外的文本对象（整文件、缩进块、URL 等） | 纯 Lua | extra |
| ☐ | `numToStr/Comment.nvim` | gc / gb 注释 | 纯 Lua | extra |
| | | ↳ 2024-08 后停更；Neovim 0.10+ 已内置注释，优先用内置或 ts-comments | | |
| ☐ | `jake-stewart/multicursor.nvim` | 多光标编辑 | 纯 Lua | extra |
| ☐ | `brenton-leighton/multiple-cursors.nvim` | 另一款多光标实现 | 纯 Lua | extra |
| ☐ | `folke/twilight.nvim` | 变暗非当前代码块 | 纯 Lua | extra |
| ☐ | `karb94/neoscroll.nvim` | 平滑滚动 | 纯 Lua | extra |
| ☐ | `folke/edgy.nvim` | 侧栏与底栏窗口的布局管理 | 纯 Lua | extra |
| ☐ | `smjonas/live-command.nvim` | 实时预览 :norm / :g 等命令的效果 | 纯 Lua | extra |
| ☐ | `m4xshen/hardtime.nvim` | 阻止低效的重复按键，帮你改掉坏习惯 | 纯 Lua | extra |
| ☐ | `tris203/precognition.nvim` | 提示当前可用的移动键位 | 纯 Lua | extra |
| ☐ | `chentoast/marks.nvim` | 增强 mark 的管理与可视化 | 纯 Lua | extra |
| ☐ | `gbprod/yanky.nvim` | 增强的 yank 历史与粘贴 | 纯 Lua | extra |

## N. 会话 · 项目 · 工作区

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `nvim-mini/mini.nvim#mini.sessions` | 会话的读写与删除 | 纯 Lua | core |
| ☑ | `nvim-mini/mini.nvim#mini.visits` | 记录并复用访问过的文件（最近文件、标签、跳回） | 纯 Lua | ide |
| ☐ | `folke/persistence.nvim` | 退出时自动保存会话，进入时恢复 | 纯 Lua | ide |
| ☐ | `ThePrimeagen/harpoon` | 按项目标记常用文件并一键跳转 | 纯 Lua | ide |
| | | ↳ 使用 harpoon2 分支 | | |
| ☐ | `otavioschwanck/arrow.nvim` | 书签式文件跳转，带可视化界面 | 纯 Lua | extra |
| ☐ | `nvim-mini/mini.nvim#mini.basics` | 一批合理的默认选项与键位预设，适合当发行版基线 | 纯 Lua | extra |
| ☐ | `ahmedkhalf/project.nvim` | 为 picker 提供项目根识别（含 git / LSP 模式） | 纯 Lua | extra |
| | | ↳ 2024-08 后停更；Neovim 0.12 的 vim.fs.root 可平替 | | |

## O. 通知 · 命令行 · UI 润色

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `j-hui/fidget.nvim` | 右下角显示 LSP 加载进度 | 纯 Lua | core |
| ☑ | `nvim-mini/mini.nvim#mini.notify` | 极简通知系统，统一收集 :messages | 纯 Lua | core |
| ☐ | `folke/noice.nvim` | 重构命令行、消息、通知与悬浮窗的整套 UI | 纯 Lua | ide |
| | | ↳ 依赖 nui.nvim；上游更新放缓 | | |
| ☑ | `stevearc/dressing.nvim` | 美化 vim.ui.input 与 vim.ui.select | 纯 Lua | ide |
| ☐ | `rcarriga/nvim-notify` | 可堆叠的通知管理器 | 纯 Lua | extra |
| | | ↳ 2025-09 后停更，mini.notify 或 snacks.notifier 可替代 | | |

## P. 快捷键提示

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `folke/which-key.nvim` | 按下前缀键后弹出可用键位，预设丰富 | 纯 Lua | core |
| | | ↳ 上游更新放缓 | | |
| ☐ | `nvim-mini/mini.nvim#mini.clue` | 常驻键位提示 HUD，可自定义触发前缀 | 纯 Lua | core |
| ☐ | `tris203/hawtkeys.nvim` | 扫描出尚未被占用的键位 | 纯 Lua | extra |
| | | ↳ 活跃度低，选用前先确认 | | |

## Q. 终端 · 任务 · 数据库 · HTTP

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☐ | `akinsho/toggleterm.nvim` | 浮动与分屏终端管理 | 纯 Lua | ide |
| | | ↳ 2025-03 后未更新；snacks.terminal 或内置 :terminal 可替代 | | |
| ☐ | `stevearc/overseer.nvim` | 任务运行器，把 build / test / lint 收成统一入口 | 纯 Lua | ide |
| ☐ | `chomosuke/term-edit.nvim` | 在终端缓冲区里使用命令行式的编辑键位 | 纯 Lua | extra |
| ☐ | `CRAG666/code_runner.nvim` | 一键编译并运行当前文件 | 纯 Lua | extra |
| ☐ | `mrcjkb/rustaceanvim` | Rust 专用增强，整合 rust-analyzer 与 codelldb | 外部工具 | extra |
| | | ↳ 只有 Rust 工作流需要 | | |
| ☐ | `tpope/vim-dadbod` | 把各种数据库 CLI 统一成一个接口 | 外部工具 | extra |
| | | ↳ 每种数据库都要自备客户端 | | |
| ☐ | `kristijanhusak/vim-dadbod-ui` | dadbod 的图形化界面 | 纯 Lua | extra |
| ☐ | `kristijanhusak/vim-dadbod-completion` | 表名与列名补全 | 纯 Lua | extra |
| ☐ | `mistweaverco/kulala.nvim` | HTTP 请求客户端，直接跑 .http 文件 | 外部工具 | extra |
| ☐ | `rest-nvim/rest.nvim` | 另一款 HTTP 请求客户端 | 外部工具 | extra |
| | | ↳ GPL 许可，与 MIT 代码需保持可分离 | | |
| ☐ | `folke/neoconf.nvim` | 按项目落地 LSP 与工具配置 | 纯 Lua | extra |
| ☐ | `chrisgrieser/nvim-genghis` | 文件与目录的常用操作（移动、重命名、复制路径、改权限） | 纯 Lua | extra |

## R. 调试（DAP）

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☐ | `mfussenegger/nvim-dap` | DAP 客户端，断点、单步、调用栈 | 外部工具 | ide |
| | | ↳ 插件纯 Lua，适配器必须自备；mason-nvim-dap 走网络不可用 | | |
| ☐ | `rcarriga/nvim-dap-ui` | 调试界面，变量、断点、栈帧、REPL 四个面板 | 纯 Lua | ide |
| ☐ | `nvim-neotest/nvim-nio` | 异步 IO 库，nvim-dap-ui 的依赖 | 纯 Lua | ide |
| ☐ | `theHamsta/nvim-dap-virtual-text` | 在行内显示变量当前值 | 纯 Lua | ide |
| ☐ | `mfussenegger/nvim-dap-python` | Python 调试接入 debugpy | 外部工具 | ide |
| ☐ | `leoluz/nvim-dap-go` | Go 调试接入 delve | 外部工具 | extra |
| ☐ | `jay-babu/mason-nvim-dap.nvim` | 用 mason 安装调试适配器 | 联网 | extra |
| | | ↳ 依赖 mason，离线场景排除 | | |

## S. 测试

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☐ | `nvim-neotest/neotest` | 可扩展的测试运行框架，带结果树 | 外部工具 | ide |
| ☐ | `nvim-neotest/neotest-python` | neotest 的 Python 适配器 | 外部工具 | extra |
| ☐ | `nvim-neotest/neotest-go` | neotest 的 Go 适配器 | 外部工具 | extra |
| ☐ | `nvim-neotest/neotest-plenary` | neotest 的 plenary 适配器，用来测 Lua 与插件本身 | 纯 Lua | extra |
| ☐ | `vim-test/vim-test` | 另一款多框架测试执行器，覆盖面广 | 外部工具 | extra |
| ☐ | `andythigpen/nvim-coverage` | 显示测试覆盖率 | 外部工具 | extra |

## T. 标记语言 · 写作 · 笔记

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `folke/todo-comments.nvim` | 高亮并可全局搜索 TODO / FIXME / NOTE / HACK | 纯 Lua | core |
| ☐ | `dhruvasagar/vim-table-mode` | Markdown 与 org 表格自动对齐、公式计算 | 纯 Lua | ide |
| ☑ | `MeanderingProgrammer/render-markdown.nvim` | 在缓冲区里渲染 Markdown 的标题、表格、代码块、勾选框 | 纯 Lua | ide |
| | | ↳ 需要 Nerd Font 与正确的字符宽度设置，否则表格错位 | | |
| ☐ | `nvim-orgmode/orgmode` | org-mode 复刻，待办、日程、导出 | 纯 Lua | extra |
| | | ↳ 要求 Neovim ≥ 0.12 | | |
| ☐ | `obsidian-nvim/obsidian.nvim` | Obsidian 仓库的笔记、双向链接、模板 | 纯 Lua | extra |
| | | ↳ 原 epwalsh/obsidian.nvim 的活跃继任者 | | |
| ☐ | `iamcco/markdown-preview.nvim` | 浏览器中的实时 Markdown 预览 | 编译/下载 | extra |
| | | ↳ 默认需要 node + yarn，或首次运行时下载预编译产物；离线包必须预先放入 | | |
| ☐ | `ellisonleao/glow.nvim` | 用 glow 在终端内渲染 Markdown | 外部工具 | extra |

## U. 中文 / CJK

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `keaising/im-select.nvim` | 离开插入模式时自动切回英文输入法，回来时切回中文 | 外部工具 | core |
| | | ↳ 双平台最省事的方案。Windows 用 im-select.exe，Linux 用 fcitx5-remote 或 ibus | | |
| ☑ | `kkew3/jieba.vim` | 中文按词移动（w / b / e）与中文文本对象 | 编译/下载 | core |
| | | ↳ 需要 Rust 编译或预编译二进制；离线包必须预置产物 | | |
| ☐ | `amekusa/auto-input-switch.nvim` | 按上下文切换输入法，中英混排场景更细 | 外部工具 | extra |
| ☐ | `Old-Farmer/im-autoswitch.nvim` | 另一款可配置的输入法自动切换 | 外部工具 | extra |
| ☐ | `tonyfettes/fcitx5.nvim` | fcitx5 深度集成 | 纯 Lua | extra |
| | | ↳ 2022 年后停更，且仅支持 Linux | | |

## V. AI 助手（默认排除）

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☐ | `olimorris/codecompanion.nvim` | 聊天与内联改写，支持接入本地模型服务 | 联网 | extra |
| | | ↳ 若指向本机 Ollama 或 llama.cpp，才勉强算离线 | | |
| ☐ | `yetone/avante.nvim` | Cursor 风格的 AI 编辑体验 | 联网 | extra |
| | | ↳ 另有 curl 依赖与编译步骤 | | |
| ☐ | `zbirenbaum/copilot.lua` | GitHub Copilot 内联补全 | 联网 | extra |
| | | ↳ 需要 GitHub 账号认证 | | |
| ☐ | `milanglacier/minuet-ai.nvim` | 多后端补全，可指向本地服务 | 联网 | extra |
| ☐ | `David-Kunz/gen.nvim` | 极简 LLM 调用，支持本地模型 | 联网 | extra |
| | | ↳ 代码量极小，适合当自己写 AI 集成的参考 | | |

## W. 性能 · 大文件 · 启动分析

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `dstein64/vim-startuptime` | 图形化分析启动耗时，按插件排序 | 纯 Lua | core |
| ☐ | `nvim-mini/mini.nvim#mini.extra` | mini 的额外 picker 集合（注册表、颜色、诊断等） | 纯 Lua | extra |
| ☐ | `LunarVim/bigfile.nvim` | 超过阈值时自动关闭 treesitter / LSP / 折叠等重功能 | 纯 Lua | extra |
| | | ↳ 2024-08 后停更，snacks.bigfile 可替代 | | |
| ☐ | `ouuan/nvim-bigfile` | 按文件类型分别设置大小阈值 | 纯 Lua | extra |
| | | ↳ 2024-11 后停更 | | |

## X. 其它实用小件与备选方案

| | 插件 | 作用 | 依赖 | 档位 |
| --- | --- | --- | --- | --- |
| ☑ | `MagicDuck/grug-far.nvim` | 项目级搜索替换，带预览与逐条确认 | 外部工具 | ide |
| ☑ | `mrjones2014/smart-splits.nvim` | 智能分屏切换与调整大小，可与 tmux 联动 | 纯 Lua | ide |
| ☐ | `nvim-pack/nvim-spectre` | 另一款项目级搜索替换面板 | 外部工具 | extra |
| ☐ | `numToStr/Navigator.nvim` | 在 Neovim 与 tmux 分屏间无缝切换 | 纯 Lua | extra |
| ☐ | `christoomey/vim-tmux-navigator` | 同上，VimScript 老牌实现，也支持 Windows Terminal | 纯 Lua | extra |
| ☐ | `godlygeek/tabular` | 按分隔符对齐文本块 | 纯 Lua | extra |
| | | ↳ VimScript 老牌插件 | | |
| ☐ | `tpope/vim-speeddating` | 让 Ctrl-A / Ctrl-X 认识日期与时间 | 纯 Lua | extra |
| ☐ | `jbyuki/one-small-step-for-vimkind` | 调试 Neovim 自身的 Lua 代码 | 纯 Lua | extra |
| ☐ | `folke/lazy.nvim` | 功能最强的插件管理器 | 纯 Lua | extra |
| | | ↳ 与「不用管理器、pack/start 直接加载」的方案冲突，列出仅供你对比后再定；若选它必须设 `install.missing = false` 与 `rocks.enabled = false` | | |
