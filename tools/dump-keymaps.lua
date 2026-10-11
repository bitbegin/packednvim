-- 导出当前 Neovim 实例的全部键位，供 tools/gen-keymaps.py 生成文档。
--
-- 为什么要「干净基线 + 发行版」各 dump 一次再取差集：
-- nvim_get_keymap 会把 Neovim 内置的几十个默认键位也返回（Y、[、]、<C-W> 前缀…），
-- 直接倒出来只会淹没真正属于本发行版的那部分。取差集得到的才是「这个发行版加了什么」。
--
-- 用法（由 gen-keymaps 脚本调用）：
--   nvim --headless -u NONE     -l tools/dump-keymaps.lua   # 基线
--   nvim --headless -u init.lua -l tools/dump-keymaps.lua   # 发行版
-- 环境变量：
--   DUMP_OUT  输出文件路径（必填）

local out = vim.env.DUMP_OUT
if out == nil or out == '' then
  io.stderr:write('dump-keymaps: 必须设置 DUMP_OUT\n')
  vim.cmd('cquit 1')
end

local MODES = { 'n', 'i', 'x', 's', 'o', 't', 'c' }

--- 把非法 UTF-8 字节替换成 \xNN 记号。
--
-- 为什么需要：键位里可能含原始字节（Neovim 把某些特殊键存成单字节），
-- 而我们的说明文字是 UTF-8 中文 —— 不能简单「丢掉所有 >= 0x80 的字节」，
-- 那会把中文也毁掉。所以按 UTF-8 编码规则逐字符校验，只替换真正非法的字节。
-- 不做这一步，生成的 tsv 就不是合法 UTF-8，下游 Python 读它会直接崩。
local function sanitize_utf8(s)
  local out, i, n = {}, 1, #s
  while i <= n do
    local c = s:byte(i)
    local len = 1
    if c >= 0xC2 and c <= 0xDF then
      len = 2
    elseif c >= 0xE0 and c <= 0xEF then
      len = 3
    elseif c >= 0xF0 and c <= 0xF4 then
      len = 4
    elseif c >= 0x80 then
      len = 0 -- 0x80..0xC1 不能作为首字节
    end

    local valid = len > 0 and (i + len - 1) <= n
    if valid and len > 1 then
      for k = 1, len - 1 do
        local cc = s:byte(i + k)
        if cc == nil or cc < 0x80 or cc > 0xBF then
          valid = false
          break
        end
      end
    end

    if valid then
      out[#out + 1] = s:sub(i, i + len - 1)
      i = i + len
    else
      out[#out + 1] = ('\\x%02X'):format(c)
      i = i + 1
    end
  end
  return table.concat(out)
end

local function clean(s)
  s = tostring(s or '')
  -- 制表符与换行会破坏 tsv 结构；< 与 > 保留，它们是键名的组成部分
  s = s:gsub('[\t\r\n]', ' ')
  return sanitize_utf8(s)
end

local lines = {}
local seen = {}

local function emit(mode, map, scope)
  -- Lua 回调式映射没有 rhs，只有 callback —— 那种情况用 <Lua> 占位，
  -- 说明文字靠 desc（本发行版所有自建键位都带 desc）。
  local rhs = map.rhs
  if rhs == nil or rhs == '' then
    rhs = map.callback ~= nil and '<Lua>' or ''
  end

  local key = mode .. '\t' .. map.lhs
  if seen[key] then return end -- 全局与 buffer-local 重名时以先出现的为准
  seen[key] = true

  lines[#lines + 1] = table.concat({
    mode,
    clean(map.lhs),
    clean(rhs),
    clean(map.desc),
    map.buffer == 1 and 'buffer' or scope,
  }, '\t')
end

for _, m in ipairs(MODES) do
  for _, map in ipairs(vim.api.nvim_get_keymap(m)) do
    emit(m, map, 'global')
  end
end

-- 当前缓冲区的 buffer-local 键位（例如 LSP attach 后按缓冲区设的那些）
for _, m in ipairs(MODES) do
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, m)) do
    emit(m, map, 'buffer')
  end
end

table.sort(lines)
vim.fn.writefile(lines, out)
io.write(('[dump-keymaps] %d 条 -> %s\n'):format(#lines, out))
