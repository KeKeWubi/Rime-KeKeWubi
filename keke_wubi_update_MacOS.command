#!/bin/zsh
# 可可五笔 Rime MacOS 全自动更新器
echo "=============================================="
echo "        可可五笔 Rime 一键更新工具"
echo "=============================================="
echo ""

# 路径配置：临时文件全部存放系统/tmp缓存，不污染Rime目录
RIMENEW="$HOME/Library/Rime"
ZIP_TEMP="/tmp/KeKeWubi.zip"
TMP_DIR="/tmp/tmp_keke"

# ====================== 词库备份确认提示 ======================
echo "重要提醒！更新会清空Rime目录全部旧配置文件"
echo ""
echo " ⚠️ 若修改了「用户文件夹」位置，部署完成后需要手动把所有文件从 $RIMENEW 复制到你自定义目录！"
echo ""
echo " ⚠️ 若修改过个人词库（例如可可五笔86版：keke_wubi_86_user.dict.yaml），请务必备份个人词库文件！"
echo ""
echo " ⚠️ 压缩包下载成功且校验通过后，会清空Rime全部旧内容，确认已备份再继续！"
echo ""
echo " 准备好更新按回车键继续；不想更新直接关闭窗口退出。"
read -r
echo ""
echo " 已确认。开始执行更新流程..."
echo ""
# ==================================================================

ZIP_RAW="https://github.com/KeKeWubi/Rime-KeKeWubi/archive/refs/heads/main.zip"

# Rime目录不存在则创建
[ ! -d "$RIMENEW" ] && mkdir -p "$RIMENEW"

echo "1. 清理系统缓存内旧临时文件"
rm -rf "$TMP_DIR" 2>/dev/null
rm -f "$ZIP_TEMP" 2>/dev/null

echo "2. 开始从GitHub下载源码包至系统临时目录..."
curl -fsSL --insecure -o "$ZIP_TEMP" "$ZIP_RAW"
if [ $? -ne 0 ]; then
    echo "❌ GitHub直链下载失败，请切换手机热点或手动下载更新包"
    echo "手动下载地址：$ZIP_RAW"
    read -r
    exit 1
fi

# 校验压缩包存在且非空
if [ ! -f "$ZIP_TEMP" ]; then
    echo "❌ 未生成压缩包，下载失败"
    read -r
    exit 1
fi
ZIP_SIZE=$(stat -f%z "$ZIP_TEMP")
if [ "$ZIP_SIZE" -eq 0 ]; then
    echo "❌ 下载得到空文件，网络中断，请重试"
    rm -f "$ZIP_TEMP"
    read -r
    exit 1
fi

echo "3. 校验压缩包完好，清空Rime目录全部原有内容（仅保留当前运行脚本）"
# 删除Rime下所有子文件夹
find "$RIMENEW" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} \; 2>/dev/null
# 删除Rime下所有文件，过滤保留当前command脚本
SCRIPT_NAME=$(basename "$0")
find "$RIMENEW" -mindepth 1 -maxdepth 1 -type f | while read -r file; do
    FILENAME=$(basename "$file")
    if [ "$FILENAME" != "$SCRIPT_NAME" ]; then
        rm -f "$file" 2>/dev/null
    fi
done
echo "   Rime旧文件清理完成，目录干净无残留"
echo ""

echo "4. 在系统缓存目录解压压缩包"
unzip -q "$ZIP_TEMP" -d "$TMP_DIR"
if [ ! -d "$TMP_DIR/Rime-KeKeWubi-main" ]; then
    echo "❌ 压缩包损坏，解压失败"
    rm -f "$ZIP_TEMP"
    rm -rf "$TMP_DIR"
    read -r
    exit 1
fi

echo "5. 将仓库内所有文件直接复制到Rime根目录（不嵌套文件夹）"
cp -R "$TMP_DIR/Rime-KeKeWubi-main/"* "$RIMENEW"/

echo "6. 清理系统全部临时文件"
rm -rf "$TMP_DIR"
rm -f "$ZIP_TEMP"

echo ""
echo "=============================================="
echo "✅ 可可五笔配置文件已拷贝到目录：$RIMENEW"
echo ""
echo "按下回车会自动打开此目录。"
echo ""
echo "如果你改过Rime默认用户目录，手动把全部文件复制到你自定义文件夹；"
echo ""
echo "未修改目录则右键鼠须管菜单栏图标 → 重新部署 生效方案"
echo "=============================================="
echo ""
read -r
open "$RIMENEW"
exit
