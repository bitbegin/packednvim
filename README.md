# 自制 Neovim 发行版

目标是做一个**自包含、运行时零联网**的 Neovim 发行版：Neovim 本体、插件、命令行工具、
预编译的 tree-sitter 解析器全部随包分发，解压即用。当前出 4 个平台 ——
Linux x64 / Linux arm64 / Windows x64 / macOS Apple Silicon。

## 当前状态

| 部分 | 状态 |
| --- | --- |
| 插件选型目录（206 条 / 24 分类） | ✅ 已按七步决策收敛，当前套用 `recommended`（44 个插件） |
| 架构设计与调研记录 | ✅ 已完成 |
| 需求 5 搜索工作流 | ✅ 已实现并实测通过 |
| 随包分发的命令行工具 | ✅ 6 个（`rg` / `fzf` / `fd` / `stylua` / `shfmt` / `shellcheck`），由 CI 按平台现取、**不进版本库**；`im-select.exe` 例外保留（上游产物名不含平台信息，无法可靠匹配） |
| Neovim 本体 | ✅ **随包分发**（`runtime/`）。包里的 tree-sitter 解析器就是由它亲自编译的，所以 ABI 不会失配 —— 见 [`docs/INSTALL.md`](docs/INSTALL.md) 原理 11 |
| 插件 vendoring（`tools/vendor.ps1`） | ✅ 已执行：45/45 成功，`vendor/lock.json` 锁定每个仓库的 commit |
| GitHub Actions 自动打包发布 | ✅ 已跑通：4 个平台各出一个完整包，发到 Release（tag = `main+<UTC时间戳>+<短hash>`） |
| 预置「编译/下载」风险项的产物 | ✅ 已跑通并实测：blink 原生库、jieba cdylib、21 个 tree-sitter 解析器都在包里 |
| 配置骨架（11 个分组） | ✅ 已完成：`theme` `mini` `ui` `search` `syntax` `complete` `git` `edit` `lang` `zh` `misc` |

跑测试（会真正调用 `rg`，所以需要能创建子进程的环境）：

```bash
pwsh -File tests/run.ps1     # Windows
./tests/run.sh               # Linux
```

## 已确认的约束

| 项目 | 你的选择 |
| --- | --- |
| 目标平台 | **4 个平台各出一个包**：`linux64` / `linux-arm64` / `win64` / `darwin-arm64`。不出 `win-arm64`（上游有 3 个工具没有 Windows arm64 产物）与 macOS Intel（对应托管 runner 不可用） |
| Neovim 版本 | **0.13 nightly**：CI 取最新一份并**打进包里**；当前是 `v0.13.0-dev-1828+g7e1ae5115f` |
| 打包范围 | 每个包自带该平台的 Neovim、6 个命令行工具、预编译的 tree-sitter 解析器、以及两个插件的原生库 |
| 离线要求 | 运行时零联网安装、零联网运行；插件全部随包分发 |
| 搜索能力 | **必须可用**：`rg` 全文搜索 + `fzf` 或 `telescope` 模糊查找（需求 4） |
| 大文件搜索 | **必须可用**：正则搜索 + 结果按行显示在独立窗口 + 点击跳转；禁用内置 `:vimgrep`（GB 级文件会卡死），走外部 `rg` + quickfix（需求 5） |
| 打包方式 | **每个平台一个包**（原「只打一个包、内含两平台二进制」已作废 —— 那样每个包都要带一半用不到的东西） |
| 用途 | 通用为主，另加 Lua/Neovim 配置开发、C/C++/嵌入式、Python、写作与 Markdown、运维与 Shell |

**已定细节**：搜索结果窗口**双击跳转**（单击只移动光标）；默认 picker 用 **`fzf-lua`**，故 `fzf` 二进制随包分发。见 [`docs/SEARCH-WORKFLOW.md`](docs/SEARCH-WORKFLOW.md)。

## 先看这两个结论

调研后有两个决策会直接影响你勾选时的心态，先说清楚：

