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

SERVER_TYPE=$(echo $HOSTNAME | awk -F'.' '{print $2}')

if [ $SERVER_TYPE == "ct8" ];then
    DOMAIN=$USER.ct8.pl
elif [ $SERVER_TYPE == "serv00" ];then
    DOMAIN=$USER.serv00.net
else
    DOMAIN="unknown-domain"
fi

[[ $SERVER_TYPE == "ct8" ]] && WORKDIR="/usr/home/$USER/domains/$DOMAIN/vmess" || WORKDIR="/usr/home/$USER/domains/$DOMAIN/vmess"
[ -d "$WORKDIR" ] || (mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR")



UUID_FILE="$WORKDIR/.vmess_uuid"  # Define a location to store the UUID

# Check if UUID file exists
if [ -f "$UUID_FILE" ]; then
    export UUID=$(cat "$UUID_FILE")  # Read the existing UUID
else
    export UUID=$(uuidgen)  # Generate a new UUID
    echo "$UUID" > "$UUID_FILE"  # Save the UUID to the file
fi


read_vmess_port() {
    while true; do
        reading "请输入服务器端口 (面板开放的tcp端口): " vmess_port
        if [[ "$vmess_port" =~ ^[0-9]+$ ]] && [ "$vmess_port" -ge 1 ] && [ "$vmess_port" -le 65535 ]; then
            green "你的vmess端口为: $vmess_port"
            export PORT=$vmess_port
            break
        else
            yellow "输入错误，请重新输入面板开放的TCP端口"
        fi
    done
}


install_vmess() {
echo -e "${yellow}本脚本只安装frps穿透代理服务器和启动脚本${re}"
echo -e "${yellow}开始运行前，请确保在面板${purple}已开放1个tcp端口${re}"
echo -e "${yellow}面板${purple}Additional services${yellow}中的${purple}Run your own applications${yellow}已开启为${purplw}Enabled${yellow}状态${re}"
reading "\n确定继续安装吗？【y/n】: " choice
  case "$choice" in
    [Yy])
        cd $WORKDIR
        read_vmess_port     
        download_xray_core && wait
        generate_config        
        run_vmess && sleep 3   
      ;;
    [Nn]) exit 0 ;;
    *) red "无效的选择，请输入y或n" && menu ;;
  esac
}

uninstall_vmess() {
  reading "\n确定要卸载吗？【y/n】: " choice
    case "$choice" in
       [Yy])
          pgrep -f "vmess_config.json" | grep -v grep | xargs kill -9  
          rm -rf $WORKDIR /usr/home/$USER/logs/checkvmess.log
           echo -e "${green} 卸载完成 ${re}"
          del_cron
          green "已取消定时检测运行状态"
          ;;
        [Nn]) exit 0 ;;
    	*) red "无效的选择，请输入y或n" && menu ;;
    esac
}

kill_all_tasks() {
reading "\n清理所有进程将退出ssh连接，确定继续清理吗？【y/n】: " choice
  case "$choice" in
    [Yy]) killall -9 -u $(whoami) ;;
       *) menu ;;
  esac
}


# Download Dependency Files
download_xray_core() {
  local file_name="Xray-freebsd-64.zip"
  echo -e "${yellow} 下载xray-core( $file_name ): ${re}"
  curl -sL -o $file_name https://github.com/XTLS/Xray-core/releases/latest/download/Xray-freebsd-64.zip
  if [ -f "./$file_name" ];then
    echo -e "${green} 下载 $file_name 成功，正在解压...${re}"
    unzip -o $file_name | awk 'BEGIN {ORS=" "} {print "."}'  
    echo -e "${green} 解压完毕${re}"
    chmod +x xray
    rm -rf $file_name
    echo -e "${yellow} $file_name 已删除.${re}"
  else
    echo -e "${red} 下载 $file_name 失败 ${re}"
    exit 1
 fi

  echo -e "${yellow}正在下载generator.js${re}"
  curl -fsSL  https://raw.githubusercontent.com/sunq945/serv00-app/main/vmess/generator.js -o generator.js 
  
  if [ -f "./generator.js" ];then
    echo -e "${green} 下载 generator.js 成功${re}"
  else
    echo -e "${red} 下载 generator.js  失败 ${re}"
    exit 1
 fi
}

CRON_CMD="/bin/sh $WORKDIR/checkvmess.sh" 

get_timer() {
    while true; do
        reading "请输入定时分钟数(0~59,${yellow}注意：输入0则取消定时${re}${red}): " time_out
        if [[ "$time_out" =~ ^[0-9]+$ ]] && [ "$time_out" -ge -1 ] && [ "$time_out" -le 60 ]; then
            green "你的定时分钟数为: $time_out"
            if [ $time_out == "0" ];then
              yellow "如果您已经设置过定时，以下即将为您取消定时检测运行状态"
            fi
            break
        else
            yellow "输入错误，请重新输入分钟数(0~59)"
        fi
    done
}


