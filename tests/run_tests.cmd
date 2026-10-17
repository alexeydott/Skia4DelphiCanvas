@echo off
setlocal
set "RSVARS=%~1"
if not defined RSVARS set "RSVARS=D:\Embarcadero RAD Studio\23.0\bin\rsvars.bat"
if not exist "%RSVARS%" (
  echo Compiler environment not found: "%RSVARS%"
  exit /b 1
)
call "%RSVARS%"
if errorlevel 1 exit /b 1
pushd "%~dp0"
if not defined SKIA_PYTHON set "SKIA_PYTHON=python"
"%SKIA_PYTHON%" "..\scripts\audit_emf_fixtures.py" --check
if errorlevel 1 goto fail
"%SKIA_PYTHON%" "..\scripts\render_emf_reference.py"
if errorlevel 1 goto fail
call :run win32 dcc32
if errorlevel 1 goto fail
call :run win64 dcc64
if errorlevel 1 goto fail
popd
exit /b 0
:fail
popd
exit /b 1
:run
setlocal
if not exist "build\%~1" mkdir "build\%~1"
%~2 -B -NSSystem;Winapi;Vcl -E"build\%~1" -N0"build\%~1" -U"..\src\fpc\vendor;..\src;%BDS%\lib\%~1\release" SkiaCanvasTests.pas
if errorlevel 1 exit /b 1
copy /y "..\runtime\%~1\sk4d.dll" "build\%~1\sk4d.dll" >nul
if errorlevel 1 exit /b 1
"build\%~1\SkiaCanvasTests.exe"
if errorlevel 1 exit /b 1
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "..\scripts\run_emf_fuzz.ps1" -CompilerKind Delphi -Platform %~1 -CompilerRoot "%BDS%" -OutputDirectory "%CD%\build\%~1\fuzz"
exit /b %errorlevel%
