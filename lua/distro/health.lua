-- :checkhealth distro
--
-- 离线发行版最怕的不是报错，而是**静默少东西**：工具没带上、插件没 vendor 到、
-- 语言服务器没装，用户却只看到「功能不好用」。所以健康检查的职责是：把所有
-- 「本该有但现在没有」的东西一次列清楚，并说明缺了会影响什么。
--
-- 这符合本发行版的降级策略：探测失败只报告、不报错（见 lsp.lua / format.lua）。

local M = {}

local h = vim.health

-- ---------------------------------------------------------------------------
-- 读 bin/manifest.json：让检查清单与真正随包的东西保持同步，
-- 而不是在代码里再抄一份工具列表（那种副本迟早会过期）。
-- ---------------------------------------------------------------------------
local function read_manifest()
  local path = (vim.g.distro_root or '') .. '/bin/manifest.json'
  if vim.fn.filereadable(path) ~= 1 then return nil end
  local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), '\n'))
  if not ok then return nil end
  return data
end

local function current_platform()
  local os = vim.fn.has('win32') == 1 and 'windows' or 'linux'
  local arch = jit.arch == 'arm64' and 'arm64' or 'x64'
  return os .. '-' .. arch
end

-- ---------------------------------------------------------------------------
-- 语言服务器清单（按发行版选定的用途：Lua / C-C++ / Python / Shell / 通用）
-- 每项写明「缺了会影响什么」，而不是只报一个名字。
-- ---------------------------------------------------------------------------
local LSP_EXPECTED = {
  { 'lua_ls', { 'lua-language-server' }, 'Lua 与 Neovim 配置开发（你的主要用途，强烈建议装）' },
  { 'clangd', { 'clangd' }, 'C / C++ 的补全与跳转' },
  { 'basedpyright', { 'basedpyright-langserver', 'pyright-langserver' }, 'Python 的类型检查与补全' },
  { 'bashls', { 'bash-language-server' }, 'Shell 脚本补全' },
  { 'jsonls', { 'vscode-json-language-server' }, 'JSON 补全与校验' },
  { 'yamlls', { 'yaml-language-server' }, 'YAML 补全与校验' },
}

-- 不属于插件依赖、但发行版文档里承诺的运行期前置条件
local EXTRA_COMMANDS = {
  { 'git', 'gitsigns / neogit 的全部功能；没有它版本控制相关功能不可用' },
  { 'clang-format', 'conform 格式化 C / C++' },
  { 'clang-tidy', 'nvim-lint 检查 C / C++' },
  { 'luacheck', 'nvim-lint 检查 Lua（无官方预编译产物，需自行安装或构建）' },
  { 'im-select', 'Windows 上输入法自动切换（Linux 用 fcitx5-remote / ibus）' },
  { 'fcitx5-remote', 'Linux(fcitx5) 上输入法自动切换' },
  { 'ibus', 'Linux(ibus) 上输入法自动切换' },
}

