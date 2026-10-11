# 快捷键速查

> **本文件由 `tools/gen-keymaps.py` 生成，请勿手改。**
> 它与配置不可能脱节：脚本分别用 `-u NONE`（干净 Neovim）与 `-u init.lua`（本发行版）
> 导出全部键位后取差集，得到的就是本发行版实际新增/改写的键位。
> 改完配置重跑 `python tools/gen-keymaps.py` 即可刷新。

只列**全局**键位。插件在自己缓冲区里建的内部键位（fzf-lua 的 picker 界面、
mini.starter 的启动页等）不算「你会按的键」，所以不在下表 —— 那些键位在对应界面里
按 `?` 或看界面底部提示即可。LSP 的缓冲区键位单独列在最后。

作为对照：干净 Neovim 的全局键位共 70 条（都是内置默认）。

「说明」一列来自每个键位的 `desc`。本发行版要求所有自建键位都写 `desc`，
所以 which-key 的提示与本文档用的是同一份文字，不会各说各话。

## 前导键

前导键是 <kbd>空格</kbd>（`vim.g.mapleader = ' '`）。按前导键后稍等，
`which-key` 会弹出下一步可选键位。

### `<leader>b` —— 缓冲区

| 键位 | 模式 | 说明 |
| --- | --- | --- |
| `<leader>bd` | 普通 | 关闭当前缓冲区（保留窗口） |

### `<leader>f` —— 查找（fzf-lua 交互选择器）

| 键位 | 模式 | 说明 |
| --- | --- | --- |
| `<leader>f/` | 普通 | 当前文件内搜索行（fzf） |
| `<leader>fD` | 普通 | 全项目诊断（fzf） |
| `<leader>fG` | 普通 | 搜索光标下的词（fzf） |
| `<leader>fS` | 普通 | 全项目符号（fzf） |
| `<leader>fb` | 普通 | 切换缓冲区（fzf） |
| `<leader>fc` | 普通 | 可用命令（fzf） |
| `<leader>fd` | 普通 | 当前文件诊断（fzf） |
| `<leader>ff` | 普通 | 查找文件（fzf） |
| `<leader>fg` | 普通 | 全项目搜索（fzf 交互） |
| `<leader>fh` | 普通 | 帮助标签（fzf） |
| `<leader>fk` | 普通 | 查看键位（fzf） |
| `<leader>fm` | 普通 | 标记（fzf） |
| `<leader>fr` | 普通 | 最近文件（fzf） |
| `<leader>fs` | 普通 | 当前文件符号（fzf） |

### `<leader>g` —— Git

| 键位 | 模式 | 说明 |
| --- | --- | --- |
| `<leader>gq` | 普通 | 重排当前段落 |

### `<leader>m` —— 消息与命令行

| 键位 | 模式 | 说明 |
| --- | --- | --- |
| `<leader>m` | 普通 | 查看消息 |

### `<leader>p` —— 粘贴

| 键位 | 模式 | 说明 |
| --- | --- | --- |
| `<leader>p` | 可视 | 粘贴且不覆盖寄存器 |

### `<leader>q` —— 退出

| 键位 | 模式 | 说明 |
| --- | --- | --- |
| `<leader>qq` | 普通 | 退出全部 |
| `<leader>qw` | 普通 | 保存并退出全部 |

### `<leader>s` —— 搜索（rg + quickfix 工作流）

| 键位 | 模式 | 说明 |
| --- | --- | --- |
| `<leader>sG` | 普通 | 搜索：正则进 quickfix |
| `<leader>sR` | 普通 | 全项目替换（grug-far） |
| `<leader>sc` | 普通 | 搜索：关闭结果窗口 |
| `<leader>sf` | 普通 | 搜索：仅当前文件（大文件） |
| `<leader>sg` | 普通 | 搜索：实时 grep（fzf-lua，鼠标双击即跳） |
| `<leader>sn` | 普通 | 搜索：下一个结果 |
| `<leader>sp` | 普通 | 搜索：上一个结果 |
| `<leader>sr` | 普通 | 全项目替换（grug-far） |
| `<leader>su` | 普通 | 搜索：连被忽略的文件一起搜 |
| `<leader>sw` | 普通 | 搜索：光标下单词 |

### `<leader>u` —— 杂项

| 键位 | 模式 | 说明 |
| --- | --- | --- |
| `<leader>ur` | 普通 | 重载当前文件 |

### `<leader>w` —— 窗口

| 键位 | 模式 | 说明 |
| --- | --- | --- |
| `<leader>wo` | 普通 | 只保留当前窗口 |
| `<leader>ws` | 普通 | 水平分屏 |
| `<leader>wv` | 普通 | 垂直分屏 |

### `<leader>y` —— 复制

