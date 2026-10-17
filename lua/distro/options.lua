-- 全局选项。
--
-- 原则：
--   1. 只设定「几乎所有人都该这么用」的项，可争议的留给用户在 keys/extra 里改。
--   2. 与发行版的既定决策对齐：Nerd Font 强依赖（已定）、中文用户优先（CJK）、
--      搜索走外置 rg（见 search.lua，那边的 grepprg/grepformat 在这里不再重复设）。
--   3. 每一项都写清「为什么」，避免以后有人删掉却不知道代价。

local opt = vim.opt

-- ---------------------------------------------------------------------------
-- 前导键
-- ---------------------------------------------------------------------------
-- 空格是最省事的选择：不占任何默认键位，且两只手都够得到。
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- 字节码缓存：启动时把 Lua 模块编译结果缓存到 stdpath('state')。
-- 对装了 40+ 插件的发行版，这一项能省下可观的启动时间。
pcall(vim.loader.enable)

-- ---------------------------------------------------------------------------
-- 中文 / CJK（本发行版面向中文用户，这几项不是可选项）
-- ---------------------------------------------------------------------------
-- 歧义宽度字符按 **单宽** 处理。
--
-- 这个值曾经是 'double'（「CJK 终端里歧义字符按双宽才算对」的老经验），
-- 但它在本项目里引发了**一整串**实际故障，按时间顺序：
--
--   1. options.lua 自己的 listchars 用了 `·`，E1512，整份 options 静默失效
--   2. dressing 默认的 listchars 用了 `…`，E1512，<leader>sG 直接报错
--   3. gitsigns 的符号列 `▎` 被算成 2 格，符号列被撑宽（不报错，只是错位）
--   4. fzf 画的分隔线 `─` 被算成 2 格，截成一截一截的 `--`
--   5. fzf 实时 grep 清空查询后，上一次搜索的文字残留在屏幕上
--      （散落如星点，只有整屏重绘才消失）
--
-- 1-4 是「Neovim 自己画的东西」宽度算错；5 最隐蔽，也最说明问题本质：
--
--   fzf（Go 的 runewidth，未开 EastAsianWidth）按 1 格定位光标，
--   Neovim 按 2 格往终端缓冲区的网格里放字符 —— **两边对不上账**。
--   fzf 以为擦掉了，网格里还留着；整屏重绘（改窗口大小）才重新对齐。
--   这也解释了为什么换终端（PowerShell / Alacritty）都复现：
--   错位发生在 Neovim 内部网格，与外面哪个终端显示无关。
--   而在 shell 里直接跑 `rg --files | fzf`（不经过 Neovim）则完全正常 ——
--   实测排除了 fzf 自身。
--
-- 为什么 single 不影响中文：汉字属于东亚宽度分类里的「宽（W）」，
-- 不是「歧义（A）」，ambiwidth 根本不作用于它。受影响的只有
-- `…` `±` `─` `▌` 这类两边都说得通的字符。
--
-- 为什么 single 反而更正确：现代终端（Windows Terminal / Alacritty）默认
-- 就把歧义字符渲染成 1 格。'double' 是老式 CJK locale 终端的经验，
-- 在这里只会让 Neovim 与真实显示相反。
--
-- 若将来真有「歧义字符按双宽渲染」的终端环境，再把这里改回 'double'，
-- 同时必须连带检查上面 1-4 那几处 ASCII 化的地方。
opt.ambiwidth = 'single'

-- 用 jieba.vim 做中文按词移动（w/b/e）。它提供的动作会覆盖默认行为，
-- 中文按词移动（w/b/e）。jieba 由 plugins/zh.lua 负责真正的接线与产物检查。
opt.fileformats = { 'unix', 'dos', 'mac' }

-- ---------------------------------------------------------------------------
-- 编辑行为
-- ---------------------------------------------------------------------------
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.shiftround = true          -- 缩进对齐到 shiftwidth 的整数倍，避免累积漂移
opt.smartindent = true
opt.wrap = false
opt.linebreak = true           -- 若开了 wrap，按词换行而不是硬切

opt.ignorecase = true
opt.smartcase = true           -- 有大写时自动区分大小写
opt.inccommand = 'split'       -- 替换时实时预览，改错立刻看得见

opt.undofile = true            -- 跨会话撤销；大文件会被 search.lua 关掉
opt.undolevels = 10000
opt.swapfile = false
opt.backup = false

