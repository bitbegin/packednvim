#!/usr/bin/env pwsh
<#
.SYNOPSIS
    把仓库里的配置同步到某个「已解压的包目录」。

.DESCRIPTION
    为什么需要这个脚本：

    改配置发生在**仓库**里（D:\lang\nvim 的 lua/、init.lua、启动脚本），
    而实际运行的是**解压出来的包目录**。两者是分开的，于是很容易出现
    「我改了、你跑的还是旧的」—— 本项目已经因此浪费过好几轮排查，
    而且更糟：我口头说「已同步」却没说清是哪个目录，等于没说。

    这个脚本把「同步」变成一个明确、可复验的动作：
      - 目标目录必须是真包（有 init.lua 与 pack/distro），避免误拷到别处
      - nvim.cmd 自动转成 CRLF（cmd.exe 对 LF 结尾的多行 if(...) 块解析不可靠）
      - -Check 只比对不写入，用来回答「我这个副本是最新的吗」

    注意：这**不会**更新包里的 pack/（插件）与 vendor/（解析器）——
    那些是构建产物，由 CI 产出；本脚本只同步配置与启动脚本。

.PARAMETER PackageDir
    解压出来的包目录（里面应有 init.lua、pack/distro）。

.PARAMETER Check
    只比对，不写入。会列出每个文件的同步状态。

.EXAMPLE
    pwsh tools/sync-to-package.ps1 -PackageDir D:\lang\nvim\build\pkg\unpacked\packednvim
    pwsh tools/sync-to-package.ps1 -PackageDir D:\packednvim -Check
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PackageDir,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$dst = (Resolve-Path -LiteralPath $PackageDir).Path

# 先确认目标是个包，而不是随便一个目录 —— 拷错地方比没拷更难查
if (-not (Test-Path (Join-Path $dst 'init.lua'))) {
    throw "$dst 里没有 init.lua，看起来不是解压出来的包目录"
}
if (-not (Test-Path (Join-Path $dst 'pack/distro'))) {
    throw "$dst 里没有 pack/distro，看起来不是解压出来的包目录"
}

# 同步清单：配置本体 + 启动脚本。tools/ 不进包；docs/ 在 package.ps1 的 INCLUDE
# 里（随包分发），但它是文档、不参与运行逻辑，故不在本脚本同步范围内。
$items = @('init.lua', 'nvim.cmd', 'nvim.sh', 'neovide.cmd', 'neovide.sh', 'neovide.vbs', 'neovide.toml', 'lua')

# 批处理必须 CRLF（cmd.exe 对 LF 结尾的多行 if(...) 块解析不可靠），
# 所以这两类文件不能直接比哈希 / 直接拷贝。
$crlfFiles = @('nvim.cmd', 'neovide.cmd', 'neovide.vbs')

# 逐文件比对。nvim.cmd 特殊处理，见下。
function Compare-One([string]$rel) {
    $src = Join-Path $root $rel
    $tgt = Join-Path $dst $rel
    if (-not (Test-Path $tgt)) { return '缺失' }

    $srcItem = Get-Item $src
    if ($srcItem.PSIsContainer) {
        # 目录：递归比对文件集合与内容
        $srcFiles = Get-ChildItem $src -Recurse -File | ForEach-Object { $_.FullName.Substring($src.Length + 1) }
        $tgtFiles = Get-ChildItem $tgt -Recurse -File | ForEach-Object { $_.FullName.Substring($tgt.Length + 1) }
        if (($srcFiles | Sort-Object) -join '|' -ne (($tgtFiles | Sort-Object) -join '|')) { return '文件集不同' }
        foreach ($f in $srcFiles) {
            if ((Get-FileHash (Join-Path $src $f)).Hash -ne (Get-FileHash (Join-Path $tgt $f)).Hash) { return '内容过期' }
        }
        return '同步'
    }

    # 批处理在包里必须是 CRLF，所以不能直接比哈希 —— 统一成 LF 再比
    if ($crlfFiles -contains $rel) {
        $a = ([System.IO.File]::ReadAllText($src)) -replace "`r`n", "`n"
        $b = ([System.IO.File]::ReadAllText($tgt)) -replace "`r`n", "`n"
        return $(if ($a -eq $b) { '同步' } else { '内容过期' })
    }

    return $(if ((Get-FileHash $src).Hash -eq (Get-FileHash $tgt).Hash) { '同步' } else { '内容过期' })
}

Write-Host ("=== 仓库 : {0}" -f $root)
Write-Host ("=== 目标 : {0}" -f $dst)
Write-Host ''

$drift = @()
foreach ($rel in $items) {
    if (-not (Test-Path (Join-Path $root $rel))) { continue }
    $state = Compare-One $rel
    $mark = if ($state -eq '同步') { '✓' } else { '✗' }
    Write-Host ("  {0} {1,-14} {2}" -f $mark, $rel, $state)
    if ($state -ne '同步') { $drift += $rel }
}

if ($Check) {
    Write-Host ''
    if ($drift.Count -eq 0) {
        Write-Host '这个副本与仓库一致。' -ForegroundColor Green
        exit 0
    }
    Write-Host ('以下项与仓库不一致：{0}' -f ($drift -join ', ')) -ForegroundColor Yellow
    Write-Host '跑一次不带 -Check 的命令即可同步。'
    exit 1
}

if ($drift.Count -eq 0) {
    Write-Host ''
    Write-Host '已经是最新，无需同步。' -ForegroundColor Green
    exit 0
}

Write-Host ''
Write-Host ('=== 同步 {0} 项 ===' -f $drift.Count)
foreach ($rel in $drift) {
    $src = Join-Path $root $rel
    $tgt = Join-Path $dst $rel
    if ((Get-Item $src).PSIsContainer) {
        # **必须拷贝目录内容（\*）而不是目录本身。**
        # Copy-Item <源目录> <已存在的目标目录> -Recurse 的语义是
        # 「把源目录整个塞进目标里」，于是生成 lua\lua\... 这样的嵌套，
        # 而原来的文件一个都没被更新 —— 这个坑真实发生过：
        # 同步脚本报告「已同步 lua」，但包里的 mini.lua 仍是旧版本，
        # 于是「我修了、你跑的还是旧的」又出现了一轮。
        Copy-Item (Join-Path $src '*') $tgt -Recurse -Force
    } elseif ($crlfFiles -contains $rel) {
        # 必须 CRLF，否则 cmd.exe 解析多行 if(...) 块会出问题
        $t = [System.IO.File]::ReadAllText($src) -replace "`r`n", "`n" -replace "`n", "`r`n"
        [System.IO.File]::WriteAllText($tgt, $t, (New-Object System.Text.UTF8Encoding($false)))
    } else {
        Copy-Item $src $tgt -Force
    }
    Write-Host ("  已同步 {0}" -f $rel)
}

Write-Host ''
Write-Host '完成。' -ForegroundColor Green
Write-Host '提示：这只同步配置与启动脚本；pack/（插件）与 vendor/（解析器）是构建产物，由 CI 产出。'
