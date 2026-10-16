-- 编辑增强：光标词高亮、缩进探测、重复、撤销树、分屏移动、目录编辑。

return {
  {
    names = 'vim-illuminate',
    pack = 'start',
    -- 注意模块名是 illuminate（不是 vim-illuminate）
    setup = function()
      local ok, illuminate = pcall(require, 'illuminate')
      if not ok then return end
      pcall(illuminate.setup, {
        -- 用 mini.cursorword 之外再叠一层「同名符号高亮」：前者是当前词，
        -- 后者（illuminate）会借 LSP 找到同一符号的所有引用。
        -- 延迟设大一点：中文输入法下频繁重绘会卡。
        delay = 200,
        filetypes_denylist = { 'oil', 'fzf', 'ministarter', 'markdown' },
        -- 大文件不算（search.lua 打的那个标记）
        under_cursor = true,
      })
      vim.keymap.set('n', ']r', function() require('illuminate').goto_next_reference(false) end, { desc = '下一个同名引用' })
      vim.keymap.set('n', '[r', function() require('illuminate').goto_prev_reference(false) end, { desc = '上一个同名引用' })
    end,
  },

  {
    names = 'guess-indent.nvim',
    pack = 'start',
    setup = function()
      local ok, guess = pcall(require, 'guess-indent')
      if not ok then return end
      -- 按文件内容推断缩进宽度，覆盖 options.lua 里的默认 2 空格。
      -- 对混着 tab 的老项目很有用，否则一打开就是满屏缩进警告。
      pcall(guess.setup, {
        auto_cmd = true,
        override_editorconfig = false,   -- editorconfig 更明确时听它的
      })
    end,
  },

  {
    names = 'vim-repeat',
    pack = 'start',
    -- 纯 vimscript 插件（没有 lua/ 目录），无需 setup。
    -- 它的作用：让插件提供的动作也能被 `.` 重复 —— 例如 mini.surround 的
    -- `saiw)` 之后按 `.` 能重复。没有它的话很多插件操作一按 . 就失效。
    setup = nil,
  },

  {
    names = 'undotree',
    pack = 'opt',
    keys = { '<leader>uU' },
    desc = '撤销树（可视化撤销历史）',
    -- 纯 vimscript 插件：没有 lua/，靠 :UndotreeToggle 命令使用。
    setup = function()
      vim.keymap.set('n', '<leader>uU', '<Cmd>UndotreeToggle<CR>', { desc = '撤销树（undotree）' })
    end,
  },

  {
    names = 'smart-splits.nvim',
    pack = 'start',
    setup = function()
      local ok, splits = pcall(require, 'smart-splits')
      if not ok then return end
      pcall(splits.setup, {
        -- 注意：这个插件是 **v3**，配置是**嵌套**的，不是扁平的。
        -- `at_edge` 在 v3 里位于 move 之下。写成顶层会被它的 check_keys() 判为
        -- 未知键，启动时弹警告「problems in your config, see :checkhealth
        -- smart-splits」—— 我最初就是那么写的。
        move = {
          -- 到边界时不要跳到别的 tmux/kitty 面板：我们没集成那些，
          -- 否则光标会「跑出」编辑器，很难理解发生了什么。
          -- v3 的默认值是 wrap（环绕），正是我们不要的行为。
          at_edge = 'stop',
        },
        -- 关掉「没检测到任何后端」的警告。
        -- 原文：none of the configured backends detected, falling back to plain
        -- window movement（backend.lua: 条件是 #specs > 0 且 warn_if_unusable）。
        -- 它的意思是「没找到 tmux/kitty/wezterm 之类的复用器集成，退回普通窗口移动」
        -- —— 对本发行版而言这**正是期望行为**，我们本来就不做复用器集成。
        -- 留着它只会在每次启动时给用户一条看不懂、也不需要处理的警告。
        mux = { warn_if_unusable = false },
      })

      local map = function(keys, fn, desc) vim.keymap.set('n', keys, fn, { desc = desc }) end
      map('<C-h>', function() splits.move_cursor_left() end, '移到左边窗口')
      map('<C-j>', function() splits.move_cursor_down() end, '移到下边窗口')
      map('<C-k>', function() splits.move_cursor_up() end, '移到上边窗口')
      map('<C-l>', function() splits.move_cursor_right() end, '移到右边窗口')
      -- 调整分屏大小（与上面同键+Shift，符合直觉）
      map('<M-h>', function() splits.resize_left() end, '向左扩')
      map('<M-l>', function() splits.resize_right() end, '向右扩')
      map('<M-j>', function() splits.resize_down() end, '向下扩')
      map('<M-k>', function() splits.resize_up() end, '向上扩')
    end,
  },

  {
    names = 'oil.nvim',
    pack = 'opt',
    keys = { '<leader>e', '-' },
    desc = '像编辑文本一样编辑目录',
    setup = function()
      pcall(require('oil').setup, {
        default_file_explorer = true,   -- 接管目录缓冲区（options.lua 里已关掉 netrw）
        columns = { 'icon' },
        view_options = { show_hidden = true },
        -- 用浮动窗口打开，避免把编辑区切成两半
        float = { padding = 2, max_width = 0.8, max_height = 0.8, border = 'rounded' },
        keymaps = {
          ['g?'] = { 'actions.show_help', mode = 'n' },
          ['<CR>'] = 'actions.select',
          ['-'] = 'actions.parent',      -- 再按 - 回到上层
          ['g.'] = { 'actions.toggle_hidden', mode = 'n' },
        },
      })
      vim.keymap.set('n', '<leader>e', function() require('oil').open() end, { desc = '目录编辑（oil）' })
      vim.keymap.set('n', '-', function() require('oil').open() end, { desc = '目录编辑（oil）' })
    end,
  },
}
