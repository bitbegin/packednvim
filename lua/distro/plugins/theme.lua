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

      -- 窗口分隔线加清晰度。
      --
      -- 反馈：从搜索结果回车跳转后，「新窗口和老窗口界限不明显」。
      -- 分屏边界由 WinSeparator 高亮组着色，tokyonight 给它的默认色
      -- 在深背景上偏淡，两个窗口并排时看不出边界在哪。
      --
      -- 取色策略：**借用 FloatBorder 的前景色**。浮动窗口（fzf、dressing、
      -- 各类弹窗）的边框每个主题都会刻意调成清晰可见，让普通分屏线
      -- 与它们同色，既解决了可见性，视觉上也统一 —— 所有的「框」是一个颜色。
      -- 用 ColorScheme 自动命令而不是直接设一次，是为了切主题
      -- （:colorscheme kanagawa 等）后仍然生效。
      --
      -- 另外把当前标签页加粗：跳转会开新标签页（switchbuf=usetab,newtab），
      -- 多个标签页时一眼认出刚跳到的那页。
      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('distro_theme_boundary', { clear = true }),
        callback = function()
          local border = vim.api.nvim_get_hl(0, { name = 'FloatBorder', link = false })
          if border and border.fg then
            vim.api.nvim_set_hl(0, 'WinSeparator', { fg = border.fg, bold = true })
          end
          vim.api.nvim_set_hl(0, 'MiniTablineCurrent', { bold = true })
        end,
      })
    end,
  },
}