function M.check()
  h.start('distro')

  -- -------------------------------------------------------------------------
  h.start('distro: 运行环境')
  local v = vim.version()
  local ver = ('%d.%d.%d'):format(v.major, v.minor, v.patch)
  -- nvim-treesitter 的 main 分支要求 >= 0.12；vim.lsp.config 要求 >= 0.11
  if v.major == 0 and v.minor < 12 then
    h.error(('Neovim %s 低于本发行版要求（>= 0.12）'):format(ver))
  else
    h.ok(('Neovim %s'):format(ver))
  end
  h.info('发行版根目录：' .. (vim.g.distro_root or '(未设置)'))
  h.info('平台：' .. current_platform())
  if vim.g.have_nerd_font then
    h.ok('已启用 Nerd Font 图标（本发行版强依赖；若显示为方块，请安装 Nerd Font）')
  end
  if vim.fn.has('win32') == 1 then
    h.info('Windows 提示：安装路径要与本发行版文档一致，且建议开启长路径支持')
  end

  -- -------------------------------------------------------------------------
  h.start('distro: 插件')

  local pack = require('distro.pack')
  local installed = pack.installed()
  local n_start = #installed.start
  local n_opt = #installed.opt

  local lock_path = (vim.g.distro_root or '') .. '/vendor/lock.json'
  local expected = nil
  if vim.fn.filereadable(lock_path) == 1 then
    local ok, lock = pcall(vim.json.decode, table.concat(vim.fn.readfile(lock_path), '\n'))
    if ok and lock.plugins then expected = #lock.plugins end
  end

  if n_start + n_opt == 0 then
    h.error('pack/distro 下没有任何插件 —— 是不是没跑 tools/vendor.ps1？'
      .. '（pack/ 是构建产物，不进版本库）')
  else
    h.ok(('已 vendor 插件：start %d 个 / opt %d 个'):format(n_start, n_opt))
  end
  -- lock 会保留「历史上选过、现已从方案移除」的插件记录（保留是为了可复现），
  -- 所以它比磁盘上的目录多几个是正常的 —— 不能当成「有缺失」来报警。
  if expected and expected > n_start + n_opt then
    h.info(('vendor/lock.json 有 %d 条记录，磁盘上 %d 个目录；多出的部分是'
      .. '历史上选过、现已从方案移除的插件（记录有意保留）')
      :format(expected, n_start + n_opt))
  end
  local loaded = pack.loaded()
  if #loaded > 0 then
    h.info('已按需加载（packadd）：' .. table.concat(loaded, ', '))
  end

  -- -------------------------------------------------------------------------
  h.start('distro: 随包工具')

  local manifest = read_manifest()
  if not manifest then
    h.error('读不到 bin/manifest.json —— 随包工具的完整性无法确认')
  else
    local platform = current_platform()
    local checked, missing, from_bin, from_system = 0, {}, 0, 0
    for _, t in ipairs(manifest.tools or {}) do
      if t.platform == platform then
        checked = checked + 1
        local path = (vim.g.distro_root or '') .. '/bin/' .. t.file
        if vim.fn.filereadable(path) == 1 and vim.fn.executable(path) == 1 then
          from_bin = from_bin + 1
        elseif vim.fn.executable(vim.fn.fnamemodify(t.file, ':r')) == 1 then
          -- 自带的那份不可用，但系统 PATH 上有同名命令：能用，但不是我们预期的那份
          from_system = from_system + 1
        else
          missing[#missing + 1] = ('%s（%s，%s）'):format(t.tool, t.version, t.file)
        end
      end
    end
    if #missing == 0 then
      h.ok(('%d 个随包工具就位于 bin/（%d 个回退到系统 PATH）'):format(from_bin, from_system))
    else
      h.error('以下随包工具缺失或不可执行：')
      for _, m in ipairs(missing) do h.error('  ' .. m) end
      h.info('Linux 上常见原因：从 Windows 复制导致丢了可执行位。'
        .. '修：chmod +x bin/rg bin/fzf bin/fd bin/stylua bin/shfmt bin/shellcheck')
    end
    if from_system > 0 then
      h.warn(('%d 个工具正从系统 PATH 取用，而不是 bin/ 里随包的那份 —— '
        .. '版本可能与 manifest.json 记录的不一致'):format(from_system))
    end
  end

  -- -------------------------------------------------------------------------
  h.start('distro: 语言服务器')

  local lsp = require('distro.lsp')
  local missing_lsp = {}
  for _, item in ipairs(LSP_EXPECTED) do
    local name, cmds, why = item[1], item[2], item[3]
    local found = nil
    for _, c in ipairs(cmds) do
      if vim.fn.executable(c) == 1 then
        found = c
        break
      end
    end
    if found then
      h.ok(('%s（%s）—— %s'):format(name, found, why))
    elseif lsp.skipped[name] then
      h.warn(('%s 未启用：没找到 %s'):format(name, table.concat(cmds, ' / ')))
      missing_lsp[#missing_lsp + 1] = ('%s —— 影响：%s'):format(name, why)
    end
  end
  if #missing_lsp > 0 then
    h.info('本发行版按决定**不打包语言服务器**，请自行安装后重启。缺失清单：')
    for _, m in ipairs(missing_lsp) do h.info('  ' .. m) end
  end

  -- -------------------------------------------------------------------------
  h.start('distro: 其它外部命令')

  local need = {}
  for _, item in ipairs(EXTRA_COMMANDS) do
    if vim.fn.executable(item[1]) ~= 1 then
      need[#need + 1] = ('%s —— %s'):format(item[1], item[2])
    end
  end
  if #need == 0 then
    h.ok('全部就位')
  else
    h.warn('以下命令不在 PATH 上（只影响对应功能，不影响启动）：')
    for _, n in ipairs(need) do h.warn('  ' .. n) end
  end

  -- -------------------------------------------------------------------------
  h.start('distro: tree-sitter')

  -- 解析器可能来自两处：随包的 vendor/prebuilt/<平台>/，或本机 stdpath('data')/site
  local candidates = {
    (vim.g.distro_root or '') .. '/vendor/prebuilt/'
      .. (vim.fn.has('win32') == 1 and 'win64' or 'linux64') .. '/neovim-data/site/parser',
    vim.fn.stdpath('data') .. '/site/parser',
  }
  local found_dir, count = nil, 0
  for _, dir in ipairs(candidates) do
    local files = vim.fn.glob(dir .. '/*', false, true)
    if #files > 0 then
      found_dir, count = dir, #files
      break
    end
  end
  if found_dir then
    h.ok(('%d 个解析器，来自 %s'):format(count, found_dir))
    -- Neovim 自带的 C / Lua / Markdown / Vimscript 等始终可用，所以这里不是致命项
    if count < 10 then
      h.warn('解析器偏少；Markdown / Lua / C 之外的高亮可能缺失')
    end
  else
    h.warn('没有找到任何随包或本机的 tree-sitter 解析器')
    h.info('不影响基本编辑：Neovim 自带 C / Lua / Markdown / Vimscript / Vimdoc 的解析器')
    h.info('离线包应在 vendor/prebuilt/<平台>/neovim-data/site/parser 下带上解析器')
  end

  -- -------------------------------------------------------------------------
  h.start('distro: 离线状态')

  h.ok('插件与工具均已随包分发，运行时不发起任何网络请求')
  h.info('本发行版的联网风险项（打包时必须预置产物，否则首次使用会尝试下载）：')
  h.info('  blink.cmp 的原生库 -> pack/distro/start/blink.cmp/target/release/')
  h.info('  jieba.vim 的 cdylib  -> pack/distro/start/jieba.vim/lua/jieba_vim/')
  h.info('  tree-sitter 解析器   -> vendor/prebuilt/<平台>/neovim-data/site/parser/')
  local verify = (vim.g.distro_root or '') .. '/tools/verify-offline.ps1'
  if vim.fn.filereadable(verify) == 1 then
    h.info('完整验收：pwsh tools/verify-offline.ps1（在断网环境里跑）')
  end
end

return M
