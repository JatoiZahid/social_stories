@echo off
REM ---------------------------------------------------------------
REM  Builds the Android APK and copies it to the dist\ folder.
REM    build_apk.bat           release APK (default)
REM    build_apk.bat debug     debug APK
REM    build_apk.bat split     smaller release APKs, one per CPU type
REM ---------------------------------------------------------------
setlocal
cd /d "%~dp0"

set "NOPAUSE=1"
call "%~dp0setup.bat"
if errorlevel 1 goto :fail
set "NOPAUSE="

set "MODE=%~1"
if "%MODE%"=="" set "MODE=release"

if not exist dist mkdir dist

if /i "%MODE%"=="debug" (
  echo Building DEBUG APK...
  call flutter build apk --debug %DART_DEFINES%
  if errorlevel 1 goto :fail
  copy /y "build\app\outputs\flutter-apk\app-debug.apk" "dist\social_stories-debug.apk" >nul
  goto :done
)

if /i "%MODE%"=="split" (
  echo Building RELEASE APKs per CPU type...
  call flutter build apk --release --split-per-abi %DART_DEFINES%
  if errorlevel 1 goto :fail
  copy /y "build\app\outputs\flutter-apk\app-*-release.apk" "dist\" >nul
  goto :done
)

echo Building RELEASE APK...
call flutter build apk --release %DART_DEFINES%
if errorlevel 1 goto :fail
copy /y "build\app\outputs\flutter-apk\app-release.apk" "dist\social_stories.apk" >nul

:done
echo.
echo APK ready in: %cd%\dist
dir /b dist\*.apk
start "" "%cd%\dist"
pause
endlocal & exit /b 0

:fail
echo.
echo Build failed. See the messages above.
pause
endlocal & exit /b 1
