# bin/ —— 随包分发的外部工具

这个目录是架构里预留的外部工具注入点。启动脚本会把 `<发行版>/bin` **前置**进 `PATH`，
因此这里的工具优先于系统 PATH 上的同名工具，但**不会覆盖或改动系统里的任何东西**。

Windows 与 Linux 两套二进制放在同一个目录，靠扩展名区分（`.exe` 即 Windows）。

**Neovim 基线**：`NVIM v0.13.0-dev-1828+g7e1ae5115f`

| 文件 | 工具 | 版本 | 平台 | SHA256（前 16 位） | 大小 |
| --- | --- | --- | --- | --- | --- |
| `rg.exe` | ripgrep | 15.2.0 | windows-x64 | `14231169855EC520…` | 4,218,880 字节 |
| `rg` | ripgrep | 15.2.0 | linux-x64 | `E62198EB19B136B8…` | 5,408,904 字节 |
| `fzf.exe` | fzf | v0.74.5 | windows-x64 | `7CC161C1FD600C74…` | 6,235,136 字节 |
| `fzf` | fzf | v0.74.5 | linux-x64 | `C8D3AC08594F271A…` | 5,529,760 字节 |
| `fd.exe` | fd | v10.5.0 | windows-x64 | `D67D27A8E375ED7E…` | 4,104,192 字节 |
| `fd` | fd | v10.5.0 | linux-x64 | `E79642A479D2816C…` | 3,708,016 字节 |
| `stylua.exe` | stylua | v2.6.0 | windows-x64 | `8BE0383E979B3C69…` | 9,057,280 字节 |
| `stylua` | stylua | v2.6.0 | linux-x64 | `58F2F3056700C3A3…` | 10,528,848 字节 |
| `shfmt.exe` | shfmt | v3.14.1 | windows-x64 | `13629CE28442CA80…` | 3,801,600 字节 |
| `shfmt` | shfmt | v3.14.1 | linux-x64 | `76E77641FAA02581…` | 3,571,872 字节 |
| `shellcheck.exe` | shellcheck | v0.11.0 | windows-x64 | `C9E82ADA36EF4B8D…` | 34,778,624 字节 |
| `shellcheck` | shellcheck | v0.11.0 | linux-x64 | `4DA528DDB3A4D1B7…` | 16,213,136 字节 |
| `im-select.exe` | im-select | master@890b3eb1 | windows-x64 | `E66F0A6E30B9F207…` | 130,560 字节 |

同样的内容以机器可读形式放在 `manifest.json`，供打包脚本与 `:checkhealth` 读取。

## 为什么必须随包

| 工具 | 谁在用 | 缺了会怎样 |
| --- | --- | --- |
| `ripgrep` | quickfix 正则搜索（需求 5）、fzf-lua 的 grep、grug-far | 搜索功能整体失效 |
| `fzf` | fzf-lua（需求 4 指定的默认 picker） | ``<leader>sg`` 静默退回 quickfix，失去实时预览与鼠标跳转 |
| `fd` | fzf-lua 的找文件后端 | 回退到较慢的路径遍历 |
| `stylua` | conform.nvim 格式化 Lua | 保存时无法格式化 Lua |
| `shfmt` | conform.nvim 格式化 Shell | 保存时无法格式化 Shell |
| `shellcheck` | nvim-lint 检查 Shell | Shell 脚本没有静态检查 |
| `im-select` | im-select.nvim：Windows 上离开插入模式时自动切回英文输入法 | Windows 上输入法自动切换不可用（Linux 侧用系统的 fcitx5-remote / ibus，不受影响） |

## 版本与来源

