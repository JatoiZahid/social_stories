@echo off
REM ---------------------------------------------------------------
REM  Runs the app on a connected phone or emulator with hot reload.
REM    run_app.bat            debug (press r = hot reload, q = quit)
REM    run_app.bat release    release build, fastest, no hot reload
REM ---------------------------------------------------------------
setlocal
cd /d "%~dp0"

set "NOPAUSE=1"
call "%~dp0setup.bat"
if errorlevel 1 goto :fail

echo.
echo Available devices:
call flutter devices
echo.

if /i "%~1"=="release" (
  call flutter run --release %DART_DEFINES%
) else (
  call flutter run %DART_DEFINES%
)
if errorlevel 1 goto :fail
endlocal & exit /b 0

:fail
echo.
echo Could not run the app. Connect a phone with USB debugging on, or start an emulator
echo (Android Studio ^> Device Manager), then try again.
pause
endlocal & exit /b 1
