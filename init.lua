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

-- 把随包的 tree-sitter 解析器与查询挂上 runtimepath。
--
-- 打包时它们被放在 vendor/prebuilt/<平台>/neovim-data/site 下（内含 parser/ 与
-- queries/）。**不挂上去的话，包里的解析器就是纯死重量** —— Neovim 与
-- nvim-treesitter 都只在 runtimepath 上找 parser/ 与 queries/，不会主动去翻包里的
-- vendor/ 目录。这正是第一次实机验收时发现的：包里 20 个解析器，运行时一个都看不见。
--
-- 用 append 而不是 prepend：Neovim 自带 c/lua/markdown/vim 等解析器，
-- 那些与它自身的 ABI 一定匹配，让它们优先更稳；我们补的是 Neovim 没有的那些语言。
local platform = vim.fn.has('win32') == 1 and 'win64' or 'linux64'
local prebuilt = root .. '/vendor/prebuilt/' .. platform .. '/neovim-data/site'
if vim.uv.fs_stat(prebuilt) then
  vim.opt.runtimepath:append(prebuilt)
  vim.g.distro_treesitter_dir = prebuilt
end

require('distro').setup()
