@echo off
setlocal
set "RSVARS=%~1"
if not defined RSVARS set "RSVARS=D:\Embarcadero RAD Studio\23.0\bin\rsvars.bat"
if not exist "%RSVARS%" ( echo Compiler environment not found: "%RSVARS%" & exit /b 1 )
call "%RSVARS%"
if errorlevel 1 exit /b 1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_fuzz_delphi.ps1" %2 %3 %4 %5 %6 %7 %8 %9
exit /b %errorlevel%
