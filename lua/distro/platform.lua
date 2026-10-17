-- 平台差异的唯一权威来源。
--
-- 为什么需要它：jieba 在 macOS 用 .so 而 blink 用 .dylib，这条知识曾经
-- 散落在 harvest.lua、release.yml、zh.lua 三处，结果在第三处写错，
-- 让 darwin 包误报「缺少 cdylib」。**能写错的地方只允许有一个。**
--
-- 注意：扩展名必须与**各插件自己的加载器**一致，而不是与
-- 「共享库的常见叫法」一致 —— blink.cmp 的 get_lib_extension() 与
-- jieba.vim 的 loader 对 macOS 的约定不同，这不是我们能统一的，
-- 所以 lib_ext 按插件家族（family）区分。
local M = {}

--- 小写的操作系统名（jit.os）：'windows' / 'linux' / 'osx' / 'bsd' / 'posix'
function M.os_name()
  return jit.os:lower()
end

--- 可执行文件后缀：Windows 为 '.exe'，其余为 ''。
function M.exe_suffix()
  return vim.fn.has('win32') == 1 and '.exe' or ''
end

--- 共享库后缀。
--- family：'blink'（macOS 为 .dylib）或 'jieba'（macOS 为 .so）。
function M.lib_ext(family)
  local os = M.os_name()
  if os == 'windows' then
    return '.dll'
  end
  if family == 'blink' and (os == 'osx' or os == 'mac') then
    return '.dylib'
  end
  return '.so'
end

return M
