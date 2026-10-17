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
