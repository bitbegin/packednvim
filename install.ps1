# packednvim installer / uninstaller (Windows, per-user, no admin rights)
#
#   double-click install.cmd        -> install
#   install.cmd /u                  -> uninstall
#
# What it sets up
#   1. clears the "downloaded from the Internet" mark (Mark of the Web)
#   2. %LOCALAPPDATA%\nvim  ->  this package      (junction; config discovery)
#   3. <pkg>\bin on the user PATH                 (rg / fzf / fd / neovide ...)
#   4. XDG_STATE_HOME + XDG_CACHE_HOME            (keeps state/cache in the package)
#   5. NEOVIDE_CONFIG -> <pkg>\bin\neovide.toml   (GUI window size + CJK font fallback;
#      Neovide never looks inside bin/ on its own -- it only reads
#      %APPDATA%\neovide\config.toml or the path in NEOVIDE_CONFIG)
#   6. file associations -> bin\neovide.exe "%1"  (GUI, no console, no .cmd/.vbs shim)
#   7. "Open with packednvim" right-click entry
#
# Design notes (learned the hard way)
#   * NEVER write XDG_CONFIG_HOME: config discovery relies on %LOCALAPPDATA%\nvim.
#     Pointing it at an empty dir makes init.lua unfindable and the distro stops
#     loading entirely.
#   * Write registry values with `reg add`, one argument per token. The
#     Set-ItemProperty -Name '(default)' route silently creates a *named* value
#     "(default)" that Explorer never reads.
#   * Must run under Windows PowerShell 5.1: no `$x = if (...)`, no multi-line
#     @() pipelines.

param([switch]$Uninstall)

$ErrorActionPreference = 'Stop'

$Pkg        = $PSScriptRoot
$Bin        = $Pkg + '\bin'
$NvimExe    = $Pkg + '\runtime\bin\nvim.exe'
$NeovideExe = $Pkg + '\bin\neovide.exe'
$StateDir   = $Pkg + '\.local'
$StateFile  = $StateDir + '\install-state.json'

$LocalApp   = [Environment]::GetFolderPath('LocalApplicationData')
if (-not $LocalApp) { $LocalApp = $env:LOCALAPPDATA }
$LinkPath   = $LocalApp + '\nvim'
$StateHome  = $LinkPath + '\.local\state'
$CacheHome  = $LinkPath + '\.local\cache'
$LogDir     = $LocalApp + '\nvim-data\logs'

$Handler = $NvimExe
if (Test-Path -LiteralPath $NeovideExe) { $Handler = $NeovideExe }
$CmdLine = '"' + $Handler + '" "%1"'

$Exts = @('md', 'markdown', 'txt')

# 图标值：<exe>,0。必须在变量里拼好 —— 写成内联的 ($NeovideExe + ',0')
# 会在参数绑定阶段被当成数组，报「无法将值 ",0" 转换为 System.Int32」。
$IconValue = $Handler + ',0'

function Say([string]$m) { Write-Host ('  ' + $m) }

function GetRegDefault([string]$sub) {
    $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($sub)
    if (-not $k) { return $null }
    $v = $k.GetValue('')
    $k.Close()
    return $v
}

# 用 .NET 写入而不是 reg.exe：
#   PowerShell 传**空字符串参数**时会被丢弃，于是 `reg add ... /d '' /f`
#   变成 `/d` 吃掉 `/f`，reg.exe 转而询问「要覆盖吗？(Yes/No)」并等 stdin
#   —— 安装脚本就此永久卡住（实测用 Set-PSDebug 定位到这一步）。
#   SetValue 对空字符串是安全的。
function RegSetDefault([string]$sub, [string]$value) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($sub)
    $key.SetValue('', $value, [Microsoft.Win32.RegistryValueKind]::String)
    $key.Close()
    if ((GetRegDefault $sub) -ne $value) { Write-Warning ('registry write failed: ' + $sub) }
}

function RegSetString([string]$sub, [string]$name, [string]$value) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($sub)
    $key.SetValue($name, $value, [Microsoft.Win32.RegistryValueKind]::String)
    $key.Close()
}

