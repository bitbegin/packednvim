@echo off
rem packednvim uninstaller (per-user). Undoes everything install.cmd added:
rem   the config link, the PATH entry, XDG_STATE_HOME / XDG_CACHE_HOME,
rem   file associations, the right-click entry and application registrations.
rem
rem The package directory itself is NOT deleted - remove it afterwards.

setlocal
set "PS1=%~dp0uninstall.ps1"
if not exist "%PS1%" (
  echo [ERROR] uninstall.ps1 not found next to this file.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
echo.
pause
exit /b 0
