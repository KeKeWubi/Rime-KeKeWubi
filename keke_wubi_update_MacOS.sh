#!/bin/zsh
clear
echo "=============================================="
echo "      可可五笔 Rime 在线一键部署工具"
echo "代码仓库：https://github.com/KeKeWubi/Rime-KeKeWubi"
echo "=============================================="
echo ""

# 区分系统Rime目录
if [[ "$(uname)" == "Darwin" ]]; then
    RIME目录="$HOME/Library/Rime"
else
    RIME目录="$HOME/.config/rime"
fi

仓库直链="https://github.com/KeKeWubi/Rime-KeKeWubi/archive/refs/heads/main.zip"
镜像加速链接="https://mirror.ghproxy.com/$仓库直链"
压缩包="${RIME目录}/可可五笔安装包.zip"
临时解压目录="${RIME目录}/临时缓存文件夹"

mkdir -p "${RIME目录}"

echo "1. 清理旧缓存文件"
rm -rf "${临时解压目录}" "${压缩包}"

echo "2. 使用国内镜像下载源码"
curl -fsSL --insecure -o "${压缩包}" "${镜像加速链接}"
if [ $? -ne 0 ]; then
    echo "镜像超时，切换原始链接下载"
    rm -rf "${压缩包}"
    curl -fsSL --insecure -o "${压缩包}" "${仓库直链}"
    if [ $? -ne 0 ]; then
        echo "❌ 下载全部失败，请更换网络重试"
        exit 1
    fi
fi

# 校验文件不为空
if [ ! -f "${压缩包}" ] || [ ! -s "${压缩包}" ]; then
    echo "❌ 下载文件为空，网络异常"
    rm -rf "${压缩包}"
    exit 1
fi

echo "3. 解压源码包"
unzip -q "${压缩包}" -d "${临时解压目录}"
if [ ! -d "${临时解压目录}/Rime-KeKeWubi-main" ]; then
    echo "❌ 压缩包损坏，解压失败"
    rm -rf "${临时解压目录}" "${压缩包}"
    exit 1
fi

echo "4. 复制全部方案文件到Rime根目录"
cp -r "${临时解压目录}/Rime-KeKeWubi-main/"* "${RIME目录}/"

echo "5. 清理临时文件"
rm -rf "${临时解压目录}" "${压缩包}"

echo ""
echo "=============================================="
echo "✅ 可可五笔配置文件已拷贝到本地的 Rime 根目录！"
echo "目录路径：~/Library/Rime"
echo "请打开鼠须管，执行重新部署生效方案"
echo "=============================================="
open "${RIME目录}"