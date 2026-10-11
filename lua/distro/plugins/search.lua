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

-- 注：这里曾有一个 fd_bin()，用来把 files.cmd 指到随包的 fd。
-- 已删除 —— 那种做法会覆盖掉 fzf-lua 默认命令里带的 --exclude .git，
-- 而且没必要：启动脚本已把 <发行版>/bin 前置进 PATH。

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

        -- 刻意**不**设置 files.cmd 与 fd_opts，用 fzf-lua 自己的默认值。
        --
        -- 教训：我曾用 files.cmd 指定随包 fd 的完整路径，看似更「确定」，
        -- 实则破坏了默认行为 —— files.lua:33 是
        --   if opts.cmd and #opts.cmd > 0 then command = opts.cmd
        -- 一旦设了 cmd，fd_opts 就完全失效，而默认的 fd_opts 里带着
        --   --exclude .git --exclude .jj
        -- 于是列表会把 .git 内部的文件也混进来（--hidden 打开后 fd 会进 .git）。
        -- 另外 --hidden / --follow / --no-ignore 这些开关只作用于默认形式的命令。
        --
        -- 不设 cmd 也不会退回到「系统的 fd」：启动脚本已把 <发行版>/bin 前置进 PATH，
        -- 所以裸命令名 fd / rg 解析到的就是随包那份。
        -- fzf-lua 会在 fd / fdfind / rg / find 之间自动挑可用的，前两个都在包里。
        -- 发行版自己的运行期状态不该出现在搜索结果里。
        --
        -- .local/ 下是会话、undo、以及与 vim.loader 的字节码缓存
        -- （cache/luac/，文件名是 URI 编码后的路径，例如
        --  D%3a%2flang%2f...%2flua%2fdistro%2fsearch.luac —— 那串看不懂的
        --  %3a%2f 就是它）。从包目录里搜索时，这些东西会淹没真正的项目文件。
        --
        -- 两层保险，因为两者作用的位置不同：
        --   file_ignore_patterns 是**追加**语义，作用于 fzf-lua 的 Lua 侧过滤
        --     与 grep provider，对 fd / rg 两条路都生效，且不会丢掉默认值；
        --   fd_opts 决定真正下发的 fd 命令，它能被我截取命令来验证 ——
        --     但它是**替换**语义。
        file_ignore_patterns = { '^%.local/' },

        -- 注意：fd_opts 是替换语义，所以这里的值必须与 fzf-lua 的默认保持一致，
        -- 我只在结尾追加了 --exclude .local。
        -- 默认值来源：fzf-lua/defaults.lua 的 M.defaults.files.fd_opts
        --   [[--color=never --type f --type l --exclude .git --exclude .jj]]
        -- 上游若增删默认排除项，这里会落后 —— 代价是「多排或少排一个目录」，
        -- 比丢掉 .git 那种「列表混进版本库内部」的后果轻得多，故可接受。
        fd_opts = '--color=never --type f --type l --exclude .git --exclude .jj --exclude .local',

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
            extraArgs = { '--hidden', '--glob=!.git/*', '--glob=!.local/*' },
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
