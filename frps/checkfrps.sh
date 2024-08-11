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
appname="frps"



printLog(){
    local time=$(date "+%Y-%m-%d %H:%M:%S")
    local log_str="[${time}]:$1"    
    local FILE=$BASH_SOURCE
    local filename=$(basename $FILE .sh)
    echo "$log_str" >> ~/$filename.log
}

WORKDIR="/usr/home/$USER/domains/${USERNAME}.serv00.net/frps"

# running files
run_vless() { 
  if [ -f "./frps" ] && [ -f "./frps.toml" ]; then  
      nohup ./frps -c ./frps.toml >/dev/null 2>&1 &
  else
    msg="frps or frps.toml is not exist,skiping runing"
    purple "$msg"
    printStatus "$msg"
  fi
}
printStatus(){
  printLog "$appname status: $1 "
}

main(){
    cd $WORKDIR
    result=$(pgrep -f "frps" 2> /dev/null)
    if [ -z ${result} ]; then
      red "frps is not running, restarting..."
      pkill -f "frps" 
      run_vless 
      sleep 2
      pgrep -f "frps" >/dev/null && { green "frps restart ok"; printStatus "restart ok" ;} || { purple "frps restart failed";  printStatus "restart failed"; }
  
    else
      green "frps is running"
      printStatus "running" 
    fi;    
    
}

main "$@"
