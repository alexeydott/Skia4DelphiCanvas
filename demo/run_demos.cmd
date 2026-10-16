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
%~2 -B -NSSystem;Winapi;Vcl -E"build\%~1" -N0"build\%~1" -U"..\src\fpc\vendor;..\src;%BDS%\lib\%~1\release" SkiaDemo.pas
if errorlevel 1 exit /b 1
copy /y "..\runtime\%~1\sk4d.dll" "build\%~1\sk4d.dll" >nul
if errorlevel 1 exit /b 1
"build\%~1\SkiaDemo.exe"
if errorlevel 1 exit /b 1
%~2 -B -NSSystem;Winapi;Vcl -E"build\%~1" -N0"build\%~1" -U"..\src\fpc\vendor;..\src;%BDS%\lib\%~1\release" SkiaPdfSvgDemo.pas
if errorlevel 1 exit /b 1
"build\%~1\SkiaPdfSvgDemo.exe"
exit /b %errorlevel%
