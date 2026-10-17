-- 格式化：conform.nvim 调度，配合随包分发的 stylua / shfmt / shellcheck。
--
-- 核心原则：**先探测命令是否存在**。
-- 缺一个格式化器只该让「那一种语言」不能格式化，不该让保存时报错或卡住。
-- 这也符合本发行版的分工：bin/ 里带了 Lua 与 Shell 的格式化器，
-- C/C++ 与 Python 的按需自备（见 docs/DECIDED.md）。

local M = {}

-- 期望的格式化器（键名用 conform 的内置名字）
local WANT = {
  lua = { 'stylua' },
  sh = { 'shfmt' },
  bash = { 'shfmt' },
  zsh = { 'shfmt' },
  python = { 'ruff_format', 'black' },
  c = { 'clang_format' },
  cpp = { 'clang_format' },
  json = { 'prettier' },
  jsonc = { 'prettier' },
  yaml = { 'prettier' },
  markdown = { 'prettier' },
  javascript = { 'prettier' },
  typescript = { 'prettier' },
  typescriptreact = { 'prettier' },
}

-- 探测结果，供 :checkhealth distro 或排错查看
M.available = {}
M.unavailable = {}

local function is_available(conform, name)
  local spec = conform.formatters and conform.formatters[name]
  if not spec then return false end
  -- 命令可能是函数（动态决定）；那种情况交给 conform 自己处理，我们不算它缺失
  local cmd = spec.command or name
  if type(cmd) == 'function' then return true end
  if type(cmd) == 'table' then cmd = cmd[1] end
  return vim.fn.executable(cmd) == 1
end

--- 格式化指定缓冲区（LSP 键位里 <leader>fmt 会调它）
-- @param bufnr number|nil
function M.format(bufnr)
  local ok, conform = pcall(require, 'conform')
  if not ok then
    vim.notify('distro: conform.nvim 未加载，无法格式化', vim.log.levels.WARN)
    return
  end
  conform.format({
    bufnr = bufnr,
    async = true,
    lsp_format = 'fallback', -- 没有外部格式化器时退回 LSP，总比什么都不做强
    timeout_ms = 3000,
  })
end

function M.setup()
  local ok, conform = pcall(require, 'conform')
  if not ok then return end

  -- 按探测结果过滤：只保留命令真实存在的格式化器
  local by_ft = {}
  for ft, names in pairs(WANT) do
    local keep = {}
    for _, name in ipairs(names) do
      if is_available(conform, name) then
        keep[#keep + 1] = name
        M.available[name] = true
      else
        M.unavailable[name] = true
      end
    end
    if #keep > 0 then by_ft[ft] = keep end
  end

  conform.setup({
    formatters_by_ft = by_ft,

    -- 「该缓冲区没有可用格式化器」不弹通知：WANT 已按「命令存在」过滤过，
    -- 再提示只剩噪音。conform 真正的开关是 notify_no_formatters ——
    -- （这里曾写 vim.g.conform_quiet = true，那是不存在的配置项，静默无效。）
    -- notify_on_error 保持默认开启：格式化器**运行时**的失败值得知道。
    notify_no_formatters = false,

    -- 保存时格式化，但有两个例外：
    --   1. 大文件（search.lua 打了 distro_bigfile 标记）—— 别在几 MB 的文件上跑格式化
    --   2. 没有可用格式化器的缓冲区 —— conform 会直接跳过，不报错
    format_on_save = function(bufnr)
      if vim.b[bufnr].distro_bigfile then return nil end
      local ft = vim.bo[bufnr].filetype
      if not by_ft[ft] then return nil end
      return { timeout_ms = 3000, lsp_format = 'fallback' }
    end,
  })
end

--- 供 health 报告：拿不到格式化器的语言清单
-- @return string[]
function M.missing_formatters()
  local names = {}
  for name in pairs(M.unavailable) do names[#names + 1] = name end
  table.sort(names)
  return names
end

return M
