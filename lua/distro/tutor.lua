-- 快捷键训练营（tutor / 游戏模式）
--
-- 目的：把发行版里真实在用、但「学了不用就忘」的键位做成小关卡，边玩边练。
-- 设计约束与其它模块一致：
--   * 零联网、零新依赖 —— 只用本包已 vendor 的插件与内置能力
--   * 每个关卡都有**可编程验证**的完成条件，不靠自觉
--   * 失败要能看懂：每题都有提示与标准答案
--
-- 玩法
--   <leader>tt   开始 / 重开
--   <leader>tn   跳过本题
--   <leader>th   看提示（扣分）
--   <leader>tr   重做本题
--   <leader>tq   退出训练营
--
-- 评分
--   基础 100 分/题；每用一次提示 -30；连击每多一级 +20%（上限 +100%）；跳过 -50。
--   结束时按总分给段位，并记录历史最高分（存 stdpath('state')/tutor.json）。

local M = {}

-- ---------------------------------------------------------------------------
-- 关卡定义
--
-- 字段：
--   id     唯一标识（存档用）
--   title  关卡名
--   task   目标描述（显示给玩家）
--   keys   标准答案（按「看提示」后显示；默认不剧透）
--   hint   提示文字
--   setup  函数：重置工作缓冲区内容
--   check  函数：返回 true 表示完成（在工作缓冲区里执行）
-- ---------------------------------------------------------------------------

local function lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function buf_text()
  return table.concat(lines(), '\n')
end

local function cursor()
  return vim.api.nvim_win_get_cursor(0)
end

local function has_line(pattern)
  for _, l in ipairs(lines()) do
    if l:find(pattern, 1, true) then return true end
  end
  return false
end

