# 安装与使用原理

本文两部分：
- **安装说明** —— 照着做就能跑起来
- **安装原理** —— 为什么这么设计。这部分不是背景知识，而是**踩过的坑**：
  每一条都对应一个「不这么做就会出问题」的实测结论。

另见 [`USAGE.md`](USAGE.md)（怎么用）与 [`KEYMAPS.md`](KEYMAPS.md)（快捷键速查）。

---

## 一、安装说明

### 0. 先挑对包

本发行版**按平台分别出包**，包里已经带了 Neovim 本体、插件、随包工具与
预编译的 tree-sitter 解析器：

| 平台 | 文件名 |
| --- | --- |
| Windows x86_64 | `packednvim-win64.zip` |
| Linux x86_64 | `packednvim-linux64.tar.gz` |
| Linux arm64 | `packednvim-linux-arm64.tar.gz` |
| macOS Apple Silicon | `packednvim-darwin-arm64.tar.gz` |

**不出包的平台**，以及原因：

| 平台 | 为什么 |
| --- | --- |
| Windows arm64 | 上游有 3 个工具（stylua / shfmt / shellcheck）根本没有 Windows arm64 产物，包会先天残缺 |
| macOS Intel | 对应的托管 runner 不可用 |

这两个平台的打包脚本**是支持的**（`fetch-runtime.ps1` 与 `fetch-tools.ps1` 都列了它们），
在自建 runner 或本机上可以照常打出包来 —— 缺的只是 CI 里那台机器。

### 1. 前置条件

| 条件 | 说明 |
| --- | --- |
| **Nerd Font** | 强依赖。状态栏、文件类型图标、诊断符号都用 Nerd Font 字形；不装会显示成方块 |
| Neovim | **不需要自己装** —— 包里带了一份（`runtime/`） |
| C 编译器 | **不需要**。tree-sitter 解析器已用包内那个 Neovim 预先编译好 |
| 语言服务器（可选） | 按决定**不打包**。缺了不影响启动，只是没有补全与跳转 |

> 为什么把 Neovim 一起打包：tree-sitter 解析器与 Neovim 内嵌的 tree-sitter 运行时
> 强耦合。解析器若由「某一个」Neovim 编译、却被「另一个」加载，上游一旦抬高最低
> 兼容 ABI，用户就会突然失去语法高亮。现在**由包里这个 Neovim 亲自编译、再自己
> 加载**，这条风险链被彻底切断。代价是包大一些，换来的是确定性 —— 详见原理 11。

### 2. 解压

把 `packednvim.zip` 解压到任意目录。**路径不要有中文和空格**（插件与工具里
难免有处理路径的地方，这类问题排查成本很高）。

```
D:\packednvim\          （Windows 示例）
/opt/packednvim/        （Linux 示例）
```

解压后应该看到：

```
init.lua          入口
nvim.cmd          Windows 启动脚本
nvim.sh           Linux/macOS 启动脚本
bin/              随包工具（rg / fzf / fd / stylua / shfmt / shellcheck / im-select）
lua/distro/       配置本体
pack/distro/      插件：start/ 启动即加载，opt/ 按键才加载
vendor/           lock.json（可复现凭证）+ prebuilt/（两平台的 tree-sitter 解析器）
docs/             文档
VERSION           这个包是什么、怎么来的
```

### 3. 启动

**Windows**

```bat
cd /d D:\packednvim
nvim.cmd
```

**Linux / macOS**

```bash
cd /opt/packednvim
chmod +x nvim.sh        # 从 Windows 解压过来的话需要补可执行位
./nvim.sh
```

打开文件、传参数都可以，脚本会把参数原样转给 Neovim：

```bat
nvim.cmd D:\code\main.py
nvim.cmd +"lua vim.cmd('checkhealth distro')"
```

**如果 Neovim 不在 PATH 上**，用 `NVIM_EXE` 指定：

