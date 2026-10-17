@echo off
rem packednvim installer / uninstaller (per-user, no admin needed).
rem
rem   install.cmd              add <pkg>\bin to PATH + register .md/.markdown
rem   install.cmd /u           undo everything it added
rem   install.cmd md txt json  choose your own extension list
rem
rem All the logic lives in install.ps1 (keeps this file free of quoting traps).

setlocal
set "PS1=%~dp0install.ps1"
if not exist "%PS1%" (
  echo [ERROR] install.ps1 not found next to this file.
  pause
  exit /b 1
)

if /i "%~1"=="/u" goto uninstall
if /i "%~1"=="-u" goto uninstall
if /i "%~1"=="--uninstall" goto uninstall

set "EXTS=md markdown"
if not "%~1"=="" set "EXTS=%*"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Ext %EXTS%
echo.
pause
exit /b 0

:uninstall
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Uninstall
echo.
pause
exit /b 0
