-- 发布包冒烟测试：CI 在每个平台的 runner 上，对**刚打出来的那个包**执行。
--
-- 目的：把「四个平台 built」变成「四个平台 verified」。此前 CI 只断言
-- 产物文件存在，没有任何 runner 启动过它构建的 nvim —— jieba 的 macOS
-- 扩展名错误（构建成功、运行必炸）就是这么漏过去的。
--
-- 用法（在解压出的包目录旁边）：
--   .\nvim.cmd --headless -l <仓库>/tools/smoke.lua     # Windows
--   ./nvim.sh  --headless -l <仓库>/tools/smoke.lua     # Linux / macOS
-- 任何断言失败 -> 非零退出码 -> 构建标红。
--
-- 报告原则：失败时必须**自带定位信息**（哪个插件、什么错、:messages 里
-- 还有什么）。第一版只报数量，darwin 首跑抓到一个配置失败却看不出
-- 是谁 —— 看不出原因的失败报告等于让人再跑一遍。

local failures = {}
local n = 0

local function check(name, ok, detail)
  n = n + 1
  io.write(('[smoke] %-34s %s%s\n'):format(name, ok and 'OK' or 'FAIL',
    detail and ('  ' .. tostring(detail)) or ''))
  if not ok then
    failures[#failures + 1] = name
  end
end

local root = vim.g.distro_root
local platform = require('distro.platform')

-- ---- 1. 配置分组 -------------------------------------------------------
local reg = require('distro.plugins')
local nf = 0
local failed_detail = {}
for k, v in pairs(reg.failed or {}) do
  nf = nf + 1
  failed_detail[#failed_detail + 1] = k .. '：' .. tostring(v):gsub('\n.*', '')
end
check('11 个配置分组全部载入', #(reg.groups or {}) == 11, (#(reg.groups or {})) .. ' 个')
check('无缺失分组', #(reg.missing or {}) == 0, table.concat(reg.missing or {}, ','))
check('无插件配置失败', nf == 0, (#failed_detail > 0)
  and (nf .. ' 个 -> ' .. table.concat(failed_detail, '；'))
  or '0 个')
check('声明与实际目录一致', #(reg.reconciled or {}) == 0,
  (#(reg.reconciled or {})) .. ' 处：' .. table.concat(reg.reconciled or {}, '；'))

-- ---- 2. distro 模块 ----------------------------------------------------
local d = require('distro')
local dn = 0
for _ in pairs(d.failed or {}) do dn = dn + 1 end
check('无模块加载失败', dn == 0, dn .. ' 个')

-- ---- 3. tree-sitter 解析器（随包编译，ABI 应与随包 nvim 一致）----------
local loaded = 0
for _, l in ipairs({ 'bash', 'c', 'cpp', 'go', 'json', 'lua', 'markdown', 'python', 'rust', 'toml', 'vim', 'yaml' }) do
  if pcall(vim.treesitter.language.add, l) then loaded = loaded + 1 end
end
check('tree-sitter 解析器可加载', loaded == 12, loaded .. '/12')

-- ---- 4. 随包工具（bin/ 里能找到）---------------------------------------
local missing_tools = {}
for _, t in ipairs({ 'rg', 'fzf', 'fd', 'stylua', 'shfmt', 'shellcheck' }) do
  if vim.uv.fs_stat(root .. '/bin/' .. t .. platform.exe_suffix()) == nil then
    missing_tools[#missing_tools + 1] = t
  end
end
check('6 个命令行工具随包就位', #missing_tools == 0, table.concat(missing_tools, ','))

-- ---- 5. 原生库（扩展名规则来自 platform.lua）---------------------------
check('blink.cmp 原生库',
  vim.uv.fs_stat(root .. '/pack/distro/start/blink.cmp/target/release/libblink_cmp_fuzzy'
    .. platform.lib_ext('blink')) ~= nil)
check('jieba.vim cdylib',
  vim.uv.fs_stat(root .. '/pack/distro/start/jieba.vim/lua/jieba_vim/jieba_vim_rs'
    .. platform.lib_ext('jieba')) ~= nil)

-- ---- 6. 出过回归的运行时行为（每一条都有一次真实的踩坑）-----------------
check('ambiwidth=single（宽度判定）', vim.o.ambiwidth == 'single')
check('tempname() 非空（TMPDIR 回归）', vim.fn.tempname() ~= '')
check('switchbuf 开新标签页', vim.o.switchbuf:find('newtab') ~= nil)
check('搜索键位 sg/sG 已注册',
  vim.fn.maparg('<leader>sg', 'n') ~= '' and vim.fn.maparg('<leader>sG', 'n') ~= '')

-- ---- 7. 用户覆盖层（若用户放了配置，必须能加载）-------------------------
local user_cfg = root .. '/.local/config/user.lua'
if vim.uv.fs_stat(user_cfg) then
  check('用户配置 .local/config/user.lua 可加载', pcall(dofile, user_cfg))
end

io.write(('[smoke] %s：%d 项检查，%d 项失败  (distro_root=%s)\n')
  :format(#failures == 0 and '通过' or '失败', n, #failures, root))

if #failures > 0 then
  -- 启动期的 vim.notify（包括注册表记录的配置错误、插件脚本报错）都进
  -- :messages 历史；headless 下它们不打印到 stdout，这里主动倒出来，
  -- 让失败日志**自解释**，不用再翻 Actions 的完整日志。
  local msgs = vim.fn.execute('messages')
  if msgs and #msgs > 0 then
    io.write('\n[smoke] :messages 尾部（定位用）：\n')
    local lines = vim.split(msgs, '\n')
    for i = math.max(1, #lines - 30), #lines do
      if lines[i] ~= '' then
        io.write('  ' .. lines[i] .. '\n')
      end
    end
  end
  os.exit(1)
end
