# packednvim uninstaller (Windows, per-user).
#
# Removes everything install.cmd set up: the config link, the PATH entry,
# the XDG_STATE_HOME / XDG_CACHE_HOME variables, the file associations,
# the "Open with packednvim" right-click entry and the application
# registrations. The package directory itself is NOT deleted.
#
# The rollback logic lives in exactly one place: install.ps1 -Uninstall.
# This file only forwards, so there is no second copy to drift out of sync.
# ASCII only: Windows PowerShell 5.1 reads .ps1 as ANSI unless it has a BOM,
# so non-ASCII comments would come out garbled.

$ErrorActionPreference = 'Stop'

$impl = $PSScriptRoot + '\install.ps1'
if (-not (Test-Path -LiteralPath $impl)) {
    Write-Error ('install.ps1 not found next to uninstall.ps1: ' + $impl)
    exit 1
}

& $impl -Uninstall
exit $LASTEXITCODE
