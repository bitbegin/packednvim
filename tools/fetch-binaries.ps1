<#
.SYNOPSIS
    下载随包分发的外部工具二进制，校验后放进 bin/。

.DESCRIPTION
    需求 4 / 5 把 rg 与 fzf 定为硬依赖，因此这两个必须随包分发。此外单文件静态
    工具（fd / stylua / shfmt / ruff）体积小、无运行时依赖，一起打包性价比很高。

    本脚本负责：

      1. 现场向 GitHub API 取最新版本号与每个产物的 SHA256（不写死版本）
      2. 断点续传下载（代理会中途断流，curl --retry 对「停滞」不生效）
      3. 校验大小 + SHA256，任何一项不符就中止，绝不落位
      4. 解压并把产物放进 bin/
      5. 附带许可证全文（分发二进制必须带）
      6. 生成 bin/README.md 清单

    bin/ 里 Windows 与 Linux 两套并存，靠扩展名区分（.exe 后缀即 Windows）。

    工具清单在下面的 $specs 里，一行一个产物。加工具就加行，不用改流程。

.PARAMETER Proxy
    下载用的本机代理。留空字符串表示直连。

.PARAMETER Force
    即使 bin/ 下已有同名文件也重新下载覆盖。

.PARAMETER Only
    只处理名字里含该字符串的工具，便于单个重试。例如 -Only ripgrep

.EXAMPLE
    pwsh -File tools/fetch-binaries.ps1
    pwsh -File tools/fetch-binaries.ps1 -Only fzf -Force
    pwsh -File tools/fetch-binaries.ps1 -Proxy ''
#>
[CmdletBinding()]
param(
    [string]$Proxy = 'http://127.0.0.1:7892',
    [switch]$Force,
    [string]$Only = '',
    [int]$TimeoutMinutes = 15
)

$ErrorActionPreference = 'Stop'

$root   = Split-Path -Parent $PSScriptRoot
$binDir = Join-Path $root 'bin'
$dlDir  = Join-Path $root 'build\downloads'
$tmpDir = Join-Path $root 'build\extract'

New-Item -ItemType Directory -Force -Path $binDir, $dlDir, $tmpDir | Out-Null

$proxyArgs = @()
if ($Proxy) { $proxyArgs = @('-x', $Proxy) }

# ====================================================================
# 工具函数
# ====================================================================

function Get-GitHubRelease {
    param([string]$Repo, [int]$Attempts = 8)
    $url = "https://api.github.com/repos/$Repo/releases/latest"
    # 代理会间歇性握手失败，元数据请求也要重试，不能只给下载加重试
    for ($i = 1; $i -le $Attempts; $i++) {
        $raw = & curl.exe @proxyArgs -sS --max-time 180 $url 2>$null
        if ($LASTEXITCODE -eq 0 -and $raw) {
            try {
                $obj = $raw | ConvertFrom-Json
                if ($obj.tag_name) { return $obj }
            } catch { }
        }
        Write-Host ("  [重试 {0}/{1}] {2} 的发布信息没取到" -f $i, $Attempts, $Repo) -ForegroundColor DarkGray
        Start-Sleep -Seconds 2
    }
    throw "取不到 $Repo 的发布信息（代理不稳定？）"
}

function Get-Asset {
    param($Release, [string]$Pattern)
    $a = $Release.assets | Where-Object { $_.name -like $Pattern } | Select-Object -First 1
    if (-not $a) {
        # 把可用产物列出来，这样改 $specs 时一次就能改对
        $names = ($Release.assets | ForEach-Object { $_.name }) -join "`n      "
        throw "在 $($Release.tag_name) 里找不到匹配 $Pattern 的产物。可用产物：`n      $names"
    }
    return $a
}

