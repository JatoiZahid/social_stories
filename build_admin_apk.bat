@echo off
REM ---------------------------------------------------------------
REM  Builds the admin app (review submissions, manage subscribers)
REM  to dist\stories_admin.apk.
REM  The server address in story_server.txt is filled in on the
REM  app's connect screen (it can be changed there).
REM ---------------------------------------------------------------
setlocal EnableExtensions
cd /d "%~dp0"

where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Flutter was not found. Add Flutter's "bin" folder to PATH.
  goto :fail
)

set "STORY_URL="
set "DART_DEFINES="
if exist story_server.txt for /f "usebackq eol=# tokens=*" %%U in ("story_server.txt") do if not defined STORY_URL set "STORY_URL=%%U"
if defined STORY_URL set "DART_DEFINES=--dart-define=STORY_SERVER_URL=%STORY_URL%"

cd /d "%~dp0admin_app"
call flutter pub get
if errorlevel 1 goto :fail
echo Building the admin app...
call flutter build apk --release %DART_DEFINES%
if errorlevel 1 goto :fail

cd /d "%~dp0"
if not exist dist mkdir dist
copy /y "admin_app\build\app\outputs\flutter-apk\app-release.apk" "dist\stories_admin.apk" >nul
echo.
echo Admin app ready: %cd%\dist\stories_admin.apk
start "" "%cd%\dist"
pause
endlocal & exit /b 0

:fail
echo.
echo Build failed. See the messages above.
pause
endlocal & exit /b 1
