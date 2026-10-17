# 离线发行版架构设计

本文说明「不联网也能装、能跑」这件事具体怎么落地。所有决策都基于调研核实的版本事实，来源见 `RESEARCH-NOTES.md`。

## 0. 先看事实，再谈设计

调研核实到的关键事实（2026-10 核对，均取自 Neovim 官方仓库的 `news.txt` / `deps.txt` 与各插件仓库 API）：

| 事实 | 影响 |
| --- | --- |
| 稳定版是 **0.12.6**，**0.13 尚无稳定版** | 你指定的 0.13 nightly 与 0.12 是同一 API 代际，配置可以按 0.12 写，但 nightly 的树解析器 ABI 可能随时变 |
| `vim.pack` 于 **0.12.0** 引入 | 可用，但它默认要 `git` 联网 clone，且磁盘上的插件与 spec 的 `src` 不一致时会**删掉重克隆**——对离线包是隐患 |
| `vim.lsp.config()` / `vim.lsp.enable()` 于 **0.11.0** 引入 | 可以完全不依赖 `require('lspconfig')`（已废弃），也不需要 mason |
| `nvim-lspconfig` 要求 **≥ 0.11.3**，且是纯配置数据 | 可以放心 vendor，它自己不联网 |
| `nvim-treesitter` 的 **`main`** 分支要求 0.12+，安装解析器需要 `curl` + `tar` + `tree-sitter-cli` + C 编译器 | 编译能力只在**打包机**上需要；最终用户拿到的必须是预编译产物 |
| `master` 分支已冻结（为兼容 0.11） | 新项目直接上 `main` |
| Neovim 自带 C / Lua / Markdown / Vimscript / Vimdoc / query 的解析器与查询文件 | 零 vendor 解析器也有基础高亮，不会开局就瞎 |
| `mason.nvim` 没有官方离线模式；`mason-lspconfig` 只认 mason 自己装的服务器 | **整个 mason 体系直接排除** |
| 0.12.6 内置 tree-sitter **0.26.13**，支持 ABI 15 解析器 | 解析器与 Neovim 版本强耦合，见第 5 节 |
| nightly 是 **v0.13.0-dev-1828+g7e1ae5115f**（2026-10-11 发布，`assets` 含 `nvim-win-arm64` / `nvim-win64` / `nvim-linux-*`） | 你指定 nightly 可行；注意它是滚动更新的，每次升级都要重跑解析器构建 |
| 本机架构实测为 **AMD64**（AMD Zen），不是 ARM64 | Windows 产物用 `nvim-win64.zip`；`nvim-win-arm64.zip` 在这台机器上跑不起来 |

## 1. 目录布局

```
nvim-distro/
├── init.lua                     入口，只做一件事：加载 distro
├── nvim.cmd / nvim.sh           启动脚本：XDG 隔离 + bin 前置 PATH + -u init.lua
├── lua/distro/
│   ├── init.lua                 顺序编排：options → pack → plugins → search → lsp → format → keymaps
│   ├── options.lua              全局选项（含 ambiwidth=single）
│   ├── keymaps.lua              键位定义，带 desc 以便 which-key 显示
│   ├── pack.lua                 从 pack/distro/opt 按需 packadd（懒加载）
│   ├── platform.lua             平台差异的唯一权威源（exe 后缀 / 原生库后缀按插件家族）
│   ├── lsp.lua                  vim.lsp.config + vim.lsp.enable，服务器探测
│   ├── format.lua               conform.nvim 规格，先探测命令存在性
│   ├── health.lua               :checkhealth distro 的报告
│   └── plugins/                 每个功能域一个配置文件（theme / mini / ui / …）
├── pack/distro/                 ← **构建产物，不进版本库**
│   ├── start/                   编辑刚需，Neovim 启动时自动加载（35 个）
│   └── opt/                     较重或按需使用，由 pack.lua 显式 :packadd（8 个）
├── runtime/                     ← **随包的 Neovim 本体**：解析器由它亲自编译，ABI 不可能失配
├── vendor/
│   ├── lock.json                每个仓库的 commit、分支、许可、字节数 —— **要提交**
│   └── treesitter/site/         预编译解析器 + 查询（每平台一个包，不再分平台子目录）
├── bin/                         随包的外部工具 —— CI 按平台现取，**不进版本库**
│   ├── rg[.exe]  fzf[.exe]  fd[.exe]                    搜索与查找
│   ├── stylua[.exe]  shfmt[.exe]  shellcheck[.exe]      格式化与检查
│   ├── im-select.exe            例外留在版本库：上游产物名不含平台信息，无法可靠匹配
│   ├── README.md / manifest.json  版本清单（自动生成，manifest 供 checkhealth 读取）
│   └── licenses/                各工具的许可证全文，分发时必须附带
├── tools/
│   ├── parse_selection.py       目录 → build/selection.json
│   ├── check-stack.py           校验方案里没有同格多选
│   ├── verify-repos.py          核验目录里的仓库地址是否真实存在
│   ├── verify-binaries.py       校验 bin/ 完整性
│   ├── vendor.ps1               按 selection.json + lock.json 拉取插件（仅打包机联网）
│   ├── fetch-runtime.ps1        取 Neovim 本体（按平台）
│   ├── fetch-tools.ps1          取随包工具（按平台）
│   ├── harvest.lua              CI 里用**包内那个 nvim** 编译 tree-sitter 解析器
│   ├── package.ps1              组装并归档（win = zip，其余 = tar.gz）
│   ├── smoke.lua                冒烟断言：CI 逐平台对刚打出的包执行
│   ├── gen-keymaps.py / dump-keymaps.lua   生成 docs/KEYMAPS.md（对比干净 nvim）
│   └── sync-to-package.ps1      把仓库配置同步进已解压的包目录
└── catalog/                     选型目录（唯一数据源）
```

