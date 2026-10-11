-- 在 CI 里采集「平台相关」的产物。
--
-- 为什么需要它：包里有三样东西跟平台绑定，无法只编一次就同时满足 Windows 与 Linux ——
--   tree-sitter 解析器（.so / .dll，且 ABI 与 Neovim 版本强耦合）
--   blink.cmp 的 Rust 模糊匹配库
--   jieba.vim 的 Rust cdylib
--
-- 分工（这个划分是查过源码后定的，不是猜的）：
--   * tree-sitter 解析器 → 装进 stdpath('data')/site，**必须由本脚本收走**
--   * blink.cmp 的原生库   → 落在 <插件>/target/release/，**在 pack/ 内部，随包自动带上**
--   * jieba.vim 的 cdylib  → 落在 <插件>/lua/jieba_vim/，同上，由 workflow 调它的 build 脚本
--   所以本脚本只需采集 tree-sitter 那部分。
--
-- 策略是**让插件自己 bootstrap**（它们本来就带下载/编译逻辑），而不是我们复刻构建细节 ——
-- 后者会随上游改动失效。CI 有网，正好借这个能力。
--
-- 用法：
--   nvim --headless -u <distro>/init.lua -l tools/harvest.lua
-- 环境变量：
--   DISTRO_ROOT   发行版根目录（默认由 MYVIMRC 推断）
--   HARVEST_OUT   产物输出目录（默认 build/prebuilt）
--   XDG_DATA_HOME 必须由调用方指向干净临时目录，插件产物会落在这里

local function env(name, default)
  local v = vim.env[name]
  if v == nil or v == '' then return default end
  return v
end

local distro = vim.fs.normalize(env('DISTRO_ROOT', vim.fn.fnamemodify(vim.env.MYVIMRC or '.', ':h')))
local out = vim.fs.normalize(env('HARVEST_OUT', distro .. '/build/prebuilt'))
local data = vim.fs.normalize(vim.fn.stdpath('data'))

local log = function(msg) io.write('[harvest] ' .. msg .. '\n') end
log('distro = ' .. distro)
log('out    = ' .. out)
log('data   = ' .. data)
log('nvim   = ' .. tostring(vim.version()))

vim.fn.mkdir(out, 'p')

-- ---------------------------------------------------------------------------
-- 1. tree-sitter 解析器
--    列表按发行版实际要支持的语言来（少装几个能明显缩短 CI 时间）。
--    nvim-treesitter 的 install_dir 默认是 stdpath('data')/site，正好在我们要收走的目录里。
-- ---------------------------------------------------------------------------
local PARSERS = {
  'lua', 'luadoc', 'c', 'cpp', 'python', 'bash', 'markdown', 'markdown_inline',
  'vim', 'vimdoc', 'query', 'json', 'yaml', 'toml', 'diff', 'gitcommit',
  'regex', 'comment', 'printf', 'cmake', 'make',
}

local parser_dir = data .. '/site/parser'

--- 等解析器真正落盘。
--
-- 关键：**nvim-treesitter 的 install() 是异步的**（内部用他自己的 async 协程，
-- 见 install.lua 里 `M.install = a.async(...)`）。调用后立刻返回，
-- 下载与编译在后台推进 —— 第一次 CI 就是因为我按同步逻辑写、
-- 采集时目录还空着而失败：日志里「Downloading tree-sitter-…」出现在断言之后，
-- 正是异步在断言之后才跑起来的证据。
--
-- vim.wait 会推进事件循环，那些协程才能继续跑。
-- 结束条件取三者之一：达到目标数量 / 连续 15 秒没有新产出 / 到达总时限。
local function wait_for_parsers(target, max_ms)
  local start = vim.uv.now()
  local last_n, last_change = -1, vim.uv.now()
  while vim.uv.now() - start < max_ms do
    vim.wait(500)
    local n = #vim.fn.glob(parser_dir .. '/*', false, true)
    if n >= target then return n end
    if n ~= last_n then
      last_n, last_change = n, vim.uv.now()
      log(('  解析器进度 %d/%d'):format(n, target))
    elseif vim.uv.now() - last_change > 15000 then
      log(('  连续 15 秒无新产出，认为已停止（%d/%d）'):format(n, target))
      break
    end
  end
  return #vim.fn.glob(parser_dir .. '/*', false, true)
end

