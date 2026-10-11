# 调研记录（事实与来源）

本文件保存决定架构取舍的原始事实，便于日后复核。核对时间：2026-10。许可证、归档状态、最后提交时间取自各仓库的 GitHub API。

## 1. Neovim 版本与 API 代际

- 最新稳定版 **v0.12.6**（2026-10-09）；0.11 线最后一版是 v0.11.7；**0.13 无稳定版**。
  来源：[releases](https://api.github.com/repos/neovim/neovim/releases?per_page=15)
- `vim.pack` 于 **0.12.0** 引入（0.12 的 `news.txt` NEW FEATURES → PLUGINS）。`runtime/lua/vim/pack.lua` 在 v0.11.0 不存在、v0.12.6 存在。
  来源：[0.12 news](https://raw.githubusercontent.com/neovim/neovim/v0.12.0/runtime/doc/news.txt)
- `vim.lsp.config()` / `vim.lsp.enable()` 于 **0.11.0** 引入。
- 内置补全的公开形态是 0.12 的 `'autocomplete'` 选项（配合 `vim.lsp.completion`）。注意**不存在 `vim._complete` 这个运行时模块**，别照抄网上的写法。
- `vim.diagnostic`：0.11 起 `virtual_text` 默认关闭、新增 `jump` 表与 `virtual_lines`；0.12 移除了 `disable()` / `is_disabled()`，诊断符号不再通过 `sign_define` 配置。
- `vim.fs`：0.11 新增 `rm/abspath/relpath` 与 `dir()/find()` 的 `follow`；0.12 新增 `vim.fs.ext()`、`vim.fs.root()` 优先级列表。
- **实际最低版本要求**：`nvim-lspconfig` 要 ≥ 0.11.3；用 `vim.pack`、`'autocomplete'` 或 `nvim-treesitter` 的 `main` 分支则要 ≥ 0.12。`nvim-treesitter` 官方只保证最新稳定版与 nightly。

## 2. 插件管理器对比

| 管理器 | 状态 | 离线可行性 |
| --- | --- | --- |
| `folke/lazy.nvim` | 活跃（最近提交 2026-06，v11.17.5） | 可离线：`install.missing = false`，`rocks.enabled = false`（默认 true，会指向远端 rocks 服务），`checker.enabled` 本来就是 false。**插件目录缺失时仍会 git clone**；`dev.path` / `dir =` 可指向本地检出 |
| `wbthomason/packer.nvim` | 2024-03 后无提交，实质停更 | LuaRocks 依赖要联网，避免 |
| `junegunn/vim-plug` | 活跃（2026-10） | 需显式 `:PlugInstall` 才拉取；预置目录后完全离线 |
| `nvim-mini/mini.nvim` 的 `mini.deps` | **开发冻结**（官方建议迁移到 `vim.pack`） | `add()` 只检查目录是否存在，预置后可离线 |
| `lewis6991/pckr.nvim` / `savq/paq-nvim` | 活跃度低 | 只在显式安装时 clone，预置后可离线 |
| **`pack/*/start` + `pack/*/opt`**（内置） | 稳定 | **完全没有网络行为**，`opt` + `:packadd` 即按需加载 |

`vim.pack` 的两个离线隐患：它**需要 `git`**；若磁盘上的插件目录与 spec 的 `src` 不一致，会**删除并重新克隆**。
来源：[pack.txt](https://raw.githubusercontent.com/neovim/neovim/v0.12.6/runtime/doc/pack.txt)

## 3. nvim-treesitter

- `main` 是默认分支（活跃）；`master` 已锁死，仅为兼容 0.11。
- `main` 要求 Neovim ≥ 0.12，安装解析器需要 `curl` + `tar` + `tree-sitter-cli ≥ 0.26.1`（不是 npm 版）+ C 编译器。
- 离线做法：预置 `parser/<lang>.so`（Linux）/ `parser/<lang>.dll`（Windows）+ `queries/<lang>/*.scm`。解析器已存在时 `install()` 是空操作，运行期不需要编译器、curl、tar 或 tree-sitter-cli。
- **ABI 耦合**：0.12.6 内置 tree-sitter **0.26.13**，支持 ABI 15。ABI 不匹配的解析器会静默加载失败。
  来源：[deps.txt](https://raw.githubusercontent.com/neovim/neovim/v0.12.6/cmake.deps/deps.txt)
- Neovim 自带 C / Lua / Markdown / Vimscript / Vimdoc / query 的解析器与查询文件。

## 4. mason 体系为什么不能用

- 需要网络的环节：注册表下载与刷新（`registries = {"github:mason-org/mason-registry"}`，`registry_cache.refresh` 默认开启）、每次 `:MasonInstall`（走 GitHub Releases / npm / PyPI / cargo）、metadata 的 `providers`（`api.mason-registry.dev`）、可选的 Socket.dev 客户端自动安装。
- **没有受支持的完全离线模式**。可以预先把包装进 `stdpath('data')/mason/packages/*/bin` 并 vendor 注册表，但设计前提就是在线的。
- `mason-lspconfig` 明确「不会识别装在别处的服务器」。
- 替代方案：`vim.env.PATH` 前置自带 `bin/`，然后 `vim.lsp.config(name, { cmd = {...} })` + `vim.lsp.enable(name)`。
  来源：[mason README](https://raw.githubusercontent.com/mason-org/mason.nvim/main/README.md)

## 5. 插件的非纯 Lua 依赖矩阵

| 插件 | 外部依赖 | 是否可降级 | Win/Linux 预编译产物 |
| --- | --- | --- | --- |
| `nvim-telescope/telescope.nvim` | `rg`、`fd`、`git` | 是，官方称「推荐依赖」；缺 `fd` 时 `find_files` 有回退 | rg / fd 都有 |
| `nvim-telescope/telescope-fzf-native.nvim` | `make` + C 编译器 | 是，默认走纯 Lua 排序器 | 仅构建期需要 |
| `ibhagwan/fzf-lua` | **`fzf` 是硬依赖**；`rg` 用于 grep | fzf 不可降级 | 有 |
| `folke/snacks.nvim` | picker 用 `rg`/`fd`/`git` | 是，有 Lua 回退 | 有 |
| `saghen/blink.cmp` | Rust 模糊匹配器，**运行时下载** | 是，`fuzzy.implementation = "lua"` | 官方发布二进制 |
| `hrsh7th/nvim-cmp`、`L3MON4D3/LuaSnip` | 无 | — | — |
| `lewis6991/gitsigns.nvim`、`NeogitOrg/neogit`、`sindrets/diffview.nvim` | `git` | 功能所需，无回退 | MinGit 可移植 |
| `mfussenegger/nvim-dap` | 各语言调试适配器 | 是，插件本身纯 Lua | dlv / codelldb 有 |
| `stevearc/conform.nvim`、`mfussenegger/nvim-lint` | 你配置的格式化器 / linter | 是，纯 Lua 调度 | 取决于具体工具 |
| `MeanderingProgrammer/render-markdown.nvim` | 无（但需 Nerd Font 与正确字符宽度） | — | — |
| `iamcco/markdown-preview.nvim` | `node` + `yarn`，**或首次下载 bundle** | 官方双路径 | 产物需预先 vendor |
| `rest-nvim/rest.nvim` | **`curl`** 硬依赖 | 否 | curl 有 |
| `mistweaverco/kulala.nvim` | `curl`（高级传输另需其他） | 基本可用 | curl 有 |
| `obsidian-nvim/obsidian.nvim` | `rg` 用于搜索 | 是 | 有 |
| `tpope/vim-dadbod` | 各数据库 CLI | 是，按库决定 | 取决于库 |

## 6. 可移植二进制的来源

**注意：你目前选择不打包工具，本表供日后决定时参考。**

| 工具 | 许可 | 平台产物 | 压缩体积 |
| --- | --- | --- | --- |
| [ripgrep](https://github.com/BurntSushi/ripgrep/releases) | MIT / Unlicense 双许可 | win msvc zip、linux musl tar.gz（静态） | 1.8–2.3 MB |
| [fd](https://github.com/sharkdp/fd/releases) | MIT / Apache-2.0 | win msvc zip、linux musl tar.gz | ~1.5 MB |
| [fzf](https://github.com/junegunn/fzf/releases) | MIT | windows_amd64.zip、linux_amd64.tar.gz | ~2.3 MB |
| [MinGit](https://github.com/git-for-windows/git/releases) | GPL-2.0 | `*-64-bit.zip` | ~30 MB |
| [lua-language-server](https://github.com/LuaLS/lua-language-server/releases) | MIT | win32-x64.zip、linux-x64.tar.gz | 3.7–4.5 MB |
| [clangd](https://github.com/clangd/clangd/releases) | Apache-2.0（含 LLVM 例外） | clangd-windows.zip 29.7 MB、clangd-linux.zip 118 MB | **最大的一项** |
| [basedpyright](https://github.com/DetachHead/basedpyright/releases) / pyright | MIT | basedpyright 有二进制；pyright 是 Node 应用 | 10–20 MB |
| [gopls](https://github.com/golang/tools/releases) | BSD-3-Clause | **无发布产物**，需自己构建 | ~20 MB |
| [rust-analyzer](https://github.com/rust-lang/rust-analyzer/releases) | MIT / Apache-2.0 | win msvc zip、linux gnu gz | 15–18 MB |
| typescript-language-server | Apache-2.0 | **仅 npm 包**，需自带 Node 运行时 | ~1 MB + Node ~50 MB |
| [StyLua](https://github.com/JohnnyMorganz/StyLua/releases) | MPL-2.0 | windows / linux zip | ~3 MB |
| [shfmt](https://github.com/mvdan/sh/releases) | BSD-3-Clause | 双平台单文件 | ~3 MB |
| prettier | MIT | npm / 独立 JS，需 Node | ~8 MB |
| [tree-sitter CLI](https://github.com/tree-sitter/tree-sitter/releases) | MIT | windows x64 / linux x64 zip | 3.8–8.6 MB |
| [luacheck](https://github.com/lunarmodules/luacheck/releases) | MIT | **仅源码 / luarocks**，无官方 exe | 小 |
| [ruff](https://github.com/astral-sh/ruff/releases) | MIT | win msvc zip、linux musl tar.gz | ~10 MB |
| black | MIT | wheel（需内嵌 Python）或 PyInstaller | ~2 MB |
| [gofumpt](https://github.com/mvdan/gofumpt/releases) | BSD-3-Clause | 双平台单文件 | ~3 MB |
| [delve](https://github.com/go-delve/delve/releases) | MIT | win zip、linux tar.gz | ~13 MB |
| [codelldb](https://github.com/vadimcn/codelldb/releases) | MIT | `.vsix`（本质是 zip，解开即可） | 51–56 MB |

许可提示：`git`（GPL-2.0）、`nvim-lint` 与 `rest.nvim`（GPL-3.0）是 copyleft，分发时需附源码或书面承诺，并与 MIT 部分保持可分离。`gopls` 与 `luacheck` 想离线只能自己构建。

## 7. 离线会静默翻车的地方

1. **运行时下载**：`blink.cmp` 首次使用拉二进制（[issue #1376](https://github.com/Saghen/blink.cmp/issues/1376)）；codelldb 的 bootstrap 包会去下载真正的适配器；`markdown-preview.nvim` 会拉 bundle。**判定方法**：在完全离线的环境跑一次，然后对比插件目录的文件清单。
2. **版本探测**：不少插件会跑 `rg --version` / `git --version` / `fzf --version`，命令不在 `PATH` 时报的错很难懂。启动脚本要把自带 `bin/` 前置进 `PATH`。
3. **锁文件陷阱**：在线生成的锁文件可能指向你从没 vendor 过的 commit。锁文件必须在离线包自身内部生成。
4. **首次运行期望编译器**：任何带 `build` 步骤的插件离线都会失败。本方案不用管理器，从机制上规避了这一点。
5. **Nerd Font**：`render-markdown`、`snacks`、`fzf-lua` 的 devicons、`lualine` 都假设有 Nerd Font 且字符宽度正确，否则显示方块、表格错位。要么随包带字体，要么默认关图标。
6. **Windows 路径**：Lua 侧普遍用 `/`；反斜杠会破坏 ripgrep 参数、`shellslash` 与 `jobstart` 的引号。用 `vim.fs.normalize`，并把 find / grep / git / DAP 四个场景在 Windows 上分别测。
7. **长路径**：Windows `MAX_PATH` 260 会截断深层 vendor 树与解析器目录。安装根要短，建议开启 `LongPathsEnabled`。
8. **联网探测**：`rust-analyzer` 与 `gopls` 可能尝试拉工具链或模块；LuaLS 的语言包、pyright 的 Node 都有 `download` 选项。全部关掉，并在防火墙阻断下验证。
9. **杀软与 SmartScreen**：新解压的未签名 `.exe`（rg、fd、fzf、dlv）在 Windows 上可能被隔离，需要写进文档让用户加白名单。

## 8. 主要参考

- [awesome-neovim](https://github.com/rockerBOO/awesome-neovim) · [dotfyle](https://dotfyle.com) — 插件生态索引
- [nvim-treesitter master→main 迁移说明](https://github.com/nvim-treesitter/nvim-treesitter/discussions/7901)
- [Neovim 0.12 news](https://raw.githubusercontent.com/neovim/neovim/v0.12.0/runtime/doc/news.txt) · [pack.txt](https://raw.githubusercontent.com/neovim/neovim/v0.12.6/runtime/doc/pack.txt)
- [nvim-lspconfig README](https://raw.githubusercontent.com/neovim/nvim-lspconfig/master/README.md) · [mason README](https://raw.githubusercontent.com/mason-org/mason.nvim/main/README.md)
- [kkew3/jieba.vim](https://github.com/kkew3/jieba.vim) — 中文分词移动
- 各插件与工具的许可证、归档状态、最后提交时间：`https://api.github.com/search/repositories?q=repo:OWNER/NAME`
