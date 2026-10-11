# 跑发行版的测试。
#
#   pwsh -File tests/run.ps1                  # 默认跑 tests/test_search.lua
#   pwsh -File tests/run.ps1 tests/foo.lua    # 跑指定测试
#
# nvim 选取顺序：$env:NVIM → PATH 上的 nvim → 仓库内 build/toolchain（可选，若你解压了一份）
#
# 两个要点：
#   1. 把 XDG_* 都指到 build/xdg 下，让 nvim 的数据、状态、缓存都留在仓库内。
#      发行版的启动脚本将来也这么做，保证自包含、不和你已有的 Neovim 配置串味。
#   2. 必须能创建子进程（搜索功能要调 rg）。在受限沙箱里 Neovim spawn 会失败，
#      测试会报错——那是环境限制，不是发行版的问题。

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$testFile = if ($args.Count -ge 1) { $args[0] } else { 'tests/test_search.lua' }

# 1. 显式指定
$nvim = if ($env:NVIM -and (Test-Path $env:NVIM)) { $env:NVIM } else { $null }

# 2. PATH
if (-not $nvim) {
  $cmd = Get-Command nvim -ErrorAction SilentlyContinue
  if ($cmd) { $nvim = $cmd.Source }
}

# 3. 仓库内自带
if (-not $nvim) {
  $local = Join-Path $root 'build\toolchain\nvim-win64\bin\nvim.exe'
  if (Test-Path $local) { $nvim = $local }
}

if (-not $nvim) {
  Write-Host '找不到 nvim。装一份并加进 PATH，或用 $env:NVIM 指定。' -ForegroundColor Red
  exit 2
}

$verLine = (& $nvim --version | Select-Object -First 1)
$verLine = if ($verLine) { $verLine.Trim() } else { '(读不出版本)' }

# 版本底线：vim.lsp.config 要 0.11+，nvim-treesitter 的 main 分支要 0.12+
if ($verLine -match '^NVIM v(\d+)\.(\d+)') {
  $maj = [int]$Matches[1]
  $min = [int]$Matches[2]
  if ($maj -eq 0 -and $min -lt 12) {
    Write-Host "警告：$verLine 低于 0.12，本发行版要求的很多能力不可用。" -ForegroundColor Yellow
  }
} else {
  Write-Host "警告：版本号无法解析 —— $verLine" -ForegroundColor Yellow
}

$env:XDG_DATA_HOME   = Join-Path $root 'build\xdg\data'
$env:XDG_STATE_HOME  = Join-Path $root 'build\xdg\state'
$env:XDG_CACHE_HOME  = Join-Path $root 'build\xdg\cache'
$env:XDG_CONFIG_HOME = Join-Path $root 'build\xdg\config'

Write-Host "nvim     : $nvim"
Write-Host "版本     : $verLine"
Write-Host "测试文件 : $testFile`n"

Push-Location $root
try {
  & $nvim --headless -u init.lua -l $testFile
  $code = $LASTEXITCODE
} finally {
  Pop-Location
}

Write-Host "`n退出码: $code"
exit $code
