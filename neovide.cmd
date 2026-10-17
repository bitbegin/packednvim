@echo off
rem Launcher for this Neovim distribution via the Neovide GUI (Windows).
rem
rem IMPORTANT: this file is intentionally ASCII-only, for the same reason as
rem nvim.cmd: cmd.exe parses .cmd files using the system OEM code page, not
rem UTF-8, so non-ASCII comments get mis-decoded and can leak out as commands.
rem
rem Why this script has to exist instead of just pointing Neovide at nvim.exe:
rem
rem 1. Neovide spawns nvim itself, so every environment variable set HERE is
rem    inherited by that child process. That is how the distro's XDG isolation
rem    reaches Neovide's nvim. Setting variables inside init.lua would be too
rem    late: Neovim has already resolved stdpath() by then.
rem
rem 2. The distro's init.lua must be loaded. Neovide does not read a config
rem    path from its own settings -- it accepts NeoVim arguments after a bare
rem    double-dash separator (clap last=true plus allow_hyphen_values, verified
rem    in src/cmd_line.rs). So the -u <DISTRO>\init.lua pair goes after it.
rem
rem 3. Neovide needs the --neovim-bin option BEFORE the separator, otherwise
rem    that flag would be forwarded to nvim and rejected as unknown.
rem
rem Neovide itself must be installed and on PATH, or set NEOVIDE_EXE to its
rem full path. Set NEOVIDE_SIZE / NEOVIDE_FRAME etc. as usual; they are read
rem by Neovide from the environment, which this script leaves untouched.

setlocal

set "DISTRO=%~dp0"
if "%DISTRO:~-1%"=="\" set "DISTRO=%DISTRO:~0,-1%"

rem Resolve the Neovim binary that Neovide will drive.
rem Same preference order as nvim.cmd, most specific first.
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

rem Resolve Neovide. Preference order:
rem   1. NEOVIDE_EXE     - explicit override, for testing another build
rem   2. bin\neovide.exe - the copy shipped in this package
rem   3. neovide.exe on PATH
rem bin/ is checked explicitly (not via PATH) so the bundled copy wins even when
rem the user has another Neovide installed; PATH is prepended with bin/ later too.
set "NEORUN="
if defined NEOVIDE_EXE set "NEORUN=%NEOVIDE_EXE%"
if not defined NEORUN if exist "%DISTRO%\bin\neovide.exe" set "NEORUN=%DISTRO%\bin\neovide.exe"
if not defined NEORUN (
  for %%I in (neovide.exe) do set "NEORUN=%%~$PATH:I"
)
if not defined NEORUN (
  echo [packednvim] Cannot find Neovide.
  echo.
  echo   This package does not include it on this platform, and it is not on PATH.
  echo   Install Neovide from https://neovide.dev/ or set NEOVIDE_EXE:
  echo       set NEOVIDE_EXE=C:\Program Files\Neovide\neovide.exe
  echo.
  echo   Text mode still works: run nvim.cmd instead.
  exit /b 1
)
if not exist "%NEORUN%" (
  if not exist "%NEORUN%.exe" (
    echo [packednvim] NEOVIDE_EXE points at a file that does not exist: %NEORUN%
    exit /b 1
  )
  set "NEORUN=%NEORUN%.exe"
)

rem Same isolation as nvim.cmd. Neovide's child nvim inherits all of these.
set "XDG_CONFIG_HOME=%DISTRO%\.local\config"
set "XDG_DATA_HOME=%DISTRO%\.local\data"
set "XDG_STATE_HOME=%DISTRO%\.local\state"
set "XDG_CACHE_HOME=%DISTRO%\.local\cache"

rem TMPDIR must be explicit: on this Windows nightly vim.fn.tempname() returns
rem an EMPTY STRING without it, which breaks fzf-lua. See nvim.cmd for the
rem full story -- it applies here too, because the bundled nvim is the same.
set "TMPDIR=%DISTRO%\.local\tmp"

rem Bundled rg / fzf / stylua must win over anything on the system PATH.
set "PATH=%DISTRO%\bin;%PATH%"

rem Optional: a per-distro Neovide config, so GUI settings travel with the
rem package instead of scattering into the user's roaming profile.
if exist "%DISTRO%\neovide.toml" set "NEOVIDE_CONFIG=%DISTRO%\neovide.toml"

for %%D in (config data state cache tmp) do (
  if not exist "%DISTRO%\.local\%%D" mkdir "%DISTRO%\.local\%%D"
)

rem --neovim-bin goes BEFORE the separator; everything after it is handed to
rem nvim verbatim. The trailing %* lets you pass files: neovide.cmd note.md
"%NEORUN%" --neovim-bin "%NVIMBIN%" -- -u "%DISTRO%\init.lua" %*
exit /b %ERRORLEVEL%