1. **不装插件管理器。** 插件直接放 `pack/distro/start/`（自动加载）和 `pack/distro/opt/`（按需 `:packadd`），这是 Neovim 内置机制。管理器的核心职责是「从网络拉取并锁定版本」，而你的要求是零联网，这个职责本身就消失了；剩下的「按需加载」内置能力已经够用。附带好处：**没有管理器就没有 `build` 钩子**，从机制上消灭了「首次启动偷偷编译」这一整类事故。
2. **不装 mason.nvim。** 它没有官方离线模式（注册表刷新、所有安装动作都走网络），`mason-lspconfig` 还只认自己装的服务器。离线方案是 `vim.lsp.config{cmd=...}` + `vim.env.PATH`。

## 插件选型：已按七步决策收敛完成

候选目录有 206 条，但**不需要你从 206 里挑**。按 [`docs/CHOOSING.md`](docs/CHOOSING.md) 的七步决策，每个互斥格已经收敛成一个答案，理由逐条写在 [`docs/DECIDED.md`](docs/DECIDED.md)，数据在 [`catalog/STACKS.toml`](catalog/STACKS.toml)。

**已套用 `recommended`：63 条 / 45 个仓库**（候选池是 206 条 / 174 个仓库）。切换只需一条命令，勾选状态会整体重写：

```bash
python tools/parse_selection.py --stack minimal     --apply   # 45 条 / 24 仓库，最轻
python tools/parse_selection.py --stack recommended --apply   # 63 条 / 45 仓库（当前）
python tools/parse_selection.py --stack full        --apply   # 107 条 / 87 仓库，全功能
python tools/parse_selection.py --overview                    # 重新生成速查表
python tools/check-stack.py                                   # 校验方案里没有同格多选
```

解析器会打印**随包工具已覆盖哪些命令**、**还需目标机器自备哪些**、**哪几项必须先预置编译产物**——这三份清单就是发行版的前置条件。

要微调就直接改 [`catalog/PLUGIN-CATALOG.md`](catalog/PLUGIN-CATALOG.md) 里的 `- [ ]`，或对着自动生成的速查表 [`catalog/OVERVIEW.md`](catalog/OVERVIEW.md) 增删。

下一步（等你说开始）：按选定清单写 vendoring 脚本、生成配置骨架、预置那三个「编译/下载」风险项的产物。

## 文档

| 文件 | 内容 |
| --- | --- |
| [`catalog/PLUGIN-CATALOG.md`](catalog/PLUGIN-CATALOG.md) | 插件选型目录（唯一数据源） |
| [`catalog/STACKS.toml`](catalog/STACKS.toml) | 三套已决策方案的显式清单（`minimal` / `recommended` / `full`） |
| [`catalog/OVERVIEW.md`](catalog/OVERVIEW.md) | 自动生成的 206 条速查表 |
| [`docs/CHOOSING.md`](docs/CHOOSING.md) | **怎么选**：重叠分析、29 处互斥格、七步决策顺序 |
| [`docs/DECIDED.md`](docs/DECIDED.md) | **已决策**：逐格答案与依据，以及还需你拍板的事项 |
| [`catalog/README.md`](catalog/README.md) | 目录的图例、行格式规范、依赖分级说明 |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | 离线发行版架构设计：目录布局、单包策略、零联网的保证与验证、tree-sitter 解析器方案、LSP 方案、Win/Linux 差异、打包流程 |
| [`docs/INSTALL.md`](docs/INSTALL.md) | **安装说明 + 安装原理**：前置条件、解压启动、验证与卸载；以及九条「不这么做就会出问题」的实测结论（packpath、XDG 隔离、解析器挂载、cmd 只认 ASCII 等） |
| [`docs/USAGE.md`](docs/USAGE.md) | **怎么用**：按「要做的事」组织（搜索 / 中文 / LSP / 格式化 / 文件 / 会话），含缺失工具的影响 |
| [`docs/KEYMAPS.md`](docs/KEYMAPS.md) | **快捷键速查**：由 `tools/gen-keymaps.py` 对比「干净 Neovim vs 本发行版」生成，不会与配置脱节 |
| [`docs/SEARCH-WORKFLOW.md`](docs/SEARCH-WORKFLOW.md) | 需求 5 的完整方案：`grepprg` 配置、quickfix 鼠标跳转映射、大文件降级代码、rg 与 fzf-lua 两条路线的取舍 |
| [`docs/RESEARCH-NOTES.md`](docs/RESEARCH-NOTES.md) | 调研原始事实与来源：版本代际、管理器对比、依赖矩阵、可移植二进制来源、离线翻车清单 |
| [`bin/README.md`](bin/README.md) | 随包分发的工具：版本、SHA256、许可证、注意事项 |
| [`tools/`](tools) | `parse_selection.py`（选型解析）、`check-stack.py`（互斥格校验）、`verify-repos.py`（核验地址）、`verify-binaries.py`（校验 bin/ 完整性）、`vendor.ps1`（拉取插件）、`harvest.lua`（CI 分平台采集预编译产物）、`fetch-binaries.ps1`（取工具） |
| [`.github/workflows/release.yml`](.github/workflows/release.yml) | CI：拉插件 → 两平台各采集一次产物 → 汇总成一个包 → 发 Release |

