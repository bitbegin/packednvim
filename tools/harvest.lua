-- 在 CI 里用**包内那个 Neovim** 编译 tree-sitter 解析器。
--
-- 这个脚本存在的唯一理由，是让解析器与运行时不再有 ABI 失配的可能：
-- 解析器由哪个二进制编译，就由那个二进制加载 —— 两者是同一个文件。
--
-- 用法（CI 里，nvim 已通过 PATH 指向包内 runtime/bin/nvim）：
--   nvim --headless -u init.lua -l tools/harvest.lua
--
-- 环境变量：
--   DISTRO_ROOT  发行版根目录（默认由 MYRVIMRC 推断）

local function env(name, default)
  local v = vim.env[name]
  if v == nil or v == '' then return default end
  return v
end

local distro = vim.fs.normalize(env('DISTRO_ROOT', vim.fn.fnamemodify(vim.env.MYVIMRC or '.', ':h')))
local site = distro .. '/vendor/treesitter/site'
local parser_dir = site .. '/parser'

local log = function(msg) io.write('[harvest] ' .. msg .. '\n') end
log('distro = ' .. distro)
log('site   = ' .. site)
log('nvim   = ' .. tostring(vim.version()))

-- ---------------------------------------------------------------------------
-- 1. 让 nvim-treesitter 直接装进 vendor/treesitter/site
--
-- 旧写法是「装到 stdpath('data') 再把整棵树搬出来」，比较绕。config.setup 支持
-- 指定 install_dir，装完原地就是最终位置，省掉搬运也省掉一类出错可能。
-- 它还会把这个目录前置进 runtimepath，所以本次会话立刻就能用。
-- ---------------------------------------------------------------------------
local PARSERS = {
  'lua', 'luadoc', 'c', 'cpp', 'python', 'bash', 'markdown', 'markdown_inline',
  'vim', 'vimdoc', 'query', 'json', 'yaml', 'toml', 'diff', 'gitcommit',
  'regex', 'comment', 'printf', 'cmake', 'make',
}

vim.fn.mkdir(parser_dir, 'p')

local ok_cfg, err_cfg = pcall(function()
  require('nvim-treesitter.config').setup({ install_dir = site })
end)
if not ok_cfg then
  log('设置 install_dir 失败：' .. tostring(err_cfg))
  vim.cmd('cquit 1')
end

-- ---------------------------------------------------------------------------
-- 2. 安装并等待落盘
--
-- **nvim-treesitter 的 install() 是异步的**（install.lua 里 `M.install = a.async(...)`）：
-- 调用即返回，下载与编译在后台协程里推进。早先我按同步逻辑写，采集时目录还空着，
-- 日志里「Downloading tree-sitter-…」出现在断言之后 —— 那就是异步的证据。
-- vim.wait 会推进事件循环，协程才能继续跑。
-- ---------------------------------------------------------------------------
local ok_ts, ts = pcall(require, 'nvim-treesitter')
if not ok_ts then
  log('require("nvim-treesitter") 失败 —— 插件没在 runtimepath 上？')
  vim.cmd('cquit 1')
end