`pack/` 是构建产物：最终用户拿到的是打包好的 zip，而不是这个 git 仓库；`pack/` 由
`tools/vendor.ps1` + 已提交的 `vendor/lock.json` 完全复现。这样源仓库保持小而干净，
而「可复现」由 lock 文件保证，不是靠把第三方代码提交进来。

`vendor.sh`（Linux 上的同一件事）尚未编写——目前的打包机是 Windows，我倾向不先写一份
未经验证的平行实现，等真的需要在 Linux 上 vendor 时再补。

## 2. 为什么不用插件管理器

| 方案 | 离线可行性 | 结论 |
| --- | --- | --- |
| **`pack/*/start` + `pack/*/opt`**（内置） | 加载纯粹靠 runtimepath，`opt` 加 `:packadd` 就实现了按需加载，**全程不碰网络** | **采用** |
| `lazy.nvim` | 可以离线，但要显式设 `install.missing = false`、`rocks.enabled = false`；插件目录缺失时**仍会 `git clone`**；锁文件若是在线生成的，可能指向你根本没 vendor 的 commit | 备选，见第 9 节 |
| `vim.pack` | 内置，但默认要 `git`，且 `src` 不匹配就删目录重克隆 | 不用 |
| `packer.nvim` | 2024-03 起实质停更，LuaRocks 依赖要联网 | 排除 |
| `vim-plug` | 单文件，预置目录后完全离线，但它解决的是「联网装插件」，我们不需要装 | 没必要 |
| `mini.deps` | 开发已冻结（官方推荐迁移到 `vim.pack`） | 排除 |

**核心洞察**：插件管理器的主要职责是「从网络拉取并锁定版本」。既然要求零联网，这个职责就消失了，剩下的「按需加载」Neovim 内置的 `pack/opt` + `:packadd` 已经够用。

副作用是好的：没有管理器就**没有 `build` 钩子**。lazy.nvim 的 `build = "make"` 这类配置在无管理器方案下根本不会执行，等于从机制上消灭了「首次启动偷偷编译」这一整类离线事故。

代价是**版本锁定要自己做**：用 `vendor/lock.json` 记录每个仓库的 commit，`tools/vendor.*` 按它拉取，绝不解析远端分支。

## 3. 每个平台一个包：内容由 STACKS 决定

已定：**四个平台各出一个完整自足的包** —— `linux64` / `linux-arm64` / `win64` / `darwin-arm64`。每个包自带该平台的 Neovim 本体、随包工具、tree-sitter 解析器与插件原生库。原「只打一个包、内含 Windows 与 Linux 两套二进制」已作废 —— 那样每个包都要带一半用不到的东西（光 `bin/` 就多背约 51 MB）。

- 勾选内容由 [`../catalog/STACKS.toml`](../catalog/STACKS.toml) 的 `recommended` 方案决定（59 条 / 43 个仓库）。`tools/package.ps1` 按平台组装归档。
- `pack/distro/start/` 放轻量必备件，Neovim 启动即加载；`pack/distro/opt/` 放较重的功能件，由 `lua/distro/pack.lua` 按需 `:packadd`。**这个划分按「启动耗时」而不是按 profile** —— 不再需要 profile 开关。
- 目录里的 `档位` 字段（`core` / `ide` / `extra`）和 `parse_selection.py --preset` 仍然可用，但**只是选型期的辅助手段，不参与打包**。真正的选择以 `STACKS.toml` 为准。

