@echo off
rem Remove the "downloaded from the Internet" mark (Mark of the Web) from all
rem files in this folder. Without it Windows may warn that the publisher
rem cannot be verified when you double-click nvim.cmd.
rem
rem Just double-click this file once, after extracting the zip.

setlocal
echo Removing the network mark from all files under:
echo   %~dp0
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%~dp0' -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue; exit 0"
echo.
echo [OK] Done. Double-click nvim.cmd now; the warning should be gone.
echo      If it still appears: right-click the ZIP BEFORE extracting,
echo      tick "Unblock", then extract again.
echo.
pause
endlocal
