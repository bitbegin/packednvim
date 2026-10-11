#!/usr/bin/env pwsh
<#
.SYNOPSIS
    取 Neovim 官方构建，放进 runtime/，作为发行版的运行时。

.DESCRIPTION
    为什么要打包 Neovim 本体（这是本发行版的一个关键决定）：

    1. **ABI 不可能失配**。tree-sitter 解析器是与 Neovim 内嵌的 tree-sitter 运行时
       强耦合的。如果解析器由「某一个」Neovim 编译、却由「另一个」Neovim 加载，
       哪天上游抬高了最低兼容 ABI，用户就会突然失去语法高亮。
       现在让**包里这个 nvim 亲自编译解析器**，再由它自己加载 —— 这条风险链被彻底切断。

    2. **用户不必先装 Neovim**，也不用担心自己那份是 0.11 还是 0.13。
       解压即用，版本行为完全可预期。

    3. 代价是包变大（各平台约 +10~22 MB 压缩前），但换来的是确定性。

    关于 nightly：官方只保留最新一份 nightly，**无法按版本回溯下载**，
    所以这个脚本取到的永远是「构建当时的最新版」。但由于我们把它**打进包里**，
    发布出去的产物本身是固定的；buildinfo 里会记下它的 commit 与版本，
    事后完全可追溯。想要严格可复现，用 -Tag 指定一个稳定标签（如 v0.12.6）。

.PARAMETER Platform
    目标平台。与工作流矩阵里的 id 一致。

.PARAMETER Tag
    Neovim 发布标签，默认 nightly。

.PARAMETER OutDir
    输出目录，默认 <仓库根>/runtime。脚本会保证 <OutDir>/bin/nvim[.exe] 存在。

.PARAMETER Proxy
    可选：下载代理前缀，例如 https://ghfast.top/ 。本地网络慢时用。

.EXAMPLE
    pwsh tools/fetch-runtime.ps1 -Platform win64
    pwsh tools/fetch-runtime.ps1 -Platform linux-arm64 -Tag v0.12.6
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('linux64', 'linux-arm64', 'win64', 'win-arm64', 'darwin-x64', 'darwin-arm64')]
    [string]$Platform,

    [string]$Tag = 'nightly',
    [string]$OutDir,
    [string]$Proxy = ''
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
if (-not $OutDir) { $OutDir = Join-Path $root 'runtime' }

# 平台 -> 官方产物名。名字必须精确，错了就是 404。
$ASSETS = @{
    'linux64'      = 'nvim-linux-x86_64.tar.gz'
    'linux-arm64'  = 'nvim-linux-arm64.tar.gz'
    'win64'        = 'nvim-win64.zip'
    'win-arm64'    = 'nvim-win-arm64.zip'
    'darwin-x64'   = 'nvim-macos-x86_64.tar.gz'
    'darwin-arm64' = 'nvim-macos-arm64.tar.gz'
}
$assetName = $ASSETS[$Platform]
if (-not $assetName) { throw "未知平台：$Platform" }

# curl 的可执行名在各平台不同：Windows 上是 curl.exe，Linux/macOS 上是 curl。
# **不能在脚本里直接写 `& curl.exe`** —— 那会在 Linux runner 上以
# 「找不到 curl.exe」失败。第一次跑 arm64 构建时撞到的就是这个。
$Curl = (Get-Command curl.exe -ErrorAction SilentlyContinue).Source
if (-not $Curl) { $Curl = (Get-Command curl -ErrorAction SilentlyContinue).Source }
if (-not $Curl) { throw '找不到 curl —— 取运行时与工具都依赖它' }

# 认证头：CI 里未认证的 GitHub API 每个 IP 每小时只有 60 次，而本工作流有 5 个平台，
# 每个平台都要查 Neovim 与 6 个工具仓库 —— 很容易撞上限流。带上 token 后额度是 5000。
#
# 限流的表现非常隐蔽：返回 {"message":"API rate limit exceeded..."}，**没有 assets 字段**，
# 于是错误信息会变成「找不到资产：现有产物：（空）」—— 空列表让人完全想不到是限流。
$apiHeaders = @()
$token = if ($env:GITHUB_TOKEN) { $env:GITHUB_TOKEN } elseif ($env:GH_TOKEN) { $env:GH_TOKEN } else { $null }
if ($token) { $apiHeaders = @('-H', "Authorization: Bearer $token") }

# 查 API 不加代理：GitHub 托管的 runner 直连很快，代理是给本地慢网络用的。
$apiArgs = @('-sS', '--max-time', '120')

Write-Host "=== 1. 查询 Neovim 发布信息（$Tag）===" -ForegroundColor Cyan
Write-Host ("  curl : {0}" -f $Curl)
Write-Host ("  token: {0}" -f $(if ($token) { '已带上' } else { '未带（可能被限流）' }))

$raw = & $Curl @apiArgs @apiHeaders -sSL "https://api.github.com/repos/neovim/neovim/releases/tags/$Tag" 2>$null
# curl 的输出被 PowerShell 捕获成**按行拆分的字符串数组**，
# 直接管道给 ConvertFrom-Json 会逐行解析，结果是不可预期的。先拼回一个字符串。
$json = ($raw -join "`n")
if (-not $json) { throw "取不到 Neovim $Tag 的发布信息（网络问题？）" }
$release = $json | ConvertFrom-Json

# 明确区分「API 报错」与「真的没有这个产物」，否则又会出现空列表那种难查的现象
if (-not $release.assets) {
    $why = if ($release.message) { $release.message } else { '响应里没有 assets 字段' }
    throw "查询 Neovim $Tag 失败：$why"
}

$asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
if (-not $asset) {
    $names = ($release.assets | ForEach-Object { $_.name }) -join ', '
    throw "在 $Tag 里找不到 $assetName。现有产物：$names"
}

# 官方给的 sha256（新式 API 才有 digest 字段）
$wantSum = $null
if ($asset.digest -and $asset.digest -match '^sha256:(.+)$') { $wantSum = $Matches[1].ToLower() }

Write-Host ("  产物   : {0}  ({1:N1} MB)" -f $asset.name, ($asset.size / 1MB))
Write-Host ("  commit : {0}" -f $release.target_commitish)
Write-Host ("  sha256 : {0}" -f ($(if ($wantSum) { $wantSum } else { '(官方未提供，跳过校验)' })))

# 官方 release notes 的首行就是 `nvim --version` 的第一行，留着写进 VERSION
$verLine = ($release.body -split "`n" | Where-Object { $_ -match 'NVIM v' } | Select-Object -First 1)
$verLine = if ($verLine) { $verLine.Trim() } else { "(unknown)" }

# ---------------------------------------------------------------------------
Write-Host "`n=== 2. 下载 ===" -ForegroundColor Cyan
$dlDir = Join-Path $root 'build/runtime-dl'
New-Item -ItemType Directory -Force -Path $dlDir | Out-Null
$archive = Join-Path $dlDir $asset.name

$url = $asset.browser_download_url
# -Proxy 是**URL 前缀式**代理（如 https://ghfast.top/ ），不是 HTTP CONNECT 代理，
# 所以是给 URL 加前缀，而不是传 curl 的 --proxy。两者混用会套两层。
if ($Proxy) { $url = $Proxy + $url }

$ok = $false
foreach ($attempt in 1..5) {
    Write-Host ("  第 {0} 次尝试" -f $attempt)
    # -C - 断点续传：网络环境经常中途断流，直连速度也可能骤降
    & $Curl @('-L', '-sS', '-C', '-', '--retry', '3', '--retry-delay', '2',
        '--speed-limit', '2048', '--speed-time', '60', '--max-time', '1800',
        '-o', $archive, $url)
    $code = $LASTEXITCODE
    if ($code -eq 0 -and (Test-Path $archive) -and (Get-Item $archive).Length -eq $asset.size) { $ok = $true; break }
    Write-Host ("    未完成（退出码 {0}），重试" -f $code) -ForegroundColor Yellow
    Start-Sleep -Seconds 4
}
if (-not $ok) { throw "下载 $assetName 失败；如果反复断流，试试 -Proxy https://ghfast.top/" }
Write-Host ("  已下载 {0:N1} MB" -f ((Get-Item $archive).Length / 1MB))

if ($wantSum) {
    $gotSum = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLower()
    if ($gotSum -ne $wantSum) { throw "sha256 不符：期望 $wantSum，实际 $gotSum" }
    Write-Host "  ✓ sha256 与官方一致" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
Write-Host "`n=== 3. 解压并归一化到 runtime/ ===" -ForegroundColor Cyan
Write-Host "  目标（即将清空重建）: $OutDir"
if (Test-Path $OutDir) { Remove-Item -Recurse -Force $OutDir }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$stage = Join-Path $dlDir 'stage'
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

if ($asset.name -like '*.zip') {
    Expand-Archive -Path $archive -DestinationPath $stage -Force
} else {
    # tar 在 Windows 10+ 自带，Linux/macOS 更不必说
    & tar -xzf $archive -C $stage
    if ($LASTEXITCODE -ne 0) { throw "解压 $($asset.name) 失败" }
}

# 官方压缩包里有一层顶层目录（nvim-linux-x86_64 / nvim-win64 / nvim-macos-arm64 …），
# 剥掉它，让 runtime/bin/nvim 成为稳定入口。这样启动脚本不必知道各平台的目录名。
$top = Get-ChildItem $stage -Directory | Select-Object -First 1
if (-not $top) { throw '解压后没有顶层目录，产物结构变了？' }
Write-Host ("  剥掉顶层目录: {0}" -f $top.Name)
Get-ChildItem $top.FullName -Force | Move-Item -Destination $OutDir -Force

# nvim.pdb 是 17 MB 的调试符号，运行完全用不到
foreach ($pdb in Get-ChildItem $OutDir -Recurse -Filter '*.pdb' -ErrorAction SilentlyContinue) {
    Write-Host ("  删除调试符号 {0}（{1:N1} MB）" -f $pdb.Name, ($pdb.Length / 1MB))
    Remove-Item $pdb.FullName -Force
}

$exe = if ($Platform -like 'win*') { 'bin/nvim.exe' } else { 'bin/nvim' }
$exePath = Join-Path $OutDir $exe
if (-not (Test-Path $exePath)) { throw "归一化后找不到 $exe —— 产物结构可能变了" }
if ($Platform -notlike 'win*') { & chmod +x $exePath }
Write-Host ("  ✓ {0}" -f $exePath) -ForegroundColor Green

# ---------------------------------------------------------------------------
# 记录它到底是什么，让包可追溯
$buildInfo = [ordered]@{
    platform = $Platform
    tag      = $Tag
    asset    = $asset.name
    commit   = $release.target_commitish
    version  = $verLine
    sha256   = $wantSum
    fetched  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}
$buildInfo | ConvertTo-Json -Depth 4 |
    ForEach-Object { $_ -replace "`r`n", "`n" } |
    Set-Content -Path (Join-Path $OutDir 'buildinfo.json') -Encoding utf8 -NoNewline

Write-Host "`n=== 完成 ===" -ForegroundColor Cyan
Write-Host ("  runtime: {0}" -f $OutDir)
Write-Host ("  版本   : {0}" -f $verLine)
