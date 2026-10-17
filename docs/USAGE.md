# 使用说明

本文按**你要做的事**组织，而不是按插件列。想知道某个键位在哪，看 [快捷键速查](KEYMAPS.md)（那份是生成的，不会和配置脱节）。

所有插件与工具都已随包分发，**任何操作都不会联网**。

---

## 搜索：两套入口，别搞混

本发行版有两套搜索，它们解决的是不同问题：

| 入口 | 形态 | 什么时候用 |
| --- | --- | --- |
| `<leader>s*` | rg 搜索：`sg` 走 fzf 实时界面，其余进 quickfix **窗口**（按行列出） | 想**看全命中并点击跳转**，或**边打字边筛** |
| `<leader>f*` | fzf-lua 交互界面，边打字边过滤 | 想**快速模糊筛**到某一个结果 |

### `<leader>s*`：rg 搜索（`sg` 实时 / 其余进 quickfix）

| 键位 | 作用 |
| --- | --- |
| `<leader>sg` | 实时 grep（fzf-lua 界面）。边输入边刷新，回车打开所在文件 |
| `<leader>sG` | 输入正则后进 quickfix（适合复杂模式） |
| `<leader>su` | 连被 `.gitignore` 忽略的文件一起搜 |
| `<leader>sw` | 直接搜光标下的单词 |
| `<leader>sf` | 只搜当前文件（大文件时用这个） |
| `<leader>sn` / `<leader>sp` | 在结果间跳下一个 / 上一个 |
| `<leader>sc` | 关闭结果窗口 |

**鼠标双击结果即跳转**——这是需求 5 明确要的，已直接绑在 quickfix 的 `<2-LeftMouse>` 上。

几个实现细节，出了问题好排查：

- **搜索是异步的**：`rg` 在子进程里跑，跑完才把结果填进 quickfix。
  所以按完 `<leader>sG` 之后界面**不会卡住**，你可以继续敲键；
  命令行会显示 `搜索中… <标题>`，完成后提示 `N 处匹配（X ms）`。
  - 结果不是「边搜边出」，而是**跑完一次性填入**（quickfix 本身不支持流式追加）。
  - 搜索期间再按一次搜索键，会**终止上一次**尚未结束的进程 ——
    两次搜索结果抢同一个 quickfix，旧结果没有意义。
  - 曾经用 `vim.fn.systemlist()`（同步），大仓库上表现为「按完假死几秒」，
    已改掉；若你看到卡顿，先确认跑的是不是旧包。
- 搜索由**随包的 rg** 执行（`bin/rg`），不依赖系统安装。
- 参数里带了 `--max-columns=300 --max-columns-preview`。压缩过的 JS、单行 JSON 这类超长行
  只显示摘要，**否则一个小结果就能把界面卡死**。
- 打开大文件时（阈值见 `lua/distro/search.lua`）会自动关掉语法高亮、折叠与 undo，
  并在状态里打标记。这是「大文件工作流」的一部分。
- 如果 rg 不可用，会明确提示而不是假装「没有匹配」。**「找不到 rg」和「搜不到结果」是两件事**，
  不要混。

### `<leader>f*`：fzf-lua

`<leader>ff` 找文件、`<leader>fg` 全项目搜、`<leader>fb` 切缓冲区、`<leader>fr` 最近文件，
其余见 [快捷键速查](KEYMAPS.md)。

fzf 与 fd 都随包分发（`bin/fzf`、`bin/fd`），配置里已**显式指向**它们，
所以不依赖 PATH 上是否装了 fzf。

---

## 中文

这是本发行版区别于其它配置的重点，专门做了三件事：

1. **按词移动对中文生效。** `jieba.vim` 接管 `w` / `b` / `e`，
   中文按分词结果跳，而不是按字节或整段跳。ASCII 仍走 Vim 原本的行为。