| 键位 | 模式 | 说明 |
| --- | --- | --- |
| `<leader>y` | 普通 | 复制到系统剪贴板 |
| `<leader>y` | 选择 | 复制到系统剪贴板 |
| `<leader>y` | 可视 | 复制到系统剪贴板 |

### 其它前导键

| 键位 | 模式 | 说明 |
| --- | --- | --- |
| `<leader>:` | 普通 | 命令行历史（可编辑） |
| `<leader>Y` | 普通 | 复制整行到系统剪贴板 |

## 直接键位（不经前导键）

| 键位 | 模式 | 说明 |
| --- | --- | --- |
| `"` | 插入 | Closeopen action for '""' pair |
| `'` | 插入 | Closeopen action for "''" pair |
| `(` | 插入 | Open action for "()" pair |
| `)` | 插入 | Close action for "()" pair |
| `-` | 普通 | Open parent directory |
| `;` | 普通/可视/操作符待决 | Repeat jump |
| `<BS>` | 插入 | MiniPairs <BS> |
| `<C-C>` | 插入 | 退出插入模式 |
| `<C-D>` | 普通 | 下半页并居中 |
| `<C-S>` | 普通/可视/选择/插入 | 保存 |
| `<C-U>` | 普通 | 上半页并居中 |
| `<CR>` | 插入 | MiniPairs <CR> |
| `<Esc>` | 普通 | 清除搜索高亮 |
| `<M-n>` | 普通 | Move to next reference |
| `<M-p>` | 普通 | Move to previous reference |
| `H` | 普通 | 上一个缓冲区 |
| `L` | 普通 | 下一个缓冲区 |
| `N` | 普通 | 上一个匹配并居中 |
| `R` | 可视/操作符待决 | 语法节点搜索（flash） |
| `S` | 普通/可视/操作符待决 | 按语法节点跳转（flash） |
| ``` | 插入 | Closeopen action for "``" pair |
| `a` | 可视/操作符待决 | Around textobject |
| `ai` | 可视/操作符待决 | Object scope with border |
| `al` | 可视/操作符待决 | Around last textobject |
| `an` | 可视/操作符待决 | Around next textobject |
| `g=` | 普通 | Evaluate |
| `g=` | 可视 | Evaluate selection |
| `g==` | 普通 | Evaluate line |
| `gA` | 普通/可视 | Align with preview |
| `gH` | 普通/可视 | Reset hunks |
| `gS` | 普通/可视 | Toggle arguments |
| `gX` | 普通/可视 | Opens filepath or URI under cursor with the system handler (file explorer, web browser, …) |
| `g[` | 普通/可视/操作符待决 | Move to left "around" |
| `g]` | 普通/可视/操作符待决 | Move to right "around" |
| `ga` | 普通/可视 | Align |
| `gc` | 普通 | Comment |
| `gc` | 操作符待决 | Comment textobject |
| `gc` | 可视 | Comment selection |
| `gcc` | 普通 | Comment line |
| `gh` | 普通/可视 | Apply hunks |
| `gh` | 操作符待决 | Hunk range textobject |
| `gm` | 普通 | Multiply |
| `gm` | 可视 | Multiply selection |
| `gmm` | 普通 | Multiply line |
| `gr` | 普通 | Replace |
| `gr` | 可视 | Replace selection |
| `grr` | 普通 | Replace line |
| `gs` | 普通 | Sort |
| `gs` | 可视 | Sort selection |
| `gss` | 普通 | Sort line |
| `gx` | 普通 | Exchange |
| `gx` | 可视 | Exchange selection |
| `gxx` | 普通 | Exchange line |
| `i` | 可视/操作符待决 | Inside textobject |
| `ii` | 可视/操作符待决 | Object scope |
| `il` | 可视/操作符待决 | Inside last textobject |
| `in` | 可视/操作符待决 | Inside next textobject |
| `j` | 普通/可视 | 下移（屏幕行） |
| `k` | 普通/可视 | 上移（屏幕行） |
| `n` | 普通 | 下一个匹配并居中 |
| `r` | 操作符待决 | 远程操作（flash） |
| `s` | 普通/可视/操作符待决 | 跳转（flash） |
| `sF` | 普通/可视/操作符待决 | Find left surrounding |
| `sFl` | 普通/可视/操作符待决 | Find previous left surrounding |
| `sFn` | 普通/可视/操作符待决 | Find next left surrounding |
| `sa` | 普通 | Add surrounding |
| `sa` | 可视 | Add surrounding to selection |
| `sd` | 普通 | Delete surrounding |
| `sdl` | 普通 | Delete previous surrounding |
| `sdn` | 普通 | Delete next surrounding |
| `sf` | 普通/可视/操作符待决 | Find right surrounding |
| `sfl` | 普通/可视/操作符待决 | Find previous right surrounding |
| `sfn` | 普通/可视/操作符待决 | Find next right surrounding |
| `sh` | 普通 | Highlight surrounding |
| `shl` | 普通 | Highlight previous surrounding |
| `shn` | 普通 | Highlight next surrounding |
| `sr` | 普通 | Replace surrounding |
| `srl` | 普通 | Replace previous surrounding |
| `srn` | 普通 | Replace next surrounding |
| `{` | 插入 | Open action for "{}" pair |
| `}` | 插入 | Close action for "{}" pair |

### `[` / `]` 系列（由 mini.bracketed 建立）

这些是「跳到前一个/后一个同类位置」的成对键位，例如 `]d` 下一个诊断、
`[q` 上一个 quickfix 项。带大写字母的是跳到**首个**，小写是**上一个/下一个**。

| 键位 | 往前 | 往后 |
| --- | --- | --- |
| `[B` / `]B` | Buffer first | Buffer last |
| `[C` / `]C` | Comment first | Comment last |
| `[D` / `]D` | Diagnostic first | Diagnostic last |
| `[F` / `]F` | File first | File last |
| `[H` / `]H` | First hunk | Last hunk |
| `[I` / `]I` | Indent first | Indent last |
| `[J` / `]J` | Jump first | Jump last |
| `[L` / `]L` | Location first | Location last |
| `[O` / `]O` | Oldfile first | Oldfile last |
| `[Q` / `]Q` | Quickfix first | Quickfix last |
| `[T` / `]T` | Treesitter first | Treesitter last |
| `[U` / `]U` | Undo first | Undo last |
| `[W` / `]W` | Window first | Window last |
| `[X` / `]X` | Conflict first | Conflict last |
| `[Y` / `]Y` | Yank first | Yank last |
| `[b` / `]b` | Buffer backward | Buffer forward |
| `[c` / `]c` | Comment backward | Comment forward |
| `[d` / `]d` | Diagnostic backward | Diagnostic forward |
| `[f` / `]f` | File backward | File forward |
| `[h` / `]h` | Previous hunk | Next hunk |
| `[i` / `]i` | Go to indent scope top | Go to indent scope bottom |
| `[j` / `]j` | Jump backward | Jump forward |
| `[l` / `]l` | Location backward | Location forward |
| `[o` / `]o` | Oldfile backward | Oldfile forward |
| `[q` / `]q` | Quickfix backward | Quickfix forward |
| `[t` / `]t` | Treesitter backward | Treesitter forward |
| `[u` / `]u` | Undo backward | Undo forward |
| `[w` / `]w` | Window backward | Window forward |
| `[x` / `]x` | Conflict backward | Conflict forward |
| `[y` / `]y` | Yank backward | Yank forward |

## LSP 键位（打开带语言服务器的文件后才生效）

这些键位由 `lua/distro/lsp.lua` 在 `LspAttach` 时按缓冲区设置，
所以只在支持的文件类型里可用（例如 `.lua`、`.c`、`.py`）。

| 键位 | 说明 |
| --- | --- |
| `gd` | 跳转到定义 |
| `gD` | 跳转到声明 |
| `gr` | 查找引用 |
| `gi` | 跳转到实现 |
| `gt` | 跳转到类型定义 |
| `K` | 悬停文档 |
| `<C-k>` | 参数签名 |
| `<leader>rn` | 重命名符号 |
| `<leader>ca` | 代码动作 |
| `<leader>ct` | 整理 imports |
| `<leader>cd` | 显示该行诊断 |
| `<leader>fmt` | 格式化当前缓冲区 |
| `[d` / `]d` | 上一个 / 下一个诊断 |

## 由插件自带、本发行版未改写的常用键位

下面这些是插件 `setup()` 时自己建立的默认键位，本发行版沿用未改，
只列出日常会用到的部分：

| 来源 | 键位 | 作用 |
| --- | --- | --- |
| mini.ai | `a` / `i` + 对象字符 | 文本对象，如 `ciq` 改引号内、`daa` 删一个参数 |
| mini.surround | `sa` `sd` `sr` | 增 / 删 / 改包围对，如 `saiw)` 给词加括号 |
| mini.comment | `gc` / `gcc` | 注释（可视模式 `gc` 注释选区） |
| mini.pairs | 插入模式输入 `(` `[` `{` `"` `'` | 自动配对，回车智能展开 |
| mini.splitjoin | `gS` | 多行参数 / 数组的拆开与合并 |
| mini.operators | `gx` `gm` `g=` | 交换两侧、乘法（复制并替换）等 |
| mini.files | `-` | 文件管理器（本发行版另绑 `<leader>e`） |
| oil.nvim | `-` | 在父目录打开（本发行版另绑 `<leader>e`，两者按需二选一） |
| gitsigns.nvim | `]c` `[c` `]c` 等 | 逐块跳转；暂存等操作见其默认键位 |
| trouble.nvim | — | 本发行版只经 `<leader>x*` 入口调用 |
