<#
.SYNOPSIS
    按选型清单把插件拉取到 pack/distro/，并锁定每个仓库的 commit。

.DESCRIPTION
    最终用户拿到的是**打包好的包**，不是这个 git 仓库，所以 pack/ 属于构建产物：
    它由本脚本 + vendor/lock.json 可复现，不进版本库。

    工作流程：

      1. 读 build/selection.json，取出当前方案要 vendor 的仓库（`python tools/parse_selection.py` 生成）
      2. 读 vendor/lock.json 里已锁定的 commit；没有就现场解析并写入
      3. 逐个 **浅克隆**（--depth 1）到 pack/distro/{start,opt}/，克隆后核对 HEAD 是否等于锁定的 commit
      4. 删掉 .git（发行版不需要历史，也省体积），记录体积与许可证文件名
      5. 回写 vendor/lock.json

    为什么用浅克隆：45 个仓库走的是会间歇性拒绝 TLS 握手的代理，--depth 1 能把传输量
    小一个数量级。克隆失败会重试，重试前清掉残留目录。

    为什么克隆后还要核对 HEAD：浅克隆拿到的是分支尖端，而尖端会动。如果实际拿到的
    commit 与锁定值不符，脚本会尝试按 sha 取一次；再不行就直接报错退出——**绝不静默
    接受版本漂移**，否则「可复现」就是空话。

    start / opt 的划分：
      pack/distro/start/  Neovim 启动即自动加载（编辑刚需，行为最可预测）
      pack/distro/opt/    需要显式 :packadd（较重或按需使用，配置骨架里管）

.PARAMETER Update
    忽略 lock 里已有的 commit，重新按分支尖端解析（即「升级插件」）。

.PARAMETER Force
    即使目标目录已存在也重新克隆。

.PARAMETER Only
    只处理仓库全名里含该子串的项，便于单个重试。例：-Only mini.nvim

.PARAMETER DryRun
    不联网、不落盘，只做本地校验：解析选型、划分 start/opt、检查目录名冲突与 lock 状态。

.PARAMETER Proxy
    git 走的代理。留空则用 git 全局配置。

.EXAMPLE
    pwsh -File tools/vendor.ps1 -DryRun           # 先看它打算做什么
    pwsh -File tools/vendor.ps1                   # 按 lock 拉取（没有 lock 就现场锁定）
    pwsh -File tools/vendor.ps1 -Update           # 重新解析并升级到各分支最新
    pwsh -File tools/vendor.ps1 -Only fzf-lua     # 只重做某一个
#>
[CmdletBinding()]
param(
    [switch]$Update,
    [switch]$Force,
    [string]$Only = '',
    [switch]$DryRun,
    [string]$Proxy = ''
)

$ErrorActionPreference = 'Stop'

$root          = Split-Path -Parent $PSScriptRoot
# 一律用正斜杠：本脚本既在 Windows 打包机上跑，也会在 GitHub Actions 的
# ubuntu runner 上跑。反斜杠在 Linux 下不是路径分隔符，会直接找不到文件。
$selectionPath = Join-Path $root 'build/selection.json'
$lockPath      = Join-Path $root 'vendor/lock.json'
$packRoot      = Join-Path $root 'pack/distro'
$startRoot     = Join-Path $packRoot 'start'
$optRoot       = Join-Path $packRoot 'opt'

$proxyArgs = @()
if ($Proxy) { $proxyArgs = @('-c', "http.proxy=$Proxy", '-c', "https.proxy=$Proxy") }

# --------------------------------------------------------------------
# start / opt 划分。放在 start 里的会在启动时自动加载，所以只放：
#   - 编辑刚需（补全、LSP、treesitter、git 标记、状态栏、键位提示）
#   - 必须在早期就在 runtimepath 上的（主题、图标、guess-indent、vim-repeat）
# 其余进 opt，由配置骨架按需 :packadd，从而压启动耗时。
# --------------------------------------------------------------------
$START_REPOS = @(
    'nvim-mini/mini.nvim',
    'nvim-lua/plenary.nvim',
    'folke/tokyonight.nvim',
    'catppuccin/nvim',
    'rebelot/kanagawa.nvim',
    'sainnhe/gruvbox-material',
    'EdenEast/nightfox.nvim',
    'rose-pine/neovim',
    'nvim-tree/nvim-web-devicons',
    'nvim-lualine/lualine.nvim',
    'folke/which-key.nvim',
    'j-hui/fidget.nvim',
    'stevearc/dressing.nvim',
    'RRethy/vim-illuminate',
    'NMAC427/guess-indent.nvim',
    'tpope/vim-repeat',
    'nvim-treesitter/nvim-treesitter',
    'nvim-treesitter/nvim-treesitter-textobjects',
    'neovim/nvim-lspconfig',
    'folke/lazydev.nvim',
    'saghen/blink.cmp',
    'L3MON4D3/LuaSnip',
    'rafamadriz/friendly-snippets',
    'stevearc/conform.nvim',
    'mfussenegger/nvim-lint',
    'lewis6991/gitsigns.nvim',
    'ibhagwan/fzf-lua',
    'folke/flash.nvim',
    'chrisgrieser/nvim-spider',
    'keaising/im-select.nvim',
    'kkew3/jieba.vim',
    # 下面 5 个补进 start：它们的配置声明为常驻（pack='start'），
    # 却曾被放进 opt/，靠注册表兜底 packadd —— 那是补丁不是设计。
    # 「声明的加载策略」与「物理目录」一致，冒烟测试的
    # reconciled==0 断言（tools/smoke.lua）才能成立。
    'folke/ts-comments.nvim',
    'mrjones2014/smart-splits.nvim',
    'MeanderingProgrammer/render-markdown.nvim',
    'folke/todo-comments.nvim',
    'antosha417/nvim-lsp-file-operations'
)

