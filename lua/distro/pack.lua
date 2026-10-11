-- 插件加载机制。
--
-- 本发行版**不用插件管理器**：插件就是 pack/distro/{start,opt} 下的目录。
--   start/  Neovim 启动时自动加载（由 packpath 发现，见 init.lua 的说明）
--   opt/    必须显式 :packadd 才会加载 —— 这就是我们实现「懒加载」的手段，
--           不需要任何管理器，也不会有任何联网行为。
--
-- 为什么不用管理器，见 docs/ARCHITECTURE.md 第 2 节：管理器的核心职责是
-- 「从网络拉取并锁定版本」，而我们的要求是零联网，这个职责本身就消失了。

local M = {}

-- 已经 packadd 过的插件名（目录名，如 'oil.nvim'）
local loaded = {}

--- 把一个 opt 插件加进 runtimepath 并加载它的 plugin/ 脚本。
-- 幂等：重复调用只生效一次。
-- @param name string pack/distro/opt 下的目录名
-- @return boolean 是否可用
function M.add(name)
  if loaded[name] then return true end
  local ok = pcall(vim.cmd, 'packadd ' .. name)
  if ok then
    loaded[name] = true
  else
    vim.notify(('distro: 无法 packadd %s（pack/distro/opt 下没有这个目录？）'):format(name),
      vim.log.levels.WARN)
  end
  return ok
end

--- 把键位变成「第一次按下时才加载」。
-- 这是整套懒加载的核心：插件在真正用到之前，连 runtimepath 都不进。
-- @param keys string|string[] 触发键位
-- @param names string|string[] 需要 packadd 的插件（顺序即加载顺序）
-- @param setup fun|nil 加载后执行的配置
-- @param desc string|nil 键位说明（which-key 会显示）
function M.lazy(keys, names, setup, desc)
  local list = type(names) == 'table' and names or { names }
  local function run()
    for _, n in ipairs(list) do
      if not M.add(n) then return end
    end
    if setup then
      local ok, err = pcall(setup)
      if not ok then
        vim.notify(('distro: 配置 %s 时出错：%s'):format(table.concat(list, ', '), err),
          vim.log.levels.ERROR)
      end
    end
  end

  for _, key in ipairs(type(keys) == 'table' and keys or { keys }) do
    vim.keymap.set('n', key, run, { desc = desc or ('加载 ' .. table.concat(list, ', ')) })
  end
end

--- 供 :checkhealth 与排错使用。
-- @return string[] 已按需加载的插件名
function M.loaded()
  local names = {}
  for name in pairs(loaded) do names[#names + 1] = name end
  table.sort(names)
  return names
end

--- 列出 pack/distro/{start,opt} 下实际存在的插件目录。
-- 用来对照「选型里要求的」与「磁盘上真有的」——离线发行版最怕静默少东西。
-- @return table<string, string[]> { start = {...}, opt = {...} }
function M.installed()
  local root = (vim.g.distro_root or '') .. '/pack/distro'
  local result = { start = {}, opt = {} }
  for _, which in ipairs({ 'start', 'opt' }) do
    local dir = root .. '/' .. which
    local ok, it = pcall(vim.fs.dir, dir)
    if ok then
      for name, kind in it do
        if kind == 'directory' then result[which][#result[which] + 1] = name end
      end
    end
    table.sort(result[which])
  end
  return result
end

return M
