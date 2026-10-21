@echo off
REM ---------------------------------------------------------------
REM  Starts an Android emulator (if none is running), waits for it
REM  to boot, then runs the app on it.
REM    run_emulator.bat                  first emulator found, debug (hot reload)
REM    run_emulator.bat release          release build (faster, no hot reload)
REM    run_emulator.bat Pixel_7_API_34   use a specific emulator by name
REM  Press r in this window to hot reload, q to quit.
REM ---------------------------------------------------------------
setlocal EnableExtensions
cd /d "%~dp0"

set "AVD="
set "MODE="
for %%A in (%*) do (
  if /i "%%~A"=="release" (set "MODE=--release") else (set "AVD=%%~A")
)

set "NOPAUSE=1"
call "%~dp0setup.bat"
if errorlevel 1 goto :fail

REM ---- find the Android SDK ---------------------------------------
set "SDK="
if defined ANDROID_HOME if exist "%ANDROID_HOME%\platform-tools\adb.exe" set "SDK=%ANDROID_HOME%"
if not defined SDK if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" set "SDK=%ANDROID_SDK_ROOT%"
if not defined SDK if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" set "SDK=%LOCALAPPDATA%\Android\Sdk"
if not defined SDK (
  echo [ERROR] Android SDK not found. Install Android Studio, or set ANDROID_HOME.
  goto :fail
)
set "ADB=%SDK%\platform-tools\adb.exe"
set "EMU=%SDK%\emulator\emulator.exe"
if not exist "%EMU%" (
  echo [ERROR] Android Emulator is not installed.
  echo         Android Studio ^> Settings ^> Android SDK ^> SDK Tools ^> tick "Android Emulator".
  goto :fail
)
"%ADB%" start-server >nul 2>nul

REM ---- already running? -------------------------------------------
call :find_device
if defined DEVICE (
  echo Using running emulator %DEVICE%
  goto :run
)

REM ---- pick an emulator (AVD) -------------------------------------
if not defined AVD call :first_avd
if not defined AVD (
  echo No emulator found - creating one...
  call flutter emulators --create --name social_stories_emulator
  call :first_avd
)
if not defined AVD (
  echo.
  echo [ERROR] Could not create an emulator automatically.
  echo         Open Android Studio ^> Device Manager ^> Create Virtual Device,
  echo         pick a phone e.g. Pixel 7, download a system image, Finish.
  echo         Then run this file again.
  goto :fail
)

echo Starting emulator "%AVD%" ...
start "Android Emulator" "%EMU%" -avd "%AVD%" -netdelay none -netspeed full

REM ---- wait for boot (max ~5 minutes) ------------------------------
echo Waiting for the emulator to boot. The first start can take a few minutes...
"%ADB%" wait-for-device
set /a TRIES=0
:wait_boot
"%ADB%" shell getprop sys.boot_completed 2>nul | findstr /c:"1" >nul && goto :booted
set /a TRIES+=1
if %TRIES% GEQ 100 (
  echo [ERROR] The emulator did not finish booting.
  echo         Check that virtualization is on in BIOS and "Windows Hypervisor Platform" is enabled.
  goto :fail
)
timeout /t 3 /nobreak >nul
goto :wait_boot

:booted
echo Emulator is ready.
call :find_device

:run
echo.
echo Running app on %DEVICE% %MODE% ...
call flutter run -d %DEVICE% %MODE% %DART_DEFINES%
if errorlevel 1 goto :fail
endlocal & exit /b 0

REM ---------------------------------------------------------------
:find_device
set "DEVICE="
"%ADB%" devices > "%TEMP%\ss_devices.txt" 2>nul
for /f "tokens=1,2" %%D in ('findstr /b /c:"emulator-" "%TEMP%\ss_devices.txt"') do (
  if "%%E"=="device" if not defined DEVICE set "DEVICE=%%D"
)
exit /b 0

:first_avd
set "AVD="
"%EMU%" -list-avds > "%TEMP%\ss_avds.txt" 2>nul
for /f "usebackq delims=" %%L in (`findstr /v /c:"|" "%TEMP%\ss_avds.txt"`) do (
  if not defined AVD set "AVD=%%L"
)
exit /b 0

:fail
echo.
echo Could not run on the emulator. See the messages above.
pause
endlocal & exit /b 1
