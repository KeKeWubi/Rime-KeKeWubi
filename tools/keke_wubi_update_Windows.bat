@echo off
chcp 936 >nul 2>&1
title 可可五笔 Rime - Windows 全自动更新工具

rem ============================================================
rem  Keke Wubi Rime - Windows auto updater
rem  Encoding: GBK (cp936). Comments: ASCII only.
rem  Why GBK: a UTF-8 batch file plus "chcp 65001" makes cmd.exe
rem  mis-read itself and run half of a comment line as a command.
rem  Why the TEMP relaunch: the copy sitting in Rime\tools gets
rem  deleted and overwritten during the update, and a batch file
rem  must never delete or rewrite itself while cmd.exe is reading it.
rem ============================================================

set "RUNBAT=%TEMP%\keke_wubi_upd_run.bat"
if /i "%~1"=="__KEKERUN" goto :MAIN
copy /y "%~f0" "%RUNBAT%" >nul 2>&1
if not exist "%RUNBAT%" goto :MAIN
(
  call "%RUNBAT%" __KEKERUN
  del /f /q "%RUNBAT%" >nul 2>&1
  exit /b
)

:MAIN
setlocal
set "RIMENEW=%APPDATA%\Rime"
set "ZIP_TEMP=%TEMP%\KeKeWubi.zip"
set "TMP_DIR=%TEMP%\tmp_keke"
set "UA=Chrome/120.0.0.0 Windows/10.0"

if not defined APPDATA goto :NO_APPDATA
if not exist "%RIMENEW%" md "%RIMENEW%" >nul 2>&1

echo ==============================================================
echo   可可五笔 Rime - Windows 全自动更新工具
echo ==============================================================
echo.
echo   接下来会依次做 6 步：
echo     1. 从 GitHub 下载最新配置包（失败就自动换官网备用通道）
echo     2. 检查下载到的压缩包是否完整
echo     3. 清空 %APPDATA%\Rime 里的全部旧配置
echo     4. 把压缩包解压到系统缓存目录
echo     5. 把新配置复制进 %APPDATA%\Rime
echo     6. 清掉临时文件，然后打开这个文件夹
echo   最后一步要你自己做：右键小狼毫托盘图标，选「重新部署」才会生效。
echo.
echo   两件必须先知道的事：
echo     A. 第 3 步会把旧配置全部删掉，个人词库也在其中，三个版本分别是
echo        keke_wubi_dict\keke_wubi_86_user.dict.yaml
echo        keke_wubi_dict\keke_wubi_98_user.dict.yaml
echo        keke_wubi_dict\keke_wubi_nc_user.dict.yaml
echo        想留着它们，请先复制到别的文件夹。
echo     B. 如果你改过「用户文件夹」的位置，本脚本只会更新
echo        %APPDATA%\Rime 这一个目录，装完还要把文件手动复制到你自定义的地方。
echo.
echo   准备好了就按任意键开始；现在直接关掉窗口就是取消。
echo.
pause >nul
echo.
echo   已确认，开始更新...
echo.

rem ---------- download sources ----------
set "ZIP_GITHUB=https://github.com/KeKeWubi/Rime-KeKeWubi/archive/refs/heads/main.zip"
set "ZIP_OFFICIAL=https://keke.kim/DownLoad/Rime-KeKeWubi-main.zip"

echo 1/6 清理系统缓存里的旧临时文件
rmdir /s /q "%TMP_DIR%" 2>nul
del /f /q "%ZIP_TEMP%" 2>nul
echo.

echo 2/6 下载配置包（优先 GitHub）
curl -fsSL --insecure -A "%UA%" -o "%ZIP_TEMP%" "%ZIP_GITHUB%"
if errorlevel 1 goto :TRY_BACKUP
if not exist "%ZIP_TEMP%" goto :TRY_BACKUP
echo      GitHub 下载成功
goto :CHECK_ZIP

