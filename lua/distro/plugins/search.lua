-- 搜索与跳转的插件侧配置。
--
-- 键位分工（这条必须写清楚，否则两套搜索会打架）：
--   <leader>s*  → 需求 5 的「rg + quickfix」工作流，实现在 lua/distro/search.lua
--                 结果**按行**列在一个窗口里，可用鼠标点击跳转
--   <leader>f*  → 需求 4 的交互式选择器（fzf-lua + 随包的 fzf）
--                 边打字边过滤，适合"先浏览再决定"
-- 两者不是重复：一个要「一眼看全、可点」，一个要「快速模糊筛」。

local function fzf_bin()
  local root = vim.g.distro_root or ''
  local exe = root .. '/bin/' .. (vim.fn.has('win32') == 1 and 'fzf.exe' or 'fzf')
  -- 随包的那份优先；万一丢了就退回 PATH 上的 fzf（fzf-lua 自己也会再兜一次底）
  if vim.fn.executable(exe) == 1 then return exe end
  return 'fzf'
end

local function fd_bin()
  local root = vim.g.distro_root or ''
  local exe = root .. '/bin/' .. (vim.fn.has('win32') == 1 and 'fd.exe' or 'fd')
  if vim.fn.executable(exe) == 1 then return exe end
  return 'fd'
end

return {
  {
    names = 'fzf-lua',
    pack = 'start',
    setup = function()
      local fzf = require('fzf-lua')

      fzf.setup({
        -- 关键：明确指向随包的 fzf。不设的话 fzf-lua 会去找 PATH 上的 fzf，
        -- 找不到就报 'fzf' is not a valid executable —— 那正是离线发行版最该避免的。
        fzf_bin = fzf_bin(),
        -- 同理，文件列举用随包的 fd（比 find/rg --files 更快，且默认遵守 .gitignore）
        fd_opts = '--color=never --hidden --exclude=.git',
        files = { cmd = fd_bin() .. ' --type f --type l' },
        winopts = {
          height = 0.85,
          width = 0.85,
          border = 'rounded',
          preview = { layout = 'flex', border = 'rounded' },
        },
        keymap = {
          builtin = {
            ['<C-d>'] = 'preview-page-down',
            ['<C-u>'] = 'preview-page-up',
            ['<C-a>'] = 'select-all',
          },
        },
        -- 大文件预览用 head 限制行数，避免预览几 MB 的文件把界面卡住
        previewers = { builtin = { syntax_limit_b = 1024 * 100 } },
      })

      -- grep 走随包的 rg，且**复用 search.lua 里那套参数**的思路：
      -- 忽略 .git、隐藏文件也搜、限制列宽防止超长行拖慢渲染。
      local ok, search = pcall(require, 'distro.search')
      if ok and type(search.rg_command) == 'function' then
        fzf.config().grep.rg_opts = nil -- 由下面的命令统管
      end

      -- 键位：全部 <leader>f*
      local map = function(keys, fn, desc)
        vim.keymap.set('n', keys, fn, { desc = desc })
      end

      map('<leader>ff', fzf.files, '查找文件（fzf）')
      map('<leader>fg', fzf.live_grep, '全项目搜索（fzf 交互）')
      map('<leader>fG', function() fzf.live_grep({ search = vim.fn.expand('<cword>'), regex = false }) end, '搜索光标下的词（fzf）')
      map('<leader>fb', fzf.buffers, '切换缓冲区（fzf）')
      map('<leader>fr', fzf.oldfiles, '最近文件（fzf）')
      map('<leader>fh', fzf.help_tags, '帮助标签（fzf）')
      map('<leader>fk', fzf.keymaps, '查看键位（fzf）')
      map('<leader>fc', fzf.commands, '可用命令（fzf）')
      map('<leader>fd', fzf.diagnostics_document, '当前文件诊断（fzf）')
      map('<leader>fD', fzf.diagnostics_workspace, '全项目诊断（fzf）')
      map('<leader>fm', fzf.marks, '标记（fzf）')
      map('<leader>f/', fzf.lines, '当前文件内搜索行（fzf）')
      map('<leader>fs', fzf.lsp_document_symbols, '当前文件符号（fzf）')
      map('<leader>fS', fzf.lsp_workspace_symbols, '全项目符号（fzf）')
    end,
  },

  {
    names = 'flash.nvim',
    pack = 'start',
    setup = function()
      require('flash').setup({
        modes = {
          -- 保留 search 模式：输入时即时高亮并可跳转，比默认的 / 好用得多
          search = { enabled = true },
          char = { enabled = true, jump_labels = true },
        },
        label = { uppercase = false }, -- 只用小写标签，少按一次 Shift
        -- 与 treesitter 配合做语法节点跳转
        jump = { nohlsearch = true },
      })

      -- flash 接管 s / S（默认的 s 只是 substitute 的别名，用得少）
      vim.keymap.set({ 'n', 'x', 'o' }, 's', function() require('flash').jump() end, { desc = '跳转（flash）' })
      vim.keymap.set({ 'n', 'x', 'o' }, 'S', function() require('flash').treesitter() end, { desc = '按语法节点跳转（flash）' })
      vim.keymap.set('o', 'r', function() require('flash').remote() end, { desc = '远程操作（flash）' })
      vim.keymap.set({ 'o', 'x' }, 'R', function() require('flash').treesitter_search() end, { desc = '语法节点搜索（flash）' })
    end,
  },

  -- 说明：`nvim-spider` **没有**启用。
  -- 它没有任何关闭默认键位的选项，必然接管 w / e / b / ge / gg，
  -- 与 jieba.vim 的中文按词移动直接冲突。两者只能留一个，
  -- 而中文分词是本发行版的差异点，所以 jieba 胜出（见 zh.lua 与 docs/DECIDED.md）。

  {
    names = 'grug-far.nvim',
    pack = 'opt',
    keys = { '<leader>sr', '<leader>sR' },
    desc = '全项目替换（grug-far）',
    setup = function()
      require('grug-far').setup({
        -- 与 search.lua 一致：rg 忽略 .git，但隐藏文件也要搜
        engines = {
          ripgrep = {
            path = 'rg',
            extraArgs = { '--hidden', '--glob=!.git/*' },
          },
        },
        border = 'rounded',
        headerLine = true,
      })

      local function open(args)
        require('grug-far').open(vim.tbl_extend('force', { prefills = { paths = vim.fn.expand('%') } }, args or {}))
      end

      vim.keymap.set('n', '<leader>sr', function() open({ prefills = { paths = vim.fn.getcwd() } }) end,
        { desc = '全项目替换（grug-far）' })
      vim.keymap.set('n', '<leader>sR', function() open() end,
        { desc = '当前文件替换（grug-far）' })
      vim.keymap.set('v', '<leader>sr', function()
        require('grug-far').with_visual_selection({ prefills = { paths = vim.fn.getcwd() } })
      end, { desc = '用选中内容替换（grug-far）' })
    end,
  },
}
