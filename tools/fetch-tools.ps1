#!/usr/bin/env pwsh
<#
.SYNOPSIS
    取指定平台需要的随包工具，装进 bin/。

.DESCRIPTION
    为什么工具不放进版本库：
      6 个平台的二进制加起来上百 MB，提交进 git 会让仓库永久膨胀
      （git 历史不会因为后来的删除而变小）。改成 CI 构建时下载，
      仓库只留这份**声明**：哪个工具、哪个平台的哪个产物、装成什么名字。

    为什么每个包只装自己平台的那份：
      拆分平台之后，linux 包里放 rg.exe 毫无意义。只装本平台可省下约一半体积。

    Windows arm64 不出包（见 docs/DECIDED.md）。顺带记录一个真实缺口：
    即使要出，stylua / shfmt / shellcheck 上游也**根本没有** Windows arm64 产物。
    所以本脚本对「找不到产物」一律是**警告并记录**，不是失败 ——
    否则一个上游缺口就能让整个平台的包打不出来。

.PARAMETER Platform
    目标平台 id。

.PARAMETER OutDir
    输出目录，默认 <仓库根>/bin。

.PARAMETER Proxy
    可选下载代理前缀，例如 https://ghfast.top/ 。

.EXAMPLE
    pwsh tools/fetch-tools.ps1 -Platform windows-x64
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('linux-x64', 'linux-arm64', 'windows-x64', 'darwin-x64', 'darwin-arm64')]
    [string]$Platform,

    [string]$OutDir,
    [string]$Proxy = ''
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
if (-not $OutDir) { $OutDir = Join-Path $root 'bin' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# ---------------------------------------------------------------------------
# 产物名来自各仓库 releases/latest 的实测结果，不是推测。
#   Mode='file' 压缩包里取 Member；Mode='raw' 该产物本身就是可执行文件。
#   Member 只写文件名，脚本会递归查找，这样不必跟着版本号目录名改。
# ---------------------------------------------------------------------------
function Get-Specs {
    param([string]$P)

    $s = @()
    switch ($P) {
        'linux-x64' {
            $s += @{ Tool='ripgrep';    Repo='BurntSushi/ripgrep';      Pattern='*x86_64-unknown-linux-musl.tar.gz'; Mode='file'; Member='rg';           Out='rg' }
            $s += @{ Tool='fzf';        Repo='junegunn/fzf';            Pattern='*linux_amd64.tar.gz';               Mode='file'; Member='fzf';          Out='fzf' }
            $s += @{ Tool='fd';         Repo='sharkdp/fd';              Pattern='*x86_64-unknown-linux-musl.tar.gz'; Mode='file'; Member='fd';           Out='fd' }
            $s += @{ Tool='stylua';     Repo='JohnnyMorganz/StyLua';    Pattern='*linux-x86_64.zip';                 Mode='file'; Member='stylua';       Out='stylua' }
            $s += @{ Tool='shfmt';      Repo='mvdan/sh';                Pattern='*_linux_amd64';                     Mode='raw';  Member='';             Out='shfmt' }
            $s += @{ Tool='shellcheck'; Repo='koalaman/shellcheck';     Pattern='*.linux.x86_64.tar.xz';             Mode='file'; Member='shellcheck';   Out='shellcheck' }
        }
        'linux-arm64' {
            # 注意 ripgrep / fd 在 arm64 linux 上提供的是 gnu 而非 musl 构建
            $s += @{ Tool='ripgrep';    Repo='BurntSushi/ripgrep';      Pattern='*aarch64-unknown-linux-gnu.tar.gz'; Mode='file'; Member='rg';           Out='rg' }
            $s += @{ Tool='fzf';        Repo='junegunn/fzf';            Pattern='*linux_arm64.tar.gz';               Mode='file'; Member='fzf';          Out='fzf' }
            $s += @{ Tool='fd';         Repo='sharkdp/fd';              Pattern='*aarch64-unknown-linux-gnu.tar.gz'; Mode='file'; Member='fd';           Out='fd' }
            $s += @{ Tool='stylua';     Repo='JohnnyMorganz/StyLua';    Pattern='*linux-aarch64.zip';                Mode='file'; Member='stylua';       Out='stylua' }
            $s += @{ Tool='shfmt';      Repo='mvdan/sh';                Pattern='*_linux_arm64';                     Mode='raw';  Member='';             Out='shfmt' }
            $s += @{ Tool='shellcheck'; Repo='koalaman/shellcheck';     Pattern='*.linux.aarch64.tar.xz';            Mode='file'; Member='shellcheck';   Out='shellcheck' }
        }
        'windows-x64' {
            $s += @{ Tool='ripgrep';    Repo='BurntSushi/ripgrep';      Pattern='*x86_64-pc-windows-msvc.zip';       Mode='file'; Member='rg.exe';       Out='rg.exe' }
            $s += @{ Tool='fzf';        Repo='junegunn/fzf';            Pattern='*windows_amd64.zip';                Mode='file'; Member='fzf.exe';      Out='fzf.exe' }
            $s += @{ Tool='fd';         Repo='sharkdp/fd';              Pattern='*x86_64-pc-windows-msvc.zip';       Mode='file'; Member='fd.exe';       Out='fd.exe' }
            $s += @{ Tool='stylua';     Repo='JohnnyMorganz/StyLua';    Pattern='*windows-x86_64.zip';               Mode='file'; Member='stylua.exe';   Out='stylua.exe' }
            $s += @{ Tool='shfmt';      Repo='mvdan/sh';                Pattern='*_windows_amd64.exe';               Mode='raw';  Member='';             Out='shfmt.exe' }
            # shellcheck 的 Windows 产物名里没有平台关键词（就叫 shellcheck-vX.Y.Z.zip），
            # 所以这里只能用 *.zip 这种宽匹配 —— 它正是之前一直可用的那条规则。
            $s += @{ Tool='shellcheck'; Repo='koalaman/shellcheck';     Pattern='*.zip';                             Mode='file'; Member='shellcheck.exe'; Out='shellcheck.exe' }
        }
        'darwin-x64' {
            $s += @{ Tool='ripgrep';    Repo='BurntSushi/ripgrep';      Pattern='*x86_64-apple-darwin.tar.gz';       Mode='file'; Member='rg';           Out='rg' }
            $s += @{ Tool='fzf';        Repo='junegunn/fzf';            Pattern='*darwin_amd64.tar.gz';              Mode='file'; Member='fzf';          Out='fzf' }
            $s += @{ Tool='fd';         Repo='sharkdp/fd';              Pattern='*x86_64-apple-darwin.tar.gz';       Mode='file'; Member='fd';           Out='fd' }
            $s += @{ Tool='stylua';     Repo='JohnnyMorganz/StyLua';    Pattern='*macos-x86_64.zip';                 Mode='file'; Member='stylua';       Out='stylua' }
            $s += @{ Tool='shfmt';      Repo='mvdan/sh';                Pattern='*_darwin_amd64';                    Mode='raw';  Member='';             Out='shfmt' }
            $s += @{ Tool='shellcheck'; Repo='koalaman/shellcheck';     Pattern='*.darwin.x86_64.tar.xz';            Mode='file'; Member='shellcheck';   Out='shellcheck' }
        }
        'darwin-arm64' {
            $s += @{ Tool='ripgrep';    Repo='BurntSushi/ripgrep';      Pattern='*aarch64-apple-darwin.tar.gz';      Mode='file'; Member='rg';           Out='rg' }
            $s += @{ Tool='fzf';        Repo='junegunn/fzf';            Pattern='*darwin_arm64.tar.gz';              Mode='file'; Member='fzf';          Out='fzf' }
            $s += @{ Tool='fd';         Repo='sharkdp/fd';              Pattern='*aarch64-apple-darwin.tar.gz';      Mode='file'; Member='fd';           Out='fd' }
            $s += @{ Tool='stylua';     Repo='JohnnyMorganz/StyLua';    Pattern='*macos-aarch64.zip';                Mode='file'; Member='stylua';       Out='stylua' }
            $s += @{ Tool='shfmt';      Repo='mvdan/sh';                Pattern='*_darwin_arm64';                    Mode='raw';  Member='';             Out='shfmt' }
            $s += @{ Tool='shellcheck'; Repo='koalaman/shellcheck';     Pattern='*.darwin.aarch64.tar.xz';           Mode='file'; Member='shellcheck';   Out='shellcheck' }
        }
    }
    return $s
}

function Invoke-Curl {
    param([string[]]$CurlArgs)
    $exe = (Get-Command curl.exe -ErrorAction SilentlyContinue).Source
    if (-not $exe) { $exe = 'curl' }
    & $exe @CurlArgs
    return $LASTEXITCODE
}

$proxyArgs = @()
if ($Proxy) { $proxyArgs = @('--proxy', $Proxy) }

# ---------------------------------------------------------------------------
Write-Host ("=== 取工具：{0} ===" -f $Platform) -ForegroundColor Cyan
$dlDir = Join-Path $root 'build/tools-dl'
New-Item -ItemType Directory -Force -Path $dlDir | Out-Null

$installed = @()
$missing = @()
$relCache = @{}

foreach ($spec in Get-Specs -P $Platform) {
    Write-Host ("`n-- {0}" -f $spec.Tool) -ForegroundColor Cyan

    # 同一个仓库多个平台共用，每个仓库只查一次 API
    if (-not $relCache.ContainsKey($spec.Repo)) {
        $apiArgs = @('-sSL', '--max-time', '120') + $proxyArgs
        $raw = & curl.exe @apiArgs "https://api.github.com/repos/$($spec.Repo)/releases/latest" 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $raw) {
            $missing += [pscustomobject]@{ tool=$spec.Tool; reason='查询 releases 失败'; pattern=$spec.Pattern }
            Write-Host '   查询失败，跳过' -ForegroundColor Yellow
            continue
        }
        $relCache[$spec.Repo] = $raw | ConvertFrom-Json
    }
    $rel = $relCache[$spec.Repo]

    $asset = $rel.assets | Where-Object { $_.name -like $spec.Pattern } | Select-Object -First 1
    if (-not $asset) {
        # 这不是错误：上游可能某个平台就没有产物（例如 shellcheck 没有 Windows arm64）。
        # 如实记录，交给 :checkhealth distro 告诉用户「哪个能力因此不可用」。
        $missing += [pscustomobject]@{ tool=$spec.Tool; reason="没有匹配 '$($spec.Pattern)' 的产物"; pattern=$spec.Pattern }
        Write-Host ("   上游没有匹配 {0} 的产物，跳过" -f $spec.Pattern) -ForegroundColor Yellow
        continue
    }

    Write-Host ("   {0}  ({1:N2} MB)" -f $asset.name, ($asset.size / 1MB))

    $url = $asset.browser_download_url
    if ($Proxy) { $url = $Proxy + $url }
    $raw_file = Join-Path $dlDir $asset.name

    $ok = $false
    foreach ($attempt in 1..4) {
        # -C - 断点续传：这个网络环境会中途断流
        $code = Invoke-Curl (@('-L', '-sS', '-C', '-', '--retry', '3', '--retry-delay', '2',
            '--max-time', '900', '-o', $raw_file, $url) + $proxyArgs)
        if ($code -eq 0 -and (Test-Path $raw_file) -and (Get-Item $raw_file).Length -eq $asset.size) { $ok = $true; break }
        Write-Host ("   第 {0} 次未完成（退出码 {1}）" -f $attempt, $code) -ForegroundColor Yellow
        Start-Sleep -Seconds 3
    }
    if (-not $ok) {
        $missing += [pscustomobject]@{ tool=$spec.Tool; reason='下载失败'; pattern=$spec.Pattern }
        Write-Host '   下载失败，跳过' -ForegroundColor Yellow
        continue
    }

    if ($asset.digest -and $asset.digest -match '^sha256:(.+)$') {
        $want = $Matches[1].ToLower()
        $got = (Get-FileHash $raw_file -Algorithm SHA256).Hash.ToLower()
        if ($want -ne $got) { throw ("{0} 的 sha256 不符：期望 {1}，实际 {2}" -f $asset.name, $want, $got) }
        Write-Host '   ✓ sha256 与官方一致' -ForegroundColor Green
    }

    $dest = Join-Path $OutDir $spec.Out

    if ($spec.Mode -eq 'raw') {
        Copy-Item $raw_file $dest -Force
    } else {
        $stage = Join-Path $dlDir ('stage-' + $spec.Tool)
        if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
        New-Item -ItemType Directory -Force -Path $stage | Out-Null

        if ($asset.name -like '*.zip') {
            Expand-Archive -Path $raw_file -DestinationPath $stage -Force
        } else {
            # tar 能处理 .tar.gz 与 .tar.xz（Windows 10+ 自带的 bsdtar 也可以）
            & tar -xf $raw_file -C $stage
            if ($LASTEXITCODE -ne 0) { throw ("解压 {0} 失败" -f $asset.name) }
        }

        # 递归按文件名找，避免跟着上游的版本号目录名走
        $found = Get-ChildItem $stage -Recurse -File -Filter $spec.Member | Select-Object -First 1
        if (-not $found) {
            $listing = (Get-ChildItem $stage -Recurse -File | ForEach-Object { $_.Name }) -join ', '
            throw ("{0} 里找不到 {1}。包内文件：{2}" -f $asset.name, $spec.Member, $listing)
        }
        Copy-Item $found.FullName $dest -Force
        Remove-Item -Recurse -Force $stage
    }

    if ($Platform -notlike 'windows*') { & chmod +x $dest }
    $item = Get-Item $dest
    Write-Host ("   -> bin/{0}  {1:N0} 字节" -f $item.Name, $item.Length) -ForegroundColor Green

    $installed += [pscustomobject]@{
        tool     = $spec.Tool
        file     = $item.Name
        platform = $Platform
        version  = $rel.tag_name
        asset    = $asset.name
        url      = $asset.browser_download_url
        sha256   = (Get-FileHash $dest -Algorithm SHA256).Hash.ToUpper()
        bytes    = $item.Length
    }
}

