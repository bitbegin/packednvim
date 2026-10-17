@echo off
rem packednvim installer (per-user, no admin rights needed).
rem
rem Double-click this file. It will:
rem   1. link %LOCALAPPDATA%\nvim -> this package (so plain nvim/neovide find the config)
rem   2. put <pkg>\bin on your user PATH
rem   3. set XDG_STATE_HOME / XDG_CACHE_HOME to live inside the package
rem   4. register .md / .markdown / .txt to open with bin\neovide.exe (GUI)
rem   5. add an "Open with packednvim" right-click entry
rem
rem To undo everything, run uninstall.cmd (not this file).

setlocal
set "PS1=%~dp0install.ps1"
if not exist "%PS1%" (
  echo [ERROR] install.ps1 not found next to this file.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
echo.
pause
exit /b 0