local ok_ts, ts = pcall(require, 'nvim-treesitter')
if ok_ts then
  local already = #vim.fn.glob(parser_dir .. '/*', false, true)
  log(('安装 %d 个 tree-sitter 解析器（需要 tree-sitter CLI + C 编译器；已有 %d 个）')
    :format(#PARSERS, already))

  local call_ok, err = pcall(function() ts.install(PARSERS) end)
  if not call_ok then
    log('调用 tree-sitter 安装失败：' .. tostring(err))
  else
    local n = wait_for_parsers(already + #PARSERS, 25 * 60 * 1000)
    log(('解析器就位 %d 个（目标 %d）'):format(n, already + #PARSERS))
  end
else
  log('require("nvim-treesitter") 失败 —— 插件没在 runtimepath 上？')
end

-- ---------------------------------------------------------------------------
-- 2. 验证 blink.cmp 的原生库
--    库由 workflow 从官方 release 预置到 <插件>/target/release/（带 sha256 校验），
--    并刻意不写 version 文件 —— blink 见「无 version + 库可加载」就直接采用，
--    因此不依赖 git tag、也不联网。这里做的是**加载验证**：它能被 require 成功，
--    同时证明这个库与当前源码的 ABI 是兼容的（比只查文件存在强得多）。
-- ---------------------------------------------------------------------------
local blink_ext = jit.os:lower() == 'windows' and '.dll' or '.so'
local blink_lib = distro .. '/pack/distro/start/blink.cmp/target/release/libblink_cmp_fuzzy' .. blink_ext
if vim.uv.fs_stat(blink_lib) then
  local ok, err = pcall(require, 'blink.cmp.fuzzy.rust')
  log('blink 原生库加载：' .. (ok and 'ok' or ('失败 -> ' .. tostring(err):gsub('\n.*', ''))))
else
  log('blink 原生库缺失：' .. blink_lib)
end

-- ---------------------------------------------------------------------------
-- 3. 收走 stdpath('data')（tree-sitter 的 parser/ 与 queries/ 都在这里）
-- ---------------------------------------------------------------------------
local function walk(root)
  local files = {}
  local function rec(dir)
    local ok, it = pcall(vim.fs.dir, dir)
    if not ok then return end
    for name, kind in it do
      local p = dir .. '/' .. name
      if kind == 'directory' then rec(p) else files[#files + 1] = p end
    end
  end
  rec(root)
  return files
end

local dest = out .. '/neovim-data'
vim.fn.mkdir(dest, 'p')

local listing, total, copied = {}, 0, 0
for _, f in ipairs(walk(data)) do
  local rel = f:sub(#data + 2)
  local size = math.max(vim.fn.getfsize(f) or 0, 0)
  total = total + size
  listing[#listing + 1] = string.format('%10d  %s', size, rel)
  if not rel:match('^log/') and not rel:match('shada') then
    local target = dest .. '/' .. rel
    vim.fn.mkdir(vim.fs.dirname(target), 'p')
    if vim.fn.filereadable(f) == 1 then
      vim.fn.writefile(vim.fn.readfile(f, 'b'), target, 'b')
      copied = copied + 1
    end
  end
end
table.sort(listing)
vim.fn.writefile(listing, out .. '/listing.txt')
log(('收走 %d 个文件，原始合计 %.1f MB'):format(copied, total / 1024 / 1024))

-- ---------------------------------------------------------------------------
-- 4. 断言：关键产物缺失就明确失败，别让 CI 报成功却产出空包
-- ---------------------------------------------------------------------------
local function has(pattern)
  for _, l in ipairs(listing) do
    if l:match(pattern) then return true end
  end
  return false
end

local problems = {}
if not has('parser/') then problems[#problems + 1] = '没有 tree-sitter 解析器（parser/ 为空）' end

-- blink 的库在 pack/ 内（不在 data 里），所以单独查；顺带做一次加载验证。
-- 注意：这里必须直接用 blink_lib 判断，不能依赖某个可能为 nil 的变量 ——
-- 否则条件恒假、断言被静默跳过，正是这类脚本最该避免的失败方式。
if vim.uv.fs_stat(blink_lib) == nil then
  problems[#problems + 1] = 'blink.cmp 原生库缺失：' .. blink_lib
elseif not pcall(require, 'blink.cmp.fuzzy.rust') then
  problems[#problems + 1] = 'blink.cmp 原生库存在但加载失败（ABI 与源码不匹配？）：' .. blink_lib
end

-- jieba 的库由 workflow 里的 build 脚本产出，同样在 pack/ 内
local jieba_ext = jit.os:lower() == 'windows' and '.dll' or '.so'
local jieba_lib = distro .. '/pack/distro/start/jieba.vim/lua/jieba_vim/jieba_vim_rs' .. jieba_ext
if vim.uv.fs_stat(jieba_lib) == nil then problems[#problems + 1] = 'jieba.vim cdylib 缺失：' .. jieba_lib end

if #problems > 0 then
  io.write('\n[harvest] 产物不完整：\n')
  for _, p in ipairs(problems) do io.write('  - ' .. p .. '\n') end
  io.write('[harvest] 完整清单见 ' .. out .. '/listing.txt\n')
  vim.cmd('cquit 1')
end

log('产物完整')
