-- 主题。
--
-- 已定：6 套主题随包分发，tokyonight 为默认。
-- 其余 5 套（catppuccin / kanagawa / gruvbox-material / nightfox / rose-pine）
-- 都只是「装了、可选」，不在这里 setup —— 用户 `:colorscheme kanagawa` 就能切。
-- 这样做的好处是启动时不加载它们的 Lua 模块，也不需要在配置里堆 6 个 if。

return {
  {
    names = 'tokyonight.nvim',
    pack = 'start',
    setup = function()
      require('tokyonight').setup({
        style = 'night', -- night / storm / moon / day 四选一，night 对比度最舒服
        transparent = false,
        terminal_colors = true,
        styles = {
          comments = { italic = true },
          keywords = { italic = true },
          -- 函数名不加粗：中文注释混排时粗体容易糊成一团
          functions = {},
          variables = {},
        },
        -- 关闭它自带的「当前行暗化」等额外效果，避免与 mini.hipatterns 打架
        dim_inactive = false,
        lualine_bold = false,
      })

      -- 立刻应用，避免启动时先闪一下 Neovim 默认配色
      pcall(vim.cmd.colorscheme, 'tokyonight')

      -- 窗口边界与标签页的可见性。
      --
      -- 反馈：从搜索结果回车跳转后，「新窗口和老窗口界限不明显」。
      -- 分屏边界由 WinSeparator 着色，tokyonight 默认给它的 #15161e
      -- 在 #1a1b26 的背景上几乎看不见。
      --
      -- 执行时机是这里的全部难点：我最初挂在 ColorScheme 上同步执行，
      -- 实测被后加载的组件覆盖（WinSeparator 回到 #15161e、
      -- MiniTablineCurrent 的 bold 丢失）—— **时机不对的高亮修改等于没改**。
      -- 所以这里用 VimEnter + ColorScheme 两个入口，并 vim.schedule
      -- 推迟到本轮事件循环末尾：所有插件都上完色之后再改。
      --
      -- 取色策略：分隔线借用 FloatBorder 的前景色 —— 浮动窗口（fzf、dressing、
      -- 弹窗）的边框每个主题都刻意调成清晰可见，让普通分屏线与它同色，
      -- 所有的「框」视觉统一。当前标签页则只叠加 bold（先读现有定义再改，
      -- 因为 nvim_set_hl 是整体替换，直接给 { bold = true } 会丢掉主题配色）。
      local function make_boundaries_visible()
        vim.schedule(function()
          local fb = vim.api.nvim_get_hl(0, { name = 'FloatBorder', link = false })
          if fb and fb.fg then
            local ws = vim.api.nvim_get_hl(0, { name = 'WinSeparator' })
            ws.fg = fb.fg
            ws.bold = true
            vim.api.nvim_set_hl(0, 'WinSeparator', ws)
          end
          local cur = vim.api.nvim_get_hl(0, { name = 'MiniTablineCurrent' })
          if cur and next(cur) ~= nil then
            cur.bold = true
            vim.api.nvim_set_hl(0, 'MiniTablineCurrent', cur)
          end
        end)
      end
      local aug = vim.api.nvim_create_augroup('distro_theme_boundary', { clear = true })
      vim.api.nvim_create_autocmd('ColorScheme', { group = aug, callback = make_boundaries_visible })
      vim.api.nvim_create_autocmd('VimEnter', { group = aug, callback = make_boundaries_visible })
    end,
  },
}