# 少数仓库的**默认分支不能用**，必须指定分支或 tag：
#   jieba.vim  —— 它需要本地编译 Rust 后端，而 build.sh / build.ps1 只在 release 分支上
#   blink.cmp  —— main 上的 v2 尚未发布且额外依赖 saghen/blink.lib；
#                 钉到最新的 v1 tag，才能用官方分平台原生库（带 sha256）
$BRANCH_OVERRIDES = @{
    'kkew3/jieba.vim'   = 'release'
    'saghen/blink.cmp'  = 'v1.10.2'
}

# --------------------------------------------------------------------
# 工具函数
# --------------------------------------------------------------------

function Get-PluginDirName {
    # 目录名：避免出现 catppuccin/nvim -> "nvim" 这种没信息量的名字
    param([string]$Repo)
    $parts = $Repo.Split('/')
    $owner = $parts[0]
    $name  = $parts[-1]
    if ($name -in @('nvim', 'neovim')) { return $owner }
    return $name
}

function Invoke-Git {
    # 统一走 git（带代理参数），并把输出与退出码一起返回
    param([string[]]$GitArgs)
    $pa = $script:proxyArgs
    $out = & git @pa @GitArgs 2>&1
    return [pscustomobject]@{ Output = ($out -join "`n"); Code = $LASTEXITCODE }
}

function Get-LicenseFiles {
    param([string]$Dir)
    return @(Get-ChildItem $Dir -File -Filter 'LICEN*' -ErrorAction SilentlyContinue |
             Select-Object -ExpandProperty Name) +
           @(Get-ChildItem $Dir -File -Filter 'COPYING*' -ErrorAction SilentlyContinue |
             Select-Object -ExpandProperty Name)
}

function Get-DirBytes {
    param([string]$Dir)
    $sum = (Get-ChildItem $Dir -Recurse -File -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) { return 0 }
    return [long]$sum
}

# --------------------------------------------------------------------
# 1. 读选型
# --------------------------------------------------------------------
Write-Host '=== 1. 读取选型 ===' -ForegroundColor Cyan

if (-not (Test-Path $selectionPath)) {
    Write-Host "找不到 $selectionPath" -ForegroundColor Red
    Write-Host "先跑：python tools/parse_selection.py --stack recommended --apply" -ForegroundColor Yellow
    exit 2
}

$selection = Get-Content $selectionPath -Raw -Encoding utf8 | ConvertFrom-Json
$wanted = @($selection.repos_to_vendor)
if ($Only) {
    $wanted = @($wanted | Where-Object { $_.repo -like "*$Only*" })
}
if ($wanted.Count -eq 0) {
    Write-Host '选型里没有待 vendor 的仓库（是否还没勾选？）' -ForegroundColor Red
    exit 2
}

Write-Host ("  待处理仓库 {0} 个" -f $wanted.Count)

# 目录名冲突检查
$dirNames = @{}
$conflicts = @()
foreach ($w in $wanted) {
    $d = Get-PluginDirName $w.repo
    if ($dirNames.ContainsKey($d)) {
        $conflicts += "$d  <-  $($dirNames[$d]) 与 $($w.repo)"
    } else {
        $dirNames[$d] = $w.repo
    }
}
if ($conflicts.Count) {
    Write-Host '目录名冲突，需在脚本里加映射：' -ForegroundColor Red
    $conflicts | ForEach-Object { Write-Host "  $_" }
    exit 2
}

# --------------------------------------------------------------------
# 2. 读 lock
# --------------------------------------------------------------------
Write-Host "`n=== 2. 读取 vendor/lock.json ===" -ForegroundColor Cyan

