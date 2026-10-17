#!/usr/bin/env bash
# Launcher for this Neovim distribution via the Neovide GUI (Linux / macOS).
#
# Mirrors nvim.cmd + neovide.cmd. Keep the three launchers in sync: the
# environment isolation below is the whole reason they exist.
#
# Why not point Neovide at nvim directly: Neovide spawns nvim itself, so the
# XDG/TMPDIR/PATH variables must be set by whoever launches Neovide. Setting
# them inside init.lua is too late -- Neovim has already resolved stdpath().
#
# Neovide must be installed and on PATH, or set NEOVIDE_EXE to its full path.

set -euo pipefail

# Resolve this script's real directory, following symlinks.
self=${BASH_SOURCE[0]}
while [ -L "$self" ]; do
  target=$(readlink "$self")
  case $target in
    /*) self=$target ;;
    *) self=$(dirname "$self")/$target ;;
  esac
done
DISTRO=$(cd "$(dirname "$self")" && pwd)

# --- Neovim binary: bundled copy first, then NVIM_EXE, then PATH ------------
NVIMBIN=""
if [ -x "$DISTRO/runtime/bin/nvim" ]; then
  NVIMBIN="$DISTRO/runtime/bin/nvim"
elif [ -n "${NVIM_EXE:-}" ]; then
  NVIMBIN=$NVIM_EXE
elif command -v nvim >/dev/null 2>&1; then
  NVIMBIN=$(command -v nvim)
fi

if [ -z "$NVIMBIN" ] || [ ! -x "$NVIMBIN" ]; then
  cat >&2 <<'EOF'
[packednvim] Cannot find Neovim.

  Expected a bundled copy at runtime/bin/nvim.
  If this package was built without one, either install Neovim 0.12+ and put
  nvim on PATH, or set NVIM_EXE:
      export NVIM_EXE=/usr/bin/nvim
EOF
  exit 1
fi

# --- Neovide binary --------------------------------------------------------
NEORUN=""
if [ -n "${NEOVIDE_EXE:-}" ]; then
  NEORUN=$NEOVIDE_EXE
elif [ -x "$DISTRO/bin/neovide" ]; then
  NEORUN="$DISTRO/bin/neovide"
elif command -v neovide >/dev/null 2>&1; then
  NEORUN=$(command -v neovide)
fi

if [ -z "$NEORUN" ] || [ ! -x "$NEORUN" ]; then
  cat >&2 <<'EOF'
[packednvim] Cannot find Neovide.

  This package does not include it on this platform (upstream ships no
  x86_64-only build for arm64), and it is not on PATH. Either install it
  from https://neovide.dev/ or set NEOVIDE_EXE:
      export NEOVIDE_EXE=/usr/local/bin/neovide

  Text mode still works: run ./nvim.sh instead.
EOF
  exit 1
fi

# --- Isolate XDG and prepend bundled tools (same as nvim.sh) ---------------
export XDG_CONFIG_HOME="$DISTRO/.local/config"
export XDG_DATA_HOME="$DISTRO/.local/data"
export XDG_STATE_HOME="$DISTRO/.local/state"
export XDG_CACHE_HOME="$DISTRO/.local/cache"
export TMPDIR="$DISTRO/.local/tmp"
export PATH="$DISTRO/bin:$PATH"

# Per-distro Neovide config, so GUI settings travel with the package.
if [ -f "$DISTRO/neovide.toml" ]; then
  export NEOVIDE_CONFIG="$DISTRO/neovide.toml"
fi

mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" \
         "$XDG_CACHE_HOME" "$TMPDIR"

# --neovim-bin BEFORE "--"; everything after "--" goes to nvim verbatim.
# The "$@" lets you pass files: ./neovide.sh note.md
exec "$NEORUN" --neovim-bin "$NVIMBIN" -- -u "$DISTRO/init.lua" "$@"
