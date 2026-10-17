# 更新与升级

这份文档回答一个问题：**插件、工具、Neovim 本体、解析器，各自怎么升级？**
所有步骤都在打包机（有网的开发环境）上做，最终用户拿到的包不需要也无法联网更新。

先记一条总原则：

> **仓库里只提交「声明」，不提交「产物」。**
> 需要提交的：`vendor/lock.json`（commit 钉点）、`tools/*.ps1` 里的版本矩阵、
> `bin/im-select.exe`（唯一入库的二进制）。
> 绝不提交：`pack/`、`bin/` 的其它二进制、`runtime/`、`vendor/treesitter/` ——
> 它们全部由 CI 按声明重新产出（见 `.gitignore`）。

---

## 一、升级插件 commit 点

`tools/vendor.ps1` 的 `-Update` 参数就是「升级插件」：忽略 lock 里已有的 commit，
重新按分支尖端解析，并把新 commit 写回 `vendor/lock.json`。

```powershell
# 全部升级
pwsh tools/vendor.ps1 -Update

# 只升级一个仓库（全名子串匹配，便于单个重试）
pwsh tools/vendor.ps1 -Update -Only mini.nvim

# 强制重新克隆（目录已存在也重拉）
pwsh tools/vendor.ps1 -Update -Only mini.nvim -Force

# 只做本地校验：不联网、不落盘，检查选型/目录名冲突/lock 状态
pwsh tools/vendor.ps1 -DryRun

# 走代理（TLS 握手在这类网络里会间歇失败）
pwsh tools/vendor.ps1 -Update -Proxy https://ghfast.top/
```

### 分支钉点（`$BRANCH_OVERRIDES`）

少数仓库不能用默认分支，`vendor.ps1` 里有一张映射表：

| 仓库 | 钉在 | `-Update` 时会发生什么 |
| --- | --- | --- |
| `kkew3/jieba.vim` | `release` 分支 | 分支尖端会移动 → 会升级；CI 会重跑 Rust 后端构建 |
| `saghen/blink.cmp` | tag `v1.10.2` | **tag 不可变，不会动**。要升必须手改这张表 |

> ⚠️ **blink.cmp 不要随手升到 main**：main 上是未发布的 v2，额外依赖
> `saghen/blink.lib`，且原生库的分平台产物格式不同。升之前先确认目标 tag
> 有官方分平台产物（带 sha256），否则会退化成纯 Lua 匹配（慢，但不会崩）。

### 升级后的必做校验

```powershell
python tools/check-stack.py     # 机械校验：方案里没有同格多选（退出码非 0 即失败）
git add vendor/lock.json        # 只提交 lock，pack/ 不进版本库
```

`vendor.ps1` 克隆后会**核对 HEAD 是否等于锁定 commit**：不一致就按 sha 重取，
再不行直接报错退出——它不静默接受版本漂移，否则「可复现」就是空话。

---

## 二、升级 `bin/` 里的命令行工具

`bin/` 的内容**由声明决定**：`tools/fetch-tools.ps1` 里的 `Get-Specs` 矩阵写明
「哪个工具、哪个平台、取哪个资产、装成什么名字」，CI 构建时按平台下载并写
`bin/manifest.json`。所以「升级工具」= 改那个矩阵，不是提交二进制。

```powershell
# 改完 tools/fetch-tools.ps1 后本地验证（会写 bin/ 与 bin/manifest.json）
pwsh tools/fetch-tools.ps1 -Platform windows-x64
```

验证点：`bin/manifest.json` 里每个工具的 `version` 与 `sha256` 是否符合预期。
产物名来自各仓库 releases 的实测结果，**上游改名后必须同步改矩阵**。

### 唯一例外：`bin/im-select.exe`

它没有 release 资源，上游产物名也不含平台信息（无法可靠匹配），所以留在版本库。
更新它要**同时改三处**，否则文档与文件会不一致：

