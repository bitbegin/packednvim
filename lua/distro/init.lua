-- 发行版主入口。
--
-- 目前只装配了与插件无关的部分（选项 + 搜索工作流）。
-- 插件加载（pack/distro/start 与 pack/distro/opt）、LSP、主题等，
-- 等插件选型确定后再挂到这里，顺序保持：profile → options → search → plugins → lsp。

local M = {}

function M.setup()
  require('distro.search').setup()
end

return M
