@echo off
chcp 65001 >nul
title 可可五笔 Rime 全自动更新器
echo ==============================================
echo        可可五笔 Rime 一键更新工具
echo ==============================================
echo.

:: 路径配置：全部临时文件移至系统缓存，不在Rime文件夹内
set "RIMENEW=%APPDATA%\Rime"
set "ZIP_TEMP=%temp%\KeKeWubi.zip"
set "TMP_DIR=%temp%\tmp_keke"

:: ====================== 词库备份确认逻辑 ======================
echo 重要提醒！更新会清空Rime目录全部旧配置文件
echo.
echo  ⚠️ 若修改了“用户文件夹”的位置，本程序部署完成后，需要手动把所有文件从目录：%appdata%\Rime 复制到你指定的位置！
echo.
echo  ⚠️ 若修改过个人词库（例如，可可五笔86版是：keke_wubi_86_user.dict.yaml），请务必备份个人词库文件！
echo.
echo  ⚠️ 项目若下载成功且校验通过后，会清空Rime全部旧内容，确认已备份再继续！
echo.
echo  如果准备好更新，按任意键继续；不想更新直接关闭窗口退出。
echo.
pause >nul
echo.
echo  已确认。开始执行更新流程...
echo.
:: ==================================================================

set "ZIP_RAW=https://github.com/KeKeWubi/Rime-KeKeWubi/archive/refs/heads/main.zip"

:: 创建Rime文件夹（不存在则新建）
if not exist "%RIMENEW%" md "%RIMENEW%"

echo 1. 清理系统缓存内旧临时文件
rmdir /s /q "%TMP_DIR%" 2>nul
del /f /q "%ZIP_TEMP%" 2>nul

echo 2. 开始从GitHub下载源码包至系统临时目录...
curl -fsSL --insecure -o "%ZIP_TEMP%" "%ZIP_RAW%"
if %errorlevel% neq 0 (
    echo ❌ GitHub直链下载失败，请切换手机热点或手动下载更新包
    echo 手动下载地址：%ZIP_RAW%
    pause
    exit /b 1
)

:CHECK_ZIP
:: 校验文件存在且非空
if not exist "%ZIP_TEMP%" (
    echo ❌ 未生成压缩包，下载失败
    pause
    exit /b 1
)
for %%f in ("%ZIP_TEMP%") do if %%~zf equ 0 (
    echo ❌ 下载得到空文件，网络中断，请重试
    del "%ZIP_TEMP%"
    pause
    exit /b 1
)

echo 3. 校验压缩包完好，清空Rime目录全部原有内容（仅保留当前运行脚本）
:: 删除Rime下所有子文件夹
for /d %%d in ("%RIMENEW%\*") do rmdir /s /q "%%d" 2>nul
:: 删除Rime下所有文件，仅保留当前bat脚本自身
for %%f in ("%RIMENEW%\*.*") do (
    setlocal enabledelayedexpansion
    if /i not "%%~nxf"=="%~nx0" del /f /q "%%f" 2>nul
    endlocal
)
echo    Rime旧文件清理完成，目录干净无残留
echo.

echo 4. 在系统缓存目录解压压缩包
powershell Expand-Archive -Path "%ZIP_TEMP%" -DestinationPath "%TMP_DIR%" -Force
if not exist "%TMP_DIR%\Rime-KeKeWubi-main" (
    echo ❌ 压缩包损坏，解压失败
    del "%ZIP_TEMP%"
    rmdir /s /q "%TMP_DIR%" 2>nul
    pause
    exit /b 1
)

echo 5. 将仓库内所有文件直接复制到Rime根目录
xcopy "%TMP_DIR%\Rime-KeKeWubi-main\*" "%RIMENEW%\" /e /h /y

echo 6. 清理系统全部临时文件
rmdir /s /q "%TMP_DIR%"
del /f /q "%ZIP_TEMP%"

echo.
echo ==============================================
echo ✅ 可可五笔配置文件已拷贝到目录：%appdata%\Rime
echo.
echo 接下来，按任意键会打开此目录。
echo.
echo 如果你改过Rime默认用户目录，手动把全部文件复制到你自定义文件夹；
echo.
echo 未修改目录则直接右键小狼毫托盘图标 → 重新部署 生效方案
echo ==============================================
echo.
pause
start "" "%RIMENEW%"
exit