local function line_starting(prefix)
  for _, l in ipairs(lines()) do
    if l:sub(1, #prefix) == prefix then return true end
  end
  return false
end

M.challenges = {
  {
    id = 'dd',
    title = '整行删除',
    task = '删掉标着「<删除我>」的那一整行',
    keys = 'dd',
    hint = 'dd 删除整行；D 是删到行尾，x 只删一个字符 —— 别混。',
    setup = function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        'local a = 1',
        'local dead_code = 2   -- <删除我>',
        'local b = 3',
        'return a + b',
      })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
    end,
    check = function() return not has_line('<删除我>') end,
  },

  {
    id = 'ciw',
    title = '改掉光标下的单词',
    task = '把 NAME 这个占位符改成 msg（不要动别的字）',
    keys = 'ciw 然后打字',
    hint = 'ciw = change inner word，进入插入模式并只替换光标下那个词。',
    setup = function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        'local NAME = "hello"',
        'print(NAME)',
      })
      vim.api.nvim_win_set_cursor(0, { 1, 7 })
    end,
    check = function() return buf_text():find('local msg = "hello"', 1, true) ~= nil end,
  },

  {
    id = 'gcc',
    title = '注释整行',
    task = '把第 2 行注释掉（用当前语言该有的注释符）',
    keys = 'gcc',
    hint = 'mini.comment：gcc 注释/反注释当前行，gc2c 一次处理两行。',
    setup = function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        'local function f()',
        '  return 42',
        'end',
      })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
    end,
    check = function() return (lines()[2] or ''):match('^%s*%-%-') ~= nil end,
  },

  {
    id = 'surround',
    title = '给单词加引号',
    task = '给第 1 行的 world 加上双引号（变成 "world"）',
    keys = 'saiw"',
    hint = 'mini.surround：sa + 文本对象 + 符号。saiw" 等价于「给内层单词加双引号」。',
    setup = function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'print(world)', 'print("ok")' })
      vim.api.nvim_win_set_cursor(0, { 1, 6 })
    end,
    check = function() return (lines()[1] or ''):find('print("world")', 1, true) ~= nil end,
  },

  {
    id = 'surround_del',
    title = '去掉括号',
    task = '把第 1 行的 (42) 变成 42（删掉那对括号）',
    keys = 'sd(',
    hint = 'mini.surround：sd + 符号 删除最近的该包围。',
    setup = function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local n = (42)', 'local m = 7' })
      vim.api.nvim_win_set_cursor(0, { 1, 10 })
    end,
    check = function() return (lines()[1] or ''):find('(42)', 1, true) == nil end,
  },

  {
    id = 'yyp',
    title = '复制整行到下面',
    task = '让第 2 行和第 1 行完全一样（共 3 行，中间重复）',
    keys = 'yyp',
    hint = 'yy 复制整行，p 粘贴到下一行；yyp 是最常用的「复制一行」组合。',
    setup = function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local duplicated = true', 'local tail = 0' })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
    end,
    check = function()
      local l = lines()
      return #l == 3 and l[1] == l[2]
    end,
  },

  {
    id = 'gU',
    title = '整行变大写',
    task = '把第 1 行全部变成大写',
    keys = 'gUU',
    hint = 'gUU 整行大写；gUiw 只转光标下的单词。',
    setup = function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local shout = "quiet"', 'local keep = "as-is"' })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
    end,
    check = function()
      local l1 = lines()[1] or ''
      return l1 == l1:upper() and l1:find('LOCAL', 1, true) ~= nil
    end,
  },

  {
    id = 'indent',
    title = '缩进一行',
    task = '把第 2 行向右缩进一次（缩进宽度是 2）',
    keys = '>>',
    hint = '>> 右缩进，<< 左缩进；= 是「按语法自动缩进」。',
    setup = function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local function f()', 'return 1', 'end' })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
    end,
    check = function() return (lines()[2] or ''):match('^  return 1') ~= nil end,
  },

  {
    id = 'treesitter_af',
    title = '文本对象：整个函数',
    task = '把整个 f 函数删掉（含 function 与 end）',
    keys = 'daf',
    hint = 'nvim-treesitter-textobjects 绑了 af/if（函数外/内）、ac/ic（类）、aa/ia（参数）。',
    setup = function()
      -- 工作缓冲区刻意不是 lua 文件类型（免得 lua_ls 附着、冒诊断标记），
      -- 但本题练的是 treesitter 文本对象，所以显式挂上 lua 解析器。
      pcall(vim.treesitter.start, 0, 'lua')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        'local keep = 1',
        'local function f()',
        '  return keep',
        'end',
        'local tail = 2',
      })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
    end,
    check = function()
      local t = buf_text()
      return t:find('function f', 1, true) == nil and t:find('local keep = 1', 1, true) ~= nil
    end,
  },

  {
    id = 'flash',
    title = '闪跳',
    task = '把光标跳到下面那行的 OK 上（别用鼠标、别用 / 搜索）',
    keys = 's 然后敲 O K 后按对应标签',
    hint = 'flash.nvim：s 后输入 1-2 个字符，屏幕上出现标签，按标签即跳过去。',
    setup = function()
      local buf = {}
      for i = 1, 12 do buf[i] = '第 ' .. i .. ' 行 filler' end
      buf[9] = '第 9 行 这里有 OK 目标'
      vim.api.nvim_buf_set_lines(0, 0, -1, false, buf)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
    end,
    check = function()
      local row, col = unpack(cursor())
      local line = lines()[row] or ''
      -- 光标停在 OK 的 O 上即算完成
      return line:sub(col + 1, col + 2) == 'OK'
    end,
  },

  {
    id = 'search',
    title = '搜索并跳到匹配',
    task = '跳到第 11 行（用 / 搜索 target_word）',
    keys = '/target_word 回车',
    hint = '/ 前向搜索，n / N 跳下一个 / 上一个；本发行版把 n/N 绑成了「跳转后居中」。',
    setup = function()
      local buf = {}
      for i = 1, 15 do buf[i] = '第 ' .. i .. ' 行普通内容' end
      buf[11] = '第 11 行 target_word 在这里'
      vim.api.nvim_buf_set_lines(0, 0, -1, false, buf)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
    end,
    check = function() return (cursor())[1] == 11 end,
  },

  {
    id = 'cj',
    title = '中文按词移动',
    task = '把光标移到「测试」这个词的首字上（只按移动键，别用鼠标）',
    keys = 'w 若干次',
    hint = 'jieba.vim 接管了 w/b/e：中文按分词跳，而不是按字节或整段。',
    setup = function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        '我们  一起  做  中文  分词  测试  用例',
      })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
    end,
    check = function()
      local row, col = unpack(cursor())
      local line = lines()[row] or ''
      -- 允许停在「测试」的首字节处
      return line:sub(col + 1, col + 6) == '测试'
    end,
  },

  {
    id = 'macro',
    title = '宏：一次处理多行',
    task = '给第 1-3 行行首各加上 > 前缀（用宏，别手打三次）',
    keys = 'qa 然后 I> 然后 Esc 然后 j 然后 q，最后 @a',
    hint = 'qa 开始录制到寄存器 a，q 结束录制，@a 执行；2@a 执行两次。',
    setup = function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'alpha', 'beta', 'gamma', 'delta' })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
    end,
    check = function()
      local l = lines()
      return l[1] == '>alpha' and l[2] == '>beta' and l[3] == '>gamma' and l[4] == 'delta'
    end,
  },

  {
    id = 'dot',
    title = '重复上一次修改',
    task = '三行都以 = 结尾（先改一次，再用 . 重复两次）',
    keys = 'A= 然后 j 然后 . 然后 j 然后 .',
    hint = 'A 行尾插入，Esc 后按 . 重复上一次修改 —— 不用重复敲同样的东西。',
    setup = function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'one', 'two', 'three' })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
    end,
    check = function()
      local l = lines()
      return l[1] == 'one=' and l[2] == 'two=' and l[3] == 'three='
    end,
  },
}

