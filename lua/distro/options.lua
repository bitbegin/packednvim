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
opt.list = true
opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
opt.fillchars = { eob = ' ', fold = ' ', foldopen = '▾', foldclose = '▸' }
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
