-- 语言工具：检查（lint）、Markdown 渲染、TODO 高亮。
--
-- 注意：**格式化（conform）不在这里**。它由 lua/distro/format.lua 统一调度，
-- 因为格式化要先探测命令是否存在、还涉及「保存时格式化」的策略，
-- 与插件配置放在一起会两边各写一半。这里只放「不属于格式化」的语言工具。

local AUG = vim.api.nvim_create_augroup('distro_lang', { clear = true })

return {
  {
    names = 'nvim-lint',
    pack = 'start',
    setup = function()
      local ok, lint = pcall(require, 'lint')
      if not ok then return end

      -- 只启用「确实可能可用」的 linter：
      --   shellcheck 随包分发（bin/shellcheck）✓
      --   luacheck  没有官方预编译产物，需用户自备 —— 缺了只是不检查，不该报错
      -- nvim-lint 自己会在命令不存在时静默跳过，所以这里全列上也没问题。
      pcall(lint.setup, {
        linters_by_ft = {
          sh = { 'shellcheck' },
          bash = { 'shellcheck' },
          lua = { 'luacheck' },
          -- C/C++ 用 clang-tidy（需自备）；没有就自动跳过
          c = { 'clangtidy' },
          cpp = { 'clangtidy' },
          python = { 'ruff' },
          markdown = { 'markdownlint' },
          yaml = { 'yamllint' },
        },
      })

      -- 触发时机：写入后 + 离开插入模式。
      --
      -- 曾经还挂了 TextChanged —— 那会在**每次普通模式的文本变动**
      -- （x、dd、J、p …… 每个编辑动作）时都跑一遍外部 linter，
      -- 等于敲一下键就开一批子进程，性能不可接受。
      -- nvim-lint 官方推荐的就是这两个事件。
      vim.api.nvim_create_autocmd({ 'BufWritePost', 'InsertLeave' }, {
        group = AUG,
        callback = function()
          -- 大文件不检查：search.lua 会打这个标记
          if vim.b.distro_bigfile then return end
          pcall(require('lint').try_lint)
        end,
      })
    end,
  },

  {
    names = 'render-markdown.nvim',
    pack = 'start',
    setup = function()
      -- 它的 setup 只是在 markdown 文件类型上挂 autocmd，对其它文件无影响，
      -- 所以放 start 而不是懒加载（懒加载还要额外处理「打开 md 时也要生效」）。
      local ok, render = pcall(require, 'render-markdown')
      if not ok then return end
      pcall(render.setup, {
        -- 中文排版：标题与列表的对齐依赖字符宽度（ ambiwidth 现为 single，
        -- 歧义字符按 1 格算），这里关掉「用字符拼出来的装饰」，
        -- 只保留标题符号、项目符号、代码块背景这类宽度无关的渲染。
        heading = { sign = false, icons = { ' ', ' ', ' ', ' ', ' ', ' ' } },
        bullet = { enabled = true },
        code = { style = 'full', border = 'thin' },
        checkbox = { enabled = true },
        -- 表格与链接的虚拟文本在中文下也对不齐，先关掉
        link = { enabled = false },
      })
    end,
  },

  {
    names = 'todo-comments.nvim',
    pack = 'start',
    setup = function()
      local ok, todo = pcall(require, 'todo-comments')
      if not ok then return end
      pcall(todo.setup, {
        -- 只认大写关键词，避免代码里普通的 todo 一词被高亮成注释标记
        signs = true,
        keywords = {
          FIX = { icon = 'F', color = 'error', alt = { 'FIXME', 'BUG', 'FIXIT' } },
          TODO = { icon = 'T', color = 'info' },
          HACK = { icon = 'H', color = 'warning' },
          WARN = { icon = 'W', color = 'warning', alt = { 'WARNING', 'XXX' } },
          PERF = { icon = 'P', color = 'default', alt = { 'OPTIM', 'PERFORMANCE' } },
          NOTE = { icon = 'N', color = 'hint', alt = { 'INFO' } },
        },
      })
      -- 用 fzf-lua 列出（它随包分发且是我们默认的 picker）
      vim.keymap.set('n', '<leader>xt', '<Cmd>TodoFzfLua<CR>', { desc = '列出 TODO/FIXME（fzf）' })
      vim.keymap.set('n', '<leader>xq', '<Cmd>TodoQuickFix<CR>', { desc = 'TODO 进 quickfix' })
      -- 逐条跳转用 mini.bracketed 已给的 ]t / [t（mini.bracketed 里就叫 treesitter 那个是 ]T）
      -- 这里再补一对 alt 键，避免与 ]t 的语义混淆
      vim.keymap.set('n', ']T', function() require('todo-comments').jump_next() end, { desc = '下一个 TODO' })
      vim.keymap.set('n', '[T', function() require('todo-comments').jump_prev() end, { desc = '上一个 TODO' })
    end,
  },
}
