-- 界面：状态栏 / 键位提示 / LSP 进度 / 输入框 / 图标。
--
-- 这里的选择都是「与 mini 主心骨不重复或经用户确认」的：
--   lualine      取代 mini.statusline（中文用户更熟悉，配置直观）
--   which-key    键位提示（<leader> 与内置前缀）。曾与 mini.clue 并存造成
--                双重弹窗，选型审查后二选一；后因 clue 的 <leader> 触发在
--                其内部表示法下失效、且用户确认先要 which-key，
--                2026-10 起由 which-key 独占该职责（clue 已在 mini.lua 禁用）
--   dressing     取代 mini.input，让输入框与 fzf-lua 的视觉风格一致
--   devicons     mini.icons 负责图标，devicons 只补它缺的品牌图标
--   fidget       LSP 进度显示

return {
  {
    names = 'lualine.nvim',
    pack = 'start',
    setup = function()
      require('lualine').setup({
        options = {
          theme = 'auto', -- 跟随当前 colorscheme，换主题时状态栏不用另配
          globalstatus = true,
          component_separators = { left = '', right = '' },
          section_separators = { left = '', right = '' },
          disabled_filetypes = { statusline = { 'starter', 'alpha', 'dashboard' } },
        },
        sections = {
          lualine_a = { 'mode' },
          lualine_b = { 'branch', 'diff' },
          lualine_c = {
            { 'filename', path = 1, symbols = { modified = ' ●', readonly = ' ' } },
            { 'diagnostics', sources = { 'nvim_lsp' }, symbols = { error = 'E', warn = 'W', info = 'I', hint = 'H' } },
          },
          lualine_x = {
          'filetype',
          -- encoding 用自定义组件，**不用**内置的 'encoding'。
          -- 原因：lualine 内置实现是 vim.opt.fileencoding:get()，在本 nightly
          -- （0.13-dev-1828）上**无条件抛 E21**（普通缓冲也能复现，不是
          -- nomodifiable 的问题）。多数刷新路径被 lualine 自己的 pcall 静默吞掉，
          -- 但 scheduled 刷新会把错误弹出来要求按回车，非常打扰。
          -- 这里用 vim.bo 读取等价信息（含 BOM 标记），读操作永不抛 E21。
          -- （fileformat.lua 用的是 vim.bo.fileformat，无此问题，保留内置组件。）
          function()
            local enc = vim.bo.fileencoding ~= '' and vim.bo.fileencoding or vim.o.encoding
            return vim.bo.bomb and (enc .. ' [BOM]') or enc
          end,
          'fileformat',
        },
          lualine_y = { 'progress' },
          lualine_z = { 'location' },
        },
        -- 大文件里关掉 diff 与诊断段：那些都需要额外计算
        tabline = {},
      })
    end,
  },

  {
    names = 'which-key.nvim',
    pack = 'start',
    setup = function()
      require('which-key').setup({
        preset = 'modern',
        -- 图标故意用 ASCII：在 ambiwidth=double 时代防错位。现在 single 已
        -- 解除约束，保持 ASCII 是实测过的稳定选择。
        icons = { breadcrumb = '>', separator = '->', group = '+' },
        -- 每个键位都设了 desc（见 keymaps.lua 与各插件配置），所以这里不需要额外 spec
        spec = {},
        win = { border = 'rounded', padding = { 1, 2 } },
      })
    end,
  },

  {
    names = 'fidget.nvim',
    pack = 'start',
    setup = function()
      require('fidget').setup({
        progress = {
          suppress_on_insert = true, -- 插入模式下不弹进度，避免挡住补全菜单
          ignore_done_already = true,
        },
        notification = {
          -- 通用通知走 Neovim 原生 cmdline 显示。
          -- （mini.notify 曾在启用清单里，但从未被接线成 vim.notify 的后端，
          --   纯死重量，选型审查后已禁用。若想要弹窗式通用通知，
          --   把这里改成 true 让 fidget 接管即可。）
          override_vim_notify = false,
        },
      })
    end,
  },

  {
    names = 'dressing.nvim',
    pack = 'start',
    setup = function()
      -- 覆盖 listchars 的原因（这是一个真会崩的地方）：
      --   dressing 的默认 win_options 里写着 listchars = "precedes:…,extends:…"，
      --   而 `…`（U+2026）是东亚「歧义宽度」字符 —— 在 ambiwidth=double 下它占 2 格，
      --   而 listchars 要求这些字段必须是 1 格，于是直接抛
      --     E1512: wrong character width for field "precedes"
      --   触发路径：任何走 vim.ui.input 的操作，例如 <leader>sG（要输入正则）。
      --
      -- 这是「CJK 正确宽度」与「插件假定字符恒为 1 格」的冲突，责任在插件的假设。
      -- 本发行版面向中文用户，所以按插件修正。
      --
      -- 写法上刻意只覆盖 listchars 这一个键：dressing.setup 是深度合并，
      -- 其余 win_options 默认值会保留。（覆盖式配置丢掉默认值，我在这上面栽过。）
      local win_options = { listchars = 'precedes:<,extends:>' }

      require('dressing').setup({
        input = { border = 'rounded', winblend = 0, win_options = win_options },
        select = {
          -- 优先用 fzf-lua 做选择界面：与本发行版的默认 picker 视觉一致
          backend = { 'fzf_lua', 'builtin' },
          builtin = { border = 'rounded', win_options = win_options },
        },
      })
    end,
  },

  {
    names = 'nvim-web-devicons',
    pack = 'start',
    setup = function()
      require('nvim-web-devicons').setup({
        -- 已定：Nerd Font 强依赖
        default = true,
        strict = false,
      })
    end,
  },
}
