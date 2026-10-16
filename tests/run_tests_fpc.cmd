@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\build_fpc_native.ps1" -Target tests %*
exit /b %errorlevel%