## 4. 「零联网」怎么保证，而不只是声明

运行时禁网的保证来自三处，缺一不可：

1. **加载路径不含网络行为**：`pack/` 是纯文件系统加载；没有管理器进程。
2. **不引入联网插件**：目录里 AI 一档全部标 `联网`，选定方案里一个都没勾。`mason` 同理。
3. **把「会偷偷下载」的插件预先处理掉**（这是唯一真正的风险面）：

| 插件 | 联网触发点 | 对策 |
| --- | --- | --- |
| `saghen/blink.cmp` | Rust 模糊匹配器首次使用时下载 | 预置二进制到插件目录；或设 `fuzzy.implementation = "lua"` 退回纯 Lua |
| `nvim-treesitter/nvim-treesitter` | `install{}` / `:TSUpdate` 走 `curl` + `tree-sitter-cli` | 预置 `parser/` 与 `queries/`；解析器已存在时 `install()` 是空操作 |
| `iamcco/markdown-preview.nvim` | 首次运行下载预编译 bundle，或用 `yarn` | 预置 bundle 产物 |
| `nvim-telescope/telescope-fzf-native.nvim` | `build` 阶段 `make` | 预置编译好的 `.so` / `.dll` |
| `kkew3/jieba.vim` | 需要 Rust 编译 | 预置预编译产物 |
| `markdown-preview` / `pyright` / LuaLS | 部分 LSP 有 `download` 选项 | 关掉所有 `download` 类选项 |
| `rust-analyzer` / `gopls` | 可能尝试拉取工具链或模块 | 在 `settings` 里禁用，并在离线环境下验证 |

**验证方法**（不能只靠声明）：CI 在每个平台的 runner 上对**刚打出来的包**跑 `tools/smoke.lua`：解压归档 → 用包内 nvim 启动 → 断言（11 个配置分组载入、解析器逐个可加载、随包工具与原生库就位、历史踩坑的行为回归）。更严格的一档 —— 断网环境下解压到干净目录、对比启动**前后**插件目录的文件清单哈希（直接抓「首次运行悄悄落盘」）—— 目前未脚本化，需要时手工执行。

## 5. Tree-sitter 解析器方案（最容易翻车的一环）

这是整个离线包里技术风险最高的一块，单独说。

- **只在打包机上满足编译前提**：`curl`、`tar`、`tree-sitter-cli ≥ 0.26.1`（注意不是 npm 那个）、C 编译器。
- **产物**：`parser/<lang>.dll`（Windows）/ `parser/<lang>.so`（Linux / macOS）+ `queries/<lang>/*.scm`。Neovim 会从任意 runtimepath 条目加载 `parser/`，优先级是 用户配置 > 插件 > 内置，所以放在 `vendor/treesitter/site/`（每平台一个包后不再分平台子目录）并加入 rtp 即可。
- **ABI 强耦合**：0.12.6 内置 tree-sitter 0.26.13，支持 ABI 15 的解析器；版本不匹配的解析器**加载失败**。你用的是 0.13 nightly，ABI 可能随 nightly 变动。
  → 因此：**每次升级 Neovim 都要重新构建包**（CI 会用包内那个 nvim 重跑 `tools/harvest.lua` 重新编译），`tools/smoke.lua` 会逐个加载解析器、把失败的列出来。这条必须写进你的升级流程，否则表现是「高亮突然全没了」而不是报错。
- **最小可用集是零**：Neovim 自带 C / Lua / Markdown / Vimscript / Vimdoc / query 的解析器。所以第一版可以先不 vendor 解析器，跑起来再补，风险最低。
- 四个平台必须**分别构建**（在各自平台的 CI 作业里），不能共用：`.dll` 与 `.so` 不通用，且架构相关（arm64 与 x64 也不通用）。

## 6. LSP 方案（不用 mason）

```lua
-- lua/distro/lsp.lua
local servers = {
  lua_ls = { cmd = { 'lua-language-server' } },
  clangd = { cmd = { 'clangd', '--background-index' } },
  basedpyright = { cmd = { 'basedpyright-langserver', '--stdio' } },
  bashls = { cmd = { 'bash-language-server', 'start' } },
}
for name, cfg in pairs(servers) do
  vim.lsp.config(name, cfg)
  vim.lsp.enable(name)
end
```

- `neovim/nvim-lspconfig` 提供各服务器的默认配置，是**纯数据、零联网**，可以放心 vendor。0.13 上不要 `require('lspconfig')`（已废弃）。
- 服务器从 `PATH` 发现；`vim.fn.executable()` 探测失败时**只报告不报错**，在 `:checkhealth distro` 里汇总缺失项。这是「只打包配置和插件」前提下最合理的降级策略。
- 你选定的用途对应需要的服务器与工具：

