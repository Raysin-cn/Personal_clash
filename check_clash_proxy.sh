#!/bin/bash

echo "开始验证 Clash 代理配置..."

# 检查代理端口是否在监听
if netstat -tuln | grep ":7890" > /dev/null; then
    echo "✅ 代理端口 7890 正在监听"
else
    echo "❌ 代理端口 7890 未在监听"
    exit 1
fi

# 检查 API 端口是否在监听
if netstat -tuln | grep ":9090" > /dev/null; then
    echo "✅ API 端口 9090 正在监听"
else
    echo "❌ API 端口 9090 未在监听"
    exit 1
fi

# 设置临时代理环境变量
export http_proxy="http://127.0.0.1:7890"
export https_proxy="http://127.0.0.1:7890"

# 测试代理连接
echo "正在测试代理连接..."
if curl -s -m 10 https://www.google.com > /dev/null; then
    echo "✅ 代理连接测试成功"
else
    echo "❌ 代理连接测试失败"
    exit 1
fi

# 获取当前 IP 地址
echo "当前 IP 地址信息："
curl -s http://ip-api.com/json | python3 -m json.tool

# 清除代理环境变量
unset http_proxy https_proxy

echo "验证完成！" 