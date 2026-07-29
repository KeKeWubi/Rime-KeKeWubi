@echo off
chcp 65001 >nul
title 可可五笔 Rime 全自动安装更新器
echo ==============================================
echo        可可五笔 Rime 在线一键部署工具
echo ==============================================
echo.

:: ====================== 新增：词库备份确认逻辑 ======================
echo ⚠️ 重要提醒！更新会覆盖Rime目录配置文件
echo.
echo  若你修改过个人词库（例如，86版五笔是：keke_wubi_86_user.dict.yaml），请先手动进入
echo  目录路径：%appdata%\rime
echo  备份你的词库文件！
echo.
echo  确认已完成词库备份，再按任意键继续；
echo  不想更新直接关闭窗口退出。
echo.
pause >nul
echo.
echo  已确认备份完成，开始执行更新流程...
echo.
:: ==================================================================

:: 基础路径配置
set "RIME=%APPDATA%\Rime"
set "ZIP_RAW=https://github.com/KeKeWubi/Rime-KeKeWubi/archive/refs/heads/main.zip"
set "ZIP_MIRROR=https://mirror.ghproxy.com/%ZIP_RAW%"
set "DOWNLOAD_ZIP=%RIME%\KeKeWubi.zip"
set "TMP_DIR=%RIME%\tmp_keke"

:: 创建Rime文件夹（不存在则新建）
if not exist "%RIME%" md "%RIME%"

echo 1. 清理临时缓存文件
rmdir /s /q "%TMP_DIR%" 2>nul
del /f /q "%DOWNLOAD_ZIP%" 2>nul

echo 2. 优先使用镜像下载源码...
curl -fsSL --insecure -o "%DOWNLOAD_ZIP%" "%ZIP_MIRROR%"
if %errorlevel% equ 0 goto CHECK_ZIP

echo 镜像连接超时，切换原生GitHub直链重试...
del "%DOWNLOAD_ZIP%" 2>nul
curl -fsSL --insecure -o "%DOWNLOAD_ZIP%" "%ZIP_RAW%"
if %errorlevel% neq 0 (
    echo ❌ 镜像与原生地址均下载失败，请检查网络或切换手机热点重试
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
xcopy "%TMP_DIR%\Rime-KeKeWubi-main\*" "%RIME%\" /e /h /y

echo 5. 清理临时文件与压缩包
rmdir /s /q "%TMP_DIR%"
del /f /q "%DOWNLOAD_ZIP%"

echo.
echo ==============================================
echo ✅ 可可五笔配置文件已拷贝到本地的 Rime 根目录！
echo 目录路径：%appdata%\rime
echo 请右键小狼毫托盘图标 → 重新部署 生效方案
echo ==============================================
echo.
pause
start "" "%RIME%"
exit