2. **字符宽度与终端保持一致**（`ambiwidth=single`）。歧义宽度字符（`─` `…` `▌` 这类）
   按 1 格算，与现代终端（Windows Terminal / Alacritty）的真实渲染一致——
   汉字属于「宽（W）」类，**不受这个设置影响**，中文照常按双宽显示。
   ⚠️ 历史教训：曾用 `ambiwidth=double`，结果引发一整串显示故障
   （`E1512` 报错、符号列撑宽、fzf 界面截断、搜索残留碎片），详见
   [`INSTALL.md` 的字符宽度一节](INSTALL.md#三常见问题)。
3. **输入法自动切换**（`im-select.nvim`）：
   - Windows：用随包的 `bin/im-select.exe`，**开箱可用**
   - Linux：需要系统有 `fcitx5-remote` 或 `ibus`

> 字体要求：本发行版**强依赖 Nerd Font**。状态栏、文件树、诊断图标都用 Nerd Font 字形。
> 如果你的终端里图标显示成方块，装一个 Nerd Font 并在终端里选它。

---

## 代码：LSP

**本发行版不打包语言服务器**（已定），也不用 mason（它没有官方离线模式）。
做法是启动时**探测 PATH**，有就接线，没有就记下来——**缺一个语言服务器不会让编辑器起不来**。

`:checkhealth distro` 会列出缺哪些服务器以及**各自影响什么**。

推荐的服务器（自行安装后重启即可）：

| 语言 | 服务器 | 安装方式提示 |
| --- | --- | --- |
| Lua | `lua-language-server` | 单文件二进制，直接放 PATH |
| C / C++ | `clangd` | 随 LLVM 发布 |
| Python | `basedpyright` 或 `pyright` | 二者只启用一个（优先 basedpyright） |
| Shell | `bash-language-server` | npm |
| JSON / YAML | `vscode-json-language-server` / `yaml-language-server` | npm |

LSP 键位（`gd`、`gr`、`K`、`<leader>ca` 等）只在**支持的文件类型里**生效，
完整列表见 [快捷键速查](KEYMAPS.md) 的「LSP 键位」一节。

---

## 格式化与检查

保存时自动格式化，由 `conform.nvim` 调度。**格式化器是先探测再启用的**：
缺一个只影响那一种语言，不会在保存时报错。

| 语言 | 格式化器 | 是否随包 |
| --- | --- | --- |
| Lua | `stylua` | ✅ `bin/stylua` |
| Shell | `shfmt` | ✅ `bin/shfmt` |
| C / C++ | `clang-format` | ❌ 需自备 |
| Python | `ruff_format` 或 `black` | ❌ 需自备 |

Shell 脚本的静态检查由 `nvim-lint` + 随包的 `bin/shellcheck` 完成。
Lua 的 `luacheck` 没有官方预编译产物，需自行安装或构建——这是「完全自包含 Lua 工作流」
里唯一的口子，已在 `:checkhealth distro` 里注明。

| 键位 | 作用 |
| --- | --- |
| `<leader>fmt` | 手动格式化当前缓冲区 |
| `<leader>ca` | 代码动作 |
| `<leader>ct` | 整理 imports |

---

## 文件、缓冲区与窗口

- `<leader>e` 打开目录编辑（`oil.nvim`：像编辑文本一样改文件名、移动、删除）
- `<leader>xx` 打开诊断列表（`trouble.nvim`），全局与当前文件各一个入口
- `<leader>bd` 关闭缓冲区但**保留窗口布局**（用 mini.bufremove，避免整屏塌掉）
- `<S-h>` / `<S-l>` 切换缓冲区；`<C-h/j/k/l>` 在窗口间移动（`smart-splits`）
- `<leader>ff` 找文件

---

## GUI（Neovide）

终端之外，本发行版也可以用 [Neovide](https://neovide.dev/) 以图形界面运行。
**Neovim 本体不变**——Neovide 只是个前端，插件、LSP、键位全都不受影响。
**外观配置随包分发**：`bin/neovide.toml` 里有初始窗口尺寸与字体回退链
（`FiraCode Nerd Font Mono` → `JetBrainsMono Nerd Font` → `Sarasa Mono SC`，
最后一项是中文字形兜底）。Neovide 自己不会去读 `bin/`，所以 `install.cmd`
会设用户级环境变量 `NEOVIDE_CONFIG` 指向它；`uninstall.cmd` 负责还原。
手动运行（没跑安装脚本）时，可以用 `--config` 或自行设这个变量。

### 前置

**Windows（x64）与 Linux（x64）已经随包带了 Neovide**，在 `bin/` 下，开箱即用。
其余平台需要自行安装（见下）。

自行安装时：

- Windows：装官方 `neovide.msi`，或 `scoop install neovide`
- Linux：发行版仓库或 [releases](https://github.com/neovide/neovide/releases)
- macOS：只能自装（官方只发布 `.dmg`，无法像单文件工具那样塞进 `bin/`）

启动器查找顺序：`NEOVIDE_EXE` → 随包 `bin/` → PATH。所以**随包那份优先于你系统里装的**。

### 各平台的随包情况

| 平台 | 随包 Neovide | 说明 |
| --- | --- | --- |
| Windows x64 | ✅ `bin/neovide.exe` | 官方产物是单个裸 exe，无伴随目录 |
| Linux x64 | ✅ `bin/neovide` | 官方产物是单个裸二进制 |
| Linux arm64 | ❌ | 上游**没有** arm64 产物 |
| macOS arm64 | ❌ | 上游只发布 `.dmg`（`tar` 处理不了） |

后两个平台启动器会明确报错并提示装法，`:checkhealth distro` 也会说明，
**不影响终端模式**——`nvim` 照常可用。

### 为什么随包的是 Neovide **nightly** 而不是稳定版

这是实测结论，不是偷懒：**Neovide 稳定版 0.16.2（当前最新）解析不了
nvim 0.13 nightly 的 `nvim_get_api_info`**，一启动就报

```
Failed to launch neovim runtime: Failed to parse Neovim api information
Caused by: Invalid parameter
```

关键证据：拿**裸 nvim**（完全不加载本发行版配置）同样失败，说明与我们的配置无关，
纯粹是 Neovide 与 nvim 0.13 的 API 元数据不兼容。同一台机器上换 Neovide nightly
立即正常。

本项目目标就是 nvim 0.13 nightly，所以只能配 Neovide nightly。代价是它是滚动产物
（不可按 tag 复现）；`bin/manifest.json` 里记录了下载时的 `sha256`，
可用来确认「这份包里的 Neovide 到底是哪个构建」。

### 启动

**Windows：直接开 `bin\neovide.exe`，或双击任意已关联的 `.md` 文件。**

`neovide.exe` 是图形程序，**本身不分配控制台窗口** —— 因此不需要任何
`.cmd` / `.vbs` 包装脚本来隐藏窗口（那几个脚本已删除）。
先跑一次 `install.cmd`，它会把 `<包>\bin` 加进 PATH 并把 `.md` 等扩展名
关联到 Neovide；之后终端里直接敲 `neovide` 也可以。

```powershell
neovide                          # 走 PATH（install.cmd 已加）
.\bin\neovide.exe                # 或直接指到包里
.\bin\neovide.exe docs\USAGE.md
```

```sh
# Linux / macOS：上游没有随包产物，自行安装后用同名命令
neovide docs/USAGE.md
```

### 配置怎么被发现（没有启动器之后）

旧方案靠启动器设环境变量；现在改成 `install.ps1` 写**用户级环境变量**，
所以不包装脚本也能做到隔离：

| 事项 | 由谁负责 |
| --- | --- |
| 找得到 `nvim` / `neovide` | 用户 PATH 加入 `<包>\bin` 与 `<包>\runtime\bin` |
| 配置发现（`init.lua`） | `%LOCALAPPDATA%\nvim` → 指向包的 junction |
| 状态与会话 | 用户级 `XDG_STATE_HOME` / `XDG_CACHE_HOME` 指向包内 `.local\` |
| **GUI 外观** | Neovide 自己的 `%APPDATA%\neovide\config.toml`（发行版不随包分发） |

> ⚠️ 所以**必须跑过 `install.cmd`**。不跑的话以上变量都不存在，只能手工
> `bin\neovide.exe`，那时它会去找你 `%APPDATA%\nvim` 下的配置，而不是包里这份。

### 外观配置

GUI 外观在 Neovide 自己的配置里（`%APPDATA%\neovide\config.toml`）：初始窗口尺寸
（`maximized`）、字体与中文回退链、框线风格。

**只把文件放进 `bin/` 不会生效。** Neovide 只读 `%APPDATA%\neovide\config.toml`
`bin/` 在 PATH 上只解决「能不能找到 `neovide.exe`」；外观配置在 Neovide 自己的目录里。
需要改外观时直接编辑 Neovide 的 `config.toml`，
不会写进你自己的 `%APPDATA%\neovide\config.toml`。

两个字体相关的坑（都踩过）：

> ⚠️ 默认字体不含中文字形。可在 `%APPDATA%\neovide\config.toml` 里配回退链
> （Sarasa Mono SC → 新宋体 → Microsoft YaHei UI）。**如果这些你机器上都没有**，
> 中文会显示成方块或字间出现空隙。换成你实际装了的等宽中文字体即可。
> 查证方法：`neovide --log`，看 `Some configured fonts could not be loaded`
> 那一行列了哪些族名 —— 列了本机没有的字体时，Neovide 只会静默退回内置字体。

> ⚠️ 加回退**只能**用 `[[font.normal]]` 数组表逐条写，不能同时出现
> `normal = ["..."]` —— 那是 TOML 的 `duplicate key`，Neovide 会**整份配置作废**
> 并静默退回默认（表现就是中文成方块、字号也不对）。

> ⚠️ `size` 的单位是**物理像素**：在 150% 缩放的屏上写 `size = "1400x900"`
> 实际只得到 933×600，看着仍然很小。所以默认用 `maximized = true`；
> 要固定尺寸请按「期望逻辑尺寸 × 缩放比例」换算，或用 `grid`（按字格算）。

编辑器侧的行为（光标动画、缩放等）**不再写在 `lua/distro/options.lua` 里**：
那里的 `if vim.g.neovide` 分支在 init 阶段永远为假（Neovide 是连接后才经 RPC
设这个变量），留着只会变成静默死代码。需要在 GUI 里生效的运行时设置应挂
`UIEnter` 自动命令。

### 排错

| 现象 | 原因 / 处理 |
| --- | --- |
| 终端里 `neovide` 找不到 | 没跑 `install.cmd`，或 PATH 未刷新（重开终端） |
| 中文全是方块 / 字间有空隙 | `%APPDATA%\neovide\config.toml` 里的回退字体本机没有；用 `neovide --log` 查 |
| 窗口很小、不像最大化 | Neovide 的 `config.toml` 没配（或位置不对，见上面） |
| 启动后是「裸 Neovim」 | `%LOCALAPPDATA%\nvim` junction 不存在或不指向本包 |
| 双击 `.md` 没反应 | 文件关联没注册；重跑 `install.cmd` |

---

## 会话

`mini.sessions` 已启用，会话文件放在发行版自己的 `stdpath('state')/sessions` 下，
**不会污染**你机器上其它 Neovim 配置的会话。

---

## 关于「没看到某个功能」

本发行版用 `pack/*/start` + `pack/*/opt` 实现加载，**没有插件管理器**。

- `start/` 里的插件在启动时加载（这是大多数）
- `opt/` 里的插件是**真正的懒加载**：按下对应键位之前，它连 `runtimepath` 都不进
  （例如 `<leader>e` → oil、`<leader>sr` → grug-far）

所以「启动很慢」通常不是插件太多，而是某个 start 插件在启动时做了重活。
用 `:StartupTime`（随包带了 `vim-startuptime`）看明细。

`:checkhealth distro` 会一次性列出：缺哪些随包工具、缺哪些语言服务器、
哪些 vendor 的插件没落盘、tree-sitter 解析器数量，以及三个**联网风险项**的产物是否就位
（blink 的原生库、jieba 的 cdylib、tree-sitter 解析器）。

---

## 现在能做什么（11 个配置分组全部已接线）

| 你要做的事 | 入口 | 背后是谁 |
| --- | --- | --- |
| 全项目搜索，结果按行进窗口、可点击跳转 | `<leader>s*` | 随包 `rg` + quickfix |
| 模糊查找文件/内容 | `<leader>f*` | `fzf-lua` + 随包 `fzf`/`fd` |
| 补全与片段 | 插入模式自动 | `blink.cmp` + `LuaSnip` + `friendly-snippets` |
| 语法高亮 / 折叠 / 缩进 | 打开文件即生效，`za`/`zc` 折叠 | `nvim-treesitter`（解析器随包） |
| 按语法节点选择与跳转 | `af` `if` `ac` `ic` `aa` `ia`、`]]` `[[` | `nvim-treesitter-textobjects` |
| **中文按词移动** | `w` `b` `e` | `jieba.vim`（cdylib 随包） |
| **输入法自动切换** | 自动（进出插入模式） | `im-select`（Windows 用随包 exe；Linux 用 fcitx5/ibus） |
| LSP 补全 / 跳转 / 重命名 | `gd` `gr` `K` `<leader>rn` `<leader>ca` … | 内置 LSP + `nvim-lspconfig` |
| 诊断列表 | `<leader>xx` `<leader>xX` `<leader>xs` | `trouble.nvim`（懒加载） |
| 格式化 | 保存时自动，`<leader>fmt` 手动 | `conform.nvim` |
| 静态检查 | 保存、离开插入模式时自动 | `nvim-lint`（`shellcheck` 随包） |
| Git 标记与逐块操作 | `]c` `[c`、`<leader>gs/gr/gp/gb/gd` | `gitsigns.nvim` |
| Git 面板 / 差异 / 历史 | `<leader>gg` `<leader>gc` `<leader>gD` `<leader>gh` | `neogit` / `diffview`（懒加载） |
| 目录编辑（像编辑文本一样改文件名） | `<leader>e` 或 `-` | `oil.nvim`（懒加载） |
| 撤销历史可视化 | `<leader>uU` | `undotree`（懒加载） |
| TODO / FIXME 汇总 | `<leader>xt` `<leader>xq`、`]T` `[T` | `todo-comments.nvim` |
| Markdown 渲染 | 打开 `.md` 即生效 | `render-markdown.nvim` |
| 启动耗时明细 | `<leader>ut` | `vim-startuptime`（懒加载） |
| 固定显示当前函数/类头部 | `<leader>uc` | `treesitter-context`（懒加载） |
| 同一符号的所有引用高亮 | 光标停留即生效，`]r`/`[r` 跳转 | `vim-illuminate` |

完整键位见 [快捷键速查](KEYMAPS.md) —— 那份是**由配置生成的**，不会与实际脱节。

## 仍然需要自备的

语言服务器与少数检查器按决定**不打包**：

`lua_ls`、`clangd`、`basedpyright`/`pyright`、`bash-language-server`、`jsonls`、`yamlls`；
以及 `luacheck`（无官方预编译产物）、`clang-format`、`clang-tidy`、`ruff`。

缺了不影响启动，`:checkhealth distro` 会列出缺哪些以及各自影响什么。
