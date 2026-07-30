#!/bin/zsh
export LANG=en_US.UTF-8
clear

echo "=============================================="
echo "        可可五笔 Rime Mac 在线一键部署工具"
echo "=============================================="
echo ""

# 基础路径配置
RIMENEW="$HOME/Library/Rime"

# ====================== 词库备份确认逻辑 ======================
echo "重要提醒！更新会覆盖Rime目录配置文件"
echo ""
echo " ⚠️若修改了“用户文件夹”的位置，本程序下载完毕后，需要手动把所有文件从目录：~/Library/Rime 复制到你指定的位置！"
echo ""
echo " ⚠️若修改过个人词库（例如，可可五笔86版是：keke_wubi_86_user.dict.yaml），请务必备份个人词库文件！"
echo ""
echo " 如果准备好更新，按回车键继续；不想更新直接关闭窗口退出。"
echo ""
read "?按回车确认继续..."
echo ""
echo " 已确认。开始执行更新流程..."
echo ""
# ==================================================================

ZIP_RAW="https://github.com/KeKeWubi/Rime-KeKeWubi/archive/refs/heads/main.zip"
DOWNLOAD_ZIP="$RIMENEW/KeKeWubi.zip"
TMP_DIR="$RIMENEW/tmp_keke"

# 创建Rime文件夹（不存在则新建）
mkdir -p "$RIMENEW"

echo "1. 清理临时缓存文件"
rm -rf "$TMP_DIR" 2>/dev/null
rm -f "$DOWNLOAD_ZIP" 2>/dev/null

echo "2. 开始从GitHub下载源码包..."
curl -fsSL --insecure -o "$DOWNLOAD_ZIP" "$ZIP_RAW"
if [ $? -ne 0 ]; then
    echo "❌ GitHub直链下载失败，请切换手机热点或手动下载更新包"
    echo "手动下载地址：$ZIP_RAW"
    read "?按回车关闭窗口"
    exit 1
fi

# 校验文件存在且非空
if [ ! -f "$DOWNLOAD_ZIP" ]; then
    echo "❌ 未生成压缩包，下载失败"
    read "?按回车关闭窗口"
    exit 1
fi
ZIP_SIZE=$(du -s "$DOWNLOAD_ZIP" | awk '{print $1}')
if [ "$ZIP_SIZE" -eq 0 ]; then
    echo "❌ 下载得到空文件，网络中断，请重试"
    rm -f "$DOWNLOAD_ZIP"
    read "?按回车关闭窗口"
    exit 1
fi

echo "3. 解压压缩包到临时目录"
unzip -q -o "$DOWNLOAD_ZIP" -d "$TMP_DIR"
if [ ! -d "$TMP_DIR/Rime-KeKeWubi-main" ]; then
    echo "❌ 压缩包损坏，解压失败"
    rm -f "$DOWNLOAD_ZIP"
    rm -rf "$TMP_DIR" 2>/dev/null
    read "?按回车关闭窗口"
    exit 1
fi

echo "4. 将仓库内所有文件直接复制到Rime根目录（不嵌套文件夹）"
cp -R "$TMP_DIR/Rime-KeKeWubi-main/"* "$RIMENEW/"

echo "5. 清理临时文件与压缩包"
rm -rf "$TMP_DIR"
rm -f "$DOWNLOAD_ZIP"

echo ""
echo "=============================================="
echo "✅ 可可五笔配置文件已拷贝到目录：~/Library/Rime"
echo ""
echo " 接下来，按回车键会打开此目录。"
echo ""
echo " 如果你改过Rime默认用户目录，手动把全部文件复制到你自定义文件夹；"
echo ""
echo " 未修改目录则点击顶部菜单栏鼠须管图标 → 重新部署 生效方案"
echo "=============================================="
echo ""
read "?按回车打开目录"
open "$RIMENEW"
exit 0
