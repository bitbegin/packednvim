@echo off
rem Launcher for this Neovim distribution (Windows).
rem
rem IMPORTANT: this file is intentionally ASCII-only.
rem cmd.exe parses .cmd files using the system OEM code page, NOT UTF-8.
rem Non-ASCII bytes in comments get mis-decoded and can leak out as commands
rem (we hit exactly that: a Chinese comment produced "is not recognized as an
rem internal or external command" and the script exited with 9009).
rem The detailed rationale in Chinese lives in docs/USAGE.md instead.
rem
rem What this script does:
rem
rem 1. Isolates the XDG directories. Passing -u alone is NOT enough: Neovim still
rem    puts $XDG_CONFIG_HOME/nvim and $XDG_DATA_HOME/nvim/site on the runtimepath,
rem    so your existing Neovim config and plugins would load alongside this one
rem    (keymap clashes, duplicate plugins, startup errors - all hard to diagnose).
rem    All four XDG variables therefore point inside this directory, which makes
rem    the install self-contained and movable.
rem
rem 2. Prepends bin/ to PATH, so config files can call rg / fzf / stylua and get
rem    the bundled copies without depending on the system.
rem
rem 3. Runs Neovim with -u pointing at this distribution's init.lua.
rem
rem NOTE: Neovim itself is NOT bundled. Install Neovim 0.12+ and either put
rem nvim.exe on PATH or set NVIM_EXE to its full path.

setlocal

set "DISTRO=%~dp0"
if "%DISTRO:~-1%"=="\" set "DISTRO=%DISTRO:~0,-1%"

rem Resolve the Neovim binary.
rem Preference order, most specific first:
rem   1. runtime\bin\nvim.exe  - the copy bundled in this package. Using it means the
rem      tree-sitter parsers in this package were compiled BY this very binary, so
rem      their ABI cannot mismatch, and the version is whatever we shipped.
rem   2. NVIM_EXE              - explicit override for testing another build.
rem   3. nvim.exe on PATH      - last resort; version no longer under our control.
set "NVIMBIN="
if exist "%DISTRO%\runtime\bin\nvim.exe" set "NVIMBIN=%DISTRO%\runtime\bin\nvim.exe"
if not defined NVIMBIN if defined NVIM_EXE set "NVIMBIN=%NVIM_EXE%"
if not defined NVIMBIN (
  for %%I in (nvim.exe) do set "NVIMBIN=%%~$PATH:I"
)
if not defined NVIMBIN (
  echo [packednvim] Cannot find Neovim.
  echo.
  echo   Expected a bundled copy at runtime\bin\nvim.exe.
  echo   If this package was built without one, either install Neovim 0.12+
  echo   and put nvim.exe on PATH, or set NVIM_EXE:
  echo       set NVIM_EXE=D:\tools\nvim-win64\bin\nvim.exe
  exit /b 1
)
if not exist "%NVIMBIN%" (
  if not exist "%NVIMBIN%.exe" (
    echo [packednvim] NVIM_EXE points at a file that does not exist: %NVIMBIN%
    exit /b 1
  )
  set "NVIMBIN=%NVIMBIN%.exe"
)

set "XDG_CONFIG_HOME=%DISTRO%\.local\config"
set "XDG_DATA_HOME=%DISTRO%\.local\data"
set "XDG_STATE_HOME=%DISTRO%\.local\state"
set "XDG_CACHE_HOME=%DISTRO%\.local\cache"

rem TMPDIR must be set explicitly. Without it, this Windows nightly's
rem vim.fn.tempname() returns an EMPTY STRING (verified: TEMP is valid, yet
rem tempname() == ""). That breaks fzf-lua: it builds "<fzf> ... > <tempname>",
rem so the redirect target is empty and cmd.exe reports
rem "The system cannot find the path specified", after which
rem vim.fn.delete("") throws E474: Invalid argument.
rem The E474 traceback points at fzf.lua's cleanup, which misleads you away
rem from the real cause - an empty tempname.
set "TMPDIR=%DISTRO%\.local\tmp"

set "PATH=%DISTRO%\bin;%PATH%"

rem Create every directory we point at. Missing ones are not harmless:
rem a non-existent temp/cache dir is exactly what surfaces as weird errors
rem much later, far from the cause.
for %%D in (config data state cache tmp) do (
  if not exist "%DISTRO%\.local\%%D" mkdir "%DISTRO%\.local\%%D"
)

"%NVIMBIN%" -u "%DISTRO%\init.lua" %*
exit /b %ERRORLEVEL%