## 已定 vs 待定

**已定：**

1. **外部工具由 CI 按平台现取。** 每个平台 6 个：`rg`、`fzf`、`fd`、`stylua`、`shfmt`、`shellcheck`；另有 `im-select.exe` —— 它是**唯一留在版本库里**的二进制，因为上游产物名不含平台信息、无法可靠匹配，而它只有约 200 KB 且只在 Windows 需要。**`bin/` 其余内容不进版本库**：6 个平台的二进制上百 MB，而 git 历史不会因为后来的删除而变小。`ruff` 按决定移除。
2. **语言服务器暂不打包。** 由用户自行安装，发行版只探测、不报错，缺失项在 `:checkhealth distro` 汇总。
3. **图标强依赖 Nerd Font。** 用户文档里必须写明要装，否则满屏方块。
4. **搜索双击跳转**、**默认 picker 用 `fzf-lua`**（见 [`docs/SEARCH-WORKFLOW.md`](docs/SEARCH-WORKFLOW.md)）。
5. **主心骨用 mini**（`snacks.nvim` 不选）。
6. **保留 6 个主题**：`tokyonight`（默认）、`catppuccin`、`kanagawa`、`gruvbox-material`、`nightfox`、`rose-pine`。
7. **方案选 `recommended`**：62 项 / 44 个插件。
8. **每个平台一个包**，各自带该平台的 Neovim 本体、命令行工具、tree-sitter 解析器与插件原生库。原「只打一个包、内含两平台二进制」已作废 —— 那样每个包都要带一半用不到的东西。
9. **两个许可待核项不用**：`nvim-tree/nvim-tree.lua`（API 报 NOASSERTION）与 `romgrk/barbar.nvim`（无 LICENSE 文件）已从目录删除，条目数 208 → 206。
10. **不做 Python 工具链。**

**待定：**

1. **`luacheck`**：Lua 侧唯一没有随包的工具（`stylua` 已随包）。它没有官方预编译产物，要随包得自己构建——这是「Lua 工作流完全自包含」的唯一缺口。
2. **Python 工具链**已按决定留空；日后想要可以加回 `ruff` 或 `black`。

## 环境备注

- **Neovim 已装好可直接用**：`D:\tools\nvim-win64\bin\nvim.exe`，`NVIM v0.13.0-dev-1828+g7e1ae5115f`，已在 PATH 上，敲 `nvim` 即是这一份。安装目录里的 `bin/nvim.pdb` 是 17.5 MB 调试符号，删掉不影响运行。
- **nightly 是滚动标签**，每次重建都换 commit。`docs/ARCHITECTURE.md` 第 5 节讲过解析器 ABI 与 Neovim 版本强耦合，所以**每次更新 nightly 都要重跑解析器构建**，否则症状是「高亮突然全没了」而且不报错。
- **git 代理已修正**为 `http://127.0.0.1:7892`，与系统代理一致，vendoring 可用。
- 你的代理会间歇性拒绝 TLS 握手，也会中途断流，所以 `tools/fetch-binaries.ps1` 用的是「限时重试 + 断点续传」，而不是 `curl --retry`（`--retry` 对「传输停滞」不生效）。
- 受限模式下有两个限制：Windows 的 TLS 凭据被拒绝（`schannel: SEC_E_NO_CREDENTIALS`），任何联网命令都要放行；Neovim 也无法创建子进程，所以 `tests/run.ps1` 必须在放行后或沙箱外运行。