1. 替换 `bin/im-select.exe`
2. `README.md` 的工具表那一行：sha256、字节数、`master@<blob>` 标记
3. `docs/DECIDED.md` 的「`im-select.exe`」决策行 + `README.md` 的二进制清单条目

---

## 三、升级 Neovim 本体、解析器与插件原生库

| 组成 | 怎么更新 | 注意 |
| --- | --- | --- |
| Neovim 本体 | `pwsh tools/fetch-runtime.ps1 -Platform win64 -Tag nightly` | CI 目前取**最新 nightly**；钉到具体 commit 是待办项（需配合 `actions/cache`，因为 nightly 资产会被上游每天覆盖） |
| tree-sitter 解析器 | 改 `tools/harvest.lua` 的 `PARSERS` 清单，CI 用**包内那个 nvim** 重编译 | 解析器 ABI 与 nvim 版本强耦合：换了 nvim 必须重编译，否则「高亮突然全没了」 |
| blink.cmp 原生库 | 跟随 blink 的 tag（workflow 里从官方 release 取并校验 sha256） | 分平台产物：macOS 是 `.dylib`、Windows `.dll`、Linux `.so` |
| jieba cdylib | CI 里就地构建（`release` 分支的 build 脚本） | 构建树随即删除（曾因此单插件占 218 MB） |

扩展名的权威定义只有一处：`lua/distro/platform.lua`（`lib_ext(family)`）。
blink 与 jieba 在 macOS 的扩展名不同，这是两家加载器的约定差异，**不要试图统一**。

---

## 四、一次完整升级的标准动作

```powershell
# 1. 插件（按需）
pwsh tools/vendor.ps1 -Update [-Only <子串>]

# 2. 工具（按需）
#    编辑 tools/fetch-tools.ps1 的 Get-Specs 矩阵

# 3. 方案校验（必须通过，否则 CI 的 vendor job 会红）
python tools/check-stack.py

# 4. 本地冒烟（对已解压的包；16 项断言）
#    <包目录>\nvim --headless -l tools\smoke.lua

# 5. 提交声明并推送
git add vendor/lock.json tools/ docs/ README.md bin/im-select.exe
git commit -m "升级：<说明>"
git push
```

推送后由 CI 完成其余全部工作：vendor → 四平台构建（取 nvim/工具/原生库、
用包内 nvim 编译解析器）→ **每平台解压自己刚打出的包并跑冒烟** → 发 Release
（tag = `main+<UTC时间戳>+<短hash>`）。

**不要**在本地 `package.ps1` 打包往外发：本地 `pack/` 可能残留栈外目录，
发布包必须来自 CI 的全新克隆。

---

## 五、回退

- **回退插件版本**：`git revert` 那笔改 `vendor/lock.json` 的提交，然后重跑
  `pwsh tools/vendor.ps1`（不带 `-Update`，严格按 lock 复现）并重新构建。
- **回退整个包**：Release 是冻结的，旧的 tag 与资产都还在；用户端「先解压新包
  到新目录、确认没问题再删旧的」即可回退（见 `docs/INSTALL.md` 原理 10）。

## 六、常见坑（都踩过）

1. **`vendor.ps1` 静默用默认分支**：已修——指定分支克隆失败只重试，绝不降级。
2. **lock 里记 `HEAD` 而不是 tag**：detached HEAD 下会写出 `HEAD`，CI 拼 URL 后
   404。现在记录的是 tag。
3. **上游资产改名**：`fetch-tools.ps1` 的矩阵写的是实测资产名；改名后必须同步，
   否则该平台该工具会「警告并记录为缺失」，不会失败（这是刻意设计——上游缺口
   不该让整个平台的包打不出来）。
4. **CI 的 `concurrency: cancel-in-progress`**：快速连续推送会取消前一次构建。
5. **TLS 间歇失败**：`unexpected eof while reading` 很常见，脚本都带重试；
   手工操作时重跑一次即可。