```bat
set NVIM_EXE=D:\tools\nvim-win64\bin\nvim.exe
nvim.cmd
```

```bash
export NVIM_EXE=/opt/nvim/bin/nvim
./nvim.sh
```

### 4. 验证安装

进 Neovim 后跑：

```
:checkhealth distro
```

它会逐项报告：Neovim 版本、插件数量、随包工具是否就位、缺哪些语言服务器、
tree-sitter 解析器数量，以及三个「联网风险项」的产物是否齐全。

也可以不开界面直接验：

```bash
nvim --headless -u init.lua -c "lua print(#vim.api.nvim_get_runtime_file('parser/*', true) .. ' 个解析器')" -c "qa!"
```

### 5. 卸载

**直接删掉整个目录即可。** 这是刻意的设计：所有运行期状态（会话、undo、
byte-code 缓存、插件数据）都写在发行版目录内的 `.local/`，不碰用户主目录。
详见下面的「原理 2」。

### 6. 可选：让它在任何目录都能启动

**Windows**：把发行版目录加进 PATH，然后直接用 `nvim` 会走系统那份；
想用自己的那份就显式调 `nvim.cmd`。或者建一个快捷方式指向 `nvim.cmd`。

**Linux**：

```bash
ln -s /opt/packednvim/nvim.sh ~/.local/bin/pnvim
pnvim                     # 任何目录都能用
```

注意别把发行版目录直接加进 PATH 而不经 `nvim.sh` —— 那样 XDG 隔离不会生效。

---

## 二、安装原理

### 原理 1：不用插件管理器，因为它的核心职责在离线场景下消失了

