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

local ok_ts, ts = pcall(require, 'nvim-treesitter')
if ok_ts then
  log(('安装 %d 个 tree-sitter 解析器（需要 tree-sitter CLI + C 编译器）'):format(#PARSERS))
  local ok, err = pcall(function() ts.install(PARSERS) end)
  if not ok then log('tree-sitter 安装失败：' .. tostring(err)) end
else
  log('require("nvim-treesitter") 失败 —— 插件没在 runtimepath 上？')
end

-- ---------------------------------------------------------------------------
-- 2. blink.cmp 的原生库
--    v1 的逻辑要从 git tag 推断版本，而 vendored 副本没有 .git，
--    所以用 force_version 明确指定（值取自 vendor/lock.json 记录的 tag，避免两处脱节）。
--    产物落在 <插件>/target/release/，随 pack/ 一起进包，本脚本不必收走。
-- ---------------------------------------------------------------------------
local blink_tag = nil
local lock_path = distro .. '/vendor/lock.json'
if vim.fn.filereadable(lock_path) == 1 then
  local ok, lock = pcall(vim.json.decode, table.concat(vim.fn.readfile(lock_path), '\n'))
  if ok and lock and lock.plugins then
    for _, p in ipairs(lock.plugins) do
      if p.repo == 'saghen/blink.cmp' then blink_tag = p.branch end
    end
  end
end
log('blink.cmp 目标版本 = ' .. tostring(blink_tag))

local ok_blink, blink = pcall(require, 'blink.cmp')
if ok_blink then
  pcall(function()
    blink.setup({
      fuzzy = {
        prebuilt_binaries = {
          force_version = blink_tag,
          download = true,
          ignore_version_mismatch = true,
        },
      },
    })
  end)
  -- 主动触发一次下载，并等它落盘
  local lib_path
  pcall(function()
    local files = require('blink.cmp.fuzzy.download.files')
    lib_path = files.lib_path
    require('blink.cmp.fuzzy.download').ensure_downloaded(function() end)
  end)
  if lib_path then
    vim.wait(60000, function() return vim.uv.fs_stat(lib_path) ~= nil end, 200)
    log(('blink 原生库 %s -> %s'):format(lib_path, vim.uv.fs_stat(lib_path) and '已就位' or '缺失'))
  else
    log('拿不到 blink 原生库的预期路径')
  end
else
  log('require("blink.cmp") 失败：' .. tostring(blink))
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

-- blink 的库在 pack/ 内，不在 data 里，所以单独查
if blink_tag then
  local ext = jit.os:lower() == 'windows' and '.dll' or '.so'
  local p = distro .. '/pack/distro/start/blink.cmp/target/release/libblink_cmp_fuzzy' .. ext
  if vim.uv.fs_stat(p) == nil then problems[#problems + 1] = 'blink.cmp 原生库缺失：' .. p end
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
