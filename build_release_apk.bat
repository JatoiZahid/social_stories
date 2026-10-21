@echo off
REM ---------------------------------------------------------------
REM  Builds a SIGNED RELEASE APK (ready to share or upload).
REM    build_release_apk.bat        signed release APK
REM    build_release_apk.bat aab    also builds an .aab for Google Play
REM
REM  First run: creates your signing key (android\upload-keystore.jks)
REM  and android\key.properties. BACK UP BOTH FILES. If you lose the
REM  key, you cannot publish updates to the same app.
REM ---------------------------------------------------------------
setlocal EnableExtensions
cd /d "%~dp0"

set "NOPAUSE=1"
call "%~dp0setup.bat"
if errorlevel 1 goto :fail

set "KEYSTORE=%cd%\android\upload-keystore.jks"
set "KEYPROPS=android\key.properties"
set "ALIAS=upload"

if exist "%KEYPROPS%" (
  echo [signing] Using existing %KEYPROPS%
  goto :patch
)

call :ask_password
if errorlevel 1 goto :fail

if exist "%KEYSTORE%" (
  echo [signing] Found existing keystore, writing key.properties...
  goto :write_props
)

call :find_keytool
if errorlevel 1 goto :fail

echo [signing] Creating signing key %KEYSTORE% ...
"%KEYTOOL%" -genkeypair -v -keystore "%KEYSTORE%" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias %ALIAS% -storepass "%STOREPASS%" -keypass "%STOREPASS%" -dname "CN=Social Stories, OU=Mobile, O=Social Stories"
if errorlevel 1 (
  echo [ERROR] Could not create the keystore.
  goto :fail
)

:write_props
set "KSPATH=%KEYSTORE:\=/%"
> "%KEYPROPS%" echo storePassword=%STOREPASS%
>> "%KEYPROPS%" echo keyPassword=%STOREPASS%
>> "%KEYPROPS%" echo keyAlias=%ALIAS%
>> "%KEYPROPS%" echo storeFile=%KSPATH%
echo [signing] Wrote %KEYPROPS%

:patch
echo [signing] Configuring Gradle release signing...
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\patch_signing.ps1" "android\app"
if errorlevel 1 goto :fail

if not exist dist mkdir dist

echo.
echo Building signed RELEASE APK...
call flutter build apk --release --obfuscate --split-debug-info=build\symbols %DART_DEFINES%
if errorlevel 1 goto :fail
copy /y "build\app\outputs\flutter-apk\app-release.apk" "dist\social_stories-release.apk" >nul

if /i "%~1"=="aab" (
  echo.
  echo Building signed App Bundle for Google Play...
  call flutter build appbundle --release --obfuscate --split-debug-info=build\symbols %DART_DEFINES%
  if errorlevel 1 goto :fail
  copy /y "build\app\outputs\bundle\release\app-release.aab" "dist\social_stories-release.aab" >nul
)

echo.
echo Done. Signed files in: %cd%\dist
dir /b dist\*-release.*
echo.
echo Remember to back up android\upload-keystore.jks and android\key.properties.
start "" "%cd%\dist"
pause
endlocal & exit /b 0

REM ---------------------------------------------------------------
:ask_password
echo.
echo A signing password is needed (at least 6 characters).
echo Use only letters and numbers - symbols like ^& ^| ^< ^> %% ^^ break batch files.
set "STOREPASS="
set /p "STOREPASS=Signing password: "
if not defined STOREPASS (
  echo [ERROR] No password entered.
  exit /b 1
)
if "%STOREPASS:~5,1%"=="" (
  echo [ERROR] Password must be at least 6 characters.
  exit /b 1
)
exit /b 0

:find_keytool
set "KEYTOOL="
for /f "delims=" %%K in ('where keytool 2^>nul') do if not defined KEYTOOL set "KEYTOOL=%%K"
if not defined KEYTOOL if defined JAVA_HOME if exist "%JAVA_HOME%\bin\keytool.exe" set "KEYTOOL=%JAVA_HOME%\bin\keytool.exe"
if not defined KEYTOOL if exist "%ProgramFiles%\Android\Android Studio\jbr\bin\keytool.exe" set "KEYTOOL=%ProgramFiles%\Android\Android Studio\jbr\bin\keytool.exe"
if not defined KEYTOOL if exist "%ProgramFiles%\Android\Android Studio\jre\bin\keytool.exe" set "KEYTOOL=%ProgramFiles%\Android\Android Studio\jre\bin\keytool.exe"
if not defined KEYTOOL (
  echo [ERROR] keytool not found. Install Android Studio or a Java JDK, or set JAVA_HOME.
  exit /b 1
)
exit /b 0

:fail
echo.
echo Release build failed. See the messages above.
pause
endlocal & exit /b 1