`pack/distro/` 就是[原生包机制](https://neovim.io/doc/user/repeat.html#packages)：

- `start/` 里的插件在启动时自动加载
- `opt/` 里的插件必须显式 `:packadd` 才加载 —— **这就是懒加载的实现**，
  不需要任何管理器

插件管理器（lazy.nvim / packer 等）的核心职责是「从网络拉取并锁定版本」。
本发行版要求**零联网运行**，这个职责本身就不存在了，管理器自然也不需要。
`vendor/lock.json` 承担了「锁定版本」剩下那一半职责：它记录每个仓库的分支与
commit，让 `tools/vendor.ps1` 能在打包时拉到确定的版本。

### 原理 2：必须隔离 XDG 目录（只加 `-u` 是不够的）

直觉上「用 `-u` 指定自己的 init.lua」就够了，其实不够：

**Neovim 仍然会把 `$XDG_CONFIG_HOME/nvim` 与 `$XDG_DATA_HOME/nvim/site` 放进
runtimepath。** 于是你机器上原有的 Neovim 配置与插件会一起加载 ——
键位冲突、插件重复、启动报错，而且极难定位（报错来自别人的配置）。

所以 `nvim.cmd` / `nvim.sh` 把四个变量全部指向发行版目录内的 `.local/`：

```
XDG_CONFIG_HOME = <distro>/.local/config
XDG_DATA_HOME   = <distro>/.local/data
XDG_STATE_HOME  = <distro>/.local/state
XDG_CACHE_HOME  = <distro>/.local/cache
TMPDIR          = <distro>/.local/tmp
```

**`TMPDIR` 也是必需的，而且它踩过一次坑。** 不显式设置它时，本 Windows nightly 的
`vim.fn.tempname()` 会返回**空字符串**（`$TEMP` 明明有效）。后果不是「临时文件放错地方」，
而是一串看起来毫不相干的错误：

1. `fzf-lua` 把命令拼成 `<fzf> … > <tempname>`，重定向目标成了空 → cmd 报
   **「系统找不到指定的路径。」**，这句话被显示在 fzf 窗口里
2. 紧接着 `vim.fn.delete('')` 抛 **`E474: Invalid argument`**，栈回溯指向
   `fzf-lua/fzf.lua:175` 的清理动作

那个 `E474` 栈回溯极具误导性——它指向的是**收尾动作**，而不是病因。
真因是一条空字符串。所以启动脚本除了设 `TMPDIR`，还会把上述五个目录**都建出来**：
一个不存在的 temp/cache 目录，往往在很远的地方表现为一个看不懂的错误。

代价是发行版目录会变大（会话、undo、缓存都在里面），换来的是：

- 与机器上其它 Neovim 配置**完全互不影响**，可以并存
- 整个目录可搬走/可删除，删除即卸载干净
- 行为可复现 —— 换台机器是同一套状态

### 原理 3：`runtimepath` 和 `packpath` 都要前置（只前置前者，插件一个都不加载）

这是本项目第一个实测出来的坑，也是最隐蔽的一个。

`vim.opt.runtimepath:prepend(root)` **不会**同步 `packpath` ——
Vim 文档明确说明这是两个独立选项。而分工不同：

| 选项 | 决定什么 |
| --- | --- |
| `runtimepath` | `require('distro.*')`、`after/`、`ftplugin/`、`syntax/` |
| `packpath` | **`pack/*/start` 会不会被自动加载** |

只前置 runtimepath 的后果：`lua/` 能正常 require，启动看起来完全正常，
**但 `pack/` 里几十个插件一个都没加载**。`init.lua` 里两个都前置，注释里也写了原因。

### 原理 4：随包的 tree-sitter 解析器必须主动挂上 runtimepath

解析器与查询文件打包在 `vendor/prebuilt/<平台>/neovim-data/site/` 下。
**Neovim 与 nvim-treesitter 只在 runtimepath 上找 `parser/` 与 `queries/`，
不会主动去翻包里的 `vendor/` 目录。**

所以 `init.lua` 会把该目录 append 进 runtimepath。不挂上去的话，
包里那 20 个解析器就是纯死重量 —— 这个现象在第一次实机验收时真的出现了：
包里 20 个解析器，运行时一个都看不见。

用 `append` 而不是 `prepend`：Neovim 自带 c/lua/markdown/vim 等解析器，
那些与它自身的 ABI 必然匹配，让它们优先更稳；我们补的是 Neovim 没有的语言。

### 原理 5：平台相关的产物，靠文件扩展名共存于同一个包

按决定只出一个包（同时支持 Windows 与 Linux）。但有三样东西是**平台相关**的：

| 产物 | Windows | Linux |
| --- | --- | --- |
| tree-sitter 解析器 | `parser/<lang>.dll` | `parser/<lang>.so` |
| blink.cmp 原生库 | `libblink_cmp_fuzzy.dll` | `libblink_cmp_fuzzy.so` |
| jieba cdylib | `jieba_vim_rs.dll` | `jieba_vim_rs.so` |

**扩展名不同，所以可以同包共存**，运行时由 `init.lua` 按平台选目录
（`vendor/prebuilt/win64` 或 `linux64`），插件的加载器自己按扩展名找。

这也是为什么包比较大（解压约 165 MB）：`bin/` 里同时装了两个平台的工具，
`vendor/prebuilt/` 里同时装了两个平台的解析器。

### 原理 6：`bin/` 前置进 PATH，而不是依赖系统安装

启动脚本把 `<distro>/bin` 前置进 `PATH`。于是配置里直接写 `rg` / `fzf` /
`stylua` 拿到的就是随包的那一份，**不依赖用户装没装、装的是哪个版本**。

对离线发行版来说这一点很关键：如果依赖系统 PATH，用户「没输出」和
「rg 没装」会表现成同一个现象，很难区分。随包之后，
`fzf-lua` 这类插件可以显式指向 `<distro>/bin/fzf`，行为确定。

（这个坑也在 CI 里真实出现过：`bin/` 里的 Linux 二进制是从 Windows 复制过来的，
**没有可执行位**，`vim.fn.executable()` 判定不可用，于是报「找不到 rg」。
现在可执行位记录在 git 索引里，clone 出来就带着。）

### 原理 7：Windows 上 `.cmd` 脚本只能是 ASCII + CRLF

`nvim.cmd` 故意不含任何非 ASCII 字符，注释也用英文。原因不是偏好：

**`cmd.exe` 按系统 OEM 代码页解析 `.cmd` 文件字节，不认 UTF-8。**
（中文 Windows 上是 GBK。）中文注释会被解码错乱，其中一段甚至会被当成命令
执行 —— 实测的现象是脚本以 `9009`（命令未找到）退出，并打印
`'变量解析过程打印出来' is not recognized as an internal or external command`。

同理 `.cmd` 需要 CRLF 换行：`cmd.exe` 对 LF 结尾的多行 `if (...)` 块解析不可靠。
两条都写在 `.gitattributes` 里（`*.cmd text eol=crlf`），并在文件头注明。

### 原理 8：`VERSION` 与 `vendor/lock.json` 是不同的东西

| 文件 | 作用 | 内容 |
| --- | --- | --- |
| `VERSION` | 说明**这个包**是什么 | Neovim 基线版本、插件数量、构建它的 commit 与 Actions run |
| `vendor/lock.json` | 说明**每个插件**来自哪个版本 | 每个仓库的 URL、分支、commit、许可证文件 |

只看 `VERSION` 能知道包的身份；要看某个插件到底是哪个 commit，
查 `lock.json`。两者都不含时间以外的隐式信息 —— **下载到的包可以完整追溯**。

### 原理 9：nightly 基线不可逐字节复现（这是取舍，不是疏漏）

`VERSION` 里的 `neovim-baseline: nightly` 意味着：

- 官方只保留最新一份 nightly，**无法按版本回溯下载**，所以用 nightly 构建出来的包
  不是逐字节可复现的
- tree-sitter 解析器的 ABI 与 Neovim 版本强耦合，nightly 升级后解析器可能失配

想要可复现，把 workflow 的 `nvim_tag` 输入改成稳定标签（如 `v0.12.6`）再构建。

### 原理 10：升级 Neovim 之后，这个包会不会失效？

会，也可能不会 —— 取决于**哪一部分**。把「什么与 Neovim 版本耦合」分清，
就不必凭猜：

| 组成 | 与 Neovim 版本的耦合 | 升级后 |
| --- | --- | --- |
| `bin/` 里的工具（rg / fzf / fd / stylua / shfmt / shellcheck） | **完全无关** | 永远照常工作 |
| 插件（纯 Lua） | 弱耦合：依赖公开 API，可能有弃用警告 | 通常照常；个别插件可能要求更新的版本 |
| blink 的原生库 | 只耦合 **Lua 5.1 ABI**（LuaJIT 的 ABI 极稳定），不用 Neovim 内部 API | 通常照常 |
| jieba 的 cdylib | 同上（Lua 5.1 绑定） | 通常照常 |
| **tree-sitter 解析器** | **耦合 tree-sitter 的语言 ABI 版本** | ⚠️ **唯一有实质风险的项** |

解析器为什么有风险：每个解析器在编译时声明一个语言 ABI 版本（`LANGUAGE_VERSION`），
而 Neovim 内嵌的 tree-sitter 运行时会接受一个**范围**的 ABI。当上游把
「最低兼容 ABI」抬高（历史上从 13 抬到 14 时淘汰过一批），旧解析器就会以
`Incompatible language version` 加载失败。

但**这个风险比听起来小**，原因有二：

1. ABI 抬升是低频事件（以年计），不是每次 Neovim 更新都会发生；
2. Neovim **自带** c / lua / markdown / vim / vimdoc / query / diff 等解析器，
   那些与它自身必然匹配。所以即使随包的解析器全部失效，
   **编辑 Lua / C / Markdown 依然有高亮** —— 退化而不是崩溃。

#### 怎么确认有没有失效

```bash
nvim --headless -u init.lua -c "lua for _,l in ipairs({'bash','python','yaml','toml'}) do local ok,err=pcall(vim.treesitter.language.add,l) print(l, ok, err or '') end" -c "qa!"
```

全部 `true` 就没问题；出现 `Incompatible language version` 就是 ABI 失配。

#### 失效了怎么办

解析器可以单独刷新，**不必重新构建整个包**：

1. 在一台**有网络且有 C 编译器**的机器上，用同一份配置跑：
   ```bash
   nvim --headless -u init.lua -c "lua require('nvim-treesitter').install({'lua','c','cpp','python','bash','markdown','json','yaml','toml'})" -c "qa!"
   ```
   （它会下载语法并用 tree-sitter CLI 编译，需要 `tree-sitter` 与 `cc`/MSVC）
2. 把产出的 `parser/*` 复制进包里的
   `vendor/prebuilt/<平台>/neovim-data/site/parser/`，覆盖旧文件。
   **Windows 上记得把 `.so` 改名成 `.dll`** —— nvim-treesitter 会把文件名硬编码成
   `.so`，而 Neovim 在 Windows 只按 `.dll` 找（见原理 4）。

拿到新包也一样：重新触发一次 workflow 即可，CI 会为新基线重建解析器。

> 提醒：刷新解析器时**查询文件（queries）也应当同源**。查询是按语法节点名写的，
> 新语法若改了节点名而查询没跟着换，可能出现高亮错乱或查询报错。
> 本包里解析器与查询来自同一次构建，天然一致；单独换其中一半才需要注意这点。

#### 一个实用建议

因为 XDG 目录在包**内部**（原理 2），不同 Neovim 基线的包可以并存、互不干扰：

```
D:\packednvim-0.13-dev1828\
D:\packednvim-0.13-dev2050\
```

升级 Neovim 时**先解压新包到新目录**，确认没问题再删旧的 —— 而不是就地升级。
升级本身只是换掉你系统里的 `nvim.exe`，包自己不动，所以随时可以回退。

---

## 原理 11：为什么把 Neovim 本体也打进包

前面的原理 9 讲了 ABI 耦合的风险，原理 11 就是它的解法。

tree-sitter 解析器不是普通插件：它们是共享库，必须与 Neovim **内嵌的 tree-sitter
运行时**的语言 ABI 对上。风险在于「谁编译的」和「谁加载的」可能是两个不同的
Neovim —— 打包机上一个，用户机器上另一个。

把 Neovim 打进包之后，「编译解析器的那一个」与「加载解析器的那一个」是**同一个文件**，
这条风险链在结构上就断了。CI 的顺序也是照此安排的：先把 Neovim 取进 `runtime/`，
再把 PATH 指向它，然后用它编译解析器。

代价与取舍：

| 得 | 失 |
| --- | --- |
| ABI 失配不可能发生 | 每个包大约多 10~22 MB |
| 用户不必先装 Neovim | nightly 基线随构建时间漂移（但**产物本身固定**，且 `VERSION` 记了版本与 commit） |
| 版本行为完全可预期 | 想换 Neovim 版本必须重新构建，而不是就地升级 |

最后一条看着像缺点，其实是优点：升级变成显式动作，且可以两个包并存、随时回退
（见原理 10 末尾的建议）。

## 原理 12：归档格式必须按平台分

Windows 用 `.zip`，其余平台用 `.tar.gz`。这不是偏好，是硬要求：

**zip 不保留可执行位。** 用 zip 分发 Linux/macOS 包，用户解压后
`runtime/bin/nvim` 与 `bin/rg` 都没有 `+x`，表现为「文件在但执行不了」。
这个坑本项目踩过一次（Linux 的 rg 丢了可执行位，报「找不到 rg」），
当时靠 `chmod` 补救；现在从打包格式上就不给它发生的机会。

同理，`bin/` 里的工具不再提交进版本库，改由 CI 按平台现取 ——
6 个平台的二进制上百 MB，而 **git 历史不会因为后来的删除而变小**，
所以一开始就不该进去。仓库里现在只留下「要取什么」的声明。
唯一例外是 `im-select.exe`：它上游的产物名不含平台信息，无法可靠匹配，
只有约 200 KB，且只在 Windows 需要。

---

## 三、常见问题

### `E1512: Wrong character width for field "..."` —— 这是 `ambiwidth=double` 的代价

本发行版为中文把 `ambiwidth` 设为 `double`（东亚「歧义宽度」字符按 2 格算，
否则中文与框线字符会错位）。代价是：**任何把歧义宽度字符写进宽度敏感选项的插件都会报 E1512**，
因为 `listchars` / `fillchars` / `statuscolumn` 这些字段要求字符恰好 1 格。

已经遇到并修掉的两处：

| 位置 | 出问题的字符 | 处理 |
| --- | --- | --- |
| 本发行版 `options.lua` 自己的 `listchars` | `·`（U+00B7）、`␣`（U+2423） | 改用 ASCII |
| `dressing.nvim` 的默认 `win_options.listchars` | `…`（U+2026） | 在配置里只覆盖该字段 |

**再遇到时的排查套路**（这个类别的错误会持续出现，所以值得记住）：

```bash
# 在插件目录里搜「可能被写进宽度敏感选项的非 ASCII 字符」
grep -rn 'fillchars\|listchars\|statuscolumn' pack/distro/start/ | grep -P '[^\x00-\x7F]'
```

找到后**只覆盖那一个键**即可（插件的 `setup` 通常是深度合并，其余默认值会保留）。
不要去改用 `ambiwidth=single` —— 那会让中文与框线字符在 CJK 终端里全部错位，
是把一个局部问题换成一个全局问题。

如果你的终端把歧义宽度字符渲染成 **1 格**（少数配置），那把 `ambiwidth` 设回 `single`
才是正确的，此时这个类别的错误也会一并消失。

**图标显示成方块**
没装 Nerd Font，或终端没用它。这是强依赖，不是可选项。

**`:checkhealth distro` 说找不到 rg / fzf**
1) 确认是通过 `nvim.cmd` / `nvim.sh` 启动的（它们负责前置 PATH）；
2) Linux 上从 Windows 解压的话，补可执行位：
`chmod +x bin/rg bin/fzf bin/fd bin/stylua bin/shfmt bin/shellcheck`。

