-- 需求 4 / 5 的回归测试。
--
-- 跑法（在发行版根目录，用随包的 nvim）：
--   nvim --headless -u init.lua -l tests/test_search.lua
--
-- 有失败时以退出码 1 结束，方便将来接进 CI 或打包前的冒烟检查。
--
-- 注意：本测试真正调用 rg（子进程），因此**必须在能创建子进程的环境里跑**。
-- 在受限沙箱内 Neovim 会 spawn 失败（shell_error = -1），测试会因此失败 ——
-- 这是环境限制，不是发行版的问题。

local passes, fails = 0, 0

local function check(name, cond, detail)
  if cond then
    passes = passes + 1
    io.write('PASS  ' .. name .. '\n')
  else
    fails = fails + 1
    io.write('FAIL  ' .. name .. (detail and ('   [' .. tostring(detail) .. ']') or '') .. '\n')
  end
end

local function contains(haystack, needle)
  return type(haystack) == 'string' and haystack:find(needle, 1, true) ~= nil
end

-- 用 build/ 下的临时目录，跑完即删；build/ 本来就在 .gitignore 里
local fixdir = vim.fs.normalize(vim.fn.getcwd() .. '/build/fixtures')
vim.fn.delete(fixdir, 'rf')
vim.fn.mkdir(fixdir, 'p')

local search = require('distro.search')

--------------------------------------------------------------------
io.write('\n-- 1. 配置装配 --\n')
--------------------------------------------------------------------

check('能找到 rg', search.rg ~= nil, tostring(search.rg))
check('grepprg 含 --vimgrep', contains(vim.o.grepprg, '--vimgrep'), vim.o.grepprg)
check('grepprg 含 --with-filename', contains(vim.o.grepprg, '--with-filename'), vim.o.grepprg)
check('grepprg 以 -- 结尾', vim.o.grepprg:sub(-3) == ' --', vim.o.grepprg)
check('grepformat = %f:%l:%c:%m', vim.o.grepformat == '%f:%l:%c:%m', vim.o.grepformat)

--------------------------------------------------------------------
io.write('\n-- 2. 按行去重（含 Windows 盘符路径）--\n')
--------------------------------------------------------------------