opt.clipboard = 'unnamedplus'
-- Windows 需要显式的剪贴板工具；官方 nvim-win64.zip 自带 win32yank.exe。
if vim.fn.has('win32') == 1 and vim.fn.executable('win32yank.exe') == 1 then
  vim.g.clipboard = {
    name = 'win32yank',
    copy = { ['+'] = 'win32yank.exe -i --crlf', ['*'] = 'win32yank.exe -i --crlf' },
    paste = { ['+'] = 'win32yank.exe -o --lf', ['*'] = 'win32yank.exe -o --lf' },
    cache_enabled = 0,
  }
end

opt.mouse = 'a'                -- 需求 5 的「双击跳转」依赖鼠标
opt.confirm = true             -- 有未保存改动时先问，而不是直接失败

-- ---------------------------------------------------------------------------
-- 外观
-- ---------------------------------------------------------------------------
-- 已定：图标强依赖 Nerd Font。各插件据此决定是否画图标。
vim.g.have_nerd_font = true

opt.number = true
opt.relativenumber = true
opt.signcolumn = 'yes'         -- 常驻，避免 git 标记出现时整屏横向跳动
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.termguicolors = true
opt.showmode = false           -- 模式已由状态栏显示，再显示一次是噪音
opt.laststatus = 3             -- 全局状态栏
opt.splitright = true
opt.splitbelow = true

-- 从 quickfix / 搜索结果跳转时**开新标签页**，而不是横着切出更多窗口。
--
-- 起因是实际使用：搜完按回车看结果，窗口会越切越多（编辑区本来就分过屏的话，
-- copen 再加一个结果窗口就是三个横向窗口，屏幕被切得很碎）。
-- 新标签页的语义更清楚：一个文件一个标签页，<C-w> 系列的窗口操作也不再互相牵制。
--
-- usetab 写在前面：目标文件已经在某个标签页里显示时，直接切过去而不重复开 ——
-- 否则用 <leader>sn / <leader>sp 在结果间翻动会开出一堆重复的标签页。
-- newtab 兜底：文件还没打开过，才新建标签页。
--
-- 这一项是全局的，因此 LSP 查引用（gr）等 quickfix 跳转也同样受益。
opt.switchbuf = 'usetab,newtab'
opt.list = true
-- listchars 这里有个真实的坑：`ambiwidth=double` 会把**东亚「歧义宽度」字符**
-- （`·` U+00B7、`␣` U+2423、`»` U+00BB 都是）当成 2 格宽，而 listchars 要求
-- 这些字段必须是 1 格 —— 于是直接报 E1512 并且**整份 options 都不会生效**。
--
-- 所以这里用 ASCII：它永远窄，不受 ambiwidth 影响。
-- 想要好看字形的话，得在「CJK 宽度正确」和「漂亮的 listchars」之间取舍 ——
-- 对本发行版的目标用户（中文），前者更重要，所以选 ASCII 并在此写明原因。
opt.listchars = { tab = '> ', trail = '-', nbsp = '+' }
-- horiz / vert 是**窗口之间那条分隔线**的填充字符，默认是 `─` 和 `│`。
--
-- 为什么改成空格：`<leader>sG` 会把 quickfix 窗口开在下方（copen 默认 10 行），
-- 于是在屏幕中间横出一条 `────…`。全局状态栏（laststatus=3）本来在最底部，
-- 但那条分隔线的位置和外观都很像第二条状态栏，实际使用时极易误判成
-- 「状态栏跑到中间去了」。改成空格后两个窗口看起来连成一片，
-- 界面只剩底部那一条真正的状态栏，视觉噪音也少了。
--
-- 代价：分屏边界不再有线条提示，只能靠内容差异判断。若想恢复，
-- 删掉 horiz/vert 两项即可（或显式设成 '─' / '│'）。
opt.fillchars = {
  eob = ' ',
  fold = ' ',
  foldopen = '-',
  foldclose = '+',
  horiz = ' ',
  vert = ' ',
}
opt.pumheight = 12             -- 补全菜单最多 12 行，别挡住半个屏幕
opt.winminwidth = 5
opt.timeoutlen = 400           -- 等 which-key 弹出与组合键的超时
opt.updatetime = 200           -- 诊断与 gitsigns 的刷新间隔

-- ---------------------------------------------------------------------------
-- 文件与目录
-- ---------------------------------------------------------------------------
-- netrw 与 oil.nvim（我们用它编辑目录）会争抢目录缓冲区的接管权，所以关掉 netrw。
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrw = 1

