# packednvim installer (Windows, per-user, no admin required)
#
# What it does
#   * adds <package>\bin to the USER PATH   (nvim / rg / fzf / fd ... usable anywhere)
#   * registers file associations for the extensions you pass in (-Ext), default md,markdown
#   * adds a right-click "Open with packednvim" entry for every file type
#   * registers the launcher as an application, so it shows up in "Open with"
#
# Undo everything with:  install.cmd /u      (or: powershell -File install.ps1 -Uninstall)
#
# Everything is per-user (HKCU + user environment). No admin rights, no system-wide changes.
# Exactly what was added is recorded in .local\install-state.json, and -Uninstall removes
# only those entries, so a later change you make by hand (e.g. picking another default app)
# is not clobbered.

param(
    [switch]$Uninstall,
    [switch]$Direct,
    [string[]]$Ext = @('md', 'markdown')
)

$ErrorActionPreference = 'Stop'

$Pkg       = $PSScriptRoot
$Bin       = Join-Path $Pkg 'bin'
$NvimCmd   = Join-Path $Pkg 'nvim.cmd'
$StateDir  = Join-Path $Pkg '.local'
$StateFile = Join-Path $StateDir 'install-state.json'

# "cmd /c "<pkg>\nvim.cmd" "%1""
# 两种关联方式：
#  默认（经 nvim.cmd）—— 命令行能带环境变量，XDG/TMPDIR 全部隔离在包内
#  -Direct（直接调 exe）—— 没有 .cmd，双击即可；但注册表只能传参数、传不了
#    环境变量，所以状态目录会落到系统默认位置（%LOCALAPPDATA%\nvim-data 等）。
#    配置本身仍然正确：-u 明确指向本发行版的 init.lua。
#    GUI 优先用 neovide.exe（无控制台窗口），没有则退回终端 nvim.exe。
$NvimExe    = Join-Path $Pkg 'runtime\bin\nvim.exe'
$NeovideExe = Join-Path $Pkg 'bin\neovide.exe'
$InitLua    = Join-Path $Pkg 'init.lua'
$DirectLine = if (Test-Path -LiteralPath $NeovideExe) {
    '"' + $NeovideExe + '" -- -u "' + $InitLua + '" "%1"'
} else {
    '"' + $NvimExe + '" -u "' + $InitLua + '" "%1"'
}

$CmdLine = if ($Direct) { $DirectLine } else { 'cmd /c "' + $NvimCmd + '" "%1"' }

