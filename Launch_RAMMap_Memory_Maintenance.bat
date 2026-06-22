@echo off
setlocal
cd /d "%~dp0"

:menu
set "ACTION="
cls
echo ============================================================
echo   RAMMAP MEMORY MAINTENANCE TOOLKIT
echo ============================================================
echo   1. Diagnose memory state
echo   2. Install or verify Microsoft RAMMap
echo   3. Empty standby list
echo   4. Empty process working sets
echo   5. Run both maintenance actions
echo   0. Exit
echo ============================================================
set /p CHOICE=Select an option: 

if "%CHOICE%"=="1" set "ACTION=Diagnose"
if "%CHOICE%"=="2" set "ACTION=InstallRAMMap"
if "%CHOICE%"=="3" set "ACTION=EmptyStandbyList"
if "%CHOICE%"=="4" set "ACTION=EmptyWorkingSets"
if "%CHOICE%"=="5" set "ACTION=RepairAllSafe"
if "%CHOICE%"=="0" goto end
if not defined ACTION goto menu

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Windows_RAMMap_Memory_Maintenance_Toolkit.ps1" -Action "%ACTION%"
echo.
pause
goto menu

:end
endlocal
