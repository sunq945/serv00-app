#!/bin/bash

# 定义颜色
re="\033[0m"
red="\033[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"
red() { echo -e "\e[1;91m$1\033[0m"; }
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }
reading() { read -p "$(red "$1")" "$2"; }
USERNAME=$(whoami)
HOSTNAME=$(hostname)


BASH_SOURCE="$0"
appname="vmess"
LOGS_DIR="/usr/home/$USER/logs"
[ -d "$LOGS_DIR" ] || (mkdir -p "$LOGS_DIR" && chmod 777 "$LOGS_DIR")

printLog(){
    local time=$(date "+%Y-%m-%d %H:%M:%S")
    local log_str="[${time}]:$1"    
    local FILE=$BASH_SOURCE
    local filename=$(basename $FILE .sh)
    echo "$log_str" >> $LOGS_DIR/$filename.log
}

WORKDIR="/usr/home/$USER/domains/${USERNAME}.serv00.net/vmess"
# running files
run_vless() { 
  if [ -f "./xray" ] && [ -f "./vmess_config.json" ]; then
      nohup ./xray -c vmess_config.json >/dev/null 2>&1 &
  else
    msg="xray or config.json is not exist,skiping runing"
    purple "$msg"
    printStatus "$msg"
  fi
}

printStatus(){
  printLog "$appname status: $1 "
}

main(){
    cd $WORKDIR
    result=$(pgrep -f "vmess_config.json" 2> /dev/null)
    if [ -z ${result} ]; then
      red "vmess is not running, restarting..."
      pkill -f "vmess_config.json" 
      run_vless 
      sleep 2
      pgrep -f "vmess_config.json" >/dev/null && { green "vmess restart ok"; printStatus "restart ok" ;} || { purple "vmess restart failed";  printStatus "restart failed"; }
  
    else
      green "vmess is running"
      printStatus "running" 
    fi;    
    
}

main "$@"