function Write-Step($msg) { Write-Host "  $msg" }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Get-UserPath {
    [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Set-UserPath([string]$value) {
    [Environment]::SetEnvironmentVariable('Path', $value, 'User')
}

function ConvertTo-RegSubKey([string]$key) {
    $key -replace '^HKCU:\\', '' -replace '^HKEY_CURRENT_USER\\', ''
}

function Set-Default([string]$key, [string]$value) {
    if (-not (Test-Path -LiteralPath $key)) { New-Item -Path $key -Force | Out-Null }
    # 不要用 Set-ItemProperty -Name '(default)'：实测它建出的是**名为 "(default)"
    # 的普通值**，而不是真正的默认值，Explorer 因此完全看不到这个关联
    # （症状：双击仍打开别的程序、assoc .md 查不到）。用 .NET 写空名值才对。
    $sub = ConvertTo-RegSubKey $key
    $reg = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($sub)
    $reg.SetValue('', $value, [Microsoft.Win32.RegistryValueKind]::String)
    $reg.Close()
}

function Set-Prop([string]$key, [string]$name, [string]$value) {
    if (-not (Test-Path -LiteralPath $key)) { New-Item -Path $key -Force | Out-Null }
    New-ItemProperty -LiteralPath $key -Name $name -Value $value -PropertyType String -Force | Out-Null
}

function Get-Default([string]$key) {
    $reg = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey((ConvertTo-RegSubKey $key))
    if (-not $reg) { return $null }
    $v = $reg.GetValue('')
    $reg.Close()
    $v
}

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
if ($Uninstall) {
    if (-not (Test-Path -LiteralPath $StateFile)) {
        Write-Host "Nothing to uninstall: $StateFile not found."
        Write-Host "Run install.cmd first, or remove the entries by hand."
        exit 0
    }
    $st = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json

    Write-Host '=== Removing PATH entry ==='
    $up = Get-UserPath
    if ($up) {
        $parts = @($up -split ';' | Where-Object { $_ -and $_ -ne $st.path })
        Set-UserPath ($parts -join ';')
        Write-Step "removed $($st.path)"
    }

    Write-Host '=== Removing associations ==='
    foreach ($p in @($st.progids)) {
        if ($p) { Remove-Item -LiteralPath (Join-Path 'HKCU:\Software\Classes' $p) -Recurse -Force -ErrorAction SilentlyContinue; Write-Step "removed ProgID $p" }
    }
    foreach ($e in @($st.exts)) {
        $extKey = Join-Path 'HKCU:\Software\Classes' ".$e"
        # only drop the default value if it still points at us
        if ($e -and (Get-Default $extKey) -like 'packednvim*') {
            # Remove-ItemProperty -Name '(default)' 与 reg delete /ve 在实测里
            # 都出现过「命令不报错但默认值仍在」。直接用 .NET 注册表 API 删
            # 默认值（名称为空串），并用回读校验，避免又一次假成功。
            $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Software\Classes\.$e", $true)
            if ($key) {
                try { $key.DeleteValue('', $false) } catch { }
                $key.Close()
            }
            if (Get-Default $extKey) { Write-Warning "could not clear the default value of .$e" }
            Write-Step "removed default handler for .$e"
        }
        $owp = Join-Path $extKey 'OpenWithProgids'
        if (Test-Path -LiteralPath $owp) {
            Remove-ItemProperty -LiteralPath $owp -Name "packednvim.$e" -Force -ErrorAction SilentlyContinue
            Write-Step "removed .$e from OpenWithProgids"
        }
    }

    Write-Host '=== Removing right-click entry and application registration ==='
    Remove-Item -LiteralPath 'HKCU:\Software\Classes\*\shell\packednvim' -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'HKCU:\Software\Classes\Applications\nvim.cmd' -Recurse -Force -ErrorAction SilentlyContinue
    Write-Step 'removed "Open with packednvim" and Applications\nvim.cmd'

    Remove-Item -LiteralPath $StateFile -Force -ErrorAction SilentlyContinue
    Write-Host ''
    Write-Host '[OK] Uninstalled. Open a NEW terminal for the PATH change to take effect.'
    exit 0
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $NvimCmd)) {
    Write-Error "nvim.cmd not found next to install.ps1: $NvimCmd"
    exit 1
}

$exts = @($Ext | ForEach-Object { $_.TrimStart('.') } | Where-Object { $_ })
if ($exts.Count -eq 0) { $exts = @('md', 'markdown') }

Write-Host "=== packednvim installer ==="
Write-Host "  package: $Pkg"
Write-Host "  ext:     $($exts -join ', ')"
Write-Host ''

Write-Host '=== 0. Clearing the network mark (Mark of the Web) ==='
# Downloaded zips carry Zone.Identifier, which makes Windows warn that the
# publisher cannot be verified (and SmartScreen block nvim.exe on first run).
# Doing it here means one command both unblocks and installs.
$unblocked = 0
foreach ($file in Get-ChildItem -LiteralPath $Pkg -Recurse -File -ErrorAction SilentlyContinue) {
    try { Unblock-File -LiteralPath $file.FullName -ErrorAction Stop; $unblocked++ } catch { }
}
Write-Step "processed $unblocked files (no-op for files that had no mark)"

Write-Host '=== 1. User PATH ==='
$up = Get-UserPath
if (($up -split ';') -contains $Bin) {
    Write-Step "already present: $Bin"
} else {
    $new = if ($up) { $Bin + ';' + $up } else { $Bin }
    Set-UserPath $new
    Write-Step "added: $Bin"
}

Write-Host '=== 2. File associations ==='
$progIds = @()
foreach ($e in $exts) {
    $progId = "packednvim.$e"
    $progIds += $progId
    $root = Join-Path 'HKCU:\Software\Classes' $progId
    Set-Default $root "$e (packednvim)"
    Set-Default (Join-Path $root 'shell\open\command') $CmdLine
    $extKey = Join-Path 'HKCU:\Software\Classes' ".$e"
    Set-Default $extKey $progId
    Set-Prop (Join-Path $extKey 'OpenWithProgids') $progId ''
    Write-Step ".$e -> $progId"
}

Write-Host '=== 3. Right-click entry (all file types) ==='
Set-Default 'HKCU:\Software\Classes\*\shell\packednvim' 'Open with packednvim'
Set-Default 'HKCU:\Software\Classes\*\shell\packednvim\command' $CmdLine
Write-Step 'added "Open with packednvim"'

Write-Host '=== 4. Application registration (so it appears in "Open with") ==='
$app = 'HKCU:\Software\Classes\Applications\nvim.cmd'
Set-Default (Join-Path $app 'shell\open\command') $CmdLine
Set-Prop $app 'FriendlyAppName' 'packednvim (Neovim)'
foreach ($e in $exts) { Set-Prop (Join-Path $app 'SupportedTypes') ".$e" '' }
Write-Step 'registered as "packednvim (Neovim)"'

Write-Host '=== 5. Recording state for -Uninstall ==='
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
[ordered]@{
    installed_at = (Get-Date).ToString('s')
    package      = $Pkg
    path         = $Bin
    exts         = $exts
    progids      = $progIds
    direct       = [bool]$Direct
} | ConvertTo-Json | Set-Content -LiteralPath $StateFile -Encoding utf8
Write-Step $StateFile

Write-Host ''
Write-Host '[OK] Installed.'
Write-Host '     * PATH: open a NEW terminal, then "nvim" works from anywhere.'
if ($Direct) {
    Write-Host '     * Mode: -Direct (no .cmd). Associations call neovide.exe/nvim.exe'
    Write-Host '       directly with -u <pkg>\init.lua; runtime state goes to the'
    Write-Host '       default %LOCALAPPDATA%\nvim-data.'
} else {
    Write-Host '     * Mode: launcher (.cmd). Full XDG/TMPDIR isolation inside the package.'
}
Write-Host '     * Double-click may still ask once which app to use: pick'
Write-Host '       "packednvim (Neovim)" and tick "Always". Windows stores that'
Write-Host '       choice in a hash-protected key that only the dialog may write.'
Write-Host '     * Undo everything:  install.cmd /u'
