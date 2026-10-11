-- 发行版入口。
--
-- 关键一点：把发行版根目录前置进 runtimepath **和** packpath。
--
-- 这两个是**独立的选项**，改 runtimepath 不会同步 packpath（Vim 文档明确说明）。
-- 而它们分工不同：
--   runtimepath -> `require('distro.*')`、after/、ftplugin/、syntax/ 等
--   packpath    -> `pack/*/start` 会不会被自动加载
--
-- 只前置 runtimepath 的后果很隐蔽：lua/ 能正常 require，看起来一切正常，
-- 但 pack/ 里的插件一个都没加载。CI 第一次跑就是这么失败的。
--
-- 这样整个发行版可以随便挪位置、不依赖 stdpath('config')，
-- 因此不会和机器上已有的 Neovim 配置互相污染。

local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h')

vim.g.distro_root = root
vim.opt.runtimepath:prepend(root)
vim.opt.packpath:prepend(root)

require('distro').setup()
