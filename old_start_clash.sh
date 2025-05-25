#!/bin/bash
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890
export NO_PROXY=localhost,127.0.0.1
tmux new-session -d -s clash '/home/lsj/Projects/Apps/clash-for-linux-without-sudo/bin/clash-linux-amd64 -d /home/lsj/Projects/Apps/clash-for-linux-without-sudo/conf 2>&1 | tee -a /home/lsj/Projects/Apps/clash-for-linux-without-sudo/logs/myclash.log'
sleep 2
/home/lsj/Projects/Apps/clash-for-linux-without-sudo/check_clash_proxy.sh