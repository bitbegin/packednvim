@echo off
rem packednvim installer / uninstaller (per-user, no admin needed).
rem
rem   install.cmd        install: PATH + config junction + env vars + associations
rem   install.cmd /u     uninstall everything it added

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

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
echo.
pause
exit /b 0

:uninstall
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Uninstall
echo.
pause
exit /b 0