local raw = {
  [[C:\proj\a.lua:12:3:foo foo]],
  [[C:\proj\a.lua:12:9:foo foo]],
  [[C:\proj\a.lua:20:1:foo]],
  [[/home/u/b.lua:5:2:foo]],
}
local deduped = search.dedupe_by_line(raw)
check('同一行多处匹配被合并', #deduped == 3, '#=' .. #deduped)
check('保留第一处匹配（列号最小）', contains(deduped[1], ':12:3:'), deduped[1])
check('不同文件不互相去重', contains(deduped[3], '/home/u/b.lua:5:2:'), deduped[3])

--------------------------------------------------------------------
io.write('\n-- 3. 真实搜索：正则 + 按行 --\n')
--------------------------------------------------------------------

-- 4 行文件：alpha|beta 共 6 处匹配，分布在 3 行上
local sample = fixdir .. '/sample.log'
vim.fn.writefile({
  'hello alpha',
  'beta beta beta',
  'gamma',
  'alpha and alpha',
}, sample)

-- 用 --no-ignore 避免上层 .gitignore 影响测试结果
search.run({ 'alpha|beta', fixdir }, 'test-dedupe', { extra = { '--no-ignore' } })
local qf = vim.fn.getqflist()
check('按行去重后命中 3 行', #qf == 3, '#qf=' .. #qf)

local lnums, all_resolved = {}, true
for _, e in ipairs(qf) do
  lnums[#lnums + 1] = e.lnum
  local name = vim.fn.bufname(e.bufnr)
  if name == '' or not contains(name, 'sample.log') then
    all_resolved = false
  end
end
table.sort(lnums)
check('命中的行号是 1/2/4', table.concat(lnums, ',') == '1,2,4', table.concat(lnums, ','))
check('每条结果都能定位到文件', all_resolved)

search.run({ 'alpha|beta', fixdir }, 'test-raw', { dedupe = false, extra = { '--no-ignore' } })
check('关掉去重后是 6 处匹配', #vim.fn.getqflist() == 6, '#=' .. #vim.fn.getqflist())

--------------------------------------------------------------------
io.write('\n-- 4. 单文件搜索（大日志场景的取数路径）--\n')
--------------------------------------------------------------------

search.run({ 'gamma', sample }, 'test-single')
local single = vim.fn.getqflist()
check('单文件搜索命中 1 行', #single == 1, '#=' .. #single)
check('单文件搜索行号为 3', single[1] ~= nil and single[1].lnum == 3,
  single[1] and tostring(single[1].lnum))
check('单文件搜索能定位到文件（--with-filename 生效）',
  single[1] ~= nil and contains(vim.fn.bufname(single[1].bufnr), 'sample.log'))

--------------------------------------------------------------------
io.write('\n-- 5. quickfix 双击跳转 --\n')
--------------------------------------------------------------------

vim.cmd('copen')
local qfwin = vim.fn.getqflist({ winid = 0 }).winid
check('quickfix 窗口已打开', qfwin ~= 0, tostring(qfwin))
local qfbuf = vim.api.nvim_win_get_buf(qfwin)

local found_rhs = nil
for _, m in ipairs(vim.api.nvim_buf_get_keymap(qfbuf, 'n')) do
  if m.lhs == '<2-LeftMouse>' then
    found_rhs = m.rhs or ''
  end
end
check('quickfix 缓冲区里有 <2-LeftMouse> 映射', found_rhs ~= nil)
check('映射动作为 <CR> 跳转', contains(found_rhs, '<CR>'), found_rhs)
check('单击未被改成跳转（鼠标可先浏览）',
  (function()
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(qfbuf, 'n')) do
      if m.lhs == '<LeftMouse>' then
        return false
      end
    end
    return true
  end)())

--------------------------------------------------------------------
io.write('\n-- 6. 大文件降级 --\n')
--------------------------------------------------------------------

-- 先拿一个小 lua 文件当基线，确认语法高亮本来是会开的
local small = fixdir .. '/small.lua'
vim.fn.writefile({ 'local a = 1' }, small)
vim.cmd('edit ' .. vim.fn.fnameescape(small))
local baseline_syntax = vim.bo.syntax

-- 造一个 > 2MB 的 lua 文件
local big = fixdir .. '/big.lua'
local chunk = {}
for i = 1, 300000 do
  chunk[i] = 'local x' .. i .. ' = 1'
end
vim.fn.writefile(chunk, big)
local bigsize = vim.fn.getfsize(big)
check('大文件样本超过 2MB 阈值', bigsize > 2 * 1024 * 1024, tostring(bigsize))

vim.cmd('edit ' .. vim.fn.fnameescape(big))
check('大文件被标记', vim.b.distro_bigfile == true, tostring(vim.b.distro_bigfile))
check('文件类型仍被识别（只降级不残废）', vim.bo.filetype == 'lua', vim.bo.filetype)
check('语法高亮被关掉', vim.bo.syntax == '', 'syntax=' .. vim.bo.syntax .. ' 基线=' .. baseline_syntax)
check('undofile 被关掉', vim.bo.undofile == false, tostring(vim.bo.undofile))
check('foldmethod=manual', vim.wo.foldmethod == 'manual', vim.wo.foldmethod)
check('synmaxcol=200', vim.bo.synmaxcol == 200, tostring(vim.bo.synmaxcol))

-- 小文件不应被误判
vim.cmd('edit ' .. vim.fn.fnameescape(small))
check('小文件不被降级', vim.b.distro_bigfile ~= true, tostring(vim.b.distro_bigfile))

--------------------------------------------------------------------
-- 收尾
--------------------------------------------------------------------
vim.fn.delete(fixdir, 'rf')

io.write('\n' .. ('='):rep(48) .. '\n')
if fails > 0 then
  io.write(('%d passed, %d FAILED\n'):format(passes, fails))
  vim.cmd('cquit 1')
else
  io.write(('%d passed, 0 failed\n'):format(passes))
end