-- ---------------------------------------------------------------------------
-- 局内状态
-- ---------------------------------------------------------------------------
local S = {
  active = false,
  idx = 1,
  score = 0,
  combo = 0,
  best_combo = 0,
  hints = 0,
  skips = 0,
  started_at = 0,
  advance_pending = false,
}

local HUD_BUF, HUD_WIN = nil, nil
local WORK_BUF, WORK_WIN = nil, nil
local check_timer = nil

local function challenge() return M.challenges[S.idx] end

local function state_file()
  return vim.fn.stdpath('state') .. '/tutor.json'
end

local function load_best()
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(state_file()), '\n'))
  end)
  if ok and type(data) == 'table' then return data end
  return {}
end

local function save_best(best)
  pcall(function()
    vim.fn.mkdir(vim.fn.stdpath('state'), 'p')
    vim.fn.writefile({ vim.json.encode(best) }, state_file())
  end)
end

-- ---------------------------------------------------------------------------
-- HUD（浮窗）
-- ---------------------------------------------------------------------------
local function hud_lines()
  local c = challenge()
  local progress = ('%d/%d'):format(S.idx, #M.challenges)
  local elapsed = math.floor((vim.uv.hrtime() - S.started_at) / 1e9)
  local bar_n = math.max(0, math.min(#M.challenges, S.idx - 1))
  local bar = string.rep('█', bar_n) .. string.rep('░', #M.challenges - bar_n)
  local combo = S.combo > 0 and ('  🔥 连击 ×' .. S.combo) or ''
  return {
    ' 🎮 快捷键训练营   ' .. progress,
    ' ' .. bar,
    '',
    ' 关卡：' .. c.title,
    ' 目标：' .. c.task,
    '',
    (' 分数 %d   用时 %ds%s'):format(S.score, elapsed, combo),
    '',
    ' <leader>th 提示   <leader>tn 跳过',
    ' <leader>tr 重做   <leader>tq 退出',
  }
end

local function hud_draw()
  if not (HUD_BUF and vim.api.nvim_buf_is_valid(HUD_BUF)) then return end
  local body = hud_lines()
  vim.api.nvim_buf_set_lines(HUD_BUF, 0, -1, false, body)
  if HUD_WIN and vim.api.nvim_win_is_valid(HUD_WIN) then
    vim.api.nvim_win_set_config(HUD_WIN, M._hud_config(body))
  end
end

--- HUD 的位置与尺寸：贴在编辑器右上角，宽度按最长行计算。
function M._hud_config(body)
  local width = 1
  for _, l in ipairs(body) do
    local w = vim.fn.strdisplaywidth(l)
    if w > width then width = w end
  end
  width = math.min(width + 2, math.max(20, vim.o.columns - 6))
  local height = math.min(#body, math.max(6, vim.o.lines - 4))
  return {
    relative = 'editor',
    anchor = 'NE',
    row = 1,
    col = vim.o.columns - 2,
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    focusable = false,
    noautocmd = true,
    zindex = 60,
  }
end

local function hud_open()
  if not (HUD_BUF and vim.api.nvim_buf_is_valid(HUD_BUF)) then
    HUD_BUF = vim.api.nvim_create_buf(false, true)
    vim.bo[HUD_BUF].bufhidden = 'hide'
    vim.bo[HUD_BUF].filetype = 'distro-tutor'
  end
  local body = hud_lines()
  vim.api.nvim_buf_set_lines(HUD_BUF, 0, -1, false, body)
  local cfg = M._hud_config(body)
  if HUD_WIN and vim.api.nvim_win_is_valid(HUD_WIN) then
    vim.api.nvim_win_set_config(HUD_WIN, cfg)
    return
  end
  HUD_WIN = vim.api.nvim_open_win(HUD_BUF, false, cfg)
  vim.wo[HUD_WIN].winhl = 'Normal:NormalFloat,FloatBorder:FloatBorder'
end

local function hud_close()
  if HUD_WIN and vim.api.nvim_win_is_valid(HUD_WIN) then
    pcall(vim.api.nvim_win_close, HUD_WIN, true)
  end
  HUD_WIN = nil
end

-- ---------------------------------------------------------------------------
-- 判定
-- ---------------------------------------------------------------------------
local function succeeded()
  local c = challenge()
  local ok, res = pcall(c.check)
  return ok and res == true
end

local function award()
  local base = 100
  local penalty = S.hints * 30
  local mult = 1 + math.min(S.combo, 5) * 0.2
  local gain = math.max(10, math.floor((base - penalty) * mult))
  S.score = S.score + gain
  S.combo = S.combo + 1
  if S.combo > S.best_combo then S.best_combo = S.combo end
  return gain
end

local function flash(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = '🎮 训练营' })
end

local function next_challenge()
  S.idx = S.idx + 1
  S.hints = 0
  S.advance_pending = false
  if S.idx > #M.challenges then
    M.finish()
    return
  end
  M.load(S.idx)
end

--- 载入第 idx 题：重置缓冲区内容与光标，刷新 HUD。
function M.load(idx)
  S.idx = idx
  S.hints = 0
  S.advance_pending = false
  local c = challenge()

  if not (WORK_BUF and vim.api.nvim_buf_is_valid(WORK_BUF)) then
    WORK_BUF = vim.api.nvim_create_buf(false, true) -- scratch：可编辑、不落盘
    vim.bo[WORK_BUF].bufhidden = 'hide'
    vim.bo[WORK_BUF].swapfile = false
    -- 刻意**不用** lua 作文件类型：那会让 lua_ls 附着到这个练习缓冲区上，
    -- 左栏冒出一堆诊断标记，干扰练习。注释关卡的 commentstring 单独设。
    vim.bo[WORK_BUF].filetype = 'distro-tutor'
    vim.bo[WORK_BUF].commentstring = '-- %s'
    vim.b[WORK_BUF].distro_tutor = true
    M._bind_local(WORK_BUF)
  end

  if not (WORK_WIN and vim.api.nvim_win_is_valid(WORK_WIN)) then
    WORK_WIN = vim.api.nvim_get_current_win()
  end
  vim.api.nvim_win_set_buf(WORK_WIN, WORK_BUF)
  vim.api.nvim_set_current_win(WORK_WIN)

  vim.bo[WORK_BUF].modifiable = true
  vim.api.nvim_buf_set_lines(WORK_BUF, 0, -1, false, { '' })
  pcall(vim.treesitter.stop, WORK_BUF)

  local ok, err = pcall(c.setup)
  if not ok then flash('关卡初始化出错：' .. tostring(err), vim.log.levels.ERROR) end

  hud_open()
  hud_draw()
end

--- 训练营缓冲区里的局内键位（只在练习缓冲区生效，不外溢到普通 lua 文件）。
function M._bind_local(buf)
  local map = function(k, fn, desc)
    vim.keymap.set('n', k, fn, { buffer = buf, desc = desc, silent = true })
  end
  map('<leader>th', M.hint, '训练营：提示')
  map('<leader>tn', M.skip, '训练营：跳过')
  map('<leader>tr', M.retry, '训练营：重做')
  map('<leader>tq', M.stop, '训练营：退出')
end

--- 开始 / 重开一局。
function M.start()
  S.active = true
  S.idx = 1
  S.score = 0
  S.combo = 0
  S.best_combo = 0
  S.hints = 0
  S.skips = 0
  S.started_at = vim.uv.hrtime()
  WORK_WIN = vim.api.nvim_get_current_win()
  M.load(1)
  flash(('开始训练：共 %d 关，加油！'):format(#M.challenges))
end

--- 结束一局并给出段位。
function M.finish()
  S.active = false
  hud_close()
  local elapsed = math.max(1, math.floor((vim.uv.hrtime() - S.started_at) / 1e9))
  local max = #M.challenges * 100
  local pct = S.score / math.max(1, max)
  local rank = 'D'
  if pct >= 0.95 then rank = 'S'
  elseif pct >= 0.8 then rank = 'A'
  elseif pct >= 0.6 then rank = 'B'
  elseif pct >= 0.4 then rank = 'C' end

  local best = load_best()
  local is_record = S.score > (best.score or 0)
  if is_record then
    best.score = S.score
    best.rank = rank
    best.elapsed = elapsed
    save_best(best)
  end

  local msg = ('训练结束｜得分 %d（满%d）｜段位 %s｜用时 %ds｜最高连击 ×%d｜提示 %d 次'):format(
    S.score, max, rank, elapsed, S.best_combo, S.hints)
  if is_record then msg = msg .. '｜🏆 新纪录！' end
  flash(msg, vim.log.levels.INFO)

  if WORK_BUF and vim.api.nvim_buf_is_valid(WORK_BUF) then
    vim.api.nvim_buf_set_lines(WORK_BUF, 0, -1, false, {
      '🎮 训练结束',
      '',
      ('得分   %d / %d'):format(S.score, max),
      ('段位   %s'):format(rank),
      ('用时   %ds'):format(elapsed),
      ('连击   最高 ×%d'):format(S.best_combo),
      ('提示   %d 次   跳过 %d 题'):format(S.hints, S.skips),
      '',
      is_record and '🏆 新纪录！' or ('历史最高 ' .. (best.score or 0)),
      '',
      '<leader>tt 再来一局',
    })
    vim.bo[WORK_BUF].modifiable = false
  end
end

--- 看提示（扣 30 分）。
function M.hint()
  if not S.active then return end
  local c = challenge()
  S.hints = S.hints + 1
  hud_draw()
  flash(('💡 %s\n按键：%s'):format(c.hint, c.keys), vim.log.levels.INFO)
end

--- 跳过本题（扣 50 分）。
function M.skip()
  if not S.active then return end
  S.skips = S.skips + 1
  S.combo = 0
  S.score = math.max(0, S.score - 50)
  local c = challenge()
  flash(('⏭ 跳过「%s」（答案是 %s）'):format(c.title, c.keys), vim.log.levels.WARN)
  next_challenge()
end

--- 重做本题。
function M.retry()
  if not S.active then return end
  S.combo = 0
  M.load(S.idx)
end

--- 退出训练营。
function M.stop()
  if not S.active then
    hud_close()
    return
  end
  M.finish()
  if WORK_BUF and vim.api.nvim_buf_is_valid(WORK_BUF) then
    pcall(vim.api.nvim_buf_delete, WORK_BUF, { force = true })
  end
  WORK_BUF = nil
end

-- 判定轮询：编辑与光标事件后延迟检查，避免每次按键都跑一遍 check。
local function schedule_check()
  if not S.active or S.advance_pending then return end
  if check_timer then return end
  check_timer = vim.defer_fn(function()
    check_timer = nil
    if not S.active or S.advance_pending then return end
    if succeeded() then
      S.advance_pending = true
      local gain = award()
      local c = challenge()
      hud_draw()
      flash(('✅ %s  +%d（连击 ×%d）'):format(c.title, gain, S.combo))
      vim.defer_fn(function()
        if S.active then next_challenge() end
      end, 700)
    else
      hud_draw()
    end
  end, 150)
end

M._schedule_check = schedule_check

--- 绑命令与自动命令。由 keymaps 模块调用。
function M.setup()
  vim.api.nvim_create_user_command('Tutor', function() M.start() end, { desc = '快捷键训练营' })

  local aug = vim.api.nvim_create_augroup('distro_tutor', { clear = true })
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'CursorMoved', 'CursorMovedI', 'ModeChanged' }, {
    group = aug,
    callback = function()
      if not S.active then return end
      schedule_check()
    end,
  })
  vim.api.nvim_create_autocmd('VimResized', {
    group = aug,
    callback = function()
      if HUD_WIN and vim.api.nvim_win_is_valid(HUD_WIN) then hud_draw() end
    end,
  })
end

--- 供测试/健康检查使用：暴露内部状态（只读用途）。
function M._state() return S end
function M._hud_buf() return HUD_BUF end

return M
