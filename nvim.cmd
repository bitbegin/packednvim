@echo off
rem 启动本发行版（Windows）。
rem
rem 这个脚本做三件事，缺一不可：
rem
rem 1. **隔离 XDG 目录**。只用 -u 指定 init.lua 是不够的：Neovim 仍会把
rem    $XDG_CONFIG_HOME/nvim 与 $XDG_DATA_HOME/nvim/site 放进 runtimepath，
rem    于是你机器上原有的 Neovim 配置与插件会一起加载，和本发行版互相污染
rem    （键位冲突、重复插件、启动报错，都很难查）。所以四个 XDG 变量全部指向
rem    发行版目录内的 .local/，做到真正自带、可整个目录搬走。
rem
rem 2. 把 bin/ 前置进 PATH。这样配置文件里直接写 `rg` / `fzf` / `stylua` 就能
rem    找到随包的那一份，不依赖系统装没装。
rem
rem 3. 用 -u 指向发行版自己的 init.lua。
rem
rem 注意：**本发行版不含 Neovim 本体**，需要你自行安装（0.12 或更高），
rem 并让它能在 PATH 上被找到，或用 NVIM_EXE 指定完整路径。

setlocal

set "DISTRO=%~dp0"
if "%DISTRO:~-1%"=="\" set "DISTRO=%DISTRO:~0,-1%"

rem Neovim 本体：允许用 NVIM_EXE 覆盖，否则从 PATH 找
set "NVIMBIN=%NVIM_EXE%"
if not defined NVIMBIN set "NVIMBIN=nvim"

where "%NVIMBIN%" >nul 2>nul
if errorlevel 1 (
  if not exist "%NVIMBIN%" (
    echo [packednvim] 找不到 Neovim 本体：%NVIMBIN%
    echo.
    echo   本发行版只包含配置、插件与随包工具，不含 Neovim 自身。
    echo   请安装 Neovim 0.12+ 并确保 nvim.exe 在 PATH 上，
    echo   或者设置 NVIM_EXE 指向它的完整路径，例如：
    echo       set NVIM_EXE=D:\tools\nvim-win64\bin\nvim.exe
    exit /b 1
  )
)

set "XDG_CONFIG_HOME=%DISTRO%\.local\config"
set "XDG_DATA_HOME=%DISTRO%\.local\data"
set "XDG_STATE_HOME=%DISTRO%\.local\state"
set "XDG_CACHE_HOME=%DISTRO%\.local\cache"
set "PATH=%DISTRO%\bin;%PATH%"

rem 首次运行时把目录建好，免得插件各自去 mkdir
if not exist "%XDG_CONFIG_HOME%" mkdir "%XDG_CONFIG_HOME%"
if not exist "%XDG_STATE_HOME%" mkdir "%XDG_STATE_HOME%"

"%NVIMBIN%" -u "%DISTRO%\init.lua" %*
exit /b %ERRORLEVEL%