# ---------------------------------------------------------------------------
# bin/manifest.json：让 :checkhealth distro 能列出「本该有却没有」的工具。
# 这比在配置里再抄一份工具清单可靠 —— 副本迟早会过期。
# ---------------------------------------------------------------------------
$manifest = [ordered]@{
    platform = $Platform
    fetched  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    tools    = @($installed)
    missing  = @($missing)
    note     = 'im-select.exe 不在本清单内：它的上游产物名不含平台信息，无法可靠匹配，' +
               '且仅 200 KB 且只在 Windows 需要，所以留在版本库里。'
}
$manifestPath = Join-Path $OutDir 'manifest.json'
($manifest | ConvertTo-Json -Depth 6) -replace "`r`n", "`n" |
    Set-Content -Path $manifestPath -Encoding utf8

Write-Host ''
Write-Host ('=== 完成：装入 {0} 个工具，缺失 {1} 个 ===' -f $installed.Count, $missing.Count) -ForegroundColor Cyan
if ($missing.Count -gt 0) {
    Write-Host '以下工具在本平台不可用（上游未提供产物），不影响打包，但对应功能会缺失：' -ForegroundColor Yellow
    foreach ($m in $missing) { Write-Host ('  - {0}：{1}' -f $m.tool, $m.reason) }
}
Write-Host ('  清单：{0}' -f $manifestPath)
