@echo off
REM ---------------------------------------------------------------
REM  One-time project setup (safe to run again).
REM  - generates the android\ folder if it is missing
REM  - adds the text-to-speech permission to AndroidManifest.xml
REM  - downloads packages (flutter pub get)
REM ---------------------------------------------------------------
setlocal
cd /d "%~dp0"

where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Flutter was not found. Install Flutter and add its "bin" folder to PATH:
  echo         https://docs.flutter.dev/get-started/install/windows
  goto :fail
)

if not exist "android\app\src\main\AndroidManifest.xml" (
  echo [1/3] Creating Android project files...
  call flutter create . --project-name social_stories --org com.socialstories --platforms=android
  if errorlevel 1 goto :fail
) else (
  echo [1/3] Android project files already exist.
)

echo [2/3] Checking text-to-speech permission in AndroidManifest.xml...
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\patch_manifest.ps1" "android\app\src\main\AndroidManifest.xml"
if errorlevel 1 goto :fail

REM The story server address (first line of story_server.txt) is passed to
REM the app at build time. Without it, release builds use only bundled stories.
set "STORY_URL="
set "DART_DEFINES="
if exist story_server.txt for /f "usebackq eol=# tokens=*" %%U in ("story_server.txt") do if not defined STORY_URL set "STORY_URL=%%U"
if defined STORY_URL set "DART_DEFINES=--dart-define=STORY_SERVER_URL=%STORY_URL%"
REM The Google Play subscription product id (default: social_stories_premium).
if defined SUBSCRIPTION_PRODUCT_ID set "DART_DEFINES=%DART_DEFINES% --dart-define=SUBSCRIPTION_PRODUCT_ID=%SUBSCRIPTION_PRODUCT_ID%"

echo [3/3] Getting packages...
call flutter pub get
if errorlevel 1 goto :fail

echo.
echo Setup complete.
if defined STORY_URL (echo Story server: %STORY_URL%) else (echo Story server: none - add its address to story_server.txt to use one.)
if not defined NOPAUSE pause
endlocal & set "DART_DEFINES=%DART_DEFINES%" & exit /b 0

:fail
echo.
echo Setup failed. See the messages above.
if not defined NOPAUSE pause
endlocal & exit /b 1
