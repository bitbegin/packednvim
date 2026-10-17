-- 语法：tree-sitter 高亮 / 折叠 / 缩进，以及三个围绕它的插件。
--
-- 关于 nvim-treesitter 的 API：本发行版 vendor 的是 **main 分支**，
-- 它的用法与旧的 master 分支完全不同 —— 没有 `highlight = { enable = true }`
-- 那种配置表，而是：
--   require('nvim-treesitter').setup{ install_dir = ... }
--   高亮：在 FileType 里调用 vim.treesitter.start()
--   折叠：vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
--   缩进：vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
-- 这四条都取自 vendor 目录里 README 的示例，不是凭印象写的。

local AUG = vim.api.nvim_create_augroup('distro_syntax', { clear = true })

return {
  {
    names = 'nvim-treesitter',
    pack = 'start',
    setup = function()
      local ok, ts = pcall(require, 'nvim-treesitter')
      if not ok then return end

      -- install_dir 不在这里设：CI 采集解析器时已经把它指到
      -- vendor/treesitter/site 并由 init.lua 挂上 runtimepath。
      -- 这里再设一次反而可能与打包结果不一致。
      pcall(ts.setup, {})

      -- 高亮 + 缩进：按文件类型启用
      vim.api.nvim_create_autocmd('FileType', {
        group = AUG,
        desc = 'tree-sitter 高亮与缩进',
        callback = function(ev)
          -- 大文件（search.lua 会打这个标记）不启动 treesitter：
          -- 解析一个几 MB 的单行 JSON 会把编辑体验拖垮
          if vim.b[ev.buf].distro_bigfile then return end
          pcall(vim.treesitter.start, ev.buf)
          vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })

      -- 折叠：用 treesitter 的 fold 表达式。
      -- 默认 foldlevel=99 即「全部展开」，需要折叠时才按 zc/za。
      vim.api.nvim_create_autocmd('FileType', {
        group = AUG,
        desc = 'tree-sitter 折叠',
        callback = function(ev)
          if vim.b[ev.buf].distro_bigfile then return end
          vim.wo[ev.win].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
          vim.wo[ev.win].foldmethod = 'expr'
          vim.wo[ev.win].foldlevel = 99
        end,
      })
    end,
  },

  {
    names = 'nvim-treesitter-textobjects',
    pack = 'start',
    setup = function()
      local ok, textobjects = pcall(require, 'nvim-treesitter-textobjects')
      if not ok then return end
      pcall(textobjects.setup, {
        select = { lookahead = true },
        move = { set_jumps = true },
      })

      -- 只加几个最常用的：函数/类/参数/条件。
      -- 全都绑上会让键位表膨胀，而实际高频使用就是这几个。
      local map = function(keys, fn, desc)
        vim.keymap.set({ 'x', 'o' }, keys, fn, { desc = desc })
      end
      map('af', function() require('nvim-treesitter-textobjects.select').select_textobject('@function.outer', 'textobjects') end, '函数（含外）')
      map('if', function() require('nvim-treesitter-textobjects.select').select_textobject('@function.inner', 'textobjects') end, '函数（仅内）')
      map('ac', function() require('nvim-treesitter-textobjects.select').select_textobject('@class.outer', 'textobjects') end, '类（含外）')
      map('ic', function() require('nvim-treesitter-textobjects.select').select_textobject('@class.inner', 'textobjects') end, '类（仅内）')
      map('aa', function() require('nvim-treesitter-textobjects.select').select_textobject('@parameter.outer', 'textobjects') end, '参数（含外）')
      map('ia', function() require('nvim-treesitter-textobjects.select').select_textobject('@parameter.inner', 'textobjects') end, '参数（仅内）')

      -- 在函数/类之间跳。
      -- 两个方向分开写清楚：上面那版我用循环把 ]]/[[ 绑到了同一个函数（都成了
      -- 「下一个」），是「为了少写两行」造成的错误，不值得。
      -- 模式含 n：普通模式下也要能按。
      vim.keymap.set({ 'n', 'x', 'o' }, ']]', function()
        require('nvim-treesitter-textobjects.move').goto_next_start('@function.outer', 'textobjects')
      end, { desc = '下一个函数' })
      vim.keymap.set({ 'n', 'x', 'o' }, '[[', function()
        require('nvim-treesitter-textobjects.move').goto_previous_start('@function.outer', 'textobjects')
      end, { desc = '上一个函数' })
    end,
  },

  {
    names = 'ts-comments.nvim',
    pack = 'start',
    desc = '按语法树决定注释符号',
    setup = function()
      -- 它**不提供注释键位**，而是修正 &commentstring —— JSX、嵌入式 SQL 这类
      -- 「注释符取决于语法节点」的场景由它给对；gc/gcc/gb 仍由 mini.comment 提供。
      --
      -- 必须启动即加载：它靠 FileType 事件逐缓冲区设置 commentstring，
      -- 懒加载会错过已打开的缓冲区，第一次按 gc 可能就用错注释符。
      -- 我最初把它挂在 gc/gcc/gb 上懒加载 —— 既误解了它的职责
      -- （那些键是 mini.comment 的），时机也错了（FileType 早触发过了）。
      pcall(require('ts-comments').setup, {})
    end,
  },

  {
    names = 'nvim-treesitter-context',
    pack = 'opt',
    keys = { '<leader>uc' },
    desc = '固定显示当前函数/类头部',
    setup = function()
      pcall(require('treesitter-context').setup, {
        max_lines = 3,     -- 最多 3 行，别把编辑区压掉
        multiline_threshold = 1,
        mode = 'cursor',   -- 光标所在层才显示
        separator = nil,   -- 不要分隔线，减少视觉噪音
      })
      vim.keymap.set('n', '<leader>uc', function()
        vim.cmd('TSContextToggle')
      end, { desc = '开关：固定上下文头部' })
    end,
  },
}
