-- 需求 4 / 5：rg 搜索工作流
--
-- 四条不可动摇的设计约束（改之前先想清楚）：
--
--   1. 绝不用内置 :vimgrep。它把整个文件读进内存再逐行匹配，GB 级文件会直接
--      吃光内存并卡死。一律走外部 rg：流式扫描，输出天然是 file:line:col:text。
--   2. --vimgrep 必须带。普通 -n 输出没有列号，quickfix 只能跳到行首。
--   3. --with-filename 必须带。rg 搜单个文件时默认不打印文件名，
--      quickfix 会找不到文件 —— 大日志场景必踩。
--   4. 搜索结果默认按行去重：一行有 5 处匹配时只留一条（列号取第一处）。
--      这正对应「结果按行显示」，也让日志场景的结果窗口不至于爆掉。
--      想保留每处匹配，把 dedupe 关掉即可。
--
-- 另外，实际执行搜索时不经过 shell（用 systemlist 传列表），
-- 因此正则里的引号、反斜杠、管道符都不需要转义，Windows 上尤其省心。

local M = {}

-- 传给 rg 的固定参数
local RG_OPTS = {
  '--vimgrep',
  '--no-heading',
  '--with-filename',
  '--smart-case',
  '--hidden',
  '--glob=!.git/*',
  -- 发行版自己的运行期状态（会话、undo、缓存）在包内 .local/ 下，
  -- 而 vim.loader 的字节码缓存也写在那里（cache/luac/，文件名是 URI 编码的路径）。
  -- 不排除的话，从包目录里搜索会满屏都是自己的缓存与日志 ——
  -- 看起来像「搜错了地方」，实际是搜索把发行版的内部状态当成了项目文件。
  '--glob=!.local/*',
  '--max-columns=300', -- 日志里一行几 MB 是常态，不限制会把 quickfix 拖垮
  '--max-columns-preview',
}

-- 大文件降级阈值：超过就关掉高亮 / 折叠 / undo，避免跳转过去之后卡死
local BIGFILE_BYTES = 2 * 1024 * 1024

-- 定位发行版根目录，好让 <distro>/bin 里的自带 rg 优先于系统 PATH
local function distro_root()
  if vim.g.distro_root and vim.g.distro_root ~= '' then
    return vim.g.distro_root
  end
  local src = debug.getinfo(1, 'S').source:sub(2)
  return vim.fn.fnamemodify(src, ':h:h:h')
end

-- 找 rg：先看 <distro>/bin，再看 PATH
local function find_rg()
  local exe = vim.fn.has('win32') == 1 and 'rg.exe' or 'rg'
  local bundled = distro_root() .. '/bin/' .. exe
  if vim.fn.executable(bundled) == 1 then
    return bundled
  end
  if vim.fn.executable('rg') == 1 then
    return 'rg'
  end
  return nil
end

