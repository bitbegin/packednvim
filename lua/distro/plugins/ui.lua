-- 界面：状态栏 / 键位提示 / LSP 进度 / 输入框 / 图标。
--
-- 这里的选择都是「与 mini 主心骨不重复」的：
--   lualine      取代 mini.statusline（中文用户更熟悉，配置直观）
--   which-key    管 <leader> 之后的前缀；mini.clue 管 g/z/寄存器等内置前缀
--   dressing     取代 mini.input，让输入框与 fzf-lua 的视觉风格一致
--   devicons     mini.icons 负责图标，devicons 只补它缺的品牌图标
--   fidget       LSP 进度显示；通知本身交给 mini.notify

local function bundled(name)
  local root = vim.g.distro_root or ''
  return root .. '/bin/' .. name
end

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
          lualine_x = { 'filetype', 'encoding', 'fileformat' },
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
        -- 图标故意用 ASCII：`»` `➜` 这类属于东亚「歧义宽度」字符，
        -- 在 ambiwidth=double 下会占两格，弹窗里容易错位。
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
          -- 通知统一走 mini.notify，别再让 fidget 也接管一次 vim.notify
          override_vim_notify = false,
        },
      })
    end,
  },

  {
    names = 'dressing.nvim',
    pack = 'start',
    setup = function()
      require('dressing').setup({
        input = { border = 'rounded', winblend = 0 },
        select = {
          -- 优先用 fzf-lua 做选择界面：与本发行版的默认 picker 视觉一致
          backend = { 'fzf_lua', 'builtin' },
          builtin = { border = 'rounded' },
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
