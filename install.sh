#!/usr/bin/env bash
# packednvim installer (Unix): put <package>/bin on PATH and register a desktop
# entry so file managers can "open with" this Neovim.
#
#   ./install.sh                 add PATH block + desktop entry, default md files
#   ./install.sh --uninstall     undo everything it added
#   ./install.sh md txt json     choose your own extension list
set -eu

PKG="$(cd "$(dirname "$0")" && pwd)"
BIN="$PKG/bin"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
DESKTOP="$APPS/packednvim.desktop"
MARK_BEGIN="# >>> packednvim >>>"
MARK_END="# <<< packednvim <<<"
RC_FILES="$HOME/.bashrc $HOME/.zshrc"

mime_for() {
  case "$1" in
    md|markdown) echo "text/markdown" ;;
    txt)         echo "text/plain" ;;
    json)        echo "application/json" ;;
    yaml|yml)    echo "application/x-yaml" ;;
    toml)        echo "application/toml" ;;
    lua)         echo "text/x-lua" ;;
    sh|bash)     echo "application/x-shellscript" ;;
    py)          echo "text/x-python" ;;
    *)           echo "text/plain" ;;
  esac
}

remove_block() {
  f="$1"
  [ -f "$f" ] || return 0
  if grep -qF "$MARK_BEGIN" "$f" 2>/dev/null; then
    tmp="$(mktemp)"
    awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
      $0==b {skip=1; next}
      $0==e {skip=0; next}
      skip!=1 {print}
    ' "$f" > "$tmp"
    mv "$tmp" "$f"
    echo "  removed PATH block from $f"
  fi
}

if [ "${1:-}" = "--uninstall" ]; then
  echo "=== packednvim uninstaller ==="
  for f in $RC_FILES; do remove_block "$f"; done
  if [ -f "$DESKTOP" ]; then
    rm -f "$DESKTOP"
    command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS" 2>/dev/null || true
    echo "  removed $DESKTOP"
  fi
  rm -f "$PKG/.local/install-state.sh"
  echo "[OK] Uninstalled. Restart your terminal."
  exit 0
fi

EXTS="${*:-md markdown}"
echo "=== packednvim installer ==="
echo "  package: $PKG"
echo "  ext:     $EXTS"

# ---- PATH block -----------------------------------------------------------
# ---- clearing the download quarantine (macOS) ------------------------------
if command -v xattr >/dev/null 2>&1; then
  echo "=== 0. Clearing the download quarantine ==="
  find "$PKG" -type f -exec xattr -d com.apple.quarantine {} \; 2>/dev/null || true
  echo "  done (no-op when the files were not downloaded)"
fi

echo "=== 1. PATH ==="
for f in $RC_FILES; do
  # only touch shells whose rc file already exists
  [ -f "$f" ] || continue
  if grep -qF "$MARK_BEGIN" "$f" 2>/dev/null; then
    echo "  already installed in $f"
    continue
  fi
  {
    echo ""
    echo "$MARK_BEGIN"
    echo "export PATH=\"$BIN:\$PATH\""
    echo "$MARK_END"
  } >> "$f"
  echo "  added to $f"
done

# ---- desktop entry --------------------------------------------------------
echo "=== 2. Desktop entry ==="
mkdir -p "$APPS"
MIMES=""
for e in $EXTS; do MIMES="$MIMES$(mime_for "$e");"; done
cat > "$DESKTOP" <<DESKTOP_EOF
[Desktop Entry]
Type=Application
Name=Neovim (packednvim)
Comment=Offline Neovim distribution
Exec=$PKG/nvim.sh %F
Terminal=true
Icon=utilities-terminal
Categories=Utility;TextEditor;
MimeType=$MIMES
DESKTOP_EOF
echo "  wrote $DESKTOP"

# ---- default handler ------------------------------------------------------
echo "=== 3. Default handler ==="
for e in $EXTS; do
  m="$(mime_for "$e")"
  if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default packednvim.desktop "$m" 2>/dev/null && echo "  $m -> packednvim.desktop" || echo "  (xdg-mime failed for $m)"
  fi
done

mkdir -p "$PKG/.local"
printf 'exts="%s"\n' "$EXTS" > "$PKG/.local/install-state.sh"

echo ""
echo "[OK] Installed."
echo "     * open a NEW terminal, then \"nvim\" works from anywhere"
echo "     * file managers: right-click a .md file -> Open with -> Neovim (packednvim)"
echo "     * undo:  ./install.sh --uninstall"