**没有语法高亮**
`vendor/prebuilt/<平台>/` 是否存在、里面是否有 `parser/*.dll`（Windows）。
`init.lua` 会在启动时把该目录挂上 runtimepath；若目录不存在会静默跳过，
可用 `:lua print(vim.g.distro_treesitter_dir)` 查看是否挂上。

**中文按词移动（`w` / `b` / `e`）不管用**
需要 jieba 的 cdylib：`pack/distro/start/jieba.vim/lua/jieba_vim/jieba_vim_rs.{so,dll}`。
缺了会看到 `module 'jieba_vim.jieba_vim_rs' not found`。这是打包时漏了产物的典型症状。

**补全没有原生加速（退回纯 Lua）**
检查 `pack/distro/start/blink.cmp/target/release/libblink_cmp_fuzzy.{so,dll}`。
blink 的逻辑是「没有 version 文件、但共享库能加载」就直接采用，
所以只要文件在、能被加载即可。

**启动报某个插件的错，但编辑器能用**
这是刻意的降级策略：`lua/distro/init.lua` 对每个模块单独 pcall，
一个模块出问题不会让编辑器起不来。但**这也意味着错误可能被忽略**，
所以请看 `:messages` 或 `:checkhealth distro`，不要因为「能用」就跳过。

**想用自己已有的 Neovim 配置**
本发行版默认完全隔离。若想共存，就别用 `nvim.cmd`，改为手动启动并只前置
`runtimepath`/`packpath`（见原理 3），但要注意原理 2 说的污染问题。
