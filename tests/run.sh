#!/usr/bin/env sh
# 跑发行版的测试（Linux）。
#
#   ./tests/run.sh                  # 默认跑 tests/test_search.lua
#   ./tests/run.sh tests/foo.lua    # 跑指定测试
#
# nvim 选取顺序：$NVIM → PATH 上的 nvim → 仓库内 build/toolchain（可选）
#
# 说明同 run.ps1：XDG_* 都指到 build/xdg 下保持自包含；
# 测试需要能创建子进程（要调 rg），受限沙箱里会失败。

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_file=${1:-tests/test_search.lua}

nvim_bin=${NVIM:-}
if [ -z "$nvim_bin" ]; then
  nvim_bin=$(command -v nvim || true)
fi
if [ -z "$nvim_bin" ]; then
  for candidate in \
    "$root/build/toolchain/nvim-linux-x86_64/bin/nvim" \
    "$root/build/toolchain/nvim-linux-arm64/bin/nvim"
  do
    if [ -x "$candidate" ]; then nvim_bin=$candidate; break; fi
  done
fi
if [ -z "$nvim_bin" ]; then
  echo "找不到 nvim。装一份并加进 PATH，或用 NVIM=... 指定。" >&2
  exit 2
fi

ver_line=$("$nvim_bin" --version | head -n 1)
echo "nvim     : $nvim_bin"
echo "版本     : $ver_line"
echo "测试文件 : $test_file"
echo

XDG_DATA_HOME="$root/build/xdg/data"
XDG_STATE_HOME="$root/build/xdg/state"
XDG_CACHE_HOME="$root/build/xdg/cache"
XDG_CONFIG_HOME="$root/build/xdg/config"
export XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_CONFIG_HOME

cd "$root"
exec "$nvim_bin" --headless -u init.lua -l "$test_file"
