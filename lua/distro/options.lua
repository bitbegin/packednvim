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
-- 东亚宽字符按双宽处理，否则中文与框线字符会错位。
-- 注意：这只解决 Neovim 一侧，终端字体本身也要等宽 —— 文档里必须写明。
opt.ambiwidth = 'double'

-- 关闭终端「同步输出」批处理。
--
-- termsync（Neovim 0.10+）会调用终端的 synchronized-output 模式，把一帧内的
-- 所有屏幕更新打包提交，正常情况下能减少闪烁。但**终端对该模式支持不完善时**，
-- 更新会只生效一部分 —— 表现为屏幕上残留之前的内容，缩窗口/放大窗口触发整屏
-- 重绘后才消失。
--
-- 这条正是从实际使用中定位到的：fzf 实时 grep 在查询被清空（列表变空）时会
-- 残留上一次搜索的文字碎片，而放大窗口就干净了。实测本机 termsync 默认为 true。
--
-- 代价：失去同步输出带来的抗闪烁效果。在没有该缺陷的终端上，它只是略有不同；
-- 在有的终端上则直接决定「会不会画面不干净」。
opt.termsync = false

-- 让重绘保守化。
--
-- ttyfast=true（默认）时 Neovim 假定终端够快，会用「插入行/删除行/滚动区域」
-- 之类的优化来少刷几个格子。**终端对这些优化处理不当时就会出现残影或错位**，
-- 而那类问题往往只在局部更新时暴露（例如列表从有内容变成空），
-- 整屏重绘（改窗口大小）就恢复正常。
--
-- 这与上面关掉 termsync 是同一层的取舍：牺牲一点重绘效率，换取画面稳定。
-- 如果以后的终端确认没问题，这两项可以一起恢复默认值。
opt.ttyfast = false

-- 用 jieba.vim 做中文按词移动（w/b/e）。它提供的动作会覆盖默认行为，
-- 见 plugins/jieba.lua。这里只保证不因 fileformat 之类误判而失效。
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
opt.fillchars = { eob = ' ', fold = ' ', foldopen = '-', foldclose = '+' }
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
