@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_fuzz_fpc.ps1" %*
exit /b %errorlevel%