function Save-Asset {
    param($Asset, [string]$DestDir)
    $dest = Join-Path $DestDir $Asset.name
    $want = if ($Asset.digest) { ($Asset.digest -replace '^sha256:', '').ToUpper() } else { $null }

    if ((Test-Path $dest) -and -not $Force) {
        if ($want -and (Get-FileHash $dest -Algorithm SHA256).Hash -eq $want) {
            Write-Host ("  [跳过] {0}" -f $Asset.name) -ForegroundColor DarkGray
            return $dest
        }
    }

    Write-Host ("  [下载] {0}  ({1:N0} 字节)" -f $Asset.name, $Asset.size)
    # 代理会间歇性拒绝 TLS 握手，也会中途断流。所以按「限时重试 + 断点续传」来：
    # 上限用墙钟时间而不是固定次数 —— 固定次数在代理状态差时会被握手失败白白耗光。
    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    $attempt  = 0
    $lastShown = -1
    while ((Get-Date) -lt $deadline) {
        $cur = if (Test-Path $dest) { (Get-Item $dest).Length } else { 0 }
        if ($cur -eq $Asset.size) { break }
        if ($cur -gt $Asset.size) { Remove-Item $dest -Force -ErrorAction SilentlyContinue; $cur = 0 }
        $attempt++
        & curl.exe @proxyArgs -L -sS -C - -o $dest --connect-timeout 20 `
            --speed-limit 1024 --speed-time 30 --max-time 420 $Asset.browser_download_url 2>$null
        $now = if (Test-Path $dest) { (Get-Item $dest).Length } else { 0 }
        if ($now -eq $Asset.size) { break }
        if ($now -eq $cur) {
            Write-Host ("    [第 {0} 次] 无进展（{1:N0}/{2:N0}），代理可能在拒绝握手" -f `
                $attempt, $now, $Asset.size) -ForegroundColor DarkGray
        } elseif ($now -ne $lastShown) {
            Write-Host ("    [第 {0} 次] 已续传到 {1:N0}/{2:N0}" -f $attempt, $now, $Asset.size) -ForegroundColor DarkGray
            $lastShown = $now
        }
        Start-Sleep -Seconds 2
    }

    if ((Test-Path $dest) -and (Get-Item $dest).Length -ne $Asset.size) {
        throw ("下载超时：{0}`n  已得 {1:N0} / 需要 {2:N0} 字节。`n  断点已保留，重跑本脚本会继续续传。" -f `
            $Asset.name, (Get-Item $dest).Length, $Asset.size)
    }

    if (-not (Test-Path $dest)) { throw "下载失败：$($Asset.name)" }

    $len  = (Get-Item $dest).Length
    $hash = (Get-FileHash $dest -Algorithm SHA256).Hash
    if ($len -ne $Asset.size) {
        throw ("大小不符：{0}`n  期望 {1:N0} / 实际 {2:N0}" -f $Asset.name, $Asset.size, $len)
    }
    if ($want -and $hash -ne $want) {
        throw ("SHA256 不符：{0}`n  期望 {1}`n  实际 {2}" -f $Asset.name, $want, $hash)
    }
    if (-not $want) {
        # 没有官方摘要时不能声称「SHA256 与官方一致」——那是在说没做过的事
        Write-Host "  [通过] 大小与上游一致（无官方摘要，另有后续校验）" -ForegroundColor Yellow
    } else {
        Write-Host "  [通过] 大小与 SHA256 均与官方一致" -ForegroundColor Green
    }
    return $dest
}

