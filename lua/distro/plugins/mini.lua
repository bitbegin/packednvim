-- mini.nvim —— 本发行版的「主心骨」。
--
-- 已定的决策：主心骨用 mini 而不是 snacks.nvim。理由：
--   1. mini 是**一个仓库、45+ 个独立模块**，每个模块只做一件事且默认不开任何东西，
--      没有隐藏的联网/文件行为 —— 对离线发行版是最省心的形态。
--   2. 它由一个人长期维护、API 稳定、几乎不引入外部依赖。
--   3. snacks 功能更炫但耦合更深、默认行为更多，与「可预测」的目标有冲突。
--
-- 这里显式列出启用哪些模块。**没启用的也一并注明为什么不启用** ——
-- 否则以后有人会以为漏了。

local M = {}

-- 供 misc.lua 复用（把 mini 的一些模块挂到用户命令上）
-- 模块名以 mini.nvim 实际提供的为准（曾凭记忆写成 basename/hips，并不存在）。
M.enabled = {
  'ai', 'align', 'animate', 'bracketed', 'bufremove',
  'clue', 'comment', 'cursorword', 'diff', 'extra', 'files', 'git',
  'hipatterns', 'icons', 'indentscope', 'jump', 'map',
  'notify', 'operators', 'pairs', 'sessions', 'splitjoin',
  'starter', 'surround', 'tabline', 'trailspace', 'visits',
}

-- 有意不启用的模块及原因（写在这里，免得被当成遗漏）：
--   completion  用 blink.cmp（性能与 LSP 集成更好，且已有官方预编译库）
--   fuzzy/pick  用 fzf-lua（需求 4 明确要 fzf，且我们随包带了 fzf 本体）
--   statusline  用 lualine（中文用户的常见习惯，且配置更直观）
--   input       用 dressing.nvim（与 fzf-lua 的 UI 风格更一致）
--   test        需要语言特定的测试运行器，属于 full 档位，不在本发行版范围
--   deps/doc    面向插件开发，普通用户用不到
--   sessions    已启用（见下）

