#!/bin/bash

echo "正在停止 Clash 服务..."

# 清除代理环境变量
unset HTTP_PROXY
unset HTTPS_PROXY
unset NO_PROXY
unset http_proxy
unset https_proxy
unset no_proxy

# 获取当前用户名
CURRENT_USER=$(whoami)

# 停止当前用户的 Clash 进程
pkill -u "$CURRENT_USER" -f clash-linux-amd64

# 等待进程完全停止
sleep 2

# 检查是否还有进程在运行
if ps aux | grep "[c]lash-linux-amd64" | grep -q "$CURRENT_USER"; then
    echo "警告: 还有 Clash 进程在运行，尝试强制停止..."
    pkill -9 -u "$CURRENT_USER" -f clash-linux-amd64
    sleep 1
fi

# 最终检查
if ps aux | grep "[c]lash-linux-amd64" | grep -q "$CURRENT_USER"; then
    echo "❌ Clash 进程停止失败"
    ps aux | grep "[c]lash-linux-amd64" | grep "$CURRENT_USER"
    exit 1
else
    echo "✅ Clash 服务已停止"
fi
