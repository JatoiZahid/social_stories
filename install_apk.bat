@echo off
REM ---------------------------------------------------------------
REM  Installs dist\social_stories.apk on a connected Android phone
REM  (USB debugging on) or a running emulator, then opens the app.
REM  Builds the APK first if it does not exist yet.
REM ---------------------------------------------------------------
setlocal
cd /d "%~dp0"

set "APK=dist\social_stories.apk"
if not exist "%APK%" (
  echo No APK found - building it first...
  set "NOPAUSE=1"
  call flutter --version >nul 2>nul || (echo [ERROR] Flutter not found on PATH. & goto :fail)
  call "%~dp0setup.bat" || goto :fail
  REM "call" with doubled percent signs reads the value setup.bat just set.
  call flutter build apk --release %%DART_DEFINES%% || goto :fail
  if not exist dist mkdir dist
  copy /y "build\app\outputs\flutter-apk\app-release.apk" "%APK%" >nul
)

set "ADB=adb"
where adb >nul 2>nul
if errorlevel 1 (
  if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
  ) else (
    echo [ERROR] adb not found. Install Android SDK platform-tools or add them to PATH.
    goto :fail
  )
)

echo Connected devices:
"%ADB%" devices
echo Installing %APK% ...
"%ADB%" install -r "%APK%"
if errorlevel 1 (
  echo [ERROR] Install failed. Check the phone is connected, unlocked and USB debugging is allowed.
  goto :fail
)

echo Launching app...
"%ADB%" shell monkey -p com.socialstories.social_stories -c android.intent.category.LAUNCHER 1 >nul 2>nul
echo Done.
pause
endlocal & exit /b 0

:fail
pause
endlocal & exit /b 1
