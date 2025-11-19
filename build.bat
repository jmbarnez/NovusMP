@echo off
echo ==========================================
echo      Building SpaceGame.love
echo ==========================================

:: Define output locations
set BUILD_DIR=build
set OUTPUT_NAME=SpaceGame.love
set ZIP_NAME=SpaceGame.zip
set OUTPUT_PATH=%BUILD_DIR%\%OUTPUT_NAME%
set ZIP_PATH=%BUILD_DIR%\%ZIP_NAME%

:: Ensure build directory exists
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

:: Remove old build if it exists
if exist "%OUTPUT_PATH%" del "%OUTPUT_PATH%"
if exist "%ZIP_PATH%" del "%ZIP_PATH%"

:: Create the .love file (Zip archive) using PowerShell
:: Compress to a temporary .zip first, then rename to .love
powershell -command "Compress-Archive -Path 'main.lua', 'conf.lua', 'src', 'lib' -DestinationPath '%ZIP_PATH%' -Force"
if exist "%ZIP_PATH%" ren "%ZIP_PATH%" "%OUTPUT_NAME%"

echo.
if exist "%OUTPUT_PATH%" (
    echo Build Successful: %OUTPUT_PATH%
    echo.
    echo To run, drag %OUTPUT_PATH% onto love.exe 
    echo or ensure love.exe is in your PATH and type:
    echo love %OUTPUT_PATH%
) else (
    echo Build Failed!
)
echo.
pause