| 用途 | LSP 服务器 | 格式化 | 检查 |
| --- | --- | --- | --- |
| Lua / Neovim 配置 | `lua-language-server`（配 lazydev.nvim） | `stylua` | `luacheck` |
| C / C++ / 嵌入式 | `clangd` | `clang-format` | `clang-tidy` |
| Python | `basedpyright` 或 `pyright` | `ruff` / `black` | `ruff` |
| 运维 / Shell / 配置 | `bash-language-server`、`yaml-language-server`、`jsonls` | `shfmt`、`prettier` | `shellcheck` |

- 具体路径与可移植二进制来源见 `RESEARCH-NOTES.md` 的工具表。注意 `gopls` 与 `luacheck` **没有官方预编译产物**，如果你想连工具一起打包，这两个需要自己构建。

## 7. Windows 与 Linux 的差异清单

| 事项 | Windows | Linux |
| --- | --- | --- |
| 可执行文件 | 带 `.exe` 后缀，`vim.fn.executable('rg')` 会自动补后缀 | 无后缀 |
| 路径 | 统一用 `vim.fs.normalize()` / `vim.fs.joinpath()`；不要把反斜杠直接拼进给 `rg` / `jobstart` 的参数 | 原生 `/` |
| 长路径 | `MAX_PATH` 260 会截断深层的 `pack/` 树；**安装根目录要短**（如 `C:\nvim`），并建议开启 `LongPathsEnabled` | 无此限制 |
| shell | `vim.o.shell` 指向 `pwsh`/`cmd`，`jobstart` 的引号规则与 POSIX 不同，需要分别测 | `sh` 行为一致 |
| 终端与字体 | conhost 对 Nerd Font 与宽字符支持差，建议 Windows Terminal | 终端普遍更好，但东亚宽字符仍需 `ambiwidth=double` |
| 输入法 | `im-select.exe` | `fcitx5-remote` 或 `ibus` |
| 启动脚本 | `nvim.cmd` | `nvim.sh`（`chmod +x`） |

两个平台的启动脚本做同样的事：设置 `NVIM_APPNAME` 与 `XDG_*`（Windows 上对应 `$env:LOCALAPPDATA` 等），把 `<distro>/bin` 前置进 `PATH`，然后用 `-u <distro>/init.lua` 指向发行版配置。这样发行版是**自包含且不污染用户已有 Neovim 配置**的。

## 8. 从目录到产物的完整流程

完整流程由 [`.github/workflows/release.yml`](../.github/workflows/release.yml) 自动执行，核心步骤：

```bash
# 1. 你在目录里勾选（或套用预设）
python tools/parse_selection.py              # → build/selection.json
python tools/check-stack.py                  # 机械校验：方案里没有同格多选

# 2. vendoring（这一步在打包机上联网，最终用户不参与）
pwsh tools/vendor.ps1                        # 按 lock.json clone 到 pack/，并清理栈外目录

# 3. 逐平台构建（每个 CI 作业内完成，无跨作业传递）
pwsh tools/fetch-runtime.ps1 -Platform win64 -Tag nightly   # Neovim 本体 → runtime/
pwsh tools/fetch-tools.ps1   -Platform windows-x64          # 随包工具 → bin/，写 bin/manifest.json
#    （blink.cmp 原生库从官方 release 取并校验 sha256；
#      jieba 的 Rust 后端在作业里就地构建，构建树随即清掉）
nvim --headless -u init.lua -l tools/harvest.lua            # 用**包内那个 nvim** 编译解析器

# 4. 组装归档（win = zip，其余 = tar.gz —— zip 不保留可执行位）
pwsh tools/package.ps1 -Platform win64

# 5. 冒烟验收：在**刚打出来的包**上，用包内 nvim 跑 tools/smoke.lua 的断言
```

vendoring 时顺手做的事（`vendor/lock.json` 里记录）：仓库 commit、SPDX 许可标识、体积。许可证必须记录，因为分发时要能说明每一项的来源与条款。

当前需要特别标注的 copyleft 项：`git`（GPL-2.0）、`nvim-lint`（GPL-3.0）、`bin/shellcheck`（GPL-3.0）——都要与 MIT 配置代码保持可分离。目录里原本两个许可待核项（`nvim-tree/nvim-tree.lua` 与 `romgrk/barbar.nvim`）已按决定移除，不再需要处理。