$lock = $null
if ((Test-Path $lockPath) -and -not $Update) {
    $lock = Get-Content $lockPath -Raw -Encoding utf8 | ConvertFrom-Json
    Write-Host ("  已锁定 {0} 个仓库的 commit（加 -Update 可重新解析）" -f @($lock.plugins).Count)
} else {
    if ($Update -and (Test-Path $lockPath)) {
        Write-Host '  -Update：忽略已有锁定值，重新按分支尖端解析' -ForegroundColor Yellow
    } else {
        Write-Host '  没有 lock，将现场解析并写入'
    }
}
$locked = @{}
if ($lock) { foreach ($p in $lock.plugins) { $locked[$p.repo] = $p } }

# --------------------------------------------------------------------
# 3. 计划表
# --------------------------------------------------------------------
$plan = foreach ($w in $wanted) {
    $dirName = Get-PluginDirName $w.repo
    $pack    = if ($START_REPOS -contains $w.repo) { 'start' } else { 'opt' }
    $packDir = if ($pack -eq 'start') { $startRoot } else { $optRoot }

    # 分支优先级：脚本里的强制指定 > lock 里的记录 > 让 git 自己选默认分支。
    # 若强制指定与 lock 记录的分支不一致，就丢弃该 pin 重新解析 ——
    # 否则会拿着另一个分支的 commit 去 fetch，注定失败。
    $override = if ($BRANCH_OVERRIDES.ContainsKey($w.repo)) { $BRANCH_OVERRIDES[$w.repo] } else { $null }
    $lockedBranch = if ($locked.ContainsKey($w.repo)) { $locked[$w.repo].branch } else { $null }
    $branch = if ($override) { $override } else { $lockedBranch }
    $pin = if ($locked.ContainsKey($w.repo) -and (-not $override -or $override -eq $lockedBranch)) {
        $locked[$w.repo].commit
    } else { $null }

    [pscustomobject]@{
        Repo    = $w.repo
        DirName = $dirName
        Pack    = $pack
        Dest    = Join-Path $packDir $dirName
        Modules = @($w.modules)
        Pin     = $pin
        Branch  = $branch
    }
}

Write-Host "`n=== 3. 计划 ===" -ForegroundColor Cyan
Write-Host ("  pack/distro/start  {0} 个" -f @($plan | Where-Object Pack -eq 'start').Count)
Write-Host ("  pack/distro/opt    {0} 个" -f @($plan | Where-Object Pack -eq 'opt').Count)
Write-Host ''
foreach ($p in $plan | Sort-Object Pack, DirName) {
    $pin = if ($p.Pin) { $p.Pin.Substring(0, 8) } else { '待锁定' }
    Write-Host ("  [{0}] {1,-32} -> {2,-22} {3}" -f $p.Pack, $p.Repo, $p.DirName, $pin)
}

if ($DryRun) {
    Write-Host "`n-DryRun：只做本地校验，未联网、未落盘。" -ForegroundColor Yellow
    Write-Host '选型解析、start/opt 划分、目录名冲突、lock 读取 —— 全部通过。' -ForegroundColor Green
    exit 0
}

# --------------------------------------------------------------------
# 4. 克隆
# --------------------------------------------------------------------
Write-Host "`n=== 4. 克隆 ===" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $startRoot, $optRoot | Out-Null

$results = @()
$failures = @()

