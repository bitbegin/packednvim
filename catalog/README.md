# 插件目录使用说明

这个目录**既是给你看的选型清单，也是后续生成配置的唯一数据源**。
你在这里勾选，`tools/parse_selection.py` 把它读成 `build/selection.json`，后面的生成脚本据此产出 `init.lua` / `lazy` 规格 / 打包清单。所以请不要改动条目的格式，只改方括号。

## 怎么勾选

把 `- [ ]` 改成 `- [x]` 就是选中：

```diff
- - [ ] **folke/tokyonight.nvim** · 作用：深色主题，四种风格变体 · 依赖：纯 Lua · 档位：core · 许可：Apache-2.0
+ - [x] **folke/tokyonight.nvim** · 作用：深色主题，四种风格变体 · 依赖：纯 Lua · 档位：core · 许可：Apache-2.0
```

在编辑器里手工勾你要的即可。不想手动勾两百多个的话，先套一个预设：

```bash
python tools/parse_selection.py --preset core          # 试算轻量核心
python tools/parse_selection.py --preset ide           # 试算开箱即用
python tools/parse_selection.py --preset all           # 试算全勾
python tools/parse_selection.py --preset ide --apply   # 真正写回目录文件
python tools/parse_selection.py                        # 生成 build/selection.json
python tools/parse_selection.py --check                # 只校验格式
```

预设只是起点，套完之后你可以在目录里自由增删。解析器会顺便打印「你选中了多少个、其中几个是纯 Lua、需要目标机器预装哪些外部命令、哪些项必须先预置编译产物」——这就是你的发行版前置条件清单。

## 硬性格式

```
- [ ] **owner/repo** · 作用：一句话 · 依赖：<分级> · 档位：core · 许可：MIT
```

- 字段之间必须是 ` · `（空格 + 中点 + 空格）。**字段值内部不能再出现 `·`**，否则会被当成字段分隔符。
- 键值之间用全角或半角冒号都行。
- 允许的字段只有六个：`作用` `依赖` `许可` `档位` `备注` `平台`。`作用` 和 `依赖` 必填，其余可省。
- 条目必须写在 `##` 或 `###` 标题下面，标题决定它归到哪个分类。
- id 允许写成 `owner/repo#module`，用来勾选 `mini.nvim` 这类**一个仓库包含多个独立模块**的项目。解析结果会拆出 `repo` 与 `module`，vendoring 时按 `repo` 去重（所以你勾了 18 个 mini 模块，也只会克隆一次仓库）。

## 依赖分级（这是本发行版最关键的筛选维度）

你要求「所有依赖打包在一起、不能联网安装」，而你又选择了「只打包配置和插件」。这两件事的边界就是这一列：

| 分级 | 含义 | 对你的离线目标意味着 |
| --- | --- | --- |
| **纯 Lua** | 插件只有 `.lua`，不需要任何外部程序 | 直接 vendor 进包即可，零风险。**离线发行版的骨干应该尽量由这一档组成** |
| **外部工具** | 需要目标机器上已有某个命令（括号里列出，如 `rg`、`fd`、`git`） | 插件本身可离线；缺命令时功能降级或报错。需要写进前置条件，或者日后把工具也打进 `bin/` |
| **编译/下载** | 安装或首次运行时会编译源码 / 下载产物 | **必须预先 vendor**：把编译产物或预编译二进制放进插件目录，并屏蔽 `build` 钩子。否则第一次离线启动就炸 |
| **联网** | 功能本身要求网络（AI 补全、GitHub 操作等） | 与「不能联网」直接冲突，默认只作记录，不建议集成 |

`平台` 列只在不是 Windows + Linux 通吃时出现。

## 别被「体积小」误导

你选了「只打包配置和插件」，所以包体积主要取决于 vendor 进去的插件数量，**不包括**语言服务器和格式化器。
但请留意下面这类条目，它们属于「编译/下载」档，如果不做预处理，离线第一次运行就是失败现场：

- `blink.cmp`：首次使用会去下载 Rust 模糊匹配二进制（可退回纯 Lua 实现，性能下降）。
- `markdown-preview.nvim`：默认要 `node` + `yarn` 或下载预编译包。
- `telescope-fzf-native.nvim`：需要 `make` 和 C 编译器。
- `nvim-treesitter`：解析器要不要编译器，取决于走哪个分支（见 `docs/ARCHITECTURE.md`）。

## 档位 vs 方案（以方案为准）

每条都有 `档位` 字段，标识我建议的归属强度：

| 档位 | 含义 |
| --- | --- |
| `core` | 轻量核心就带。以「纯 Lua + 编辑刚需」为准，启动快、依赖少 |
| `ide` | 开箱即用在此基础上追加的功能件 |
| `extra` | 可选 / 小众 / 有风险（需编译、需额外二进制、维护停滞），默认不带 |

**但真正决定打包内容的是 [`STACKS.toml`](./STACKS.toml) 里的方案**（`minimal` / `recommended` / `full`），不是 `档位`：

- 档位是「单向建议」，方案是「逐格决策的结果」——方案会剔除停更项、联网项和同格的落选者，单靠档位做不到。
- `--preset core|ide|all` 只按档位粗筛，**已被 `--stack` 取代**，留着只为对照。
- 已定只打一个包（内含两平台二进制），产出内容由当前套用的方案决定。

## 文件

| 文件 | 内容 |
| --- | --- |
| `PLUGIN-CATALOG.md` | 主目录（唯一数据源） |
| `OVERVIEW.md` | 自动生成的速查表（208 条一览，别手工编辑） |
| `README.md` | 本文件 |

## 地址是机械核验过的

目录里 174 个去重后的仓库地址都过了一遍 `git ls-remote`：

```bash
python tools/verify-repos.py          # 逐条核验，结果写 build/repo-check.json
```

脚本会区分「地址真的写错」和「代理抖动导致没跑完」——这两件事必须分开，否则会去改本来正确的地址（我确实写错过三个：`slugbyte/lackloud`、`leslie255/nvim-lightbulb`、`hedgehog/outline.nvim`，都是这么抓出来的）。

调研来源、许可证细节、可移植二进制体积等见 `../docs/RESEARCH-NOTES.md`，架构设计见 `../docs/ARCHITECTURE.md`，怎么选见 `../docs/CHOOSING.md`。
