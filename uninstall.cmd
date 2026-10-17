@echo off
rem packednvim uninstaller (per-user). Undoes everything install.cmd added:
rem   PATH entry, XDG_STATE_HOME / XDG_CACHE_HOME, file associations,
rem   right-click entry, application registrations, and the config link.
rem
rem The package directory itself is NOT deleted - just remove it afterwards.

setlocal
set "PS1=%~dp0install.ps1"
if not exist "%PS1%" (
  echo [ERROR] install.ps1 not found next to this file.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Uninstall
echo.
pause
exit /b 0
