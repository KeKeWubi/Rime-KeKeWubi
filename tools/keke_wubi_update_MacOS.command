#!/bin/bash
# 可可五笔 Rime - MacOS 全自动更新工具
# 对应Windows批处理完整逻辑移植

clear
echo "=============================================="
echo "        可可五笔 Rime - MacOS全自动更新工具"
echo "=============================================="
echo ""

# ====================== 路径配置 ======================
RIMENEW="$HOME/Library/Rime"
ZIP_TEMP="${TMPDIR}KeKeWubi.zip"
TMP_DIR="${TMPDIR}tmp_keke"
UA="Chrome/120.0.0.0 MacOS/14.0"

# ====================== 备份提醒 ======================
echo "重要提醒！更新会清空Rime目录全部旧配置文件"
echo ""
echo " ⚠️ 若修改了鼠须管「用户文件夹」位置，更新完成后需要手动把文件复制到自定义目录！"
echo ""
echo " ⚠️ 个人词库文件（如 keke_wubi_86_user.dict.yaml）请提前备份！"
echo ""
echo " ⚠️ 下载校验通过后会清空全部旧Rime文件，确认已备份再继续！"
echo ""
echo "按回车键继续更新；直接关闭窗口退出"
read -r
echo ""
echo "已确认，开始执行更新流程..."
echo ""

# ====================== 双下载源（同一个zip文件） ======================
ZIP_GITHUB="https://github.com/KeKeWubi/Rime-KeKeWubi/archive/refs/heads/main.zip"
ZIP_OFFICIAL="https://keke.kim/DownLoad/Rime-KeKeWubi-main.zip"

# 新建Rime目录（不存在则创建）
mkdir -p "$RIMENEW"

echo "1. 清理系统缓存旧临时文件"
rm -rf "$TMP_DIR" 2>/dev/null
rm -f "$ZIP_TEMP" 2>/dev/null

echo "2. 优先从GitHub下载源码包至系统临时目录..."
# curl 下载，携带UA
curl -fsSL --insecure -A "$UA" -o "$ZIP_TEMP" "$ZIP_GITHUB"
if [ $? -ne 0 ]; then
    echo "警告：GitHub下载失败，自动切换可可五笔官网备用通道..."
    rm -f "$ZIP_TEMP" 2>/dev/null
    curl -fsSL --insecure -A "$UA" -o "$ZIP_TEMP" "$ZIP_OFFICIAL"

    # 校验官网下载文件存在且大于0字节
    if [ -f "$ZIP_TEMP" ]; then
        FILESIZE=$(stat -f%z "$ZIP_TEMP")
        if [ "$FILESIZE" -gt 0 ]; then
            echo "可可五笔官网通道下载成功"
        else
            echo "错误：官网下载得到空文件，网络异常"
            echo "手动下载地址：$ZIP_OFFICIAL"
            read -p "按回车退出..."
            exit 1
        fi
    else
        echo "错误：官网下载失败，未生成压缩包"
        echo "GitHub源：$ZIP_GITHUB"
        echo "官网源：$ZIP_OFFICIAL"
        read -p "按回车退出..."
        exit 1
    fi
else
    echo "GitHub下载成功"
fi

# ====================== 压缩包校验 ======================
echo ""
echo "3. 校验压缩包完整性"
if [ ! -f "$ZIP_TEMP" ]; then
    echo "错误：压缩包丢失，下载异常"
    read -p "按回车退出..."
    exit 1
fi
FILESIZE=$(stat -f%z "$ZIP_TEMP")
if [ "$FILESIZE" -eq 0 ]; then
    echo "错误：压缩包为空，下载中断"
    rm -f "$ZIP_TEMP"
    read -p "按回车退出..."
    exit 1
fi

# ====================== 清空原有Rime目录 ======================
echo "校验通过，清空Rime目录全部原有内容"
find "$RIMENEW" -mindepth 1 -delete
echo "   Rime旧文件清理完成，目录干净无残留"
echo ""

# ====================== 解压压缩包 ======================
echo "4. 在系统缓存目录解压压缩包"
rm -rf "$TMP_DIR" 2>/dev/null
mkdir -p "$TMP_DIR"
unzip -q "$ZIP_TEMP" -d "$TMP_DIR"

# 校验解压后的目录结构（固定Rime-KeKeWubi-main文件夹）
if [ ! -d "$TMP_DIR/Rime-KeKeWubi-main" ]; then
    echo "错误：压缩包损坏，解压失败"
    rm -f "$ZIP_TEMP"
    rm -rf "$TMP_DIR"
    read -p "按回车退出..."
    exit 1
fi

# ====================== 复制文件到Rime ======================
echo "5. 将全部配置文件复制到Rime根目录"
cp -R "$TMP_DIR/Rime-KeKeWubi-main/"* "$RIMENEW/"

# ====================== 清理临时文件 ======================
echo "6. 清理系统全部临时文件"
rm -rf "$TMP_DIR"
rm -f "$ZIP_TEMP"

# ====================== 完成提示 ======================
echo ""
echo "=============================================="
echo "✅ 可可五笔配置文件已部署至目录：$RIMENEW"
echo ""
echo "按回车键自动打开Rime配置文件夹"
echo ""
echo "修改过自定义用户目录的，手动复制全部文件到自定义文件夹；"
echo "未修改目录：打开鼠须管（Squirrel）托盘 → 重新部署 即可生效"
echo "=============================================="
echo ""
read -r
open "$RIMENEW"
exit 0