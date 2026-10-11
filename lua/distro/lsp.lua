-- LSP 接线。
--
-- 本发行版**不打包语言服务器**（已定），也**不用 mason**（它没有官方离线模式）。
-- 所以这里的做法是：
--   1. 从 PATH 探测服务器是否存在
--   2. 存在就 vim.lsp.config + vim.lsp.enable；不存在就记进 skipped，交给
--      :checkhealth distro 汇总报告
--   3. 全程不报错 —— 缺一个语言服务器不该让编辑器起不来
--
-- 用的全是 Neovim 内置 API（vim.lsp.config / vim.lsp.enable，0.11+），
-- 不依赖 require('lspconfig')（那个入口已废弃）。nvim-lspconfig 作为纯配置数据
-- 随包分发，它在 runtimepath 上会被 vim.lsp.config 自动合并。

local M = {}

-- 探测失败的服务器名 -> 尝试过的命令，供 health 报告
M.skipped = {}

--- 服务器清单。键名与 nvim-lspconfig 里的名字一致，这样它的默认配置会被自动合并；
--- 这里只覆盖「命令路径」和少数必须显式指定的项。
M.servers = {
  lua_ls = {
    cmds = { 'lua-language-server' },
    -- 写发行版自身配置时需要 lua_ls 认识 Neovim API 与我们自己的模块。
    -- lazydev 的库注入在 complete.lua 里配置（那里是它的归属），
    -- 这里只设置 lua_ls 自身的诊断与运行时选项。
    after = function(name)
      vim.lsp.config(name, {
        settings = {
          Lua = {
            runtime = { version = 'LuaJIT' },
            diagnostics = { globals = { 'vim' } },
            workspace = {
              checkThirdParty = false,
              library = vim.api.nvim_get_runtime_file('', true),
            },
            telemetry = { enable = false }, -- 离线发行版里这一项必须是 false
          },
        },
      })
    end,
  },

  clangd = {
    cmds = { 'clangd' },
    args = { '--background-index', '--clang-tidy', '--header-insertion=iwyu' },
  },

  -- basedpyright 与 pyright 二选一，优先前者（不依赖 Node）
  basedpyright = { cmds = { 'basedpyright-langserver' }, args = { '--stdio' } },
  pyright = { cmds = { 'pyright-langserver' }, args = { '--stdio' } },

  bashls = { cmds = { 'bash-language-server' }, args = { 'start' } },
  jsonls = { cmds = { 'vscode-json-language-server' }, args = { '--stdio' } },
  yamlls = { cmds = { 'yaml-language-server' }, args = { '--stdio' } },
}

-- basedpyright 与 pyright 只能启用一个：两个都装时优先靠前的那个，
-- 否则同一份 import 会被两套类型检查同时诊断，重复且互相打架。
local EITHER_GROUPS = { { 'basedpyright', 'pyright' } }

--- 找到第一个可用命令
local function detect(cmds)
  for _, c in ipairs(cmds) do
    if vim.fn.executable(c) == 1 then return c end
  end
end

local function lsp_keymaps(ev)
  local buf = ev.buf
  local map = function(keys, fn, desc)
    vim.keymap.set('n', keys, fn, { buffer = buf, desc = desc })
  end

  map('gd', vim.lsp.buf.definition, '跳转到定义')
  map('gD', vim.lsp.buf.declaration, '跳转到声明')
  map('gr', vim.lsp.buf.references, '查找引用')
  map('gi', vim.lsp.buf.implementation, '跳转到实现')
  map('gt', vim.lsp.buf.type_definition, '跳转到类型定义')
  map('K', vim.lsp.buf.hover, '悬停文档')
  map('<C-k>', vim.lsp.buf.signature_help, '参数签名')
  map('<leader>rn', vim.lsp.buf.rename, '重命名符号')
  map('<leader>ca', vim.lsp.buf.code_action, '代码动作')
  map('<leader>ct', function()
    vim.lsp.buf.code_action({ apply = true, context = { only = { 'source.organizeImports' } } })
  end, '整理 imports')
  map('<leader>cd', vim.diagnostic.open_float, '显示该行诊断')
  map('[d', function() vim.diagnostic.jump({ count = -1 }) end, '上一个诊断')
  map(']d', function() vim.diagnostic.jump({ count = 1 }) end, '下一个诊断')
  map('<leader>fmt', function() require('distro.format').format(buf) end, '格式化当前缓冲区')

  -- 大文件不做语义高亮：search.lua 会打上 distro_bigfile 标记
  if vim.b[buf].distro_bigfile then
    pcall(vim.treesitter.stop, buf)
  end
end

function M.setup()
  local enabled = {}

  for name, spec in pairs(M.servers) do
    if spec then
      local cmd = detect(spec.cmds)
      if cmd then
        local cfg = { cmd = { cmd } }
        if spec.args then
          vim.list_extend(cfg.cmd, spec.args)
        end
        vim.lsp.config(name, cfg)
        if spec.after then
          local ok, err = pcall(spec.after, name)
          if not ok then
            vim.notify(('distro: 配置 %s 时出错：%s'):format(name, err), vim.log.levels.WARN)
          end
        end
        enabled[name] = true
      else
        M.skipped[name] = spec.cmds
      end
    end
  end

  -- 互斥组：同组只启用靠前的那个；两个都没装时不做处理，
  -- 让它们都留在 skipped 里如实报告。
  for _, group in ipairs(EITHER_GROUPS) do
    local picked = nil
    for _, name in ipairs(group) do
      if enabled[name] then
        picked = name
        break
      end
    end
    if picked then
      for _, name in ipairs(group) do
        if name ~= picked then
          enabled[name] = nil -- 不启用它
        end
        M.skipped[name] = nil -- 也不算缺失：同组已有的那个能覆盖这个语言
      end
    end
  end

  for name in pairs(enabled) do
    local ok, err = pcall(vim.lsp.enable, name)
    if not ok then
      vim.notify(('distro: 启用 %s 失败：%s'):format(name, err), vim.log.levels.WARN)
      enabled[name] = nil
    end
  end

  M.enabled = enabled

  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('distro_lsp', { clear = true }),
    desc = 'LSP 键位与大文件降级',
    callback = lsp_keymaps,
  })

  -- 诊断的呈现方式：不写行内虚拟文本（靠 mini.notify / trouble 集中看），
  -- 只保留符号列与行内高亮，视觉噪音小，也更适合中文注释混排。
  vim.diagnostic.config({
    virtual_text = false,
    severity_sort = true,
    underline = true,
    signs = true,
    update_in_insert = false,
    float = { border = 'rounded', source = true },
  })
end

--- 供 health / 排错使用
-- @return string[]
function M.enabled_names()
  local names = {}
  for name in pairs(M.enabled or {}) do names[#names + 1] = name end
  table.sort(names)
  return names
end

return M