local before = #vim.fn.glob(parser_dir .. '/*', false, true)
log(('安装 %d 个解析器（需要 tree-sitter CLI + C 编译器；目录里已有 %d 个）'):format(#PARSERS, before))

local call_ok, call_err = pcall(function() ts.install(PARSERS) end)
if not call_ok then
  log('调用安装失败：' .. tostring(call_err))
  vim.cmd('cquit 1')
end

local target = before + #PARSERS
local start = vim.uv.now()
local last_n, last_change = -1, vim.uv.now()
-- 判定「停止产出」的阈值要足够宽。曾经用 15 秒，结果在 macOS 上编译还没结束
-- 就被判为停止 —— 日志里 "Compiling parser" 出现在失败信息之后，就是这个原因。
-- 单个语法（如 cpp/yaml）编译超过 15 秒很正常，所以放宽到 5 分钟。
local STALL_MS = 5 * 60 * 1000
while vim.uv.now() - start < 25 * 60 * 1000 do
  vim.wait(500)
  local n = #vim.fn.glob(parser_dir .. '/*', false, true)
  if n >= target then break end
  if n ~= last_n then
    last_n, last_change = n, vim.uv.now()
    log(('  进度 %d/%d（已等待 %ds）'):format(n, target, math.floor((vim.uv.now() - start) / 1000)))
  elseif vim.uv.now() - last_change > STALL_MS then
    log(('  连续 %d 秒无新产出，认为已停止（%d/%d）'):format(STALL_MS / 1000, n, target))
    break
  end
end
log(('解析器就位 %d 个（目标 %d）'):format(#vim.fn.glob(parser_dir .. '/*', false, true), target))

-- ---------------------------------------------------------------------------
-- 3. Windows：把解析器由 .so 改名为 .dll
--
-- nvim-treesitter 的安装逻辑把目标文件名**硬编码成 .so**
-- （install.lua 里 `fs.joinpath(install_dir, lang) .. '.so'`），
-- 但 Windows 上 tree-sitter CLI 产出的是 DLL（实测前两字节 'MZ'）。
-- 而 Neovim 在 Windows 只找 `parser/<lang>.dll` —— 不改名，这些解析器等于不存在。
-- 这个坑真实发生过：第一版包里 20 个解析器，运行时一个都加载不了。
-- ---------------------------------------------------------------------------
if jit.os:lower() == 'windows' then
  local renamed = 0
  for _, f in ipairs(vim.fn.glob(parser_dir .. '/*.so', false, true)) do
    if vim.uv.fs_rename(f, f:sub(1, -4) .. '.dll') then renamed = renamed + 1 end
  end
  log(('Windows：%d 个解析器由 .so 改名为 .dll'):format(renamed))
end

-- ---------------------------------------------------------------------------
-- 4. 断言
-- ---------------------------------------------------------------------------
local problems = {}
local n_parsers = #vim.fn.glob(parser_dir .. '/*', false, true)
if n_parsers < 10 then
  problems[#problems + 1] = ('解析器只有 %d 个，明显偏少'):format(n_parsers)
end

-- 加载验证：比「文件存在」强得多 —— 它同时证明 ABI 是匹配的，
-- 而这正是本脚本存在的意义所在。
local probe = { 'bash', 'python', 'yaml', 'lua', 'c' }
for _, lang in ipairs(probe) do
  local ok, err = pcall(vim.treesitter.language.add, lang)
  if not ok then
    problems[#problems + 1] = ('加载解析器 %s 失败：%s'):format(lang, tostring(err):gsub('\n.*', ''))
  end
end

-- 平台相关的插件产物（由 workflow 在本脚本之前准备好）。
--
-- 扩展名必须与**插件自己的加载器**一致，而不是与「共享库的常见叫法」一致：
--   blink.cmp 的 get_lib_extension()：mac/osx -> .dylib，windows -> .dll，其余 .so
--   jieba.vim  的 loader：windows -> .dll，其余（含 macOS）-> .so
-- 曾经这里对三者统一用「windows ? .dll : .so」，于是 macOS 上把 .dylib 报成缺失 ——
-- **断言写错比没有断言更糟**，它会指出一个并不存在的问题。
local os_name = jit.os:lower()
local blink_ext = (os_name == 'windows' and '.dll')
  or ((os_name == 'osx' or os_name == 'mac') and '.dylib')
  or '.so'
local jieba_ext = os_name == 'windows' and '.dll' or '.so'

local blink_lib = distro .. '/pack/distro/start/blink.cmp/target/release/libblink_cmp_fuzzy' .. blink_ext
if vim.uv.fs_stat(blink_lib) == nil then
  problems[#problems + 1] = 'blink.cmp 原生库缺失：' .. blink_lib
end

local jieba_lib = distro .. '/pack/distro/start/jieba.vim/lua/jieba_vim/jieba_vim_rs' .. jieba_ext
if vim.uv.fs_stat(jieba_lib) == nil then
  problems[#problems + 1] = 'jieba.vim cdylib 缺失：' .. jieba_lib
end

if #problems > 0 then
  io.write('\n[harvest] 产物不完整：\n')
  for _, p in ipairs(problems) do io.write('  - ' .. p .. '\n') end

  -- 把 :messages 的尾部打出来。nvim-treesitter 把下载/编译的错误抛给它的 logger，
  -- 不打印的话日志里只剩「解析器 0 个」，完全看不出为什么失败。
  local msgs = vim.fn.execute('messages')
  if msgs and #msgs > 0 then
    local lines = vim.split(msgs, '\n')
    local tail = {}
    for i = math.max(1, #lines - 40), #lines do tail[#tail + 1] = lines[i] end
    io.write('\n[harvest] :messages 尾部（用于定位解析器为何没产出）：\n')
    for _, l in ipairs(tail) do io.write('  ' .. l .. '\n') end
  end

  vim.cmd('cquit 1')
end

log(('产物完整：%d 个解析器，blink 与 jieba 的原生库均已就位'):format(n_parsers))
