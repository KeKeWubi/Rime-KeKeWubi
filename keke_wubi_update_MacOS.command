#!/bin/zsh
export LANG=en_US.UTF-8
clear

echo "=============================================="
echo "        可可五笔 Rime Mac 一键部署更新工具"
echo "=============================================="
echo ""

# ====================== 词库备份确认 ======================
echo "⚠️ 重要提醒！更新会覆盖 Rime 目录配置文件"
echo ""
echo "  若你修改过个人词库（例如，86版五笔：keke_wubi_86_user.dict.yaml）"
echo "  请先手动进入目录备份词库文件："
echo "  ~/Library/Rime"
echo ""
echo "  确认已完成词库备份，按回车键继续；直接关闭窗口可退出更新"
echo ""
read "?按回车确认备份完毕..."
echo ""
echo "已确认备份完成，开始执行更新流程..."
echo ""
# ==========================================================

# 路径配置
RIME="$HOME/Library/Rime"
ZIP_RAW="https://github.com/KeKeWubi/Rime-KeKeWubi/archive/refs/heads/main.zip"
ZIP_MIRROR="https://mirror.ghproxy.com/$ZIP_RAW"
DOWNLOAD_ZIP="$RIME/KeKeWubi.zip"
TMP_DIR="$RIME/tmp_keke"

# 创建Rime文件夹
mkdir -p "$RIME"

echo "1. 清理历史临时缓存文件"
rm -rf "$TMP_DIR" 2>/dev/null
rm -f "$DOWNLOAD_ZIP" 2>/dev/null

echo "2. 优先使用GH镜像下载源码包..."
curl -fsSL --insecure -o "$DOWNLOAD_ZIP" "$ZIP_MIRROR"
# 替代goto，用if判断下载结果
if [ $? -ne 0 ]; then
    echo "镜像连接超时，切换原生GitHub直链重试..."
    rm -f "$DOWNLOAD_ZIP" 2>/dev/null
    curl -fsSL --insecure -o "$DOWNLOAD_ZIP" "$ZIP_RAW"
    if [ $? -ne 0 ]; then
        echo "❌ 镜像与原生地址均下载失败，请检查网络或切换手机热点重试"
        read "?按回车关闭窗口"
        exit 1
    fi
fi

# 校验压缩包存在且不为空
echo "3. 校验下载文件完整性"
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

echo "4. 解压压缩包至临时目录"
unzip -q -o "$DOWNLOAD_ZIP" -d "$TMP_DIR"
if [ ! -d "$TMP_DIR/Rime-KeKeWubi-main" ]; then
    echo "❌ 压缩包损坏，解压失败"
    rm -f "$DOWNLOAD_ZIP"
    rm -rf "$TMP_DIR" 2>/dev/null
    read "?按回车关闭窗口"
    exit 1
fi

echo "5. 将仓库全部文件复制到Rime根目录（覆盖旧文件）"
cp -R "$TMP_DIR/Rime-KeKeWubi-main/"* "$RIME/"

echo "6. 清理临时文件夹与压缩包"
rm -rf "$TMP_DIR"
rm -f "$DOWNLOAD_ZIP"

echo ""
echo "=============================================="
echo "✅ 可可五笔配置文件已拷贝至本地 Rime 目录！"
echo "目录路径：$HOME/Library/Rime"
echo "操作提示：点击顶部菜单栏鼠须管图标 → 重新部署 生效配置"
echo "=============================================="
echo ""

read "?按回车打开Rime配置目录"
open "$RIME"
exit 0