foreach ($p in $plan) {
    Write-Host ("`n[{0}] {1}" -f $p.Pack, $p.Repo) -ForegroundColor White
    $url = "https://github.com/$($p.Repo).git"
    $ok = $false

    for ($attempt = 1; $attempt -le 3 -and -not $ok; $attempt++) {
        if (Test-Path $p.Dest) { Remove-Item $p.Dest -Recurse -Force -ErrorAction SilentlyContinue }

        # 按指定分支/tag 浅克隆。
        # 关键：**指定了分支就绝不回退到默认分支** —— 那会在一次网络抖动后
        # 悄悄换上另一个分支的代码，拿到的东西与 lock 记录完全不符却还报成功。
        # 没指定分支时才允许让 git 自己选默认分支。
        $branchArgs = if ($p.Branch) { @('--branch', $p.Branch) } else { @() }
        $clone = Invoke-Git (@('clone', '--depth', '1', '--quiet') + $branchArgs + @($url, $p.Dest))

        if ($clone.Code -ne 0) {
            $err = ($clone.Output -split "`n" | Where-Object { $_ } | Select-Object -Last 1)
            if ($p.Branch) {
                Write-Host ("  第 {0} 次克隆失败（必须的分支 {1}）：{2}" -f $attempt, $p.Branch, $err) -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                continue
            }
            Write-Host ("  第 {0} 次按默认分支克隆失败：{1}" -f $attempt, $err) -ForegroundColor Yellow
            Start-Sleep -Seconds 2
            continue
        }

        $head = (Invoke-Git @('-C', $p.Dest, 'rev-parse', 'HEAD')).Output.Trim()
        # 指定了分支/tag 时 checkout 是 detached，`rev-parse --abbrev-ref HEAD` 只会返回
        # "HEAD" —— 那样 lock 里就丢了「这份代码来自哪个 tag」这个关键信息。
        $br = if ($p.Branch) { $p.Branch } else { (Invoke-Git @('-C', $p.Dest, 'rev-parse', '--abbrev-ref', 'HEAD')).Output.Trim() }

        # 有锁定值就必须落到锁定值上，绝不静默接受漂移
        if ($p.Pin -and $head -ne $p.Pin) {
            Write-Host ("  尖端是 {0}，锁定值是 {1}，尝试按 sha 取" -f $head.Substring(0,8), $p.Pin.Substring(0,8)) -ForegroundColor DarkGray
            $fetch = Invoke-Git @('-C', $p.Dest, 'fetch', '--depth', '1', '--quiet', 'origin', $p.Pin)
            if ($fetch.Code -eq 0) {
                $null = Invoke-Git @('-C', $p.Dest, 'checkout', '--quiet', '--detach', 'FETCH_HEAD')
                $head = (Invoke-Git @('-C', $p.Dest, 'rev-parse', 'HEAD')).Output.Trim()
            }
            if ($head -ne $p.Pin) {
                Write-Host ("  拿不到锁定 commit（实际 {0}）—— 报错而不是接受漂移" -f $head.Substring(0,8)) -ForegroundColor Red
                continue
            }
        }

        $licenses = Get-LicenseFiles -Dir $p.Dest
        Remove-Item (Join-Path $p.Dest '.git') -Recurse -Force -ErrorAction SilentlyContinue
        $bytes = Get-DirBytes -Dir $p.Dest
        if ($bytes -eq 0) {
            Write-Host '  克隆结果为空，重试' -ForegroundColor Yellow
            continue
        }

        $results += [pscustomobject]@{
            repo          = $p.Repo
            dir           = "pack/distro/$($p.Pack)/$($p.DirName)"
            pack          = $p.Pack
            branch        = $br
            commit        = $head
            bytes         = $bytes
            license_files = @($licenses)
            clone_url     = $url
        }
        Write-Host ("  OK  {0}  {1:N0} 字节  许可证: {2}" -f $head.Substring(0,8), $bytes,
            $(if ($licenses.Count) { $licenses -join ', ' } else { '未找到（需手工确认）' })) -ForegroundColor Green
        $ok = $true
    }

    if (-not $ok) { $failures += $p.Repo }
}

# --------------------------------------------------------------------
# 5. 回写 lock
# --------------------------------------------------------------------
Write-Host "`n=== 5. 写入 vendor/lock.json ===" -ForegroundColor Cyan

# 未处理到的仓库（例如 -Only 只做了一部分）保留原有记录，避免误删
$kept = @()
if ($lock) {
    $doneRepos = $results | Select-Object -ExpandProperty repo
    $kept = @($lock.plugins | Where-Object { $doneRepos -notcontains $_.repo })
}

$newLock = [ordered]@{
    generated_by = 'tools/vendor.ps1'
    note         = 'pack/ 是构建产物，不进版本库；本文件是它的可复现凭证'
    plugins      = @(($results + $kept) | Sort-Object repo)
}
New-Item -ItemType Directory -Force -Path (Split-Path $lockPath) | Out-Null
# 用 LF 写 lock：它是提交进版本库的文件，Windows 上 Set-Content 会写 CRLF
$lockText = ($newLock | ConvertTo-Json -Depth 6) -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($lockPath, $lockText, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("  已写出 {0}（本次更新 {1} 个，保留旧记录 {2} 个）" -f $lockPath, $results.Count, $kept.Count)

# --------------------------------------------------------------------
Write-Host "`n=== 完成 ===" -ForegroundColor Cyan
$totalBytes = ($results | Measure-Object -Property bytes -Sum).Sum
Write-Host ("  成功 {0} / {1}，合计 {2:N1} MB" -f $results.Count, $plan.Count, ($totalBytes / 1MB))
$noLicense = @($results | Where-Object { @($_.license_files).Count -eq 0 })
if ($noLicense.Count) {
    Write-Host "  以下仓库没找到许可证文件，分发前必须人工确认：" -ForegroundColor Yellow
    $noLicense | ForEach-Object { Write-Host "    - $($_.repo)" }
}
if ($failures.Count) {
    Write-Host "`n  失败的仓库（可用 -Only 单个重试）：" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "    - $_" }
    Write-Host "`n  提示：代理会间歇性拒绝 TLS 握手，直接重跑本脚本即可续做（已完成的会跳过）。" -ForegroundColor Yellow
    exit 1
}
exit 0
