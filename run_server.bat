@echo off
REM ---------------------------------------------------------------
REM  Starts the story server (Spring Boot): the admin page for adding
REM  and editing stories, and the API the app downloads them from.
REM    run_server.bat             port 8080
REM    run_server.bat 9000        another port
REM  The first start copies the app's 12 stories into server\data\.
REM  The admin token is printed below (and saved in server\data\admin_token.txt).
REM  Needs Java 17+. Uses JAVA_HOME, or the Java that comes with Android Studio.
REM ---------------------------------------------------------------
setlocal
cd /d "%~dp0server"

if defined JAVA_HOME if exist "%JAVA_HOME%\bin\java.exe" goto :java_ok
set "JAVA_HOME="
if exist "%ProgramFiles%\Android\Android Studio\jbr\bin\java.exe" set "JAVA_HOME=%ProgramFiles%\Android\Android Studio\jbr"
if not defined JAVA_HOME if exist "%ProgramFiles%\Android\Android Studio\jre\bin\java.exe" set "JAVA_HOME=%ProgramFiles%\Android\Android Studio\jre"
if not defined JAVA_HOME (
  where java >nul 2>nul
  if errorlevel 1 (
    echo [ERROR] Java was not found. Install Android Studio or a Java 17+ JDK, or set JAVA_HOME.
    goto :fail
  )
)
:java_ok

if not "%~1"=="" set "PORT=%~1"

echo Starting the story server. The first start downloads Spring Boot and can take a few minutes...
call "%~dp0server\gradlew.bat" bootRun --console=plain
if errorlevel 1 goto :fail
endlocal & exit /b 0

:fail
echo.
echo The story server stopped with an error. See the messages above.
pause
endlocal & exit /b 1