:TRY_BACKUP
echo      警告：GitHub 下载失败，自动切换可可五笔官网备用通道...
del /f /q "%ZIP_TEMP%" 2>nul
curl -fsSL --insecure -A "%UA%" -o "%ZIP_TEMP%" "%ZIP_OFFICIAL%"
if not exist "%ZIP_TEMP%" goto :ERR_DOWNLOAD
for %%f in ("%ZIP_TEMP%") do if %%~zf gtr 0 goto :BACKUP_OK
goto :ERR_DOWNLOAD
:BACKUP_OK
echo      官网通道下载成功

:CHECK_ZIP
if not exist "%ZIP_TEMP%" goto :ERR_DOWNLOAD
set "ZSIZE=0"
for %%f in ("%ZIP_TEMP%") do set "ZSIZE=%%~zf"
if "%ZSIZE%"=="0" goto :ERR_EMPTY
echo.

echo 3/6 清空 %APPDATA%\Rime 里的旧文件
rem This script runs from %TEMP%, so the whole Rime folder can go.
attrib -h -s -r "%RIMENEW%\*.*" >nul 2>&1
for /d %%d in ("%RIMENEW%\*") do rmdir /s /q "%%~fd" 2>nul
for %%f in ("%RIMENEW%\*.*") do del /f /q /a "%%~ff" 2>nul
echo      旧文件清理完成
echo.

echo 4/6 解压配置包
if not exist "%TMP_DIR%" md "%TMP_DIR%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%ZIP_TEMP%' -DestinationPath '%TMP_DIR%' -Force" 2>nul
if exist "%TMP_DIR%\Rime-KeKeWubi-main" goto :UNZIPPED
rem PowerShell failed, retry with the tar.exe shipped since Win10 1803
echo      PowerShell 解压未成功，改用系统 tar 重试...
tar -xf "%ZIP_TEMP%" -C "%TMP_DIR%" 2>nul
if not exist "%TMP_DIR%\Rime-KeKeWubi-main" goto :ERR_UNZIP

:UNZIPPED
echo.
echo 5/6 复制到 %APPDATA%\Rime
xcopy "%TMP_DIR%\Rime-KeKeWubi-main\*" "%RIMENEW%" /e /h /y /r
echo.

echo 6/6 清理临时文件
rmdir /s /q "%TMP_DIR%" 2>nul
del /f /q "%ZIP_TEMP%" 2>nul
echo.

echo ==============================================================
echo   更新完成，配置文件已经放到 %APPDATA%\Rime
echo ==============================================================
echo.
echo   接下来还要做两步：
echo     1. 按任意键，会打开这个文件夹
echo     2. 右键任务栏的小狼毫托盘图标，选「重新部署」，等它跑完再打字
echo.
echo   如果你把「用户文件夹」改到了别的位置，请把上面这个目录里的
echo   全部文件手动复制到你自定义的目录，再执行重新部署。
echo.
echo   本脚本已随新包一起更新，位置：tools\keke_wubi_update_Windows.bat
echo.
pause
if exist "%RIMENEW%" start "" explorer.exe "%RIMENEW%"
endlocal
exit /b 0

rem ---------- error exits ----------
:ERR_DOWNLOAD
echo.
echo 错误：下载失败，压缩包不存在或为空。
echo 请检查网络后重试，或手动下载压缩包替换：
echo   https://github.com/KeKeWubi/Rime-KeKeWubi
goto :FAIL

:ERR_EMPTY
del /f /q "%ZIP_TEMP%" 2>nul
echo.
echo 错误：下载到的是空文件，网络中断，请重试。
goto :FAIL

:ERR_UNZIP
del /f /q "%ZIP_TEMP%" 2>nul
rmdir /s /q "%TMP_DIR%" 2>nul
echo.
echo 错误：压缩包解压失败，文件可能已损坏，请重试。
goto :FAIL

:NO_APPDATA
echo 错误：读不到 APPDATA 环境变量，无法确定 Rime 目录，脚本退出。
goto :FAIL

:FAIL
echo.
echo 本次更新没有完成。按任意键关闭窗口。
pause >nul
endlocal
exit /b 1
