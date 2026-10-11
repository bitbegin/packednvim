-- 发行版入口。
--
-- 关键一点：把发行版根目录前置进 runtimepath。
--
-- 这样 `nvim -u <distro>/init.lua` 才 require 得到 lua/distro/*，
-- 也才能发现 pack/distro/{start,opt}（pack 目录是靠 runtimepath 查找的）。
-- 好处是整个发行版目录可以随便挪位置、不依赖 stdpath('config')，
-- 因此不会和你机器上已有的 Neovim 配置互相污染。

local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h')

vim.g.distro_root = root
vim.opt.runtimepath:prepend(root)

require('distro').setup()
