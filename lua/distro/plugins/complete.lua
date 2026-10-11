-- 补全与片段：blink.cmp + LuaSnip + friendly-snippets + lazydev。
--
-- 一个重要背景：blink.cmp **钉在 v1.10.2**（main 上的 v2 尚未发布，且额外依赖
-- saghen/blink.lib）。所以这里的配置项是 v1 的形状 —— 例如 signature.enabled。
-- 若将来升到 v2，配置写法会变，不能直接照搬。

return {
  {
    names = 'blink.cmp',
    pack = 'start',
    setup = function()
      local ok, blink = pcall(require, 'blink.cmp')
      if not ok then return end
      pcall(blink.setup, {
        keymap = { preset = 'default' },
        -- 已定：Nerd Font 强依赖；mono 变体在等宽字体下对齐更稳
        appearance = { nerd_font_variant = 'mono' },

        completion = {
          -- 文档不自动弹：中文注释混排时它会盖住代码，需要时按 <C-k> 看
          documentation = { auto_show = false, auto_show_delay_ms = 300 },
          menu = { border = 'rounded' },
          ghost_text = { enabled = false },   -- 幽灵文本与中文宽度叠加容易错位
          list = { selection = { preselect = false } },  -- 不要替我预选，避免误回车
        },

        sources = {
          -- 顺序即优先级：LSP 最可信，buffer 兜底
          default = { 'lsp', 'path', 'snippets', 'buffer' },
        },

        snippets = { preset = 'luasnip' },

        -- 随包已经预置了原生模糊匹配库（CI 里从官方 release 取并校验 sha256），
        -- 所以这里明确「优先用 rust，缺了才警告并退回 Lua」。
        -- 退回 Lua 也能用，只是慢 —— 这正是我们要的降级方式。
        fuzzy = { implementation = 'prefer_rust_with_warning' },

        signature = { enabled = true },
      })
    end,
  },

  {
    names = 'LuaSnip',
    pack = 'start',
    setup = function()
      local ok, luasnip = pcall(require, 'luasnip')
      if not ok then return end
      pcall(luasnip.setup, {
        history = true,
        updateevents = 'TextChanged,TextChangedI',
        enable_autosnippets = true,
      })

      -- friendly-snippets 是纯数据仓库（没有 lua/ 目录），要显式加载才会生效。
      -- 不加载的话 LuaSnip 是没有片段的空壳。
      pcall(function()
        require('luasnip.loaders.from_vscode').lazy_load()
      end)

      -- 跳转键位。blink 的 preset 已经给了 <C-n>/<C-p> 用于菜单，
      -- 这里只补「在片段占位符之间跳」——它只在片段激活时生效，不冲突。
      vim.keymap.set({ 'i', 's' }, '<C-l>', function()
        if luasnip.expand_or_locally_jumpable() then luasnip.expand_or_jump() end
      end, { desc = '展开片段 / 跳到下一个占位符' })
      vim.keymap.set({ 'i', 's' }, '<C-h>', function()
        if luasnip.locally_jumpable(-1) then luasnip.jump(-1) end
      end, { desc = '跳到上一个占位符' })
    end,
  },

  {
    names = 'friendly-snippets',
    pack = 'start',
    -- 纯数据仓库：没有 lua/、没有 setup()，由上面 LuaSnip 那段 lazy_load 加载。
    -- 单独列出来是为了让「它为什么在包里」有据可查。
    setup = nil,
  },

  {
    names = 'lazydev.nvim',
    pack = 'start',
    setup = function()
      local ok, lazydev = pcall(require, 'lazydev')
      if not ok then return end
      -- 写 Neovim 配置时让 lua_ls 认识 vim.* 与 luv，并把发行版自己的 lua/ 也加进去。
      -- 没有它的话，编辑本发行版的配置会满屏「未定义的全局 vim」。
      pcall(lazydev.setup, {
        library = {
          { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
          { path = (vim.g.distro_root or '') .. '/lua', words = { 'distro' } },
        },
      })
    end,
  },
}