function RemoveReg([string]$sub) {
    Remove-Item -LiteralPath ('HKCU:\' + $sub) -Recurse -Force -ErrorAction SilentlyContinue
}

# 直接写 HKCU\Environment，不走 [Environment]::SetEnvironmentVariable：
# 后者会向所有顶层窗口广播 WM_SETTINGCHANGE 并逐个等待响应，窗口一多
# 就要 5 秒以上（实测）。这里只写注册表，新开的进程/重启 Explorer 后生效。
function SetUserEnvFast([string]$name, [string]$value) {
    $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
    if (-not $k) { $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment') }
    if ($value) {
        $k.SetValue($name, $value, [Microsoft.Win32.RegistryValueKind]::String)
    } else {
        try { $k.DeleteValue($name, $false) } catch { }
    }
    $k.Close()
}

function GetUserPath { [Environment]::GetEnvironmentVariable('Path', 'User') }
function SetUserPath([string]$v) { [Environment]::SetEnvironmentVariable('Path', $v, 'User') }

function IsReparsePoint([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return $false }
    $item = Get-Item -LiteralPath $p -Force
    return [bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
}

if ($Uninstall) {
    if (-not (Test-Path -LiteralPath $StateFile)) {
        Write-Host ('Nothing to uninstall (' + $StateFile + ' not found).')
        exit 0
    }
    $st = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json

    Write-Host '=== PATH ==='
    $up = GetUserPath
    if ($up) {
        $drop = @()
        if ($st.paths) { foreach ($x in @($st.paths)) { $drop += [string]$x } }
        if ($st.path) { $drop += [string]$st.path }
        $parts = @()
        foreach ($p in ($up -split ';')) {
            if (-not $p) { continue }
            $keep = $true
            foreach ($d in $drop) { if ($p -eq $d) { $keep = $false } }
            if ($keep) { $parts += $p }
        }
        SetUserPath ($parts -join ';')
        Say ('removed PATH entries: ' + ($drop -join ' ; '))
    }

    Write-Host '=== environment variables ==='
    foreach ($pair in @(
        @('XDG_STATE_HOME', $st.xdg_state, $st.xdg_state_prev),
        @('XDG_CACHE_HOME', $st.xdg_cache, $st.xdg_cache_prev),
        @('NEOVIDE_CONFIG', $st.neovide_config, $st.neovide_config_prev)
    )) {
        $name = $pair[0]
        $cur  = [Environment]::GetEnvironmentVariable($name, 'User')
        if ($cur -eq $pair[1]) {
            if ($pair[2]) { SetUserEnvFast $name $pair[2] } else { SetUserEnvFast $name $null }
            Say ('restored ' + $name)
        }
    }

    # NEOVIDE_CONFIG 单独回滚（规则与上面两个 XDG 变量一致：只在自己设的值仍生效时恢复）
    $curNv = [Environment]::GetEnvironmentVariable('NEOVIDE_CONFIG', 'User')
    if ($curNv -and $st.neovide_config -and ($curNv -eq $st.neovide_config)) {
        if ($st.neovide_config_prev) { SetUserEnvFast 'NEOVIDE_CONFIG' $st.neovide_config_prev }
        else { SetUserEnvFast 'NEOVIDE_CONFIG' $null }
        Say 'restored NEOVIDE_CONFIG'
    }

    Write-Host '=== associations ==='
    foreach ($p in @($st.progids)) {
        if ($p) { RemoveReg ('Software\Classes\' + $p); Say ('removed ProgID ' + $p) }
    }
    foreach ($e in @($st.exts)) {
        $extKey = 'Software\Classes\.' + $e
        if ((GetRegDefault $extKey) -like 'packednvim*') {
            $k2 = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($extKey, $true)
            if ($k2) { try { $k2.DeleteValue('', $false) } catch { }; $k2.Close() }
            Say ('cleared default for .' + $e)
        }
        Remove-ItemProperty -LiteralPath ('HKCU:\' + $extKey + '\OpenWithProgids') -Name ('packednvim.' + $e) -Force -ErrorAction SilentlyContinue
    }
    RemoveReg 'Software\Classes\*\shell\packednvim'
    Say 'removed right-click entry'
    RemoveReg 'Software\Classes\Applications\neovide.exe'
    RemoveReg 'Software\Classes\Applications\nvim.exe'
    Say 'removed application registrations'

    Write-Host '=== config link ==='
    if ($st.link) {
        $lp = [string]$st.link
        if (IsReparsePoint $lp) {
            # 必须用 rmdir：Remove-Item 对「有子项的重解析点」要么提示确认
            # （无 -Recurse），要么在 5.1 下 -Recurse 跟进目标把包内容删掉。
            # rmdir 只移除链接本身，目标目录原样保留。
            & cmd /c rmdir /q "$lp" 2>&1 | Out-Null
            if (Test-Path -LiteralPath $lp) { Write-Warning ('could not remove link ' + $lp) }
            else { Say ('removed link ' + $lp) }
        }
    }

    Remove-Item -LiteralPath $StateFile -Force -ErrorAction SilentlyContinue
    Write-Host ''
    Write-Host '[OK] Uninstalled. Open a NEW terminal for PATH changes to apply.'
    exit 0
}

if (-not (Test-Path -LiteralPath $Handler)) {
    Write-Error ('neovide.exe / nvim.exe not found under ' + $Pkg)
    exit 1
}

Write-Host '=== packednvim installer ==='
Say ('package : ' + $Pkg)
Say ('handler : ' + $Handler)
Write-Host ''

# 注：这里不再做「解除锁定（Mark of the Web）」。
# 需求已明确不需要；对整包 13000+ 文件逐个 Unblock-File 会卡数分钟
# （实测过），而 pack/vendor 里的 .lua/.dll 带不带标记都不影响加载。

Write-Host '=== 1. standard config dir (junction) ==='
if (IsReparsePoint $LinkPath) {
    # 已经是一个链接：先看它指向谁。指向别的包时不能默默接管 ——
    # 那意味着用户在两个发行版副本之间切换，必须把这件事说出来。
    $curTarget = ''
    try {
        $t = (Get-Item -LiteralPath $LinkPath -Force).Target
        if ($t) { $curTarget = [string](@($t)[0]) }
    } catch { }
    $curNorm = ($curTarget -replace '/', '\').TrimEnd('\')
    $pkgNorm = ($Pkg -replace '/', '\').TrimEnd('\')
    if ($curNorm -and ($curNorm -ne $pkgNorm)) {
        Write-Host ('  NOTE: ' + $LinkPath + ' currently points to:')
        Write-Host ('        ' + $curNorm)
        Write-Host ('        re-pointing it to: ' + $pkgNorm)
        & cmd /c rmdir /q "$LinkPath" 2>&1 | Out-Null
        & cmd /c mklink /J "$LinkPath" "$Pkg" | Out-Null
        if (Test-Path -LiteralPath ($LinkPath + '\init.lua')) { Say ('re-pointed to ' + $pkgNorm) }
        else { Write-Warning 'could not re-point the config link' }
    } else {
        Say ('already a link to this package: ' + $LinkPath)
    }
} else {
    if (Test-Path -LiteralPath $LinkPath) {
        $bak = $LinkPath + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Rename-Item -LiteralPath $LinkPath -NewName (Split-Path $bak -Leaf)
        Say ('existing config moved to ' + $bak)
    }
    & cmd /c mklink /J "$LinkPath" "$Pkg" | Out-Null
    if (Test-Path -LiteralPath ($LinkPath + '\init.lua')) { Say ('junction: ' + $LinkPath + ' -> ' + $Pkg) }
    else { Write-Warning 'junction creation failed' }
}

Write-Host '=== 2. user PATH ==='
# 两个目录都要在 PATH 上：
#   <pkg>\bin        工具（rg / fzf / fd / stylua / shfmt / shellcheck / neovide）
#   <pkg>\runtime\bin nvim.exe 本体（放在原位才能自己找到 runtime\share\nvim\runtime）
# 前置写入，保证优先于系统安装的同名程序。
$RtBin = $Pkg + '\runtime\bin'
$up = GetUserPath
$parts = @()
if ($up) { foreach ($p in ($up -split ';')) { if ($p) { $parts += $p } } }
$added = @()
foreach ($want in @($RtBin, $Bin)) {
    $has = $false
    foreach ($p in $parts) { if ($p -eq $want) { $has = $true } }
    if ($has) { Say ('already present: ' + $want) }
    else { $parts = @($want) + $parts; $added += $want; Say ('added: ' + $want) }
}
if ($added.Count -gt 0) { SetUserPath ($parts -join ';') }

Write-Host '=== 3. environment variables ==='
foreach ($d in @($StateHome, $CacheHome, $LogDir)) {
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
}

$prevState = [Environment]::GetEnvironmentVariable('XDG_STATE_HOME', 'User')
$prevCache = [Environment]::GetEnvironmentVariable('XDG_CACHE_HOME', 'User')
SetUserEnvFast 'XDG_STATE_HOME' $StateHome
SetUserEnvFast 'XDG_CACHE_HOME' $CacheHome
Say ('XDG_STATE_HOME -> ' + $StateHome)
Say ('XDG_CACHE_HOME -> ' + $CacheHome)

# GUI 外观：Neovide 只认 %APPDATA%\neovide\config.toml 或 NEOVIDE_CONFIG。
# 随包的 bin\neovide.toml 带字体回退链（含中文字形），不指过去就用内置默认。
$NeovideToml = $Bin + '\neovide.toml'
$prevNeovide = [Environment]::GetEnvironmentVariable('NEOVIDE_CONFIG', 'User')
if (Test-Path -LiteralPath $NeovideToml) {
    SetUserEnvFast 'NEOVIDE_CONFIG' $NeovideToml
    Say ('NEOVIDE_CONFIG -> ' + $NeovideToml)
} else {
    Say 'bin\neovide.toml not found (GUI uses Neovide defaults)'
}
Write-Host '=== 4. file associations ==='
$progIds = @()
foreach ($e in $Exts) {
    $progId = 'packednvim.' + $e
    $progIds += $progId
    RegSetDefault ('Software\Classes\' + $progId) ($e + ' (packednvim)')
    RegSetDefault ('Software\Classes\' + $progId + '\shell\open\command') $CmdLine
    RegSetDefault ('Software\Classes\.' + $e) $progId
    RegSetString ('Software\Classes\.' + $e + '\OpenWithProgids') $progId ''
    Say ('.' + $e + ' -> ' + $progId)
}

Write-Host '=== 5. right-click entry ==='
RegSetDefault 'Software\Classes\*\shell\packednvim' 'Open with packednvim'
RegSetDefault 'Software\Classes\*\shell\packednvim\command' $CmdLine
Say 'added "Open with packednvim"'

Write-Host '=== 6. application registrations (visible in "Open with") ==='
RegSetDefault 'Software\Classes\Applications\neovide.exe\shell\open\command' ('"' + $NeovideExe + '" "%1"')
RegSetString 'Software\Classes\Applications\neovide.exe' 'FriendlyAppName' 'Neovide (packednvim)'
RegSetString 'Software\Classes\Applications\neovide.exe' 'DefaultIcon' ( + ',0')
foreach ($e in $Exts) { RegSetString 'Software\Classes\Applications\neovide.exe\SupportedTypes' ('.' + $e) '' }
Say 'registered Neovide (packednvim)'

RegSetDefault 'Software\Classes\Applications\nvim.exe\shell\open\command' ('"' + $NvimExe + '" "%1"')
RegSetString 'Software\Classes\Applications\nvim.exe' 'FriendlyAppName' 'Neovim (packednvim, console)'
foreach ($e in $Exts) { RegSetString 'Software\Classes\Applications\nvim.exe\SupportedTypes' ('.' + $e) '' }
Say 'registered Neovim (packednvim, console)'

Write-Host '=== 7. state (for /u) ==='
if (-not (Test-Path -LiteralPath $StateDir)) { New-Item -ItemType Directory -Force -Path $StateDir | Out-Null }
$state = [ordered]@{}
$state['installed_at'] = (Get-Date).ToString('s')
$state['package'] = $Pkg
$state['path'] = $Bin
$state['paths'] = @($Bin, $RtBin)
$state['link'] = $LinkPath
$state['exts'] = $Exts
$state['progids'] = $progIds
$state['handler'] = $Handler
$state['xdg_state'] = $StateHome
$state['xdg_cache'] = $CacheHome
$state['xdg_state_prev'] = $prevState
$state['xdg_cache_prev'] = $prevCache
$state['neovide_config'] = $NeovideToml
$state['neovide_config_prev'] = $prevNeovide
$state['neovide_config'] = $NeovideToml
$state | ConvertTo-Json | Set-Content -LiteralPath $StateFile -Encoding utf8
Say $StateFile

Write-Host ''
Write-Host '[OK] Installed.'
Write-Host '     * open a NEW terminal (or restart Explorer) so PATH/env are visible'
Write-Host '     * double-click .md -> Neovide window, no console, no log warning'
Write-Host '     * if Windows asks once, pick "Neovide (packednvim)" and tick Always'
Write-Host '     * undo everything:  uninstall.cmd'
