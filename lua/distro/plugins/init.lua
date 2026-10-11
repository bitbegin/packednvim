-- 插件配置注册表。
--
-- 配置按**功能分组**放在本目录下（theme / mini / ui / search / syntax /
-- complete / git / edit / lang / zh / misc），每个分组文件返回一个 spec 列表：
--
--   {
--     names = 'oil.nvim',            -- pack/distro/{start,opt} 下的目录名
--     pack  = 'start' | 'opt',
--     keys  = '<leader>e' | {...},   -- 仅 pack='opt' 时有意义：按下才加载
--     desc  = 'which-key 里显示的说明',
--     setup = function() ... end,
--   }
--
-- 分组的理由：本发行版每个插件的取舍都有原因（为什么用 mini 不用 snacks、
-- 为什么用 fzf-lua 不用 telescope），把选择相近的放一起，理由才讲得清楚。
--
-- start 里的插件由 Neovim 在启动时通过 packpath 自动可用（已实测：配置期内
-- require 就能成功），所以这里对它们只做 setup，不做 packadd。

local M = {}

-- 顺序即加载顺序：主题最先（后续插件的默认高亮组依赖它），
-- 其余大致按「越基础越靠前」。
local GROUPS = {
  'theme',
  'mini',
  'ui',
  'search',
  'syntax',
  'complete',
  'git',
  'edit',
  'lang',
  'zh',
  'misc',
}

--- 本次启动没能载入的分组，供 :checkhealth distro 报告
M.missing = {}
--- 成功载入的分组
M.groups = {}
--- 每个插件配置失败的原因
M.failed = {}

--- 这个插件实际在哪个目录（start 还是 opt）？
--
-- 为什么要查实际目录：**同一个决定被两处做了一次** ——
-- tools/vendor.ps1 的 start 清单决定插件落到 start/ 还是 opt/，
-- 而各分组文件里的 `pack` 字段表达的是「意图」。
-- 两边不一致时（我这次就撞上 4 个：todo-comments、render-markdown、
-- smart-splits、nvim-lsp-file-operations 声明 start 却在 opt/），
-- require 会失败、被 pcall 静默吞掉，表现为「配置写了却完全没生效」。
--
-- 与其要求两处永远一致（做不到），不如让注册表以**实际目录**为准：
-- 声明为常驻但在 opt/ 的，就补一次 packadd。
local function locate(name)
  local base = (vim.g.distro_root or '') .. '/pack/distro'
  if vim.uv.fs_stat(base .. '/start/' .. name) then return 'start' end
  if vim.uv.fs_stat(base .. '/opt/' .. name) then return 'opt' end
  return nil
end

function M.setup()
  local pack = require('distro.pack')
  local missing, ok_groups, failed = {}, {}, {}
  --- 声明与实际不符的插件（记录但不报错，供 :checkhealth 显示）
  M.reconciled = {}

  for _, group in ipairs(GROUPS) do
    local ok, specs = pcall(require, 'distro.plugins.' .. group)
    if not ok or type(specs) ~= 'table' then
      missing[#missing + 1] = group
    else
      ok_groups[#ok_groups + 1] = group
      for _, spec in ipairs(specs) do
        local names = spec.names or group
        local actual = locate(names)
        local declared = spec.pack or 'start'

        if actual ~= nil and actual ~= declared then
          M.reconciled[#M.reconciled + 1] = ('%s: 声明 %s，实际在 %s'):format(names, declared, actual)
        end

        -- 只有「真的在 opt/ 且配了触发键」才是懒加载；
        -- 其余情况都要保证它在启动时可用（在 opt/ 的补一次 packadd）。
        if actual == 'opt' and spec.keys then
          pack.lazy(spec.keys, names, spec.setup, spec.desc)
        else
          if actual == 'opt' then pack.add(names) end
          if spec.setup then
            local ok2, err = pcall(spec.setup)
            if not ok2 then
              failed[names] = tostring(err)
              vim.notify(('distro: 配置 %s 出错：%s'):format(names, err), vim.log.levels.ERROR)
            end
          end
        end
      end
    end
  end

  M.missing, M.groups, M.failed = missing, ok_groups, failed
end

return M
