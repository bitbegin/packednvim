-- 杂项：诊断列表、启动耗时、以及几个被别处引用的辅助入口。
--
-- 注意这个文件的结构：返回的是一个**数组**（注册表用 ipairs 遍历），
-- 但另外挂了具名函数 `recent_files`。数组部分不受影响，而 mini.starter 里
-- 「最近文件」那一项的动作字符串引用的就是这里 —— 之前那个函数不存在，
-- 也就是说按下去会报错。这是一个「配置里引用了尚未实现的东西」的典型漏网。

local specs = {
  {
    names = 'trouble.nvim',
    pack = 'opt',
    keys = { '<leader>xx', '<leader>xX', '<leader>xs' },
    desc = '诊断/引用/符号列表面板',
    setup = function()
      pcall(require('trouble').setup, {
        -- 浮动窗口，不切走编辑区
        win = { type = 'float', border = 'rounded' },
        -- 不要自动打开：诊断数量变化时弹窗会打断输入
        auto_open = false,
        auto_close = false,
        auto_preview = true,
      })
      vim.keymap.set('n', '<leader>xx', '<Cmd>Trouble diagnostics toggle<CR>', { desc = '诊断列表（trouble）' })
      vim.keymap.set('n', '<leader>xX', '<Cmd>Trouble diagnostics toggle filter.buf=0<CR>', { desc = '当前文件诊断（trouble）' })
      vim.keymap.set('n', '<leader>xs', '<Cmd>Trouble symbols toggle<CR>', { desc = '符号列表（trouble）' })
      vim.keymap.set('n', '<leader>xr', '<Cmd>Trouble lsp_references toggle<CR>', { desc = '引用列表（trouble）' })
    end,
  },

  {
    names = 'vim-startuptime',
    pack = 'opt',
    keys = { '<leader>ut' },
    desc = '查看启动耗时明细',
    -- 纯 vimscript 插件（没有 lua/ 目录），提供 :StartupTime 命令。
    -- 它的输出按插件聚合，是排查「哪个 start 插件拖慢启动」最直接的工具 ——
    -- 本发行版装了 30 个 start 插件，这个入口值得放在手边。
    setup = function()
      vim.keymap.set('n', '<leader>ut', '<Cmd>StartupTime<CR>', { desc = '启动耗时（vim-startuptime）' })
    end,
  },
}

--- 列出最近访问的文件。
--
-- mini.starter 的「最近文件」项调用这个函数，所以它必须存在且可用。
-- 优先用 mini.visits（它记录访问频率与时间，比 :oldfiles 更有用）；
-- 拿不到就退回 fzf-lua 的 oldfiles，保证这一项任何时候都不会「按了没反应」。
function specs.recent_files()
  local ok, visits = pcall(require, 'mini.visits')
  if ok and type(visits.select) == 'function' then
    local ok2 = pcall(visits.select)
    if ok2 then return end
  end
  local ok3, fzf = pcall(require, 'fzf-lua')
  if ok3 and type(fzf.oldfiles) == 'function' then
    pcall(fzf.oldfiles)
    return
  end
  vim.notify('distro: 最近文件不可用（mini.visits 与 fzf-lua 都取不到）', vim.log.levels.WARN)
end

return specs
