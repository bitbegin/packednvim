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
    end,
  },
}
