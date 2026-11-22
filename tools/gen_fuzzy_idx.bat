@echo off
rem ----------------------------------------------------------------
rem  Rebuild keke_fuzzy_z_86/98/nc.idx after editing dict.yaml files
rem  ASCII-only on purpose: cmd.exe can parse this file correctly
rem  no matter which code page (936 / 65001) is active.
rem
rem  Layout required:
rem    Rime\tools\gen_fuzzy_idx.bat   (this file)
rem    Rime\tools\gen_fuzzy_idx.ps1   (does the actual work)
rem    Rime\lua\                      (output goes here)
rem ----------------------------------------------------------------

rem Normalize paths WITHOUT trailing backslash:
rem a trailing "\" inside quotes breaks powershell.exe argument parsing
rem ("...Rime\" becomes an escaped quote, hence "illegal characters in path")
for %%i in ("%~dp0.")  do set "TOOLDIR=%%~fi"
for %%i in ("%~dp0..") do set "RIMEDIR=%%~fi"

if not exist "%TOOLDIR%\gen_fuzzy_idx.ps1" (
    echo [ERROR] gen_fuzzy_idx.ps1 not found in: %TOOLDIR%
    echo gen_fuzzy_idx.bat and gen_fuzzy_idx.ps1 must stay together in Rime\tools\
    pause
    exit /b 1
)
if not exist "%RIMEDIR%\lua" (
    echo [ERROR] "lua" folder not found in: %RIMEDIR%
    echo This .bat must stay in the tools folder inside your Rime user directory.
    pause
    exit /b 1
)

echo Rime directory: %RIMEDIR%
echo.
echo [1/3] 86
powershell -NoProfile -ExecutionPolicy Bypass -File "%TOOLDIR%\gen_fuzzy_idx.ps1" "%RIMEDIR%" 86 "%RIMEDIR%\lua\keke_fuzzy_z_86.idx"
if errorlevel 1 goto :FAIL

echo.
echo [2/3] 98
powershell -NoProfile -ExecutionPolicy Bypass -File "%TOOLDIR%\gen_fuzzy_idx.ps1" "%RIMEDIR%" 98 "%RIMEDIR%\lua\keke_fuzzy_z_98.idx"
if errorlevel 1 goto :FAIL

echo.
echo [3/3] nc
powershell -NoProfile -ExecutionPolicy Bypass -File "%TOOLDIR%\gen_fuzzy_idx.ps1" "%RIMEDIR%" nc "%RIMEDIR%\lua\keke_fuzzy_z_nc.idx"
if errorlevel 1 goto :FAIL

echo.
echo ==========================================================
echo   All three indexes rebuilt.
echo   Next steps:
echo   1) Right-click the Weasel tray icon, choose "Redeploy"
echo      (the IME caches the idx until you redeploy)
echo   2) Press F4, turn on fuzzy-Z, type z or zzz to verify
echo ==========================================================
pause
exit /b 0

:FAIL
echo.
echo [ERROR] Rebuild failed. Common causes:
echo   1. The "lua" folder is not next to the "tools" folder
echo   2. keke_wubi_XX_common/system/rare.dict.yaml missing in the Rime directory shown above
echo   3. PowerShell script execution blocked by policy
pause
exit /b 1
