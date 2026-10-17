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
    names = 'markview.nvim',
    pack = 'opt',
    setup = function()
      -- Typora 式 hybrid 编辑：光标所在节点显示源码、其余渲染成成品。
      --
      -- 为什么声明 opt 却在启动时 packadd：它自带 plugin/markview.lua，
      -- 靠 FileType/BufRead 钩子按文件类型启用；真正的「懒」由它自己做。
      -- 上游 README 明确警告「不要再用 lazy 包一层」，否则预览出现得更慢。
      -- 与 render-markdown 的关系：两者互斥（同时开会互相覆盖虚拟文本），
      -- 已在 catalog 的同一互斥格里，这里只装 markview 一个。
      local ok, markview = pcall(require, 'markview')
      if not ok then return end

      pcall(markview.setup, {
        preview = {
          -- 该选项是**模式白名单**，不是「默认值」：留空等于 hybrid 永不启用。
          -- 只开 normal（浏览时渲染、一进插入/可视就退回原文，避免边打字边
          -- 重排导致的跳动），这正是 Typora 的手感。想连插入模式也渲染，
          -- 把 'i' 加进来即可。
          hybrid_modes = { 'n' },
          -- 光标所在行上下各保留 0 行原文：只有光标真正所处的那一段是源码。
          edit_range = { 0, 0 },
          -- 图标沿用发行版主用的 mini.icons（ui.lua 里已经接好 MiniIcons）；
          -- 备选值是 "internal" 与 "devicons"。
          icon_provider = 'mini',
        },
        markdown = {
          headings = {
            -- 关掉「org 式按层级缩进」。中文排版下缩进会让标题与正文的
            -- 视觉对齐变得可疑，且它依赖字符宽度计算（本项目 ambiwidth=single）。
            -- 0 表示不额外加缩进字符，标题靠字号/颜色区分。
            org_shift_width = 0,
          },
        },
      })

      -- 手动开关。默认已按上面的白名单启用，这里只是给一个随时切回去的入口。
      vim.keymap.set('n', '<leader>um', '<cmd>Markview HybridToggle<cr>',
        { desc = '开关：Markdown 渲染（hybrid）' })
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