-- 大文件由 lua/distro/search.lua 的 BufReadPre 钩子降级（关语法/折叠/undo），
-- 这里只把语法高亮的行宽上限调低，减少超长行的渲染开销。
opt.synmaxcol = 500

-- ---------------------------------------------------------------------------
-- 搜索
-- ---------------------------------------------------------------------------
-- grepprg / grepformat 在 lua/distro/search.lua 里设置（需求 5 的一部分），
-- 那里还负责大文件降级与 quickfix 双击跳转，集中在一起更好维护。
opt.path:append('**')          -- gf / :find 能递归查找
opt.wildignore:append({ '*/node_modules/*', '*/.git/*', '*/target/*' })

-- ---------------------------------------------------------------------------
-- GUI（Neovide）外观
-- ---------------------------------------------------------------------------
-- 这里**没有** `if vim.g.neovide then ... end` 这种分支，因为那个判断在本文件
-- 执行时永远为假：Neovide 并不会在启动 nvim 时注入该变量（日志里的启动命令
-- 只有 `--embed -p`），它是连接成功之后才经 RPC 设的，而 options.lua 在
-- init.lua 装配置的阶段就跑完了。
--
-- 曾经写过一段 `if vim.g.neovide then vim.g.neovide_scale_factor = ... end`，
-- 当时靠启动器额外传 `--cmd "let g:neovide=v:true"` 才生效；启动器被移除后，
-- 那一段就变成了**静默的死代码**（改了没反应，且不报错，很难察觉）。
--
-- 所以下面两项**无条件**设置。guifont / guifontwide 只在 GUI 里起作用，
-- 终端里设置不报错（实测 v:errmsg 为空），因此不需要任何条件判断。
--
-- 为什么字体不放在 bin/neovide.toml 里：那个文件只有 **NEOVIDE_CONFIG**
-- 环境变量能找到，而安装脚本写进注册表的变量，**已经打开的 Explorer / 终端
-- 不会继承**。实测后果：从旧会话启动 Neovide 时读不到 toml，退回
-- Cascadia Mono / Consolas —— 这两个字体没有 Nerd Font 字形，**图标全变方块**。
-- guifont 由 nvim 自己的配置设置，不依赖任何环境变量，没有这个坑。
--
-- neovide.toml 仍负责「窗口初始尺寸」(maximized) 与框线风格，那两项没法用
-- vim 选项表达。
--
-- 字体链：等宽的 Nerd Font 优先（图标依赖它），中文回退也必须等宽，
-- 否则中文在等宽网格里宽度对不上，字与字之间会露出空隙。
--
-- 注意 guifont **只能写一个字体**：逗号分隔的回退链是 Vim GUI 的老写法，
-- Neovide 的解析器不认，会直接报错
--   Error: Failed to parse guifont: Invalid size
-- 然后在每次启动时卡在「按回车继续」。实测踩过一次。
-- 每个字体各带 :h<字号>，Neovide 会把 guifontwide 当作宽字符的回退。
local GUI_FONT = 'FiraCode Nerd Font Mono:h13'
-- guifontwide 专管「guifont 里没有的宽字符」，中文就落在这里。
local GUI_FONT_WIDE = '新宋体:h13'
vim.o.guifont = GUI_FONT
vim.o.guifontwide = GUI_FONT_WIDE

-- 但只设一次**不够**：Neovide 在 UI 附加之后会把它自己的字体值写进 guifont
-- （没配 toml 时是内置默认 `Cascadia Code,Cascadia Mono,...`），把 init 阶段
-- 设的值**覆盖掉**。实测日志里能看到：
--   OptionSet { gui_option: GuiFont("Cascadia Code,Cascadia Mono,Consolas,...") }
-- 而这个默认列表里没有 Nerd Font 字形 —— 图标就全变方块了。
--
-- 所以要在 UI 真正附加（UIEnter）之后再重申一次，这时 Neovide 的写入已经完成，
-- 我们的值才能落地并经 OptionSet 被它采用。
vim.api.nvim_create_autocmd('UIEnter', {
  callback = function()
    if vim.o.guifont ~= GUI_FONT then
      vim.o.guifont = GUI_FONT
    end
    if vim.o.guifontwide ~= GUI_FONT_WIDE then
      vim.o.guifontwide = GUI_FONT_WIDE
    end
  end,
  desc = 'GUI 附加后重申字体（Neovide 会先覆盖一次）',
})