del_cron(){
  (crontab -l | grep -v -F "* * $CRON_CMD")| crontab -
}

add_cron(){
  (crontab -l; echo "*/$time_out * * * * $CRON_CMD") | crontab -
}

create_cron(){
  local path=$(pwd)  
  cd $WORKDIR
  get_timer  
  if [ ! -f ./checkvmess.sh ];then  
  echo -e "${green} 正在下载 checkvmess.sh  ${re}"
  curl -fsSL  https://raw.githubusercontent.com/sunq945/serv00-app/main/vmess/checkvmess.sh -o checkvmess.sh && chmod +x checkvmess.sh
  fi

  cron_record=$(crontab -l | grep -F "* * $CRON_CMD")
  if [ -z "$cron_record" ];then
    if [ $time_out != "0" ];then
      add_cron
      green "设置定时检测运行状态成功"
    fi
  else
    #echo $cron_record
    if [  $time_out != "0" ];then
      r_time=$(echo ${cron_record:2}| awk -F' ' '{print $1}')
      if [ $r_time != $time_out ] ;then        
        del_cron
        add_cron
        green "修改定时检测运行状态成功"
      fi
    else
      del_cron
      green "取消定时检测运行状态成功"
    fi

  fi
  cd $path
} 


get_ip() {
ip=$(curl -s --max-time 2 ipv4.ip.sb)
if [ -z "$ip" ]; then
    if [[ "$HOSTNAME" =~ s[0-9]\.serv00\.com ]]; then
        ip=${HOSTNAME/s/web}
    else
        ip="$HOSTNAME"
    fi
fi
echo $ip
}

# Generating Configuration Files
generate_config() {

IP=$(get_ip)

  cat > generator.json << EOF
{
    "server":{        
        "uuid": "$UUID",
        "port":"$PORT",
        "host":"$IP"
    }
}
EOF

echo -e "${green} 已保存uuid和端口号到:$(pwd)/generator.json ${re}"

  if [ ! -f "./generator.js" ];then
    echo -e "${yellow}正在下载generator.js${re}"
    curl -fsSL  https://raw.githubusercontent.com/sunq945/serv00-app/main/vmess/generator.js -o generator.js 
    echo -e "${green} 下载 generator.js 完毕${re}"
  fi;

  if [ -f "./generator.js" ];then
      echo -e "${green} 即将生成配置信息${re}"
      node generator.js
  else
    echo -e "${red} 下载 generator.js  失败 ${re}"
    exit 1
  fi;     
}

show_link(){
  cat $WORKDIR/vmess_link.txt 
  echo -e "\n"
  echo -e "\n"
}
# running files
run_vmess() { 
  sleep 2
  echo -e "${green} 正在启动vmess...${re}"
  if [ -f "./xray" ] && [ -f "./vmess_config.json" ]; then
        pgrep -f "vmess_config.json" | grep -v grep | xargs kill -9               
        nohup ./xray -c vmess_config.json >/dev/null 2>&1 &
        sleep 3
        pgrep -f "vmess_config.json"> /dev/null && green "vmess is running" || { red "vmess is not running, failed!" ;}
  else
        purple "xray or vmess_config.json is not exist,skiping runing"
  fi
}

madify_port(){
  local path=$(pwd)
  cd $WORKDIR
  read_vmess_port
  rm -f generator.json
  generate_config
  run_vmess && sleep 3   
}


#主菜单
menu() {
   clear
   #while true;do
   echo ""
   purple "============ vmess 一键安装脚本 =======\n"
   echo -e "${green}脚本地址：${re}${yellow}https://github.com/sunq945/serv00-app/tree/main/vmess${re}\n"
   purple "转载请注明出处，请勿滥用\n"
   green "1. 安装vmess"
   echo  "=============================="
   red "2. 卸载vmess"
   echo  "=============================="
   green "3. 查看节点信息"
   echo  "=============================="
   green "4. 设置定时检测运行状态？"
   echo  "=============================="
   yellow "5. 修改端口"  
   echo  "=============================="
   yellow "6. 清理所有进程"
   echo  "=============================="
   red "0. 退出脚本"
   echo  "=============================="
   reading "请输入选择(0-6): " choice
   echo ""
    case "${choice}" in
        1) install_vmess ;;
        2) uninstall_vmess ;; 
        3) show_link ;; 
        4) create_cron ;;
        5) madify_port ;;
        6) kill_all_tasks ;;
        0) exit 0 ;;
        *) red "无效的选项，请输入 0 到 6" ;;
    esac
    #done;
}
menu
