@echo off
setlocal EnableExtensions EnableDelayedExpansion

goto :main

:usage
echo Usage:
echo   build.bat [-r ^| -d] [-h]
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
exit /b 0
rem ---------------------------
rem Helpers (MSVC env + generator picking)
rem ---------------------------

:ensure_msvc_env
rem If cl is already available, we are done.
where cl >nul 2>nul
if %errorlevel%==0 exit /b 0

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
  echo MSVC environment not found ^(cl.exe missing^) and vswhere.exe not found.
  echo Install Visual Studio/Build Tools with "Desktop development with C++".
  exit /b 1
)

set "VSINSTALL="
for /f "usebackq delims=" %%i in (`
  "%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
`) do set "VSINSTALL=%%i"

if not defined VSINSTALL (
  echo vswhere found, but no Visual Studio installation with VC tools was detected.
  exit /b 1
)

if exist "%VSINSTALL%\Common7\Tools\VsDevCmd.bat" (
  call "%VSINSTALL%\Common7\Tools\VsDevCmd.bat" -no_logo -arch=x64 >nul
) else if exist "%VSINSTALL%\VC\Auxiliary\Build\vcvarsall.bat" (
  call "%VSINSTALL%\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul
) else (
  echo Found Visual Studio at "%VSINSTALL%" but could not find VsDevCmd.bat/vcvarsall.bat.
  exit /b 1
)

where cl >nul 2>nul
if %errorlevel%==0 exit /b 0

echo Failed to initialize MSVC environment ^(cl.exe still missing^).
exit /b 1


:pick_vs_generator
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VSVER="
for /f "usebackq delims=" %%i in (`
  "%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationVersion
`) do set "VSVER=%%i"

set "VSMAJOR="
for /f "tokens=1 delims=." %%m in ("%VSVER%") do set "VSMAJOR=%%m"

if "%VSMAJOR%"=="17" (
  set "GEN=Visual Studio 17 2022"
  exit /b 0
)
if "%VSMAJOR%"=="16" (
  set "GEN=Visual Studio 16 2019"
  exit /b 0
)

rem Fallback (common modern default)
set "GEN=Visual Studio 17 2022"
exit /b 0

:main
set "BUILD_TYPE=Release"

:parse
if "%~1"=="" goto :parsed

if /I "%~1"=="-h" (call :usage & exit /b 0)
if /I "%~1"=="-r" (set "BUILD_TYPE=Release" & shift & goto :parse)
if /I "%~1"=="-d" (set "BUILD_TYPE=Debug"   & shift & goto :parse)

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
rem Choose generator (Windows rule):
rem   - Ninja present -> Ninja + MSVC cl
rem   - No Ninja      -> Visual Studio generator (MSVC)
rem ---------------------------
if not "%GENERATOR%"=="" (
  set "GEN=%GENERATOR%"
) else (
  where ninja >nul 2>nul
  if %errorlevel%==0 (
    set "GEN=Ninja"
  ) else (
    call :pick_vs_generator
  )
)

rem (removed invalid PowerShell block; this is a .bat script)

rem ---------------------------
rem Parallelism
rem ---------------------------
set "NUM_WORKERS=%NUMBER_OF_PROCESSORS%"
if "%NUM_WORKERS%"=="" set "NUM_WORKERS=1"

echo Generator  : %GEN%
echo Build type : %BUILD_TYPE%
echo Build dir  : %BUILD_DIR%
echo Jobs       : %NUM_WORKERS%

rem Ensure MSVC env when using Ninja+cl, or when using Visual Studio generator.
if /I "%GEN%"=="Ninja" (
  call :ensure_msvc_env || exit /b %errorlevel%
) else (
  echo "%GEN%" | findstr /I /C:"Visual Studio" >nul
  if %errorlevel%==0 (
    call :ensure_msvc_env || exit /b %errorlevel%
  )
)

rem If generator changed, wipe cache to avoid "generator mismatch" errors.
if exist "%BUILD_DIR%\CMakeCache.txt" (
  set "OLDGEN="
  for /f "usebackq tokens=1,* delims==" %%a in (`findstr /B /C:"CMAKE_GENERATOR:INTERNAL=" "%BUILD_DIR%\CMakeCache.txt"`) do (
    set "OLDGEN=%%b"
  )
  if defined OLDGEN (
    if /I not "!OLDGEN!"=="%GEN%" (
      echo Detected generator change: "!OLDGEN!" ^> "%GEN%". Cleaning "%BUILD_DIR%"...
      rmdir /s /q "%BUILD_DIR%" >nul 2>nul
    )
  )
)

rem Force MSVC when using Ninja to avoid picking up g++/c++ from PATH.
set "CC="
set "CXX="
set "CMAKE_COMPILER_ARGS="
if /I "%GEN%"=="Ninja" (
  set "CMAKE_COMPILER_ARGS=-DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl"
)

set "CMAKE_CFG=cmake -S . -B "%BUILD_DIR%" -G "%GEN%" %CMAKE_COMPILER_ARGS%"
if /I "%GEN%"=="Ninja" (
  set "CMAKE_CFG=!CMAKE_CFG! -DCMAKE_BUILD_TYPE=%BUILD_TYPE%"
) else (
  echo "%GEN%" | findstr /I /C:"Visual Studio" >nul
  if %errorlevel%==0 (
    set "CMAKE_CFG=!CMAKE_CFG! -A x64"
  )
)

call !CMAKE_CFG!
if errorlevel 1 exit /b %errorlevel%

cmake --build "%BUILD_DIR%" -j %NUM_WORKERS% --config %BUILD_TYPE%
exit /b %errorlevel%