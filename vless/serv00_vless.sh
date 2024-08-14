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


HOSTNAME=$(hostname)

export MYDOMAIN=$USER.serv00.net

CFG_ENCRYPTION="none" 
CFG_SECURITY="none"
CFG_TYPE="ws"
CFG_HOST="www.bing.com"
CFG_PATH="/?proxyip=proxyip.oracle.fxxk.dedyn.io"
CFG_REMARKS="serv00_vless"



SERVER_TYPE=$(echo $HOSTNAME | awk -F'.' '{print $2}')

if [ $SERVER_TYPE == "ct8" ];then
    DOMAIN=$USER.ct8.pl
elif [ $SERVER_TYPE == "serv00" ];then
    DOMAIN=$USER.serv00.net
else
    DOMAIN="unknown-domain"
fi




[[ "$HOSTNAME" == "s1.ct8.pl" ]] && WORKDIR="/usr/home/$USER/domains/$DOMAIN/vless" || WORKDIR="/usr/home/$USER/domains/$DOMAIN/vless"
[ -d "$WORKDIR" ] || (mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR")

UUID_FILE="$WORKDIR/.vless_uuid"  # Define a location to store the UUID

# Check if UUID file exists
if [ -f "$UUID_FILE" ]; then
    export UUID=$(cat "$UUID_FILE")  # Read the existing UUID
else
    export UUID=$(uuidgen)  # Generate a new UUID
    echo "$UUID" > "$UUID_FILE"  # Save the UUID to the file
fi



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

read_vless_port() {
    while true; do
        reading "请输入vless端口 (面板开放的tcp端口): " vless_port
        if [[ "$vless_port" =~ ^[0-9]+$ ]] && [ "$vless_port" -ge 1 ] && [ "$vless_port" -le 65535 ]; then
            green "你的vmess端口为: $vless_port"
            export PORT=$vless_port
            break
        else
            yellow "输入错误，请重新输入面板开放的TCP端口"
        fi
    done
}

install_vless() {
echo -e "${yellow}本脚本只安装vless协议代理服务器和启动脚本${re}"
echo -e "${yellow}开始运行前，请确保在面板${purple}已开放一个tcp端口${re}"
echo -e "${yellow}面板${purple}Additional services${yellow}中的${purple}Run your own applications${yellow}已开启为${purplw}Enabled${yellow}状态${re}"
reading "\n确定继续安装吗？【y/n】: " choice
  case "$choice" in
    [Yy])
        cd $WORKDIR
        read_vless_port
        generate_config
        download_vless && wait
        get_links
        run_vless && sleep 3
        
      ;;
    [Nn]) exit 0 ;;
    *) red "无效的选择，请输入y或n" && menu ;;
  esac
}

uninstall_vless() {
  reading "\n确定要卸载吗？【y/n】: " choice
    case "$choice" in
       [Yy])
          ps aux | grep app.js | grep -v grep | awk '{print $2}' | xargs kill -9
          rm -rf $WORKDIR /usr/home/$USER/logs/checkvless.log
          echo -e "${green} 卸载成功${re}"          
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
download_vless() {
  echo -e "${yellow} 下载vless.zip: ${re}"
  $(wget https://raw.githubusercontent.com/sunq945/serv00-app/main/vless/vless.zip -O vless.zip)
  if [ -f "./vless.zip" ];then
    echo -e "${green} 下载vless.zip成功，正在解压...${re}"  
    unzip -q vless.zip
    echo -e "${green} 解压完毕${re}"
    rm -rf vless.zip
    echo -e "${yellow} vless.zip is removed.${re}"
  else
    echo -e "${red} 下载vless.zip失败 ${re}"
 fi
}

CRON_CMD="/bin/sh $WORKDIR/checkvless.sh" 

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
  if [ ! -f ./checkvless.sh ];then  
  echo -e "${green} 正在下载 checkvless.sh  ${re}"
  curl -fsSL  https://raw.githubusercontent.com/sunq945/serv00-app/main/vless/checkvless.sh -o checkvless.sh && chmod +x checkvless.sh 
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

# Generating Configuration Files
generate_config() {

IP=$(get_ip)

  cat > vless_config.json << EOF
{
    "server":{
        "listen_port": $PORT,
        "uuid": "$UUID"
    },
    "client":{        
        "uuid": "$UUID",
        "addr":"$IP",
        "port":$PORT,     
        "encryption":"$CFG_ENCRYPTION",
        "security":"$CFG_SECURITY",
        "type":"$CFG_TYPE",
        "host":"$CFG_HOST",
        "path":"$CFG_PATH",
        "remarks":"$CFG_REMARKS"
    }
}
EOF
}

# running files
run_vless() { 
    sleep 3
  if [ -f "./vless/app.js" ]; then
        pgrep -f "vless/app.js" | grep -v grep | xargs kill -9       
        nohup node ./vless/app.js  >/dev/null 2>&1 &
        sleep 3
        pgrep -f "vless/app.js" > /dev/null && green "vless is running" || { red "vless is not running, failed!" ;}
  else
        purple "vless/app.js is not exist,skiping runing"
  fi
}

urlencode() {
  LC_ALL=C awk -- '
    BEGIN {
      for (i = 1; i <= 255; i++) hex[sprintf("%c", i)] = sprintf("%%%02X", i)
    }
    function urlencode(s,  c,i,r,l) {
      l = length(s)
      for (i = 1; i <= l; i++) {
        c = substr(s, i, 1)
        r = r "" (c ~ /^[-._~0-9a-zA-Z]$/ ? c : hex[c])
      }
      return r
    }
    BEGIN {
      for (i = 1; i < ARGC; i++)
        print urlencode(ARGV[i])
    }' "$@"
}


get_links(){
cat > vless_link.txt <<EOF
vless://$(echo "$UUID@$IP:$PORT?encryption=$CFG_ENCRYPTION&security=$CFG_SECURITY&type=$CFG_TYPE&host=$CFG_HOST&path=$(urlencode $CFG_PATH)#$CFG_REMARKS")
EOF
echo -e "${green} 已生成vless节点，链接如下： ${re}"
cat vless_link.txt

purple "节点信息已经保存到 $WORKDIR/vless_link.txt"

}

madify_port(){
  local path=$(pwd)
  cd $WORKDIR
  read_vless_port
  rm -f vless_config.json
  generate_config
  get_links
  run_vless && sleep 3   
}

#主菜单
menu() {
   clear
   echo ""
   purple "============ vless一键安装脚本 =======\n"
   echo -e "${green}脚本地址：${re}${yellow}https://github.com/sunq945/serv00-app/tree/main/vless${re}\n"
   purple "转载请注明出处，请勿滥用\n"
   green "1. 安装vless"
   echo  "================================="
   red "2. 卸载vless"
   echo  "================================="
   green "3. 查看节点信息"
   echo  "================================="
   green "4. 设置定时检测运行状态？"
   echo  "================================="
   yellow "5. 修改端口"
   echo  "=================================" 
   yellow "6. 清理所有进程"
   echo  "================================="
   red "0. 退出脚本"
   echo  "================================="
   reading "请输入选择(0-6): " choice
   echo ""
    case "${choice}" in
        1) install_vless ;;
        2) uninstall_vless ;; 
        3) cat $WORKDIR/vless_link.txt ;; 
	      4) create_cron ;;  
        5) madify_port ;;      
	      5) kill_all_tasks ;;
        0) exit 0 ;;
        *) red "无效的选项，请输入 0 到 6" ;;
    esac
}
menu
