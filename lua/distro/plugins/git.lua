-- Git：gitsigns（常驻）+ neogit / diffview（按需）。

local function git_keymaps(bufnr)
  local gs = require('gitsigns')
  local map = function(keys, fn, desc)
    vim.keymap.set('n', keys, fn, { buffer = bufnr, desc = desc })
  end

  -- 逐块跳转用 mini.bracketed 已给的 ]c / [c（gitsigns 自己也会建，二者一致）
  map('<leader>gs', gs.stage_hunk, '暂存这一块')
  map('<leader>gr', gs.reset_hunk, '撤销这一块')
  map('<leader>gp', gs.preview_hunk, '预览这一块')
  map('<leader>gb', function() gs.blame_line({ full = true }) end, '显示这行的 blame')
  map('<leader>gd', gs.diffthis, '查看本文件的改动')
  map('<leader>gt', gs.toggle_deleted, '显示/隐藏已删除的行')
  map('<leader>gS', gs.stage_buffer, '暂存整个文件')
  map('<leader>gR', gs.reset_buffer, '撤销整个文件的改动')
end

return {
  {
    names = 'gitsigns.nvim',
    pack = 'start',
    setup = function()
      local ok, gitsigns = pcall(require, 'gitsigns')
      if not ok then return end
      pcall(gitsigns.setup, {
        -- 符号列用 ASCII。
        -- 插件默认用的是 `▎`（U+258E）这类方块字符，而它们是东亚「歧义宽度」字符：
        -- 在 ambiwidth=double 下会占 2 格，符号列随之变宽、整屏右移。
        -- 这与 listchars 报 E1512 是同一类冲突（那边会报错，这边只是错位，更难发现）。
        signs = {
          add          = { text = '+' },
          change       = { text = '~' },
          delete       = { text = '_' },
          topdelete    = { text = '^' },
          changedelete = { text = '~' },
          untracked    = { text = '?' },
        },
        signs_staged = {
          add          = { text = '+' },
          change       = { text = '~' },
          delete       = { text = '_' },
          topdelete    = { text = '^' },
          changedelete = { text = '~' },
        },
        -- 中文注释与行内 blame 混排会很挤，关掉；需要时按 <leader>gb
        current_line_blame = false,
        -- 大文件不算 diff（search.lua 打的那个标记）
        update_debounce = 200,
        on_attach = function(bufnr)
          if vim.b[bufnr].distro_bigfile then return end
          pcall(git_keymaps, bufnr)
        end,
      })
    end,
  },

  {
    names = 'neogit',
    pack = 'opt',
    keys = { '<leader>gg', '<leader>gc' },
    desc = 'Git 状态面板（Magit 风格）',
    setup = function()
      -- 先装 diffview 再 setup：neogit 声明了 integrations.diffview，
      -- 但两者都是懒加载 —— 用户没按过 <leader>gD 时 diffview 不在
      -- runtimepath 上，neogit 打开 diff 时会找不到模块。
      -- 在这里显式补装，保证被依赖者与依赖者同时就位。
      require('distro.pack').add('diffview.nvim')
      pcall(require('neogit').setup, {
        -- 集成我们已有的 diffview（它也随包分发）
        integrations = { diffview = true },
        graph_style = 'unicode',
        kind = 'floating',   -- 浮动窗口，不抢走编辑区的分屏
      })
      vim.keymap.set('n', '<leader>gg', function() require('neogit').open({ kind = 'floating' }) end, { desc = 'Git 面板（neogit）' })
      vim.keymap.set('n', '<leader>gc', function() require('neogit').open({ 'commit' }) end, { desc = '提交（neogit）' })
    end,
  },

  {
    names = 'diffview.nvim',
    pack = 'opt',
    keys = { '<leader>gD', '<leader>gh' },
    desc = '文件历史与差异视图',
    setup = function()
      pcall(require('diffview').setup, {
        enhanced_diff_hl = true,
        view = { default = { layout = 'diff1_plain' } },
      })
      vim.keymap.set('n', '<leader>gD', '<Cmd>DiffviewOpen<CR>', { desc = '查看工作区差异（diffview）' })
      vim.keymap.set('n', '<leader>gh', '<Cmd>DiffviewFileHistory %<CR>', { desc = '当前文件的历史（diffview）' })
      vim.keymap.set('n', '<leader>gH', '<Cmd>DiffviewFileHistory<CR>', { desc = '全项目历史（diffview）' })
    end,
  },

  {
    names = 'nvim-lsp-file-operations',
    pack = 'start',
    -- 常驻而不是懒加载。理由：它只在「LSP 已连接 + 文件被重命名/移动」时才有用，
    -- 而那个时机无法用键位表达 —— 我第一次写成了绑 <leader>gg，结果和上面 neogit
    -- 撞了同一个键（自己和自己撞），而且 git 重命名后 LSP 是否同步取决于用户
    -- 有没有先按过那个键，等于引入了不确定行为。
    -- 它本身开销可忽略，常驻最省心。
    setup = function()
      pcall(require('lsp-file-operations').setup, {})
    end,
  },
}