`tpope/vim-repeat` 仓库里**没有 LICENSE 文件**，所以 `vendor/lock.json` 的 `license_files` 是空的——但它的 README 明确写着 *"Distributed under the same terms as Vim itself"*（即 Vim license）。这是扫描只按文件名找 `LICEN*` 造成的假阴性，不是许可缺失。写配置骨架时顺带把这条记进包内说明。

## 9. 需要你拍板的事项

1. **`bin/` 里放哪些工具？** 已定：**外部工具都打进 `bin/`**。当前已就位（都经官方 SHA256 校验）：

   | 工具 | 版本 | Windows | Linux | 用途 | 许可 |
   | --- | --- | --- | --- | --- | --- |
   | ripgrep | 15.2.0 | 4.2 MB | 5.4 MB | 搜索核心（需求 4/5） | MIT / Unlicense |
   | fzf | 0.74.5 | 6.2 MB | 5.5 MB | fzf-lua 的后端（需求 4） | MIT |
   | fd | 10.5.0 | 4.1 MB | 3.7 MB | 更快的文件查找 | MIT / Apache-2.0 |
   | stylua | 2.6.0 | 9.1 MB | 10.5 MB | 格式化 Lua | MPL-2.0 |
   | shfmt | 3.14.1 | 3.8 MB | 3.6 MB | 格式化 Shell | BSD-3-Clause |
   | shellcheck | 0.11.0 | **34.8 MB** | 16.2 MB | 检查 Shell | **GPL-3.0（copyleft）** |
   | im-select | master@890b3eb1 | 0.13 MB | —（Linux 用系统 fcitx5-remote/ibus） | Windows 输入法自动切换 | MIT |

   `bin/` 两平台合计约 **102.4 MB**，单个包里只带本平台那一份（约 51 MB）。**`shellcheck` 是最大的一项**（Haskell 静态链接，Windows 版尤其大）。

   **`im-select.exe` 的校验方式与其余不同**：它没有 release 资源，是从仓库 `win/out/x64/` 直接取的裸文件，上游不给 SHA256。脚本因此改用 **git blob 哈希**（`890b3eb1…`，由 GitHub API 提供）校验——这同样能锁到字节级内容，只是校验对象换成了 git 的对象哈希。`manifest.json` 里也记录它的 SHA256 供日后核对。

   两个体积事实值得知道：一是 `shellcheck` 与刚被移除的 `ruff`（51.6 MB）体积几乎一样，所以**换工具没省下体积**；二是**已定每平台一个包**，每个包只背自己那约 51 MB —— 「只打一个包、带两平台二进制」这条已经作废。

   **`shellcheck` 是 `bin/` 里唯一的 copyleft 项**（GPL-3.0），其余都是 MIT / Apache-2.0 / MPL-2.0 / BSD 这类宽松许可。分发含它的包时需附对应源码或书面承诺，并保持与 MIT 配置代码可分离。

   机制上不需要改设计：`vim.env.PATH` 前置 `<distro>/bin`，所有探测走 `vim.fn.executable()`，`bin/manifest.json` 供 `:checkhealth` 与打包脚本读取版本。

   **按决定不打包语言服务器。** `lua-language-server` / `clangd` / `basedpyright` / `bash-language-server` 都由用户自行安装；发行版只探测、不报错，缺失项在 `:checkhealth distro` 里汇总。将来若要加，`bin/` 的注入机制不用改（注意 `lua-language-server` 是**目录结构**而非单文件，需要脚本支持整目录落位）。
2. **要不要引入 lazy.nvim？** 现在方案是零管理器。若你更看重 `:Lazy` 这类管理界面，可以引入，但必须锁死 `install.missing = false`、`rocks.enabled = false`，并用离线包自己生成 lockfile（绝不用在线生成的）。**当前决定：不引入。**
3. ~~图标是否强依赖 Nerd Font？~~ **已定：强依赖**，用户文档里必须写明要装，否则满屏方块。
4. ~~默认主题？~~ **已定**：`tokyonight` 为默认，另留 `catppuccin` / `kanagawa` / `gruvbox-material` / `nightfox` / `rose-pine` 供切换。
5. ~~两个许可待核项？~~ **已定：不用这两个插件**，目录里已移除。

**仍开放的只有两件小事：**

- **Python 工具链**：`bin/` 里没有 Python 格式化 / 检查工具（`ruff` 已按决定移除）。要用就得自己装 `ruff` 或 `black`，或走 LSP 格式化。
- **`luacheck`**：Lua 侧唯一没有随包的工具（`stylua` 已随包）。它没有官方预编译产物，要用得自己装或自己构建——这是目前「Lua 工作流完全自包含」的唯一缺口。
