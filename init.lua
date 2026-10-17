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

-- ---------------------------------------------------------------------------
-- 运行期目录：等价于 nvim.cmd 里那几行 set，但**必须放在这里**。
--
-- 为什么不能只靠启动脚本：经 junction（%LOCALAPPDATA%\nvim -> 包目录）、
-- 双击、或直接调 exe 时，进程环境里没有 XDG_* / TMPDIR，Neovim 会试着把
-- 字节码缓存写到 %TEMP%\nvim\luac，失败时插件加载直接抛
--   E5113: EPERM ... luac
-- 表现就是「打开文件弹一堆 Error in .../plugin/xxx.lua」。
--
-- 放在 init.lua 最前面，任何启动方式都能自洽；nvim.cmd 里同样的设置保留，
-- 二者互为兜底（脚本先设好，这里再设一次是幂等的）。
-- ---------------------------------------------------------------------------
do
    local function dir(rel)
        local p = root .. '/.local/' .. rel
        if vim.fn.isdirectory(p) == 0 then pcall(vim.fn.mkdir, p, 'p') end
        return p
    end
    vim.env.XDG_CONFIG_HOME = dir('config')
    vim.env.XDG_DATA_HOME = dir('data')
    vim.env.XDG_STATE_HOME = dir('state')
    vim.env.XDG_CACHE_HOME = dir('cache')
    vim.env.TMPDIR = dir('tmp')
    vim.env.TMP = vim.env.TMPDIR
    vim.env.TEMP = vim.env.TMPDIR
end

vim.g.distro_root = root
vim.opt.runtimepath:prepend(root)
vim.opt.packpath:prepend(root)

-- 去重：同一个目录在 runtimepath 里出现两次，会让 Vimscript 插件被 source
-- 两次（症状是启动时报 E122 function ... already exists，例如 jieba.vim）。
-- 经 junction（%LOCALAPPDATA%\nvim）启动、又同时用 -u 指向真实路径时就会这样；
-- Neovim 自己也会把 pack/*/start 加进 runtimepath，叠加后更容易重复。
-- 比较时先 resolve 成真实路径（junction 与真实路径视为同一个），再大小写归一。
local function dedupe_paths(list)
    local seen, out = {}, {}
    for _, entry in ipairs(list) do
        if entry and entry ~= '' then
            local resolved = vim.fn.resolve(entry)
            if resolved == '' then resolved = entry end
            local key = resolved:gsub('\\', '/'):lower():gsub('/+$', '')
            if not seen[key] then
                seen[key] = true
                out[#out + 1] = entry
            end
        end
    end
    return out
end
vim.opt.runtimepath = dedupe_paths(vim.opt.runtimepath:get())
vim.opt.packpath = dedupe_paths(vim.opt.packpath:get())

-- 随包的 tree-sitter 解析器与查询要挂上 runtimepath。
--
-- **不挂上去的话，包里的解析器就是纯死重量** —— Neovim 与 nvim-treesitter 都只在
-- runtimepath 上找 parser/ 与 queries/，不会主动去翻包里的 vendor/ 目录。
-- 这一点在第一次实机验收时暴露过：包里 20 个解析器，运行时一个都看不见。
--
-- 两种布局都认，因为已经发布出去的包用的是旧布局：
--   新：vendor/treesitter/site            （每平台一个包，不必再分平台子目录）
--   旧：vendor/prebuilt/<平台>/neovim-data/site（曾经一个包里装两个平台）
--
-- 用 append 而不是 prepend：Neovim 自带 c/lua/markdown/vim 等解析器，
-- 那些与它自身的 ABI 必然匹配，让它们优先更稳；我们补的是 Neovim 没有的语言。
local ts_candidates = {
  root .. '/vendor/treesitter/site',
  root
    .. '/vendor/prebuilt/'
    .. (vim.fn.has('win32') == 1 and 'win64' or 'linux64')
    .. '/neovim-data/site',
}
for _, dir in ipairs(ts_candidates) do
  if vim.uv.fs_stat(dir) then
    vim.opt.runtimepath:append(dir)
    vim.g.distro_treesitter_dir = dir
    break
  end
end

-- 随包的 Neovim 本体（若这个包带了的话）。
-- 带上它的意义：包里的解析器就是由它亲自编译的，ABI 不可能失配。
local runtime = root .. '/runtime'
if vim.uv.fs_stat(runtime) then
  vim.g.distro_runtime = runtime
end

require('distro').setup()

-- 用户覆盖层：最后加载，让它赢过发行版的一切默认值。
--
-- 位置在 .local/config/user.lua（状态目录）：按文档的升级规则，保住 .local
-- 就保住了你的定制 —— 改发行版自己的文件，升级时会被整体覆盖掉。
-- 文件不存在则跳过；出错只报告，不让编辑器起不来（与发行版降级策略一致）。
--
-- 例：
--   vim.cmd.colorscheme('kanagawa')
--   vim.g.distro_disable = { 'mini.animate' }   -- （预留，见 USAGE.md）
local user_cfg = root .. '/.local/config/user.lua'
if vim.uv.fs_stat(user_cfg) then
  local ok, err = pcall(dofile, user_cfg)
  if not ok then
    vim.notify('distro: 用户配置 .local/config/user.lua 出错：' .. tostring(err), vim.log.levels.ERROR)
  end
end
