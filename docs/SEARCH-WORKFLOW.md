# 大文件搜索工作流

需求 5 拆成四件事，必须同时满足：

1. 能搜大文件（GB 级）
2. 支持正则
3. 结果按行显示在一个独立窗口里
4. **点击结果能跳到对应位置**

## 先说唯一的硬约束

**不能用 Neovim 内置的 `:vimgrep`，也不能用 `:grep` 的默认实现。**

| 方案 | 问题 |
| --- | --- |
| `:vimgrep` | 把整个文件读进内存再逐行匹配。GB 级文件会吃光内存并卡死，这是最典型的踩坑点 |
| `:grep` 默认 | 调外部 `grep`，输出不带列号，quickfix 跳不准，且没有 ignore 规则 |
| **外部 `rg`** | 流式扫描 + 内存映射，输出 `file:line:col:text` 天然「按行」，且不会把整个文件留在内存里 |

所以骨架一定是 `rg` + quickfix。需求 4 已经把 `rg` 定为随包分发，这里正好复用。

## 让 `:grep` 走 rg

```lua
vim.o.grepprg = 'rg --vimgrep --no-heading --smart-case --hidden --glob=!.git/*'
vim.o.grepformat = '%f:%l:%c:%m'
```

`--vimgrep` 是必须的：普通 `-n` 输出不带列号，quickfix 只能跳到行首，跳转精度不够。

## 四条需求分别怎么落地

| 需求 | 落地方式 |
| --- | --- |
| 大文件 | rg 流式扫描；quickfix 里只存结果条目，不把文件内容读进内存。**只有你按 `<CR>` 或点击时，Neovim 才真正打开那个文件**——这一步的代价见最后一节 |
| 正则 | rg 用的就是 Rust regex 语法，`:grep 'pattern'` 直接传正则。需要环视、反向引用等 PCRE 特性时加 `--pcre2` |
| 按行显示在窗口里 | quickfix 列表（`:copen`）天然一行一条，独立窗口，`:cnext` / `:cprev` 串行浏览，`:cdo` 批量处理 |
| 点击跳转 | 三段配置，纯内置，不需要插件（见下） |

### 点击跳转的三段配置

Neovim 的 quickfix 窗口默认只支持 `<CR>`；鼠标点击只会移动光标。补一条映射即可：

```lua
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'qf',
  callback = function()
    -- 双击 = 跳转；单击保留为「移动光标」，方便你先浏览结果
    vim.keymap.set('n', '<2-LeftMouse>', '<2-LeftMouse><CR>', { buffer = true })
    -- 想单击直接跳，就把这行换成： <LeftMouse> -> <LeftMouse><CR>
  end,
})
```

前提是 `mouse` 包含 `n`（默认 `mouse=a` 已包含）。这里推荐**双击**而不是单击：单击跳走会让你没法用鼠标选中结果行。

## 交互更好的备选：fzf-lua

`ibhagwan/fzf-lua` 的 `grep_lgrep` / `lgrep_curbuf` 路线：

- 结果在浮动窗口里按行列出
- **fzf 原生支持鼠标**：单击移动、双击打开 → 「点击跳转」直接满足，一行映射都不用写
- 带预览窗口，跳过去之前就能看到上下文

代价有两个：多一个 `fzf` 二进制（约 2.3 MB，需求 4 已决定随包分发）；结果不在 quickfix 里，因此不能 `:cnext` 串行浏览，也不能 `:cdo` 批量改写。

**取舍建议**：quickfix 路线适合「搜完要批量处理」，fzf-lua 路线适合「搜完跳过去看一眼」。两条都留着，用不同键位触发，互不冲突。

关于 `telescope.nvim`：它也能做，`live_grep` 依赖 rg；但结果窗口的鼠标支持不如 fzf 原生，「点击跳转」这一条要额外处理。如果你最终选了 telescope，`<CR>` 跳转是开箱可用的，鼠标这条需要自己补。

## 单文件超大日志的专门处理

「搜一个 2 GB 的日志文件」和「搜一个项目」是两件事。

只搜当前文件、不递归：

```vim
:grep! --no-heading -n <pattern> %
```

`<pattern>` 是正则，可以带 `\v`、`--pcre2` 等 rg 参数。

真正要小心的是**跳转那一步**：`<CR>` 会把那个大文件读进缓冲区，此时高亮、LSP、折叠、undo 文件都会变成负担。一个可用的降级组合：

```lua
vim.api.nvim_create_autocmd('BufReadPre', {
  callback = function(args)
    local ok, size = pcall(vim.fn.getfsize, args.file)
    if ok and size > 2 * 1024 * 1024 then   -- 2 MB 起降级，阈值按需调
      vim.b[args.buf].bigfile = true
      vim.opt_local.undofile = false        -- 超大文件的 undo 文件写入极慢
      vim.opt_local.foldmethod = 'manual'
      vim.opt_local.spell = false
      vim.opt_local.syntax = ''             -- 关语法高亮
      vim.opt_local.synmaxcol = 200
    end
  end,
})
```

