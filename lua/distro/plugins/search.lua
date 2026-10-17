-- 搜索与跳转的插件侧配置。
--
-- 键位分工（这条必须写清楚，否则两套搜索会打架）：
--   <leader>s*  → 需求 5 的「rg + quickfix」工作流，实现在 lua/distro/search.lua
--                 结果**按行**列在一个窗口里，可用鼠标点击跳转
--   <leader>f*  → 需求 4 的交互式选择器（fzf-lua + 随包的 fzf）
--                 边打字边过滤，适合"先浏览再决定"
-- 两者不是重复：一个要「一眼看全、可点」，一个要「快速模糊筛」。

local function fzf_bin()
  local root = vim.g.distro_root or ''
  local exe = root .. '/bin/' .. (vim.fn.has('win32') == 1 and 'fzf.exe' or 'fzf')
  -- 随包的那份优先；万一丢了就退回 PATH 上的 fzf（fzf-lua 自己也会再兜一次底）
  if vim.fn.executable(exe) == 1 then return exe end
  return 'fzf'
end

-- 注：这里曾有一个 fd_bin()，用来把 files.cmd 指到随包的 fd。
-- 已删除 —— 那种做法会覆盖掉 fzf-lua 默认命令里带的 --exclude .git，
-- 而且没必要：启动脚本已把 <发行版>/bin 前置进 PATH。

