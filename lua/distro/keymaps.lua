-- 通用键位。
--
-- 分工（避免同一个键被两处定义）：
--   search.lua  搜索相关（<leader>s*）
--   lsp.lua     LSP 与诊断（gd / gr / K / <leader>c*，在 LspAttach 里按缓冲区设）
--   plugins/*   各插件自己的键位
--   本文件      纯内置能力能做的事，不依赖任何插件
--
-- 全部带 desc：which-key 靠它显示说明，缺了 desc 的键位在提示里是空白的。

local M = {}

local map = vim.keymap.set

function M.setup()
  -- -------------------------------------------------------------------------
  -- 保存与退出
  -- -------------------------------------------------------------------------
  map({ 'n', 'i', 'v' }, '<C-s>', function()
    if vim.bo.modifiable then
      vim.cmd('write')
    end
  end, { desc = '保存' })

  map('n', '<leader>qq', '<Cmd>qa<CR>', { desc = '退出全部' })
  map('n', '<leader>qw', '<Cmd>wqa<CR>', { desc = '保存并退出全部' })

  -- -------------------------------------------------------------------------
  -- 缓冲区与窗口
  -- -------------------------------------------------------------------------
  map('n', '<S-l>', '<Cmd>bnext<CR>', { desc = '下一个缓冲区' })
  map('n', '<S-h>', '<Cmd>bprevious<CR>', { desc = '上一个缓冲区' })
  map('n', '<leader>bd', function()
    -- 用 mini.bufremove：关掉缓冲区但保留窗口布局，避免整屏塌掉
    local ok, bufremove = pcall(require, 'mini.bufremove')
    if ok then bufremove.delete(0, false) else vim.cmd('bdelete') end
  end, { desc = '关闭当前缓冲区（保留窗口）' })

  map('n', '<leader>wv', '<Cmd>vsplit<CR>', { desc = '垂直分屏' })
  map('n', '<leader>ws', '<Cmd>split<CR>', { desc = '水平分屏' })
  map('n', '<leader>wo', '<Cmd>only<CR>', { desc = '只保留当前窗口' })

  -- -------------------------------------------------------------------------
  -- 移动（中文/折行友好）
  -- -------------------------------------------------------------------------
  -- j/k 按屏幕行移动：开了 wrap 之后，长中文行用 j 跳整段会很难受
  map({ 'n', 'x' }, 'j', 'gj', { desc = '下移（屏幕行）' })
  map({ 'n', 'x' }, 'k', 'gk', { desc = '上移（屏幕行）' })
  map('n', '<C-d>', '<C-d>zz', { desc = '下半页并居中' })
  map('n', '<C-u>', '<C-u>zz', { desc = '上半页并居中' })
  map('n', 'n', 'nzzzv', { desc = '下一个匹配并居中' })
  map('n', 'N', 'Nzzzv', { desc = '上一个匹配并居中' })

  -- -------------------------------------------------------------------------
  -- 粘贴与剪贴板
  -- -------------------------------------------------------------------------
  -- 可视模式下粘贴不覆盖寄存器：连续粘贴同一段内容时不会越粘越少
  map('x', '<leader>p', '"_dP', { desc = '粘贴且不覆盖寄存器' })
  map({ 'n', 'v' }, '<leader>y', '"+y', { desc = '复制到系统剪贴板' })
  map('n', '<leader>Y', '"+Y', { desc = '复制整行到系统剪贴板' })

  -- -------------------------------------------------------------------------
  -- 杂项
  -- -------------------------------------------------------------------------
  map('n', '<Esc>', '<Cmd>nohlsearch<CR>', { desc = '清除搜索高亮' })
  map('n', '<leader>ur', '<Cmd>update<CR><Cmd>edit<CR>', { desc = '重载当前文件' })
  -- 用 <C-c> 代替 <Esc> 退出插入模式时不该触发自动补全，这里统一一下
  map('i', '<C-c>', '<Esc>', { desc = '退出插入模式' })

  -- 中文写作常用：把当前段落按 <textwidth> 重排
  map('n', '<leader>gq', 'gqip', { desc = '重排当前段落' })

  -- 快速打开命令行窗口与消息
  map('n', '<leader>:', 'q:', { desc = '命令行历史（可编辑）' })
  map('n', '<leader>m', '<Cmd>messages<CR>', { desc = '查看消息' })
end

return M
