@echo off
setlocal enabledelayedexpansion
echo ====================================
echo   ShaderRenderer Build Script
echo ====================================
echo.

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
cd /d "%SCRIPT_DIR%"

REM Check if CMake is installed
where cmake >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] CMake is not installed or not in PATH.
    echo Please install CMake and add it to your system PATH.
    echo Download: https://cmake.org/download/
    pause
    exit /b 1
)

REM Check if Visual Studio is available
where cl >nul 2>nul
if %errorlevel% neq 0 (
    echo [WARNING] MSVC compiler not found in PATH.
    echo Make sure you have Visual Studio 2022 installed.
    echo If building via Developer Command Prompt, ignore this warning.
    echo.
)

REM Parse command line arguments
set CONFIG=Release
set GENERATOR=Visual Studio 17 2022

:parse_args
if "%~1"=="" goto :parse_done
if /i "%~1"=="-c" set CONFIG=%~2 & shift & shift & goto :parse_args
if /i "%~1"=="--config" set CONFIG=%~2 & shift & shift & goto :parse_args
if /i "%~1"=="-g" set GENERATOR=%~2 & shift & shift & goto :parse_args
if /i "%~1"=="--generator" set GENERATOR=%~2 & shift & shift & goto :parse_args
if /i "%~1"=="-r" (
    echo [INFO] Cleaning build directory...
    rmdir /s /q build 2>nul
    shift & goto :parse_args
)
if /i "%~1"=="--reconfigure" (
    echo [INFO] Cleaning build directory...
    rmdir /s /q build 2>nul
    shift & goto :parse_args
)
if /i "%~1"=="-h" (
    echo.
    echo Usage: build.bat [options]
    echo.
    echo Options:
    echo   -c CONFIG     Set build configuration (Debug/Release/RelWithDebInfo)
    echo   -g GENERATOR  Set CMake generator (default: Visual Studio 17 2022)
    echo   -r            Reconfigure (clean build directory first)
    echo   --reconfigure Same as -r
    echo   -h            Show this help message
    echo.
    echo Examples:
    echo   build.bat                 Build with Release configuration
    echo   build.bat -c Debug        Build with Debug configuration
    echo   build.bat -r              Clean and rebuild with Release
    echo   build.bat -r -c Debug     Clean and rebuild with Debug
    echo.
    pause
    exit /b 0
)
shift
goto :parse_args
:parse_done

REM Create build directory if it doesn't exist
if not exist "build" mkdir build

REM Configure the project
echo [1/2] Configuring project...
echo.
cd build
cmake -S "%SCRIPT_DIR%" -B . -DCMAKE_BUILD_TYPE=%CONFIG% -G "%GENERATOR%"
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Configuration failed!
    echo.
    echo Common issues:
    echo   - Glad library is missing. Download from https://glad.davidebellico.hu/
    echo     and extract to vendor/glad/ with this structure:
    echo     vendor/glad/
    echo     ├── include/glad/gl.h
    echo     └── src/gl.c
    echo   - GLFW library is missing. Ensure vendor/glfw/ exists.
    echo   - Visual Studio generator not found. Check CMake documentation.
    cd ..
    pause
    exit /b 1
)

REM Build the project
echo.
echo [2/2] Building project...
cmake --build . --config %CONFIG%
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Build failed!
    echo Check the output above for error details.
    cd ..
    pause
    exit /b 1
)

cd ..

echo.
echo ====================================
echo   Build Successful!
echo ====================================
echo.
echo Configuration: %CONFIG%
echo Executable:   build/%CONFIG%/ShaderRenderer.exe
echo.
pause