-- 按 (文件, 行号) 去重，保留第一次出现的匹配（列号最小，因为 rg 按列升序输出）
local function dedupe_by_line(lines)
  local seen, out = {}, {}
  for _, l in ipairs(lines) do
    -- 惰性匹配能正确处理 Windows 盘符：C:\a\b.lua:12:3:text
    local file, line = l:match('^(.-):(%d+):%d+:')
    if file then
      local key = file .. '\0' .. line
      if not seen[key] then
        seen[key] = true
        out[#out + 1] = l
      end
    else
      -- 认不出来的行原样保留，交给 errorformat 处理
      out[#out + 1] = l
    end
  end
  return out
end

--- 执行一次 rg 搜索并把结果送进 quickfix。
-- @param args string[]  追加在 `--` 之后的参数（正则、路径等）
-- @param title string   quickfix 列表标题
-- @param opts table|nil { dedupe = boolean, extra = string[] }
--        extra 里的选项会插在 `--` 之前，用来临时改变搜索行为，
--        例如 { '--no-ignore' } 连被忽略的文件一起搜、{ '--pcre2' } 启用 PCRE 正则。
function M.run(args, title, opts)
  opts = opts or {}
  if not M.rg then
    vim.notify('distro: 找不到 rg，搜索不可用（应随包放在 <distro>/bin/rg）', vim.log.levels.ERROR)
    return
  end

  local cmd = { M.rg }
  vim.list_extend(cmd, RG_OPTS)
  if opts.extra then
    vim.list_extend(cmd, opts.extra)
  end
  cmd[#cmd + 1] = '--'
  vim.list_extend(cmd, args)

  local lines = vim.fn.systemlist(cmd)
  local code = vim.v.shell_error

  -- shell_error < 0 表示进程根本没起来（rg 不在、权限被拒、被沙箱拦住等）。
  -- 这种情况绝不能当成「无匹配」吞掉，否则用户会以为真的没搜到。
  if type(code) ~= 'number' or code < 0 then
    vim.notify(
      'distro: 无法启动 rg，搜索未执行\n命令: ' .. table.concat(cmd, ' '),
      vim.log.levels.ERROR
    )
    return
  end

  if code > 1 then -- rg: 0=有匹配 1=无匹配 2=出错
    vim.notify('rg 出错：\n' .. table.concat(lines, '\n'), vim.log.levels.ERROR)
    return
  end

  if opts.dedupe ~= false then
    lines = dedupe_by_line(lines)
  end

  vim.fn.setqflist({}, ' ', { title = title, lines = lines, efm = '%f:%l:%c:%m' })

  if #lines == 0 then
    vim.notify('无匹配', vim.log.levels.INFO)
    return
  end
  -- 就用默认的 :copen。
  --
  -- 曾在这里改成「给一个稳定高度下限」，理由是我以为默认行为会让窗口贴合结果条数
  -- （只有两三条结果就缩成三四行）。**实测推翻了那个假设**：
  --   :copen     -> 高度 10 行（即使只有 2 条结果）
  --   :copen 12  -> 高度 12 行
  -- 既然默认已经是稳定的 10 行，强制更高只会在结果很少时白占屏幕，所以撤掉。
  -- 临时改高度：在结果窗口里 :resize 20，或 <C-w> 后按 + / -
  vim.cmd('copen')
end

local function prompt(msg, on_confirm)
  vim.ui.input({ prompt = msg }, function(input)
    input = input and vim.trim(input) or ''
    if input == '' then
      return
    end
    on_confirm(input)
  end)
end

--- 项目内正则搜索（进 quickfix）
function M.grep_project()
  prompt('项目内正则搜索: ', function(pat)
    M.run({ pat }, 'rg: ' .. pat)
  end)
end

--- 只搜当前文件（大日志场景）
function M.grep_current_file()
  local file = vim.api.nvim_buf_get_name(0)
  if file == '' then
    vim.notify('当前缓冲区没有文件名', vim.log.levels.WARN)
    return
  end
  prompt('当前文件内正则搜索: ', function(pat)
    M.run({ pat, file }, 'rg (当前文件): ' .. pat)
  end)
end

--- 搜光标下的单词
function M.grep_word()
  local word = vim.fn.expand('<cword>')
  if word == '' then
    vim.notify('光标下没有单词', vim.log.levels.WARN)
    return
  end
  M.run({ '--fixed-strings', word }, 'rg: ' .. word)
end

-- <leader>sg 的实现选择：**默认走 quickfix，而不是 fzf 的实时界面**。
--
-- 原因（来自实际使用，不是推断）：fzf 的实时 grep 界面在这台机器上会出现
-- 「残留字符」——查询被清空、列表变空时，上一次搜索的文字碎片留在屏幕上，
-- 只有整屏重绘（改窗口大小）才消失。
--
-- 排查过程与结论：
--   - 换成 PowerShell 与 Alacritty **两个终端都复现** -> 不是终端问题；
--   - 去掉预览窗口 -> 仍复现 -> 不是预览的问题；
--   - --no-unicode / 具体字形 / --separator -> 只影响 `--` 分隔线，与此无关；
--   - termsync / ttyfast（Neovim 的输出批处理与重绘优化）-> 关掉仍复现。
-- 也就是说：这是 fzf 的实时列表在 Neovim 终端缓冲区里的刷新问题，
-- 从配置层面没有可表达的开关。
--
-- 所以这里做一个明确的取舍：**搜索的可靠性优先于实时预览**。
-- <leader>sg 走 rg + quickfix（同 <leader>sG 那条已验证可用的路径，
-- 只是先用输入框问模式），结果按行进窗口、可点击跳转。
--
-- fzf 仍然用于 <leader>f*（文件查找）——那里的列表是静态的，
-- 没有逐键刷新的实时列表，不受这个问题影响。
--
-- 想恢复实时 grep：把下面 M._live_grep_fzf 的调用换回 fzf.live_grep({ previewer = false })。
function M._live_grep_fzf()
  local ok, fzf = pcall(require, 'fzf-lua')
  if not ok then
    return false
  end
  -- 注意 fzf.grep_lgrep 在现代 fzf-lua 里**不存在**（lgrep 是个布尔选项，
  -- 不是 provider），所以这里一直走的是 live_grep。保留 or 链是为兼容旧版。
  local fn = fzf.grep_lgrep or fzf.live_grep or fzf.grep_project
  if type(fn) ~= 'function' then
    return false
  end
  local ok2 = pcall(fn, { previewer = false })
  if not ok2 then
    pcall(fn)
  end
  return true
end

function M._setup_grepprg()
  M.rg = find_rg()
  if not M.rg then
    vim.notify('distro: 找不到 rg，搜索工作流不可用', vim.log.levels.ERROR)
    return
  end
  -- 手敲 :grep 也能用。末尾的 -- 把 pattern 与选项隔开，
  -- 这样 :grep 'foo' 和 :grep 'foo' % 都正确。
  local parts = { M.rg }
  vim.list_extend(parts, RG_OPTS)
  parts[#parts + 1] = '--'
  vim.o.grepprg = table.concat(parts, ' ')
  vim.o.grepformat = '%f:%l:%c:%m'
end

function M._setup_quickfix_mouse()
  local group = vim.api.nvim_create_augroup('distro_search_qf', { clear = true })
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = 'qf',
    desc = 'quickfix 双击跳转（单击只移动光标）',
    callback = function(ev)
      vim.keymap.set('n', '<2-LeftMouse>', '<2-LeftMouse><CR>', {
        buffer = ev.buf,
        desc = '跳转到该结果',
      })
    end,
  })
end

function M._setup_bigfile()
  local group = vim.api.nvim_create_augroup('distro_search_bigfile', { clear = true })

  vim.api.nvim_create_autocmd('BufReadPre', {
    group = group,
    desc = '大文件自动降级，避免跳转过去后卡死',
    callback = function(ev)
      local ok, size = pcall(vim.fn.getfsize, ev.file)
      if not ok or type(size) ~= 'number' or size <= M.bigfile_bytes then
        return
      end
      vim.b[ev.buf].distro_bigfile = true
      vim.b[ev.buf].distro_bigfile_size = size
      vim.opt_local.undofile = false
      vim.opt_local.foldmethod = 'manual'
      vim.opt_local.spell = false
      vim.opt_local.syntax = ''
      vim.opt_local.synmaxcol = 200
    end,
  })

  -- 光在 BufReadPre 里清掉 syntax 是不够的：文件读完后的文件类型检测
  -- 会再触发一次语法加载，把 syntax 又设回去。所以还要在 Syntax 事件上兜住。
  vim.api.nvim_create_autocmd('Syntax', {
    group = group,
    desc = '拦住大文件的语法加载',
    callback = function(ev)
      if not vim.b[ev.buf].distro_bigfile then
        return
      end
      if vim.b[ev.buf].distro_bigfile_syntax_cleared then
        return -- 防止设置 syntax 再次触发 Syntax 造成递归
      end
      vim.b[ev.buf].distro_bigfile_syntax_cleared = true
      vim.opt_local.syntax = ''
      vim.opt_local.foldmethod = 'manual'
    end,
  })
end

function M._setup_keymaps()
  local map = vim.keymap.set

  -- <leader>sg 走 rg + quickfix：这是你已经验证可用的那条路径。
  -- 它不经过 fzf 的实时列表，因此没有显示残留问题。
  map('n', '<leader>sg', M.grep_project, { desc = '搜索：输入模式后进 quickfix' })

  -- 实时 grep 保留在另一个键上：等 fzf 的显示残留问题有了结论，可以切回去。
  map('n', '<leader>sl', function()
    M._live_grep_fzf()
  end, { desc = '搜索：实时 grep（fzf，当前存在显示残留）' })

  map('n', '<leader>sG', M.grep_project, { desc = '搜索：正则进 quickfix' })
  map('n', '<leader>su', function()
    prompt('搜索（含被忽略的文件）: ', function(pat)
      M.run({ pat }, 'rg (含忽略): ' .. pat, { extra = { '--no-ignore' } })
    end)
  end, { desc = '搜索：连被忽略的文件一起搜' })
  map('n', '<leader>sf', M.grep_current_file, { desc = '搜索：仅当前文件（大文件）' })
  map('n', '<leader>sw', M.grep_word, { desc = '搜索：光标下单词' })
  map('n', '<leader>sc', '<Cmd>cclose<CR>', { desc = '搜索：关闭结果窗口' })
  map('n', '<leader>sn', '<Cmd>cnext<CR>', { desc = '搜索：下一个结果' })
  map('n', '<leader>sp', '<Cmd>cprev<CR>', { desc = '搜索：上一个结果' })
end

function M.setup(opts)
  opts = opts or {}
  M.bigfile_bytes = opts.bigfile_bytes or BIGFILE_BYTES
  M._setup_grepprg()
  M._setup_quickfix_mouse()
  M._setup_bigfile()
  M._setup_keymaps()
end

M.RG_OPTS = RG_OPTS
M.dedupe_by_line = dedupe_by_line

return M