function Expand-ArchiveTo {
    param([string]$Archive, [string]$Dest)
    if (Test-Path $Dest) { Remove-Item $Dest -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    if ($Archive -like '*.zip') {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($Archive, $Dest, $true)
    } elseif ($Archive -like '*.tar.xz') {
        & tar.exe -xJf $Archive -C $Dest
        if ($LASTEXITCODE -ne 0) { throw "tar 解压失败：$Archive" }
    } else {
        & tar.exe -xzf $Archive -C $Dest
        if ($LASTEXITCODE -ne 0) { throw "tar 解压失败：$Archive" }
    }
}

function Get-LicenseFile {
    param([string]$Name, [string[]]$Urls, [string]$OutDir, [int]$Attempts = 4)
    $out = Join-Path $OutDir $Name
    foreach ($u in $Urls) {
        for ($i = 1; $i -le $Attempts; $i++) {
            & curl.exe @proxyArgs -L -sS --max-time 120 -o $out $u 2>$null
            if ((Test-Path $out) -and (Get-Item $out).Length -gt 100) { return $true }
            Start-Sleep -Seconds 1
        }
    }
    Remove-Item $out -Force -ErrorAction SilentlyContinue
    return $false
}

function Get-GitBlobSha1 {
    # 计算 git blob 的 SHA-1：sha1("blob <长度>\0" + 内容)。
    # 用于校验「直接放在仓库里、没有 release 资源」的二进制——
    # 这类文件 GitHub 不提供 SHA256，但 API 会给出 blob 哈希，同样能锁到字节级内容。
    param([string]$Path)
    $bytes  = [System.IO.File]::ReadAllBytes($Path)
    $header = [System.Text.Encoding]::ASCII.GetBytes("blob $($bytes.Length)`0")
    $all    = New-Object byte[] ($header.Length + $bytes.Length)
    [Array]::Copy($header, 0, $all, 0, $header.Length)
    [Array]::Copy($bytes, 0, $all, $header.Length, $bytes.Length)
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    return (($sha1.ComputeHash($all) | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Write-Utf8Lf {
    # 统一用 LF + 无 BOM 写文本文件。
    # PowerShell 的 Set-Content 在 Windows 上会写出 CRLF，而这是跨平台仓库，
    # 混入 CRLF 会让 git diff 变成整文件改动 —— 所以生成器自己负责写出 LF。
    param([string]$Path, [string]$Text)
    $normalized = $Text -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($Path, $normalized, (New-Object System.Text.UTF8Encoding($false)))
}

# ====================================================================
# 1. 取版本
# ====================================================================
Write-Host '=== 1. 现场取版本与摘要 ===' -ForegroundColor Cyan

$repos = [ordered]@{
    ripgrep    = 'BurntSushi/ripgrep'
    fzf        = 'junegunn/fzf'
    fd         = 'sharkdp/fd'
    stylua     = 'JohnnyMorganz/StyLua'
    shfmt      = 'mvdan/sh'
    shellcheck = 'koalaman/shellcheck'
}

$rel = @{}
foreach ($tool in $repos.Keys) {
    if ($Only -and $tool -notlike "*$Only*") { continue }
    $rel[$tool] = Get-GitHubRelease $repos[$tool]
    Write-Host ("  {0,-8} {1}" -f $tool, $rel[$tool].tag_name)
}

# ====================================================================
# 2. 产物清单（加工具就在这里加行）
#    Mode: file = 解压后取 Member 指向的文件；raw = 下载物本身就是可执行文件
# ====================================================================
$specs = @()
if ($rel['ripgrep']) {
    $specs += @{ Tool='ripgrep'; Rel=$rel['ripgrep']; Platform='windows-x64'; Pattern='*x86_64-pc-windows-msvc.zip';       Mode='file'; Member='rg.exe'; Out='rg.exe' }
    $specs += @{ Tool='ripgrep'; Rel=$rel['ripgrep']; Platform='linux-x64';   Pattern='*x86_64-unknown-linux-musl.tar.gz'; Mode='file'; Member='rg';     Out='rg' }
}
if ($rel['fzf']) {
    $specs += @{ Tool='fzf'; Rel=$rel['fzf']; Platform='windows-x64'; Pattern='*windows_amd64.zip';  Mode='file'; Member='fzf.exe'; Out='fzf.exe' }
    $specs += @{ Tool='fzf'; Rel=$rel['fzf']; Platform='linux-x64';   Pattern='*linux_amd64.tar.gz'; Mode='file'; Member='fzf';     Out='fzf' }
}
if ($rel['fd']) {
    $specs += @{ Tool='fd'; Rel=$rel['fd']; Platform='windows-x64'; Pattern='*x86_64-pc-windows-msvc.zip';       Mode='file'; Member='fd.exe'; Out='fd.exe' }
    $specs += @{ Tool='fd'; Rel=$rel['fd']; Platform='linux-x64';   Pattern='*x86_64-unknown-linux-musl.tar.gz'; Mode='file'; Member='fd';     Out='fd' }
}
if ($rel['stylua']) {
    $specs += @{ Tool='stylua'; Rel=$rel['stylua']; Platform='windows-x64'; Pattern='*windows-x86_64.zip'; Mode='file'; Member='stylua.exe'; Out='stylua.exe' }
    $specs += @{ Tool='stylua'; Rel=$rel['stylua']; Platform='linux-x64';   Pattern='*linux-x86_64.zip';   Mode='file'; Member='stylua';     Out='stylua' }
}
if ($rel['shfmt']) {
    # shfmt 发布的是裸可执行文件，不是压缩包
    $specs += @{ Tool='shfmt'; Rel=$rel['shfmt']; Platform='windows-x64'; Pattern='*_windows_amd64.exe'; Mode='raw'; Member=''; Out='shfmt.exe' }
    $specs += @{ Tool='shfmt'; Rel=$rel['shfmt']; Platform='linux-x64';   Pattern='*_linux_amd64';       Mode='raw'; Member=''; Out='shfmt' }
}
if ($rel['shellcheck']) {
    # Windows 给的是 zip，Linux 给的是 .tar.xz（靠 tar.exe -xJf 解）
    $specs += @{ Tool='shellcheck'; Rel=$rel['shellcheck']; Platform='windows-x64'; Pattern='*.zip';                 Mode='file'; Member='shellcheck.exe'; Out='shellcheck.exe' }
    $specs += @{ Tool='shellcheck'; Rel=$rel['shellcheck']; Platform='linux-x64';   Pattern='*.linux.x86_64.tar.xz'; Mode='file'; Member='shellcheck';     Out='shellcheck' }
}

# ====================================================================
# 3. 下载 + 校验 + 落位
# ====================================================================
Write-Host "`n=== 2. 下载 + 校验 + 落位 ===" -ForegroundColor Cyan

$installed = @()
foreach ($s in $specs) {
    Write-Host ("[{0} / {1}]" -f $s.Tool, $s.Platform) -ForegroundColor White
    $asset   = Get-Asset -Release $s.Rel -Pattern $s.Pattern
    $archive = Save-Asset -Asset $asset -DestDir $dlDir
    $target  = Join-Path $binDir $s.Out

    if ($s.Mode -eq 'raw') {
        Copy-Item $archive $target -Force
    } else {
        $stage = Join-Path $tmpDir (($s.Tool + '_' + $s.Platform) -replace '[^A-Za-z0-9_]', '_')
        Expand-ArchiveTo -Archive $archive -Dest $stage
        $found = Get-ChildItem $stage -Recurse -File |
            Where-Object { $_.Name -eq $s.Member } | Select-Object -First 1
        if (-not $found) { throw "$($asset.name) 里找不到 $($s.Member)" }
        Copy-Item $found.FullName $target -Force
    }

    $installed += [pscustomobject]@{
        Tool     = $s.Tool
        Platform = $s.Platform
        File     = $s.Out
        Bytes    = (Get-Item $target).Length
        Sha256   = (Get-FileHash $target -Algorithm SHA256).Hash
        Asset    = $asset.name
        Version  = $s.Rel.tag_name
        Url      = $asset.browser_download_url
        RunTest  = $true
    }
}

# --------------------------------------------------------------------
# 从仓库直接取的裸文件（没有 release 资源，靠 git blob 哈希固化内容）
# --------------------------------------------------------------------
$rawSpecs = @(
    @{
        Tool     = 'im-select'
        Out      = 'im-select.exe'
        Platform = 'windows-x64'
        Url      = 'https://raw.githubusercontent.com/daipeihust/im-select/master/win/out/x64/im-select.exe'
        Bytes    = 130560
        BlobSha  = '890b3eb126f7b8da40b75d58a867bb2f5e652e9e'
        Version  = 'master@890b3eb1'
    }
)

foreach ($r in $rawSpecs) {
    Write-Host ("[{0} / {1}]" -f $r.Tool, $r.Platform) -ForegroundColor White
    # 伪装成 release 资源，复用已经验证过的「限时重试 + 断点续传」下载路径
    $asset = [pscustomobject]@{
        name                 = $r.Out
        size                 = [long]$r.Bytes
        digest               = $null      # 上游没有提供 SHA256
        browser_download_url = $r.Url
    }
    $file   = Save-Asset -Asset $asset -DestDir $dlDir
    $target = Join-Path $binDir $r.Out
    Copy-Item $file $target -Force

    $blob = Get-GitBlobSha1 -Path $target
    if ($blob -ne $r.BlobSha) {
        throw ("git blob 哈希不符：{0}`n  期望 {1}`n  实际 {2}" -f $r.Out, $r.BlobSha, $blob)
    }
    Write-Host "  [通过] git blob 哈希与仓库一致（该文件无 release 资源，故无官方 SHA256）" -ForegroundColor Green

    $installed += [pscustomobject]@{
        Tool     = $r.Tool
        Platform = $r.Platform
        File     = $r.Out
        Bytes    = (Get-Item $target).Length
        Sha256   = (Get-FileHash $target -Algorithm SHA256).Hash
        Asset    = "$($r.Out)（仓库 blob $($r.BlobSha.Substring(0, 8))）"
        Version  = $r.Version
        Url      = $r.Url
        RunTest  = $false     # 它没有 --version，改用 PE 头 + blob 哈希校验
    }
}

# ====================================================================
# 4. 验证产物
# ====================================================================
Write-Host "`n=== 3. 验证产物 ===" -ForegroundColor Cyan
foreach ($r in $installed) {
    $p = Join-Path $binDir $r.File
    if ($r.Platform -eq 'windows-x64') {
        if ($r.RunTest) {
            $line = (& $p --version 2>&1 | Select-Object -First 1)
            if (-not $line) { throw "$($r.File) 跑不起来" }
            Write-Host ("  {0,-15} 运行 -> {1}" -f $r.File, $line) -ForegroundColor Green
        } else {
            $magic = (([System.IO.File]::ReadAllBytes($p))[0..1] |
                      ForEach-Object { $_.ToString('x2') }) -join ''
            if ($magic -ne '4d5a') { throw "$($r.File) 不是 PE 可执行文件（魔数 $magic）" }
            Write-Host ("  {0,-15} PE 头正确（无 --version，已用 git blob 哈希校验）" -f $r.File) -ForegroundColor Green
        }
    } else {
        $magic = (([System.IO.File]::ReadAllBytes($p))[0..3] |
                  ForEach-Object { $_.ToString('x2') }) -join ''
        if ($magic -ne '7f454c46') { throw "$($r.File) 不是 Linux 可执行文件（魔数 $magic）" }
        Write-Host ("  {0,-15} ELF 头正确（Windows 上无法执行，靠哈希与魔数验证）" -f $r.File) -ForegroundColor Green
    }
}

# ====================================================================
# 5. 许可证
# ====================================================================
Write-Host "`n=== 4. 许可证全文 ===" -ForegroundColor Cyan
$licDir = Join-Path $binDir 'licenses'
New-Item -ItemType Directory -Force -Path $licDir | Out-Null

$licSpecs = @()
if ($rel['ripgrep']) {
    $t = $rel['ripgrep'].tag_name
    $licSpecs += @{ Name='ripgrep-LICENSE-MIT.txt'; Urls=@("https://raw.githubusercontent.com/BurntSushi/ripgrep/$t/LICENSE-MIT") }
    $licSpecs += @{ Name='ripgrep-UNLICENSE.txt';   Urls=@("https://raw.githubusercontent.com/BurntSushi/ripgrep/$t/UNLICENSE") }
}
if ($rel['fzf']) {
    $t = $rel['fzf'].tag_name
    $licSpecs += @{ Name='fzf-LICENSE.txt'; Urls=@("https://raw.githubusercontent.com/junegunn/fzf/$t/LICENSE") }
}
if ($rel['fd']) {
    $t = $rel['fd'].tag_name
    $licSpecs += @{ Name='fd-LICENSE-MIT.txt';    Urls=@("https://raw.githubusercontent.com/sharkdp/fd/$t/LICENSE-MIT") }
    $licSpecs += @{ Name='fd-LICENSE-APACHE.txt'; Urls=@("https://raw.githubusercontent.com/sharkdp/fd/$t/LICENSE-APACHE") }
}
if ($rel['stylua']) {
    $t = $rel['stylua'].tag_name
    $licSpecs += @{ Name='stylua-LICENSE.txt'; Urls=@("https://raw.githubusercontent.com/JohnnyMorganz/StyLua/$t/LICENSE.md", "https://raw.githubusercontent.com/JohnnyMorganz/StyLua/$t/LICENSE") }
}
if ($rel['shfmt']) {
    $t = $rel['shfmt'].tag_name
    $licSpecs += @{ Name='shfmt-LICENSE.txt'; Urls=@("https://raw.githubusercontent.com/mvdan/sh/$t/LICENSE") }
}
if ($rel['shellcheck']) {
    $t = $rel['shellcheck'].tag_name
    $licSpecs += @{ Name='shellcheck-LICENSE.txt'; Urls=@("https://raw.githubusercontent.com/koalaman/shellcheck/$t/LICENSE") }
}
if ($installed | Where-Object { $_.Tool -eq 'im-select' }) {
    $licSpecs += @{ Name='im-select-LICENSE.txt'; Urls=@('https://raw.githubusercontent.com/daipeihust/im-select/master/LICENSE') }
}

foreach ($l in $licSpecs) {
    $ok = Get-LicenseFile -Name $l.Name -Urls $l.Urls -OutDir $licDir
    $state = if ($ok) { '✓' } else { '✗ 未取到，需手工补' }
    Write-Host ("  {0,-30} {1}" -f $l.Name, $state) -ForegroundColor $(if ($ok) { 'Green' } else { 'Yellow' })
}

# ====================================================================
# 6. 清单
# ====================================================================
Write-Host "`n=== 5. 生成清单 ===" -ForegroundColor Cyan

# 记录 Neovim 基线版本，一并写进清单
$nvimLine = '(未检测到 PATH 上的 nvim)'
$nvimCmd = Get-Command nvim -ErrorAction SilentlyContinue
if ($nvimCmd) {
    $nvimLine = (& $nvimCmd.Source --version 2>&1 | Select-Object -First 1)
    if ($nvimLine) { $nvimLine = $nvimLine.Trim() } else { $nvimLine = '(读不出版本)' }
}

$rows = foreach ($r in $installed) {
    $short = $r.Sha256.Substring(0, 16)
    $size  = $r.Bytes.ToString('N0')
    "| ``$($r.File)`` | $($r.Tool) | $($r.Version) | $($r.Platform) | ``$short…`` | $size 字节 |"
}

$srcLines = foreach ($r in $installed) {
    "- ``$($r.File)`` —— $($r.Tool) $($r.Version)，产物 ``$($r.Asset)``"
}

# 每个工具「谁在用 / 缺了会怎样 / 什么许可」——随 bin/ 内容自动生成，别手工维护
$why = [ordered]@{
    ripgrep    = 'quickfix 正则搜索（需求 5）、fzf-lua 的 grep、grug-far'
    fzf        = 'fzf-lua（需求 4 指定的默认 picker）'
    fd         = 'fzf-lua 的找文件后端'
    stylua     = 'conform.nvim 格式化 Lua'
    shfmt      = 'conform.nvim 格式化 Shell'
    shellcheck = 'nvim-lint 检查 Shell'
    'im-select' = 'im-select.nvim：Windows 上离开插入模式时自动切回英文输入法'
}
$broken = [ordered]@{
    ripgrep    = '搜索功能整体失效'
    fzf        = '``<leader>sg`` 静默退回 quickfix，失去实时预览与鼠标跳转'
    fd         = '回退到较慢的路径遍历'
    stylua     = '保存时无法格式化 Lua'
    shfmt      = '保存时无法格式化 Shell'
    shellcheck = 'Shell 脚本没有静态检查'
    'im-select' = 'Windows 上输入法自动切换不可用（Linux 侧用系统的 fcitx5-remote / ibus，不受影响）'
}
$licenseInfo = [ordered]@{
    ripgrep    = 'MIT 或 Unlicense（双许可，二选一）'
    fzf        = 'MIT'
    fd         = 'MIT / Apache-2.0（双许可，二选一）'
    stylua     = 'MPL-2.0'
    shfmt      = 'BSD-3-Clause'
    shellcheck = '**GPL-3.0** ← copyleft，见下'
    'im-select' = 'MIT'
}
$whyRows = foreach ($k in $why.Keys) {
    if ($installed | Where-Object { $_.Tool -eq $k }) {
        "| ``$k`` | $($why[$k]) | $($broken[$k]) |"
    }
}
$licRows = foreach ($k in $licenseInfo.Keys) {
    if ($installed | Where-Object { $_.Tool -eq $k }) {
        "| $k | $($licenseInfo[$k]) |"
    }
}
$linuxFiles = ($installed | Where-Object { $_.Platform -eq 'linux-x64' } |
    ForEach-Object { "bin/$($_.File)" }) -join ' '

$manifest = @"
# bin/ —— 随包分发的外部工具

这个目录是架构里预留的外部工具注入点。启动脚本会把 ``<发行版>/bin`` **前置**进 ``PATH``，
因此这里的工具优先于系统 PATH 上的同名工具，但**不会覆盖或改动系统里的任何东西**。

Windows 与 Linux 两套二进制放在同一个目录，靠扩展名区分（``.exe`` 即 Windows）。

**Neovim 基线**：``$nvimLine``

| 文件 | 工具 | 版本 | 平台 | SHA256（前 16 位） | 大小 |
| --- | --- | --- | --- | --- | --- |
$($rows -join "`n")

同样的内容以机器可读形式放在 ``manifest.json``，供打包脚本与 ``:checkhealth`` 读取。

## 为什么必须随包

| 工具 | 谁在用 | 缺了会怎样 |
| --- | --- | --- |
$($whyRows -join "`n")

## 版本与来源

$($srcLines -join "`n")

原始压缩包留在 ``build/downloads/``（该目录不进版本库）。要复现时重跑
``pwsh -File tools/fetch-binaries.ps1`` 即可，脚本会现场核对官方 SHA256。

## 许可证

| 工具 | 许可证 |
| --- | --- |
$($licRows -join "`n")

分发二进制必须附带许可证全文，所以 ``licenses/`` 不能删。

**``shellcheck`` 是 GPL-3.0**，其余都是 MIT / Apache-2.0 / MPL-2.0 / BSD 这类宽松许可。
copyleft 的含义是：你分发包含它的包时，需要同时提供对应源码或书面承诺。做法很简单——
在包里放一份说明指向 ``https://github.com/koalaman/shellcheck`` 的对应 tag，
并把 ``licenses/shellcheck-LICENSE.txt`` 一起带上；同时别把 shellcheck 与你的 MIT 配置代码
说成「单一作品」。想完全避开 copyleft，就别打包它。

## 注意事项

- **Linux 上需要可执行位。** 从 Windows 复制出来的文件没有 ``+x``，Linux 端首次使用要
  ``chmod +x $linuxFiles``。
  若这个仓库用 git 分发，提交时给 Linux 二进制打上可执行位：
  ``git update-index --chmod=+x $linuxFiles``
- 代理会中途断流，所以脚本用「限时重试 + 断点续传」而不是 ``curl --retry``（``--retry`` 对「传输停滞」不生效）。
- 官方发布信息的 ``digest`` 字段若为空，脚本只校验大小并给出警告，不会假装校验通过。
- **``im-select.exe`` 的校验方式不同**：它没有 release 资源，是从仓库 ``win/out/x64/`` 直接取的
  裸文件，所以上游不给 SHA256。脚本改用 **git blob 哈希**（``890b3eb1…``，由 GitHub API 提供）
  校验，同样能锁到字节级内容；``manifest.json`` 里也记录了它的 SHA256 供日后核对。
  它只在 Windows 上有意义——Linux 侧 ``im-select.nvim`` 用系统的 ``fcitx5-remote`` / ``ibus``。
- **语言服务器按决定不打包**：``lua-language-server`` / ``clangd`` / ``basedpyright`` /
  ``bash-language-server`` 等都不随包分发，请自行安装。发行版通过 ``vim.fn.executable()``
  探测，缺失时只在 ``:checkhealth distro`` 里报告，不报错。

_本文件由 ``tools/fetch-binaries.ps1`` 自动生成，请勿手工编辑。_
"@

Write-Utf8Lf -Path (Join-Path $binDir 'README.md') -Text $manifest
Write-Host '  已写出 bin/README.md'

# 机器可读版本，供打包脚本与 :checkhealth 使用
$manifestJson = [ordered]@{
    generated_by     = 'tools/fetch-binaries.ps1'
    neovim_baseline  = $nvimLine
    tools            = @(
        foreach ($r in $installed) {
            [ordered]@{
                file     = $r.File
                tool     = $r.Tool
                version  = $r.Version
                platform = $r.Platform
                bytes    = $r.Bytes
                sha256   = $r.Sha256
                asset    = $r.Asset
                source   = $r.Url
            }
        }
    )
}
Write-Utf8Lf -Path (Join-Path $binDir 'manifest.json') -Text ($manifestJson | ConvertTo-Json -Depth 6)
Write-Host '  已写出 bin/manifest.json'

Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue

# ====================================================================
Write-Host "`n=== 完成 ===" -ForegroundColor Cyan
Get-ChildItem $binDir -Recurse -File | Sort-Object FullName | ForEach-Object {
    "  {0,-38} {1,12:N0} 字节" -f $_.FullName.Replace("$binDir\", ''), $_.Length
}