然后在 LSP 的 `on_attach` 与 treesitter 的启动条件里判断 `vim.b.bigfile`，命中就跳过。

另外搜索时加 `--max-columns=300 --max-columns-preview`：日志里一行几 MB 是常态，不加这个限制，quickfix 会被超长行拖垮。

现成插件做同一件事：`folke/snacks.nvim` 的 `bigfile` 模块、`LunarVim/bigfile.nvim`、`ouuan/nvim-bigfile`（后两个都已停更但可用）。懒得自己写就用 snacks。

## 需求 5 对应的插件

| 插件 | 在需求 5 里的角色 | 依赖 | 档位 |
| --- | --- | --- | --- |
| *（内置）* | `grepprg` + quickfix + 三段映射，**骨架** | 仅需 `rg` | core |
| `stevearc/quicker.nvim` | 增强 quickfix：可编辑、显示上下文行、预览 | 纯 Lua | ide |
| `ibhagwan/fzf-lua` | 浮动窗口结果 + 原生鼠标双击跳转 + 预览 | `fzf` + `rg` | ide |
| `folke/snacks.nvim` | picker 的 grep；`bigfile` 模块负责大文件降级 | 纯 Lua | ide |
| `MagicDuck/grug-far.nvim` | 正则搜索**并替换**，结果在独立缓冲区 | `rg` | ide |
| `nvim-pack/nvim-spectre` | 同上，另一套交互 | `rg` | extra |
| `nvim-telescope/telescope.nvim` | 若选它作默认 picker，`live_grep` 提供正则搜索 | `rg` | core |
| `LunarVim/bigfile.nvim` / `ouuan/nvim-bigfile` | 打开大文件时自动降级 | 纯 Lua | extra |

## 已定（2026-10-11）

1. **点击跳转用双击。** 单击保留为「移动光标」，方便先用鼠标浏览结果行，只有双击才跳转，避免手滑跳走。
2. **默认 picker 用 `fzf-lua`。** 因此 `fzf` 二进制随包分发（约 2.3 MB），与 `rg` 一起放进 `bin/`。

## 已实现并验证

实现：[`lua/distro/search.lua`](../lua/distro/search.lua)
测试：[`tests/test_search.lua`](../tests/test_search.lua) —— 27 项断言，在 `nvim v0.13.0-dev-1828` 上全部通过。

```bash
pwsh -File tests/run.ps1     # Windows
./tests/run.sh               # Linux
```

实现里比上面的设计多了几处，都是有原因的：

- **搜索不经过 shell**：用 `systemlist({列表})` 直接起进程，所以正则里的引号、反斜杠、`|` 都不需要转义，Windows 上尤其省心。
- **默认按行去重**：`--vimgrep` 是「每处匹配一行」，一行 5 处匹配就给 5 条。去重后只留第一条（列号最小），这正对应「结果按行显示」，日志场景也不会把结果窗口撑爆。想保留每处匹配就把 `dedupe` 关掉。
- **`shell_error < 0` 会报错而不是「无匹配」**：进程根本没起来（rg 不在、权限被拒）和「真的没搜到」是两回事，吞掉前者会让人白找半天。
- **大文件降级要挂在 `Syntax` 事件上**：只在 `BufReadPre` 里清 `syntax` 没用，文件读完后的文件类型检测会再把语法加载回来。测试里专门用「小文件有高亮 / 大文件没高亮」做了对照。

### 键位

| 键位 | 行为 |
| --- | --- |
| `<leader>sg` | 实时模糊搜索（浮动窗口，鼠标双击即跳）。装了 `fzf-lua` 就用它，否则退回 quickfix |
| `<leader>sG` | 正则搜索进 quickfix，可按行串行浏览、可 `:cdo` 批量处理 |
| `<leader>su` | 同上，但连被 .gitignore 忽略的文件一起搜 |
| `<leader>sf` | 只搜当前文件（大日志场景） |
| `<leader>sw` | 搜光标下单词（按字面量匹配） |
| `<leader>sn` / `<leader>sp` | 下一个 / 上一个结果 |
| `<leader>sc` | 关闭结果窗口 |
| `<leader>sr` | 搜索并替换（`grug-far.nvim`，已接入） |

### 环境限制

这个测试**真正调用 rg（子进程）**，所以必须在能创建子进程的环境里跑。在受限沙箱内 Neovim 会 spawn 失败（`shell_error = -1`），测试会失败——那是环境限制，不是发行版的问题。
