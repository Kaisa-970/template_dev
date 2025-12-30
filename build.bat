@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ---------------------------
rem Usage
rem ---------------------------
:usage
echo Usage:
echo   build.bat [-r ^| -d][-h]
echo.
echo Options:
echo   -r            Build Release (default)
echo   -d            Build Debug
echo   -h            Show help
echo.
echo Default build dirs:
echo   Release -^> build\release
echo   Debug   -^> build\debug
echo.
echo Env overrides:
echo   set GENERATOR=Ninja
echo.
goto :eof

rem ---------------------------
rem Defaults
rem ---------------------------
set "BUILD_TYPE=Release"

rem ---------------------------
rem Parse args
rem ---------------------------
:parse
if "%~1"=="" goto parsed

if /I "%~1"=="-h" (call :usage & exit /b 0)
if /I "%~1"=="-r" (set "BUILD_TYPE=Release" & shift & goto parse)
if /I "%~1"=="-d" (set "BUILD_TYPE=Debug"   & shift & goto parse)

echo Unknown option: %~1
call :usage
exit /b 2

:parsed

rem ---------------------------
rem Decide build dir
rem ---------------------------

if /I "%BUILD_TYPE%"=="Release" (
set "BUILD_DIR=build\release"
) else if /I "%BUILD_TYPE%"=="Debug" (
set "BUILD_DIR=build\debug"
) else (
set "BUILD_DIR=build"
)

rem ---------------------------
rem Choose generator: prefer Ninja, fallback
rem ---------------------------
if not "%GENERATOR%"=="" (
  set "GEN=%GENERATOR%"
) else (
  where ninja >nul 2>nul
  if %errorlevel%==0 (
    set "GEN=Ninja"
  ) else (
    where nmake >nul 2>nul
    if %errorlevel%==0 (
      set "GEN=NMake Makefiles"
    ) else (
      where mingw32-make >nul 2>nul
      if %errorlevel%==0 (
        set "GEN=MinGW Makefiles"
      ) else (
        echo No suitable generator found.
        echo Install Ninja, or run from a VS Developer Command Prompt (for nmake),
        echo or install MinGW (mingw32-make), or set GENERATOR explicitly.
        echo Example:  set GENERATOR=Ninja
        exit /b 1
      )
    )
  )
)

rem ---------------------------
rem Parallelism
rem ---------------------------
set "NUM_WORKERS=%NUMBER_OF_PROCESSORS%"
if "%NUM_WORKERS%"=="" set "NUM_WORKERS=1"

echo Generator  : %GEN%
echo Build type : %BUILD_TYPE%
echo Build dir  : %BUILD_DIR%
echo Jobs       : %NUM_WORKERS%

cmake -S . -B "%BUILD_DIR%" -G "%GEN%" -DCMAKE_BUILD_TYPE=%BUILD_TYPE%
if errorlevel 1 exit /b %errorlevel%

cmake --build "%BUILD_DIR%" -j %NUM_WORKERS% --config %BUILD_TYPE%
exit /b %errorlevel%