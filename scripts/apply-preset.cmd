@echo off
setlocal
cd /d "%~dp0"

echo.
echo GAMMA OptiBridge v0.5.0-rc3 Preset Switcher
echo =============================================
echo 1. Native      1.00
echo 2. Quality     0.90
echo 3. Balanced    0.85
echo 4. Performance 0.75
echo.
set /p CHOICE=Choose preset [1-4]: 

if "%CHOICE%"=="1" set "PRESET=optibridge-native.ini"
if "%CHOICE%"=="2" set "PRESET=optibridge-quality.ini"
if "%CHOICE%"=="3" set "PRESET=optibridge-balanced.ini"
if "%CHOICE%"=="4" set "PRESET=optibridge-performance.ini"

if not defined PRESET (
  echo Invalid choice.
  pause
  exit /b 1
)

copy /Y "OptiBridge_Presets\%PRESET%" "optibridge.ini" >nul
if errorlevel 1 (
  echo Failed to write optibridge.ini.
  pause
  exit /b 1
)

echo.
echo Applied: %PRESET%
echo Keep r__tf_mipbias 0 in GAMMA.
echo Fully exit and relaunch GAMMA through MO2 before testing.
pause