- `rg.exe` —— ripgrep 15.2.0，产物 `ripgrep-15.2.0-x86_64-pc-windows-msvc.zip`
- `rg` —— ripgrep 15.2.0，产物 `ripgrep-15.2.0-x86_64-unknown-linux-musl.tar.gz`
- `fzf.exe` —— fzf v0.74.5，产物 `fzf-0.74.5-windows_amd64.zip`
- `fzf` —— fzf v0.74.5，产物 `fzf-0.74.5-linux_amd64.tar.gz`
- `fd.exe` —— fd v10.5.0，产物 `fd-v10.5.0-x86_64-pc-windows-msvc.zip`
- `fd` —— fd v10.5.0，产物 `fd-v10.5.0-x86_64-unknown-linux-musl.tar.gz`
- `stylua.exe` —— stylua v2.6.0，产物 `stylua-windows-x86_64.zip`
- `stylua` —— stylua v2.6.0，产物 `stylua-linux-x86_64.zip`
- `shfmt.exe` —— shfmt v3.14.1，产物 `shfmt_v3.14.1_windows_amd64.exe`
- `shfmt` —— shfmt v3.14.1，产物 `shfmt_v3.14.1_linux_amd64`
- `shellcheck.exe` —— shellcheck v0.11.0，产物 `shellcheck-v0.11.0.zip`
- `shellcheck` —— shellcheck v0.11.0，产物 `shellcheck-v0.11.0.linux.x86_64.tar.xz`
- `im-select.exe` —— im-select master@890b3eb1，产物 `im-select.exe（仓库 blob 890b3eb1）`

原始压缩包留在 `build/downloads/`（该目录不进版本库）。要复现时重跑
`pwsh -File tools/fetch-binaries.ps1` 即可，脚本会现场核对官方 SHA256。

## 许可证

| 工具 | 许可证 |
| --- | --- |
| ripgrep | MIT 或 Unlicense（双许可，二选一） |
| fzf | MIT |
| fd | MIT / Apache-2.0（双许可，二选一） |
| stylua | MPL-2.0 |
| shfmt | BSD-3-Clause |
| shellcheck | **GPL-3.0** ← copyleft，见下 |
| im-select | MIT |

分发二进制必须附带许可证全文，所以 `licenses/` 不能删。

**`shellcheck` 是 GPL-3.0**，其余都是 MIT / Apache-2.0 / MPL-2.0 / BSD 这类宽松许可。
copyleft 的含义是：你分发包含它的包时，需要同时提供对应源码或书面承诺。做法很简单——
在包里放一份说明指向 `https://github.com/koalaman/shellcheck` 的对应 tag，
并把 `licenses/shellcheck-LICENSE.txt` 一起带上；同时别把 shellcheck 与你的 MIT 配置代码
说成「单一作品」。想完全避开 copyleft，就别打包它。

## 注意事项

- **Linux 上需要可执行位。** 从 Windows 复制出来的文件没有 `+x`，Linux 端首次使用要
  `chmod +x bin/rg bin/fzf bin/fd bin/stylua bin/shfmt bin/shellcheck`。
  若这个仓库用 git 分发，提交时给 Linux 二进制打上可执行位：
  `git update-index --chmod=+x bin/rg bin/fzf bin/fd bin/stylua bin/shfmt bin/shellcheck`
- 代理会中途断流，所以脚本用「限时重试 + 断点续传」而不是 `curl --retry`（`--retry` 对「传输停滞」不生效）。
- 官方发布信息的 `digest` 字段若为空，脚本只校验大小并给出警告，不会假装校验通过。
- **`im-select.exe` 的校验方式不同**：它没有 release 资源，是从仓库 `win/out/x64/` 直接取的
  裸文件，所以上游不给 SHA256。脚本改用 **git blob 哈希**（`890b3eb1…`，由 GitHub API 提供）
  校验，同样能锁到字节级内容；`manifest.json` 里也记录了它的 SHA256 供日后核对。
  它只在 Windows 上有意义——Linux 侧 `im-select.nvim` 用系统的 `fcitx5-remote` / `ibus`。
- **语言服务器按决定不打包**：`lua-language-server` / `clangd` / `basedpyright` /
  `bash-language-server` 等都不随包分发，请自行安装。发行版通过 `vim.fn.executable()`
  探测，缺失时只在 `:checkhealth distro` 里报告，不报错。

_本文件由 `tools/fetch-binaries.ps1` 自动生成，请勿手工编辑。_
