-- 在 CI 里采集「平台相关」的产物。
--
-- 为什么需要它：包里有三样东西无法只编一次就同时满足 Windows 与 Linux ——
--   tree-sitter 解析器（.so / .dll，且 ABI 与 Neovim 版本强耦合）
--   blink.cmp 的 Rust 模糊匹配库
--   jieba.vim 的 Rust cdylib
-- 所以流程是「两个平台各跑一次本脚本 → 各自产出 → 汇总进一个包」。
--
-- 本脚本的策略是**让插件自己 bootstrap**，而不是我们手写 cargo / tree-sitter 命令：
-- 这三个插件本来就带「下载或编译预编译产物」的逻辑，在 CI 里（有网）直接借用它，
-- 比复刻它们的构建细节可靠得多 —— 也不会随上游改动而失效。
--
-- 用法（CI 里）：
--   nvim --headless -u <distro>/init.lua -l tools/harvest.lua
-- 环境变量：
--   DISTRO_ROOT   发行版根目录（默认取脚本上两级）
--   HARVEST_OUT   产物输出目录（默认 build/prebuilt）
--   XDG_DATA_HOME 必须由调用方指向一个干净的临时目录 —— 插件会把产物放进这里，
--                 我们再整体收走。这里刻意不去猜每个插件的内部路径。
--
-- 产出布局：
--   $HARVEST_OUT/neovim-data/...    stdpath('data') 的完整副本（含 parser/ 与 queries/）
--   $HARVEST_OUT/listing.txt        文件清单与体积，供诊断用
-- 脚本会在结束时打印清单。**没有产出就报错退出**，不留一个「看起来成功」的空产物。

local function env(name, default)
  local v = vim.env[name]
  if v == nil or v == '' then return default end
  return v
end

local function dirname(p) return vim.fn.fnamemodify(p, ':h') end

local distro = vim.fs.normalize(env('DISTRO_ROOT', dirname(dirname(vim.env.MYVIMRC or '.'))))
local out = vim.fs.normalize(env('HARVEST_OUT', distro .. '/build/prebuilt'))
local data = vim.fs.normalize(vim.fn.stdpath('data'))

local log = function(msg) io.write('[harvest] ' .. msg .. '\n') end

log('distro = ' .. distro)
log('out    = ' .. out)
log('data   = ' .. data)
log('nvim   = ' .. tostring(vim.version()))

-- XDG_DATA_HOME 必须是干净的临时目录，否则会把开发机上的既有产物一起收走。
if not vim.startswith(data, vim.fs.normalize(env('HARVEST_SANDBOX', out))) then
  log('警告：stdpath(data) 不在预期的沙箱目录内 —— 请让 CI 把 XDG_DATA_HOME 指向临时目录')
end

vim.fn.mkdir(out, 'p')

-- ---------------------------------------------------------------------------
-- 1. tree-sitter 解析器
--    nvim-treesitter 的 install_dir 可配置，装到临时 data 目录下的 site/。
--    解析器列表按发行版实际要支持的语言来（少装几个能显著缩短 CI 时间）。
-- ---------------------------------------------------------------------------
local PARSERS = {
  'lua', 'luadoc', 'c', 'cpp', 'python', 'bash', 'markdown', 'markdown_inline',
  'vim', 'vimdoc', 'query', 'json', 'yaml', 'toml', 'diff', 'gitcommit',
  'regex', 'comment', 'printf', 'cmake', 'make',
}

local ok_ts, ts = pcall(require, 'nvim-treesitter')
if ok_ts then
  log('安装 ' .. #PARSERS .. ' 个 tree-sitter 解析器（需要 tree-sitter CLI + C 编译器）')
  local ok, err = pcall(function() ts.install(PARSERS) end)
  if not ok then
    log('tree-sitter 安装失败：' .. tostring(err))
  end
else
  log('require("nvim-treesitter") 失败：插件是否已在 runtimepath 上？')
end

-- ---------------------------------------------------------------------------
-- 2 & 3. blink.cmp 与 jieba.vim 的预编译库
--    两者都是「首次使用时下载预编译产物」。这里各触发一次，产物会落到
--    stdpath('data') 下，随后被整体收走。
-- ---------------------------------------------------------------------------
for _, m in ipairs({ 'blink.cmp', 'jieba_vim' }) do
  local ok = pcall(require, m)
  log(('require(%s) -> %s'):format(m, ok and 'ok' or '失败'))
end

-- jieba.vim 提供显式的安装入口，直接调用它比依赖 require 的副作用可靠
local has_jieba = pcall(vim.cmd, 'call jieba_vim#install()')
log('jieba_vim#install() -> ' .. (has_jieba and 'ok' or '不可用（插件未加载？）'))

-- ---------------------------------------------------------------------------
-- 收走产物 + 打印清单
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
  local size = (vim.fn.getfsize(f) or 0)
  total = total + math.max(size, 0)
  listing[#listing + 1] = string.format('%10d  %s', size, rel)
  -- 词典等大文件也一并带走，但跳过明显的缓存目录
  if not rel:match('^log/') and not rel:match('shada') then
    local target = dest .. '/' .. rel
    vim.fn.mkdir(dirname(target), 'p')
    if vim.fn.filereadable(f) == 1 then
      vim.fn.writefile(vim.fn.readfile(f, 'b'), target, 'b')
      copied = copied + 1
    end
  end
end

table.sort(listing)
vim.fn.writefile(listing, out .. '/listing.txt')

log(('收走 %d 个文件，原始合计 %.1f MB'):format(copied, total / 1024 / 1024))

-- 关键产物缺失就明确失败，别让 CI 报成功却产出空包
local function has(pattern)
  for _, l in ipairs(listing) do
    if l:match(pattern) then return true end
  end
  return false
end

local problems = {}
if not has('parser/') then problems[#problems + 1] = '没有任何 tree-sitter 解析器（parser/ 为空）' end
if not has('blink') then problems[#problems + 1] = '没有 blink.cmp 的预编译库' end
if not has('jieba') then problems[#problems + 1] = '没有 jieba.vim 的预编译库' end

if #problems > 0 then
  io.write('\n[harvest] 产物不完整：\n')
  for _, p in ipairs(problems) do io.write('  - ' .. p .. '\n') end
  io.write('[harvest] 完整清单见 ' .. out .. '/listing.txt\n')
  vim.cmd('cquit 1')
end

log('产物完整')
