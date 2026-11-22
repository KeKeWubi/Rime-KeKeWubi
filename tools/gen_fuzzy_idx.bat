@echo off
chcp 65001 >nul
title 重新生成万能Z索引（改了词库后必须运行）
echo ==========================================================
echo   重新生成 keke_fuzzy_z_86 / 98 / nc .idx
echo.
echo   什么时候用：只要改过 keke_wubi_XX_common/system/rare.dict.yaml
echo   里的任何一个字，都要重做对应方案的索引，否则万能Z会
echo   查不到新词、删掉的词还在（而且不会报任何错误）。
echo.
echo   运行条件：本 bat 放在 Rime 目录的 tools 文件夹里，
echo   使用 Windows 自带 PowerShell，无需安装 Python。
echo ==========================================================
echo.

:: Rime 目录 = 本 bat 的上一级目录（自动识别，无需修改）
for %%i in ("%~dp0..") do set "HERE=%%~fi\"

if not exist "%~dp0gen_fuzzy_idx.ps1" (
    echo 错误：没找到 "%~dp0gen_fuzzy_idx.ps1"
    echo 请保持目录结构：Rime\tools\ 里同时有本 bat 和 gen_fuzzy_idx.ps1
    pause
    exit /b 1
)
if not exist "%HERE%lua" (
    echo 错误：没找到 "%HERE%lua" 文件夹
    echo 本 bat 应放在 Rime 用户目录的 tools 文件夹里运行，
    echo 也就是和 lua 文件夹的上级目录（Rime 目录）相邻。
    pause
    exit /b 1
)

echo Rime 目录：%HERE%
echo.

echo [1/3] 86 版
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0gen_fuzzy_idx.ps1" "%HERE%" 86 "%HERE%lua\keke_fuzzy_z_86.idx"
if errorlevel 1 goto :FAIL

echo.
echo [2/3] 98 版
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0gen_fuzzy_idx.ps1" "%HERE%" 98 "%HERE%lua\keke_fuzzy_z_98.idx"
if errorlevel 1 goto :FAIL

echo.
echo [3/3] 新世纪版
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0gen_fuzzy_idx.ps1" "%HERE%" nc "%HERE%lua\keke_fuzzy_z_nc.idx"
if errorlevel 1 goto :FAIL

echo.
echo ==========================================================
echo   三套索引全部生成完成。
echo.
echo   接下来必须做两步：
echo   1) 右键小狼毫托盘图标 - 重新部署（输入法才会重新读 idx）
echo   2) 按 F4 打开万能Z，打 z 或 zzz 验证正常
echo ==========================================================
pause
exit /b 0

:FAIL
echo.
echo 生成失败。常见原因：
echo   1. tools 文件夹没有和 lua 文件夹放在同一个 Rime 目录里
echo   2. 三本 keke_wubi_XX_*.dict.yaml 不在上面显示的目录里
echo   3. 公司电脑策略禁止运行 PowerShell 脚本（换台电脑或联系管理员）
pause
exit /b 1