return {
  {
    names = 'mini.nvim',
    pack = 'start',
    setup = function()
      -- mini.nvim 的推荐用法是逐个 require 模块并 setup，
      -- 而不是 require('mini') —— 后者会加载全部模块，启动开销明显。
      local disabled = {}

      for _, name in ipairs(M.enabled) do
        local ok, mod = pcall(require, 'mini.' .. name)
        if not ok then
          disabled[#disabled + 1] = name
        else
          -- 每个模块的默认配置基本都是「关」或「保守」，所以空表 setup 是合理的起点；
          -- 下面只对少数需要显式开启的模块做配置。
          local cfg = {}

          if name == 'icons' then
            -- 已定：图标强依赖 Nerd Font（vim.g.have_nerd_font 在 options.lua 里设为 true）
            cfg = { use_filetype = true }
          elseif name == 'indentscope' then
            -- 缩进线用 ASCII '|' 而不是 '│'：后者（U+2502）属于东亚「歧义宽度」
            -- 字符，在 ambiwidth=double 下会占 2 格，缩进线就和正文错位了。
            -- 与 options.lua 里 listchars 用 ASCII 是同一类取舍。
            cfg = { symbol = '|', options = { try_as_border = true } }
          elseif name == 'starter' then
            -- 空启动页：不显示「最近文件」这类可能泄露路径信息的内容，
            -- 换成明确的按键入口。中文界面，因为目标用户是中文用户。
            cfg = {
              header = table.concat({
                '',
                '  packednvim —— 离线 Neovim 发行版',
                '',
                '  所有插件与工具都已随包分发，运行时不联网',
                '',
              }, '\n'),
              items = {
                { name = '打开文件', action = 'enew', section = '操作' },
                { name = '查找文件          <leader>sf', action = 'lua require("fzf-lua").files()', section = '操作' },
                { name = '全项目搜索        <leader>sg', action = 'lua require("fzf-lua").grep_project()', section = '操作' },
                { name = '最近文件          <leader>sn', action = 'lua require("distro.plugins.misc").recent_files()', section = '操作' },
                { name = '恢复会话          <leader>ss', action = 'lua MiniSessions.select()', section = '操作' },
                { name = '健康检查          :checkhealth distro', action = 'checkhealth distro', section = '帮助' },
                { name = '退出              q', action = 'qa', section = '帮助' },
              },
            }

            -- 打开真实文件后让启动页自己消失，连它的窗口一起收掉。
            --
            -- 不做这一步的话，启动页会一直占着一个横向窗口：从搜索结果跳转之后
            -- 屏幕上就成了「启动页 + 文件 + quickfix」三个横条，编辑区被压得很小。
            -- 这是从实际使用里发现的，mini.starter 自身不会替你关。
            --
            -- 实现上刻意**不**用 User MiniStarterOpened 再嵌一层 BufEnter：
            -- 那样要依赖 mini.starter 在事件里传了什么参数。直接在 BufEnter 里
            -- 按 filetype 找启动页缓冲区，简单、不依赖对方实现，也好测。
            vim.api.nvim_create_autocmd('BufEnter', {
              group = vim.api.nvim_create_augroup('distro_starter_close', { clear = true }),
              callback = function()
                if vim.bo.filetype == 'ministarter' then return end
                for _, b in ipairs(vim.api.nvim_list_bufs()) do
                  if vim.api.nvim_buf_is_valid(b) and vim.bo[b].filetype == 'ministarter' then
                    -- 先记下它所在的窗口：只删缓冲区会留一个空窗口，那和没删差不多
                    local win = nil
                    for _, w in ipairs(vim.api.nvim_list_wins()) do
                      if vim.api.nvim_win_get_buf(w) == b then win = w end
                    end
                    pcall(vim.api.nvim_buf_delete, b, { force = true })
                    if win and vim.api.nvim_win_is_valid(win) and #vim.api.nvim_list_wins() > 1 then
                      pcall(vim.api.nvim_win_close, win, true)
                    end
                  end
                end
              end,
            })
          elseif name == 'sessions' then
            -- 会话文件放在发行版自己的 state 目录，不污染 stdpath('state') 的其它内容。
            -- mini.sessions 不会替你建目录，所以这里先建好。
            local dir = vim.fn.stdpath('state') .. '/sessions'
            vim.fn.mkdir(dir, 'p')
            cfg = { directory = dir }
          elseif name == 'notify' then
            -- 用 mini.notify 接管 vim.notify：消息有历史、可回看，且不打断输入
            cfg = { lsp_progress = { enable = false } }
          elseif name == 'clue' then
            -- 与 which-key 分工：which-key 管前导键（<leader> 之后），
            -- clue 管内置的 g / z / 寄存器 / 窗口等前缀键。
            --
            -- 注意 API：**全局触发器**的 keys 必须是单个字符串，一个前缀一条；
            -- 传成列表会报 E1174（String required for argument 1）。
            cfg = {
              triggers = {
                { mode = 'n', keys = 'g' },
                { mode = 'n', keys = 'z' },
                { mode = 'n', keys = "'" },
                { mode = 'n', keys = '"' },
                { mode = 'n', keys = '<C-w>' },
                { mode = 'x', keys = 'g' },
              },
            }
          elseif name == 'files' then
            cfg = { windows = { preview = true, width_preview = 60 } }
          elseif name == 'map' then
            cfg = { window = { config = { relative = 'editor', border = 'rounded' } } }
          end

          local ok2, err = pcall(mod.setup, cfg)
          if not ok2 then
            vim.notify(('distro: mini.%s.setup() 出错：%s'):format(name, err), vim.log.levels.WARN)
          end
        end
      end

      if #disabled > 0 then
        vim.notify(('distro: 以下 mini 模块不可用（mini.nvim 版本较旧？）：%s')
          :format(table.concat(disabled, ', ')), vim.log.levels.WARN)
      end
    end,
  },
}