return {
  {
    names = 'fzf-lua',
    pack = 'start',
    setup = function()
      -- 先替 fzf-lua 把 RPC server 建好（短地址），再 require 它。
      --
      -- 原因：fzf-lua 的 init.lua 在**模块加载时**就会执行
      --   serverstart("fzf-lua." .. os.time())   -- 相对名
      -- 失败直接 error()，整个模块加载不了。darwin 的 CI 冒烟首跑就是这么炸的：
      -- 相对名解析出的 socket 路径（包内 .local/tmp/... 一长串，约 111 字符）
      -- 超过了 unix domain socket 的 **104 字节**上限 -> EINVAL。
      -- Windows 用命名管道没有长度限制；Linux 上限 108、路径恰好短几字符才幸免
      -- —— 但真实用户把包装进深目录时 Linux 同样可能超限。
      --
      -- fzf-lua 留了口子：`if not vim.g.fzf_lua_server then`。
      -- 我们抢先建一个短地址（Unix 放 /tmp 下，一定存在且短），
      -- 它就跳过自己的创建。os.time + 随机数保证多实例不冲突；
      -- 万一失败则不设值，留给 fzf-lua 走它自己的路径
      -- （那样错误会照常出现在 reg.failed，冒烟能看见）。
      if not vim.g.fzf_lua_server then
        local addr = vim.fn.has('win32') == 1
            and ('fzf-lua-%d-%d'):format(os.time(), math.random(100000, 999999))
            or ('/tmp/fzf-lua-%d-%d'):format(os.time(), math.random(100000, 999999))
        local ok, srv = pcall(vim.fn.serverstart, addr)
        if ok and srv and srv ~= '' then
          vim.g.fzf_lua_server = srv
        end
      end

      local fzf = require('fzf-lua')

      fzf.setup({
        -- 关键：明确指向随包的 fzf。不设的话 fzf-lua 会去找 PATH 上的 fzf，
        -- 找不到就报 'fzf' is not a valid executable —— 那正是离线发行版最该避免的。
        fzf_bin = fzf_bin(),

        -- 刻意**不**设置 files.cmd 与 fd_opts，用 fzf-lua 自己的默认值。
        --
        -- 教训：我曾用 files.cmd 指定随包 fd 的完整路径，看似更「确定」，
        -- 实则破坏了默认行为 —— files.lua:33 是
        --   if opts.cmd and #opts.cmd > 0 then command = opts.cmd
        -- 一旦设了 cmd，fd_opts 就完全失效，而默认的 fd_opts 里带着
        --   --exclude .git --exclude .jj
        -- 于是列表会把 .git 内部的文件也混进来（--hidden 打开后 fd 会进 .git）。
        -- 另外 --hidden / --follow / --no-ignore 这些开关只作用于默认形式的命令。
        --
        -- 不设 cmd 也不会退回到「系统的 fd」：启动脚本已把 <发行版>/bin 前置进 PATH，
        -- 所以裸命令名 fd / rg 解析到的就是随包那份。
        -- fzf-lua 会在 fd / fdfind / rg / find 之间自动挑可用的，前两个都在包里。
        -- 发行版自己的运行期状态不该出现在搜索结果里。
        --
        -- .local/ 下是会话、undo、以及与 vim.loader 的字节码缓存
        -- （cache/luac/，文件名是 URI 编码后的路径，例如
        --  D%3a%2flang%2f...%2flua%2fdistro%2fsearch.luac —— 那串看不懂的
        --  %3a%2f 就是它）。从包目录里搜索时，这些东西会淹没真正的项目文件。
        --
        -- 两层保险，因为两者作用的位置不同：
        --   file_ignore_patterns 是**追加**语义，作用于 fzf-lua 的 Lua 侧过滤
        --     与 grep provider，对 fd / rg 两条路都生效，且不会丢掉默认值；
        --   fd_opts 决定真正下发的 fd 命令，它能被我截取命令来验证 ——
        --     但它是**替换**语义。
        file_ignore_patterns = { '^%.local/' },

        -- 注意：fd_opts 必须写在 files 之下。
        --
        -- fzf-lua 的键分两类：file_ignore_patterns 这类是**全局**键（顶层即可），
        -- 而 fd_opts 属于**每个 provider 各自**的配置（defaults.lua 里它在
        -- M.defaults.files = { ... } 之下）。我一开始写成顶层，结果被静默忽略 ——
        -- 截取命令才看出来：下发的仍是默认值，没有我加的 --exclude .local。
        --
        -- 它是**替换**语义，所以值必须与默认一致，只在结尾追加 --exclude .local。
        -- 默认值来源：fzf-lua/defaults.lua 的 M.defaults.files.fd_opts
        --   [[--color=never --type f --type l --exclude .git --exclude .jj]]
        -- 上游若增删默认排除项，这里会落后 —— 代价是「多排或少排一个目录」，
        -- 比丢掉 .git 那种「列表混进版本库内部」的后果轻得多，故可接受。
        files = {
          fd_opts = '--color=never --type f --type l --exclude .git --exclude .jj --exclude .local',
        },

        -- 只把 fzf **自己用来画界面**的歧义宽度字形换成 ASCII，而不是整个 --no-unicode。
        --
        -- 演进过程（值得记下来，因为中间走错过）：
        --   1. 一开始问题是屏幕上有两根 `--`，判断是 fzf 的 Unicode 字形在
        --      ambiwidth=double 下占 2 格导致错位 —— 这个判断是对的。
        --   2. 当时的修法用了 `--no-unicode`，它确实修掉了 `--`，
        --      但紧接着出现了新现象：空查询时预览区残留字符（像散落的星点）。
        --      而那个时间点正好在加上 --no-unicode 之后。
        --   3. --no-unicode 是**一刀切**开关，会改变 fzf 内部的绘制路径。
        --      换成下面这种「只覆盖具体字形」的做法，既能保持对齐，
        --      又不动 fzf 的其余渲染逻辑。
        --
        -- 默认值参考：pointer=▌(U+258C)、marker=┃(U+2503)、scrollbar=│(U+2502)，
        -- 三者都是东亚「歧义宽度」字符。
        -- 这里**故意不设** fzf_opts 的 --no-unicode。
        --
        -- 演化记录：排查「残留碎片」问题时，曾把 fzf 整个切成 ASCII 绘制
        -- （--no-unicode），当时它确实修掉了两根 `--` 分隔线。但真正的根因
        -- 是 options.lua 里 ambiwidth=double 让 Neovim 与 fzf 对歧义宽度字符
        -- 的宽度判定不一致 —— 改为 ambiwidth=single 后，`─` 在两边都是 1 格，
        -- fzf 的 Unicode 界面本来就不再错位。
        --
        -- 保留 --no-unicode 的唯一效果是把界面降级成 ASCII，与
        -- 「Nerd Font 强依赖」的设计相悖，所以撤掉。
        -- 若分隔线/字形再出现错位，先查 ambiwidth（见 INSTALL.md 字符宽度一节），
        -- 不要再回到这个开关。

        winopts = {
          height = 0.85,
          width = 0.85,
          border = 'rounded',
          -- backdrop 保持 fzf-lua 的默认值（60），显式写出来只是为了记录结论。
          --
          -- 我曾把它设成 false（想消除「空查询时预览区透出编辑器文字」），结果
          -- **更糟**：遮罩本来还压暗着背景，去掉之后背景变成全亮，那些字更清楚。
          -- 这说明该修的是「让相关窗口不透明」，而不是「去掉遮罩」—— 层次搞错了。
          -- 默认值 60 的语义：0 = 不透明，100 = 完全透明（即禁用）。
          backdrop = 60,
          preview = { layout = 'flex', border = 'rounded' },
        },
        keymap = {
          builtin = {
            ['<C-d>'] = 'preview-page-down',
            ['<C-u>'] = 'preview-page-up',
            ['<C-a>'] = 'select-all',
          },
        },
        -- 大文件预览用 head 限制行数，避免预览几 MB 的文件把界面卡住
        previewers = { builtin = { syntax_limit_b = 1024 * 100 } },

        -- 条目里「文件名 / 内容」之间的分隔符，默认是 `▏`（U+258F，歧义宽度）。
        -- 在 ambiwidth=double 下它占 2 格、列对不齐 —— 与上面的 --no-unicode
        -- 是同一类问题。区别在于这个字符是 **fzf-lua 自己插进条目文本**的，
        -- fzf 的 --no-unicode 管不到它，所以要单独覆盖。
        grep = { separator = '|' },
        quickfix = { separator = '|' },
        loclist = { separator = '|' },
      })

      -- 这里原先有一段 `fzf.config().grep.rg_opts = nil`，注释写着「由下面的命令统管」，
      -- 但后面并没有那样的命令 —— 是早先想法留下的死代码。
      -- 它还有风险：那是在 setup 之后直接改 fzf-lua 的内部表。
      -- 已删除：不做的事就不要留下会执行的痕迹。

      -- 键位：全部 <leader>f*
      local map = function(keys, fn, desc)
        vim.keymap.set('n', keys, fn, { desc = desc })
      end

      map('<leader>ff', fzf.files, '查找文件（fzf）')
      map('<leader>fg', fzf.live_grep, '全项目搜索（fzf 交互）')
      map('<leader>fG', function() fzf.live_grep({ search = vim.fn.expand('<cword>'), regex = false }) end, '搜索光标下的词（fzf）')
      map('<leader>fb', fzf.buffers, '切换缓冲区（fzf）')
      map('<leader>fr', fzf.oldfiles, '最近文件（fzf）')
      map('<leader>fh', fzf.help_tags, '帮助标签（fzf）')
      map('<leader>fk', fzf.keymaps, '查看键位（fzf）')
      map('<leader>fc', fzf.commands, '可用命令（fzf）')
      map('<leader>fd', fzf.diagnostics_document, '当前文件诊断（fzf）')
      map('<leader>fD', fzf.diagnostics_workspace, '全项目诊断（fzf）')
      map('<leader>fm', fzf.marks, '标记（fzf）')
      map('<leader>f/', fzf.lines, '当前文件内搜索行（fzf）')
      map('<leader>fs', fzf.lsp_document_symbols, '当前文件符号（fzf）')
      map('<leader>fS', fzf.lsp_workspace_symbols, '全项目符号（fzf）')
    end,
  },

  {
    names = 'flash.nvim',
    pack = 'start',
    setup = function()
      require('flash').setup({
        modes = {
          -- 保留 search 模式：输入时即时高亮并可跳转，比默认的 / 好用得多
          search = { enabled = true },
          char = { enabled = true, jump_labels = true },
        },
        label = { uppercase = false }, -- 只用小写标签，少按一次 Shift
        -- 与 treesitter 配合做语法节点跳转
        jump = { nohlsearch = true },
      })

      -- flash 接管 s / S（默认的 s 只是 substitute 的别名，用得少）
      vim.keymap.set({ 'n', 'x', 'o' }, 's', function() require('flash').jump() end, { desc = '跳转（flash）' })
      vim.keymap.set({ 'n', 'x', 'o' }, 'S', function() require('flash').treesitter() end, { desc = '按语法节点跳转（flash）' })
      vim.keymap.set('o', 'r', function() require('flash').remote() end, { desc = '远程操作（flash）' })
      vim.keymap.set({ 'o', 'x' }, 'R', function() require('flash').treesitter_search() end, { desc = '语法节点搜索（flash）' })
    end,
  },

  -- 说明：`nvim-spider` **没有**启用。
  -- 它没有任何关闭默认键位的选项，必然接管 w / e / b / ge / gg，
  -- 与 jieba.vim 的中文按词移动直接冲突。两者只能留一个，
  -- 而中文分词是本发行版的差异点，所以 jieba 胜出（见 zh.lua 与 docs/DECIDED.md）。

  {
    names = 'grug-far.nvim',
    pack = 'opt',
    keys = { '<leader>sr', '<leader>sR' },
    desc = '全项目替换（grug-far）',
    setup = function()
      require('grug-far').setup({
        -- 与 search.lua 一致：rg 忽略 .git，但隐藏文件也要搜
        engines = {
          ripgrep = {
            path = 'rg',
            extraArgs = { '--hidden', '--glob=!.git/*', '--glob=!.local/*' },
          },
        },
        border = 'rounded',
        headerLine = true,
      })

      local function open(args)
        require('grug-far').open(vim.tbl_extend('force', { prefills = { paths = vim.fn.expand('%') } }, args or {}))
      end

      vim.keymap.set('n', '<leader>sr', function() open({ prefills = { paths = vim.fn.getcwd() } }) end,
        { desc = '全项目替换（grug-far）' })
      vim.keymap.set('n', '<leader>sR', function() open() end,
        { desc = '当前文件替换（grug-far）' })
      vim.keymap.set('v', '<leader>sr', function()
        require('grug-far').with_visual_selection({ prefills = { paths = vim.fn.getcwd() } })
      end, { desc = '用选中内容替换（grug-far）' })
    end,
  },
}
