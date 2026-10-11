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

# Neovim 本体：允许用 NVIM_EXE 覆盖，否则从 PATH 找
NVIMBIN=${NVIM_EXE:-nvim}
if ! command -v "$NVIMBIN" >/dev/null 2>&1 && [ ! -x "$NVIMBIN" ]; then
  cat >&2 <<'EOF'
[packednvim] 找不到 Neovim 本体。

  本发行版只包含配置、插件与随包工具，不含 Neovim 自身。
  请安装 Neovim 0.12+ 并确保 nvim 在 PATH 上，或设置 NVIM_EXE：
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
