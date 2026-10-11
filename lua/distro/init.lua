-- 发行版主入口。
--
-- 顺序有讲究，不是随便排的：
--   options  最先 —— 后面所有东西都受选项影响（比如 ambiwidth、undofile）
--   pack     其次是加载机制本身，后面的插件配置要用它
--   plugins  逐插件配置（含主题）。必须在 keymaps 之前，否则插件的键位会被我们覆盖
--   search   需求 4/5 的搜索工作流。不依赖任何插件，所以放哪都行，这里紧跟插件之后
--   lsp      语言服务器接线（探测式，缺服务器只记录不报错）
--   format   格式化（同样探测式）
--   keymaps  通用键位放最后，让我们自己的定义赢在最后
--
-- 每一步都单独 pcall：某一个模块出问题不该让整个编辑器起不来。
-- 这与发行版的降级策略一致 —— 只报告，不崩溃。

local M = {}

local ORDER = {
  'options',
  'pack',
  'plugins',
  'search',
  'lsp',
  'format',
  'keymaps',
}

function M.setup()
  M.failed = {}

  for _, name in ipairs(ORDER) do
    local modname = 'distro.' .. name
    local ok, mod = pcall(require, modname)
    if not ok then
      M.failed[name] = tostring(mod)
      vim.notify(('distro: 加载 %s 失败：%s'):format(modname, mod), vim.log.levels.ERROR)
    elseif type(mod) == 'table' and type(mod.setup) == 'function' then
      local ok2, err = pcall(mod.setup)
      if not ok2 then
        M.failed[name] = tostring(err)
        vim.notify(('distro: %s.setup() 出错：%s'):format(modname, err), vim.log.levels.ERROR)
      end
    end
    -- 没有 setup 的模块（如 options）在 require 时就已完成工作
  end
end

return M
