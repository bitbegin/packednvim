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
  'comment', 'extra',
  'hipatterns', 'icons', 'indentscope', 'jump', 'map',
  'operators', 'pairs', 'sessions', 'splitjoin',
  'starter', 'surround', 'tabline', 'trailspace', 'visits',
}

-- 选型审查（2026-10）后**有意不再启用**的模块，原因是与专精插件撞了职责：
--   clue       —— 键位提示由 which-key 承担（用户确认：按键记不住，先要
--                 which-key，熟练后再评估切回）。另外 clue 的 <leader> 触发
--                 在其内部表示法下查询恒空（映射 LHS 的原始字节 vs
--                 keytrans 符号形式，见 git 历史同名提交）。
--   cursorword —— 光标词高亮，与 vim-illuminate（LSP 引用高亮）双重高亮同一批词
--   diff       —— 符号列 diff 标记，与 gitsigns 的 + ~ _ 画在同一列
--   git        —— hunk 操作，gitsigns 已全部覆盖且 <leader>g* 键位已接好
--   files      —— 与 oil 同属「文件浏览器」互斥格；check-stack 的一格一赢家
--                 否决了双入口（见 catalog/STACKS.toml），文件浏览由 oil 承担
--   notify     —— 从未把 vim.notify 接线到它，纯死重量；通用通知走原生 cmdline
-- mini.nvim 整体是一个仓库，禁用模块不省体积 —— 省的是启动时间与「双重行为」。

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
          elseif name == 'animate' then
            -- 关掉**光标移动**的动画，保留窗口/滚动那几个。
            --
            -- 原因来自实际使用反馈：默认开启的 cursor 动画会让「点击鼠标」变成
            -- 光标从当前位置滑到点击处的效果。本意是好看，用起来却像卡顿或漂移
            -- —— 尤其点击是高频操作，每次都滑一下很干扰。
            -- scroll/resize/open/close 那几个不改变光标位置，留着无妨。
            cfg = {
              cursor = { enable = false },
              scroll = { enable = true },
              resize = { enable = true },
              open = { enable = true },
              close = { enable = true },
            }
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
              -- 注意：这里显示的键位提示必须与真实映射一致 —— 曾经写错过三个
              -- （sf/sn/ss），而真实映射是 ff/fr + 当时 ss 根本没注册。
              items = {
                { name = '打开文件', action = 'enew', section = '操作' },
                { name = '查找文件          <leader>ff', action = 'lua require("fzf-lua").files()', section = '操作' },
                { name = '全项目搜索        <leader>sg', action = 'lua require("fzf-lua").grep_project()', section = '操作' },
                { name = '最近文件          <leader>fr', action = 'lua require("distro.plugins.misc").recent_files()', section = '操作' },
                { name = '恢复会话', action = 'lua MiniSessions.select()', section = '操作' },
                { name = '恢复上次搜索    <leader>ss', action = 'lua require("fzf-lua").resume()', section = '操作' },
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

                -- 只在「真的进入了文件缓冲区」时才收起启动页。
                --
                -- 这里曾漏掉一类缓冲区，后果很显眼：在启动页上按 <leader>sG，
                -- copen 先建出结果窗口并把光标挪进去 → BufEnter 触发 →
                -- 启动页所在的编辑窗口被当成「多余窗口」关掉，最后只剩一个
                -- 10 行的 quickfix 窗口，下面整屏空白（状态栏看起来「跑到
                -- 屏幕上半部分」）。
                --
                -- 所以判据不能只排除 ministarter，还要排除所有非普通缓冲区：
                -- buftype 非空（quickfix / nofile / terminal / prompt / help …）
                -- 或者没有文件名（:enew 出来的暂存缓冲）。
                if vim.bo.buftype ~= '' then return end
                if vim.api.nvim_buf_get_name(0) == '' then return end
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
            -- 刻意**不**注册 <leader>ss：它归 lua/distro/search.lua 的「fzf resume」
            -- 所有。这里曾注册过一份 MiniSessions.select，但 plugins 分组先于
            -- search 模块加载，同键后定义者胜 —— 这份映射从未真正生效过，
            -- 只会让「谁拥有 ss」变成两处各说各话。恢复会话的入口就是启动页
            -- 那一项；想绑键请在 .local/config/user.lua 里加。
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
