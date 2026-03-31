#!/bin/bash

# 自定义action函数，实现通用action功能
success() {
  echo -en "\\033[60G[\\033[1;32m  OK  \\033[0;39m]\r"
  return 0
}

failure() {
  local rc=$?
  echo -en "\\033[60G[\\033[1;31mFAILED\\033[0;39m]\r"
  [ -x /bin/plymouth ] && /bin/plymouth --details
  return $rc
}

action() {
  local STRING rc

  STRING=$1
  echo -n "$STRING "
  shift
  "$@" && success $"$STRING" || failure $"$STRING"
  rc=$?
  echo
  return $rc
}

# 函数，判断命令是否正常执行
if_success() {
  local ReturnStatus=$3
  if [ $ReturnStatus -eq 0 ]; then
          action "$1" /bin/true
  else
          action "$2" /bin/false
          exit 1
  fi
}

# 定义路劲变量
Server_Dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
Conf_Dir="$Server_Dir/conf"
Log_Dir="$Server_Dir/logs"

## 关闭clash服务
Text1="服务关闭成功！"
Text2="服务关闭失败！"

# 获取当前用户名
CURRENT_USER=$(whoami)

# 查询当前用户的 Clash 进程
PID_NUM=$(ps -ef | grep "[c]lash-linux-a" | grep "$CURRENT_USER" | wc -l)

if [ $PID_NUM -ne 0 ]; then
	echo "发现 $PID_NUM 个 Clash 进程，正在停止..."
	# 停止当前用户的所有 Clash 进程
	pkill -u "$CURRENT_USER" -f clash-linux-amd64
	sleep 2

	# 检查是否还有进程在运行
	PID_NUM=$(ps -ef | grep "[c]lash-linux-a" | grep "$CURRENT_USER" | wc -l)
	if [ $PID_NUM -ne 0 ]; then
		echo "尝试强制停止..."
		pkill -9 -u "$CURRENT_USER" -f clash-linux-amd64
		sleep 1
	fi

	ReturnStatus=0
else
	echo "没有发现运行中的 Clash 进程"
	ReturnStatus=0
fi

if_success $Text1 $Text2 $ReturnStatus

sleep 3

## 获取CPU架构
if /bin/arch &>/dev/null; then
	CpuArch=`/bin/arch`
elif /usr/bin/arch &>/dev/null; then
	CpuArch=`/usr/bin/arch`
elif /bin/uname -m &>/dev/null; then
	CpuArch=`/bin/uname -m`
else
	echo -e "\033[31m\n[ERROR] Failed to obtain CPU architecture！\033[0m"
	exit 1
fi

## 重启启动clash服务
Text5="服务启动成功！"
Text6="服务启动失败！"
if [[ $CpuArch =~ "x86_64" ]]; then
	nohup $Server_Dir/bin/clash-linux-amd64 -d $Conf_Dir &> $Log_Dir/clash.log &
	ReturnStatus=$?
	if_success $Text5 $Text6 $ReturnStatus
elif [[ $CpuArch =~ "aarch64" ||  $CpuArch =~ "arm64" ]]; then
	nohup $Server_Dir/bin/clash-linux-arm64 -d $Conf_Dir &> $Log_Dir/clash.log &
	ReturnStatus=$?
	if_success $Text5 $Text6 $ReturnStatus
elif [[ $CpuArch =~ "armv7" ]]; then
	nohup $Server_Dir/bin/clash-linux-armv7 -d $Conf_Dir &> $Log_Dir/clash.log &
	ReturnStatus=$?
	if_success $Text5 $Text6 $ReturnStatus
else
	echo -e "\033[31m\n[ERROR] Unsupported CPU Architecture！\033[0m"
	exit 1
fi

