@echo off
chcp 65001 >nul
title 可可五笔 Rime 全自动安装更新器
echo ==============================================
echo        可可五笔 Rime 在线一键部署工具
echo ==============================================
echo.

:: 基础路径配置
set "RIMENEW=%APPDATA%\Rime"

:: ====================== 词库备份确认逻辑 ======================
echo ⚠️ 重要提醒！更新会覆盖Rime目录配置文件
echo.
echo  注意：若修改了“用户文件夹”的位置，本程序下载完毕后，需要手动把所有文件从：
echo.
echo  目录路径：%appdata%\rime
echo.
echo  复制到你指定的位置！
echo.
echo  若你修改过个人词库（例如，可可五笔86版是：keke_wubi_86_user.dict.yaml），请务必备份你的词库文件！
echo.
echo  如果准备好更新，按任意键继续；
echo.
echo  不想更新直接关闭窗口退出。
echo.
pause >nul
echo.
echo  已确认备份完成，开始执行更新流程...
echo.
:: ==================================================================

set "ZIP_RAW=https://github.com/KeKeWubi/Rime-KeKeWubi/archive/refs/heads/main.zip"
set "DOWNLOAD_ZIP=%RIMENEW%\KeKeWubi.zip"
set "TMP_DIR=%RIMENEW%\tmp_keke"

:: 创建Rime文件夹（不存在则新建）
if not exist "%RIMENEW%" md "%RIMENEW%"

echo 1. 清理临时缓存文件
rmdir /s /q "%TMP_DIR%" 2>nul
del /f /q "%DOWNLOAD_ZIP%" 2>nul

echo 2. 开始从GitHub下载源码包...
curl -fsSL --insecure -o "%DOWNLOAD_ZIP%" "%ZIP_RAW%"
if %errorlevel% neq 0 (
    echo ❌ GitHub直链下载失败，请切换手机热点或手动下载更新包
    echo 手动下载地址：%ZIP_RAW%
    pause
    exit /b 1
)

:CHECK_ZIP
:: 校验文件存在且非空
if not exist "%DOWNLOAD_ZIP%" (
    echo ❌ 未生成压缩包，下载失败
    pause
    exit /b 1
)
for %%f in ("%DOWNLOAD_ZIP%") do if %%~zf equ 0 (
    echo ❌ 下载得到空文件，网络中断，请重试
    del "%DOWNLOAD_ZIP%"
    pause
    exit /b 1
)

echo 3. 解压压缩包到临时目录
powershell Expand-Archive -Path "%DOWNLOAD_ZIP%" -DestinationPath "%TMP_DIR%" -Force
if not exist "%TMP_DIR%\Rime-KeKeWubi-main" (
    echo ❌ 压缩包损坏，解压失败
    del "%DOWNLOAD_ZIP%"
    rmdir /s /q "%TMP_DIR%" 2>nul
    pause
    exit /b 1
)

echo 4. 将仓库内所有文件直接复制到Rime根目录（不嵌套文件夹）
xcopy "%TMP_DIR%\Rime-KeKeWubi-main\*" "%RIMENEW%\" /e /h /y

echo 5. 清理临时文件与压缩包
rmdir /s /q "%TMP_DIR%"
del /f /q "%DOWNLOAD_ZIP%"

echo.
echo ==============================================
echo ✅ 可可五笔配置文件已拷贝到本地临时目录！
echo.
echo 临时目录路径：%appdata%\rime
echo.
echo 如果你改过Rime自定义用户目录，请手动把这里全部文件复制到你自定义文件夹；
echo.
echo 未修改目录则直接右键小狼毫托盘图标 → 重新部署 生效方案
echo ==============================================
echo.
pause
start "" "%RIMENEW%"
exit