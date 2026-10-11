-- 中文相关：按词移动（jieba）与输入法自动切换（im-select）。
--
-- 这是本发行版区别于其它配置的重点之一。两个都要能「优雅缺失」：
-- 缺了只是少一项便利，不该让编辑器起不来。

return {
  {
    names = 'jieba.vim',
    pack = 'start',
    setup = function()
      -- 关键：jieba 的中文按词移动**默认不启用**，必须显式打开这个开关。
      -- 它的默认值是 0（有意为之：作者不想悄悄接管 w/b/e）。
      --
      -- 时机很重要：这个变量必须在插件的 plugin/ 脚本被 source 之前设好。
      -- 我们的配置在 init.lua 阶段运行，而 Neovim 在 init.lua 之后才 source
      -- plugin/**，所以这里设是来得及的。
      vim.g.jieba_vim_keymap = 1

      -- 延迟加载词典直到真的出现中文：词典解析有开销，纯英文项目不必付这个成本。
      vim.g.jieba_vim_lazy = 1

      -- 自定义词典路径（用户可覆盖）
      if vim.g.jieba_vim_user_dict == nil then
        vim.g.jieba_vim_user_dict = ''
      end

      -- 确认 cdylib 在位。缺了的话插件会在 require 时抛错 —— 与其让用户看到
      -- 一句看不懂的 module not found，不如在这里给出可操作的提示。
      local ext = jit.os:lower() == 'windows' and '.dll' or '.so'
      local lib = (vim.g.distro_root or '')
        .. '/pack/distro/start/jieba.vim/lua/jieba_vim/jieba_vim_rs' .. ext
      if vim.uv.fs_stat(lib) == nil then
        vim.notify(
          'distro: 缺少 jieba 的 cdylib（' .. lib .. '），中文按词移动将不可用。\n'
          .. '这是打包时漏了产物的症状，可跑 :checkhealth distro 查看。',
          vim.log.levels.WARN
        )
      end
    end,
  },

  {
    names = 'im-select.nvim',
    pack = 'start',
    setup = function()
      local ok, im_select = pcall(require, 'im_select')
      if not ok then return end

      -- 按平台决定用哪个命令切输入法。
      -- Windows：随包的 im-select.exe（不需要用户装任何东西）
      -- Linux ：系统里的 fcitx5-remote / ibus（它们不可能随包分发）
      local cmd, why
      if vim.fn.has('win32') == 1 then
        local exe = (vim.g.distro_root or '') .. '/bin/im-select.exe'
        if vim.fn.executable(exe) == 1 then
          cmd, why = exe, '随包的 im-select.exe'
        elseif vim.fn.executable('im-select') == 1 then
          cmd, why = 'im-select', 'PATH 上的 im-select'
        else
          why = '找不到 im-select.exe'
        end
      else
        for _, c in ipairs({ 'fcitx5-remote', 'ibus' }) do
          if vim.fn.executable(c) == 1 then
            cmd, why = c, '系统里的 ' .. c
            break
          end
        end
        if not cmd then why = '系统里没有 fcitx5-remote 也没有 ibus' end
      end

      if not cmd then
        -- 不报错、不打扰：输入法切换只是便利功能
        vim.g.distro_im_select_missing = why
        return
      end

      pcall(im_select.setup, {
        default_command = cmd,
        -- Windows 中文输入法的英文键盘布局 ID；Linux 下由 fcitx5/ibus 自己管，无意义
        default_im_select = '1033',
        -- 离开插入模式/命令行时切回默认（英文），进入插入模式时恢复上次的输入法
        set_default_events = { 'InsertLeave', 'CmdlineLeave' },
        set_previous_events = { 'InsertEnter' },
        -- 命令不存在时安静跳过，不要每次进出插入模式都弹一次提示
        keep_quiet_on_no_binary = 1,
      })
      vim.g.distro_im_select_command = cmd
      vim.g.distro_im_select_why = why
    end,
  },
}
