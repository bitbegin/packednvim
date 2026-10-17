#!/usr/bin/env pwsh
<#
.SYNOPSIS
    组装发行版目录并打包。

.DESCRIPTION
    每个平台自己组一个完整包，不再需要跨平台合并 —— 这是拆分平台后最大的简化：
    nvim、工具、解析器、blink 原生库、jieba cdylib 全都在同一个作业里产出，
    不再有「A 作业做的改动要传给 B 作业」这种容易丢东西的环节
    （上一版就是因此把 pack/ 里的二进制整个丢了）。

    归档格式按平台分：
      Windows -> .zip     用户预期就是这个
      其它    -> .tar.gz  **必须**用 tar，因为 zip 不保留可执行位。
                          这是踩过的坑：Linux 二进制丢了 +x，会表现成
                          「rg 找得到但用不了」，很难联想到是打包格式的问题。

.PARAMETER Platform
    平台 id，用于归档文件名。

.PARAMETER DistroDir
    组装输出目录，默认 <仓库根>/dist。

.EXAMPLE
    pwsh tools/package.ps1 -Platform win64
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Platform,
    [string]$DistroDir
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
if (-not $DistroDir) { $DistroDir = Join-Path $root 'dist' }

# 运行期需要的；catalog/ tools/ tests/ 是开发用的，不进包
# neovide.* 是 GUI 启动器与它的外观配置：没有它们，bin/neovide.exe 就是纯死重量
# （用户只能手动写长命令行，很容易漏掉 XDG 隔离）。
$INCLUDE = @('init.lua', 'nvim.cmd', 'nvim.sh', 'neovide.sh', 'lua', 'pack', 'bin', 'vendor', 'runtime', 'docs', 'README.md', 'install.cmd', 'uninstall.cmd', 'install.sh', 'install.ps1', 'uninstall.ps1')

$stage = Join-Path $DistroDir 'packednvim'
Write-Host ("=== 组装 {0} ===" -f $Platform) -ForegroundColor Cyan
Write-Host ("  目标（即将清空重建）: {0}" -f $stage)
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

foreach ($name in $INCLUDE) {
    $src = Join-Path $root $name
    if (-not (Test-Path $src)) {
        # runtime 与 bin 里的部分文件可能不存在（例如某平台工具上游没发布），
        # 那属于已知情况，由 manifest 与 :checkhealth 如实反映，不在这里失败。
        Write-Host ("  跳过（不存在）：{0}" -f $name) -ForegroundColor Yellow
        continue
    }
    $dst = Join-Path $stage $name
    if ((Get-Item $src).PSIsContainer) {
        # .git 目录绝不能进包（体积与信息泄露），nginx 之外一律排除
        Copy-Item $src $dst -Recurse -Force -Exclude '.git'
    } else {
        Copy-Item $src $dst -Force
    }
    Write-Host ("  已放入：{0}" -f $name)
}

# ---------------------------------------------------------------------------
# VERSION：让包自己说清它是什么、怎么来的
# ---------------------------------------------------------------------------
$packRoot = Join-Path $stage 'pack/distro'
$nPlugins = 0
if (Test-Path $packRoot) {
    $nPlugins = (Get-ChildItem $packRoot -Directory | ForEach-Object { Get-ChildItem $_.FullName -Directory }).Count
}

$runtimeInfo = $null
$bi = Join-Path $stage 'runtime/buildinfo.json'
if (Test-Path $bi) { $runtimeInfo = Get-Content $bi -Raw | ConvertFrom-Json }

$toolInfo = $null
$mi = Join-Path $stage 'bin/manifest.json'
if (Test-Path $mi) { $toolInfo = Get-Content $mi -Raw | ConvertFrom-Json }

$lines = @(
    ("platform: {0}" -f $Platform),
    ("plugins: {0}" -f $nPlugins)
)
if ($runtimeInfo) {
    $lines += ("neovim: {0}" -f $runtimeInfo.version)
    $lines += ("neovim-tag: {0}" -f $runtimeInfo.tag)
    $lines += ("neovim-commit: {0}" -f $runtimeInfo.commit)
} else {
    $lines += 'neovim: (未打包)'
}
if ($toolInfo) {
    $lines += ("tools: {0} 个" -f @($toolInfo.tools).Count)
    if (@($toolInfo.missing).Count -gt 0) {
        $lines += ("tools-missing: {0}" -f (($toolInfo.missing | ForEach-Object { $_.tool }) -join ', '))
    }
}
$lines += ("commit: {0}" -f $env:GITHUB_SHA)
$lines += ("built-by: GitHub Actions run {0}" -f $env:GITHUB_RUN_ID)
$lines += ""
# 用 LF 写：这是要在三个平台上读的文本文件
[System.IO.File]::WriteAllText((Join-Path $stage 'VERSION'), ($lines -join "`n"),
    (New-Object System.Text.UTF8Encoding($false)))
Write-Host "`n  VERSION:"
$lines | ForEach-Object { "    $_" }

# ---------------------------------------------------------------------------
# 归档
# ---------------------------------------------------------------------------
$isWindowsPkg = $Platform -like 'win*'
$archive = Join-Path $DistroDir ("packednvim-{0}.{1}" -f $Platform, $(if ($isWindowsPkg) { 'zip' } else { 'tar.gz' }))
if (Test-Path $archive) { Remove-Item $archive -Force }

Write-Host ("`n=== 归档 {0} ===" -f (Split-Path $archive -Leaf)) -ForegroundColor Cyan
Push-Location $DistroDir
try {
    if ($isWindowsPkg) {
        Compress-Archive -Path 'packednvim' -DestinationPath $archive -CompressionLevel Optimal -Force
    } else {
        # tar 保留可执行位与符号链接 —— zip 两样都丢，所以 unix 必须用 tar
        & tar -czf $archive packednvim
        if ($LASTEXITCODE -ne 0) { throw 'tar 打包失败' }
    }
} finally { Pop-Location }

$size = (Get-Item $archive).Length
$sum = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLower()
[System.IO.File]::WriteAllText("$archive.sha256", ("{0}  {1}`n" -f $sum, (Split-Path $archive -Leaf)),
    (New-Object System.Text.UTF8Encoding($false)))

Write-Host ("  归档 {0}  ({1:N1} MB)" -f (Split-Path $archive -Leaf), ($size / 1MB)) -ForegroundColor Green
Write-Host ("  sha256 {0}" -f $sum)
