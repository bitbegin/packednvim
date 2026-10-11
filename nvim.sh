#!/bin/sh
# 启动本发行版（Linux / macOS）。
#
# 这个脚本做三件事，缺一不可：
#
# 1. **隔离 XDG 目录**。只用 -u 指定 init.lua 是不够的：Neovim 仍会把
#    $XDG_CONFIG_HOME/nvim 与 $XDG_DATA_HOME/nvim/site 放进 runtimepath，
#    于是你机器上原有的 Neovim 配置与插件会一起加载，和本发行版互相污染
#    （键位冲突、重复插件、启动报错，都很难查）。所以四个 XDG 变量全部指向
#    发行版目录内的 .local/，做到真正自带、可整个目录搬走。
#
# 2. 把 bin/ 前置进 PATH。这样配置文件里直接写 `rg` / `fzf` / `stylua` 就能
#    找到随包的那一份，不依赖系统装没装。
#
# 3. 用 -u 指向发行版自己的 init.lua。
#
# 注意：**本发行版不含 Neovim 本体**，需要你自行安装（0.12 或更高），
# 并让它能在 PATH 上被找到，或用 NVIM_EXE 指定完整路径。

set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Neovim 本体的选择顺序（越靠前越确定）：
#   1. runtime/bin/nvim —— 随包分发的那份。用它意味着包里的 tree-sitter 解析器
#      就是由这个二进制亲自编译的，ABI 不可能失配，版本行为也完全可预期。
#   2. NVIM_EXE         —— 显式覆盖，便于测试别的构建。
#   3. PATH 上的 nvim   —— 兜底；此时版本不再由我们控制。
if [ -x "$here/runtime/bin/nvim" ]; then
  NVIMBIN="$here/runtime/bin/nvim"
elif [ -n "${NVIM_EXE:-}" ]; then
  NVIMBIN="$NVIM_EXE"
else
  NVIMBIN=nvim
fi

if ! command -v "$NVIMBIN" >/dev/null 2>&1 && [ ! -x "$NVIMBIN" ]; then
  cat >&2 <<'EOF'
[packednvim] 找不到 Neovim 本体。

  正常情况下包里应当带一份 runtime/bin/nvim。
  如果这个包没有带，请安装 Neovim 0.12+ 并确保 nvim 在 PATH 上，
  或设置 NVIM_EXE：
      export NVIM_EXE=/opt/nvim/bin/nvim
EOF
  exit 1
fi

XDG_CONFIG_HOME="$here/.local/config"
XDG_DATA_HOME="$here/.local/data"
XDG_STATE_HOME="$here/.local/state"
XDG_CACHE_HOME="$here/.local/cache"
PATH="$here/bin:$PATH"
export XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME PATH

mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"

exec "$NVIMBIN" -u "$here/init.lua" "$@"
