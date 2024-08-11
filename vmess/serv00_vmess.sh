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

export MYDOMAIN=${USERNAME}.serv00.net



[[ "$HOSTNAME" == "s1.ct8.pl" ]] && WORKDIR="/usr/home/$USER/domains/${USERNAME}.ct8.pl/xray" || WORKDIR="/usr/home/$USER/domains/$MYDOMAIN/vmess"
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
            green "你的frps端口为: $vmess_port"
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
          pgrep -f "vmess_config.json"| grep -v grep | awk '{print $2}' | xargs kill -9
          rm -rf $WORKDIR
           echo -e "${green} 卸载完成 ${re}"
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

download_check_script(){
  local path=$(pwd)
  cd $WORKDIR
  curl -fsSL  https://raw.githubusercontent.com/sunq945/serv00-app/main/vmess/checkvmess.sh -o checkvmess.sh && chmod +x checkvmess.sh
  if [ -f "./checkvmess.sh" ];then
    echo -e "${green} 下载 checkvmess.sh 成功， 文件位置： ${purple}"$WORKDIR/checkvmess.sh" ${re}"
    echo -e "${yellow} 你可以在vps的面板上找到cron job,进去之后 点击 “ Add cron job” 添加定时任务，建议定时为3分钟（Minuts填Every 和 3 ，其他时间选项填Each Time）， 命令行填写:
    ${green}/bin/sh $WORKDIR/checkvmess.sh
    ${re}"
  else
    echo -e "${red} 下载checkvmess.sh失败,请重新下载 ${re}"
    exit 1
  fi
  cd $path
} 


# Generating Configuration Files
generate_config() {
  cat > generator.json << EOF
{
    "server":{        
        "uuid": "$UUID",
        "port":"$PORT",
        "host":"$MYDOMAIN"
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
  cat $WORKDIR/vemss_link.txt 
  echo -e "\n"
  echo -e "\n"
}
# running files
run_vmess() { 
  sleep 2
  echo -e "${green} 正在启动vmess...${re}"
  if [ -f "./xray" ] && [ -f "./vmess_config.json" ]; then
        pgrep -f "vmess_config.json" | grep -v grep | awk '{print $2}' | xargs kill -9               
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
   green "4. 下载检测脚本checkvmess.sh"
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
        4) download_check_script ;;
        5) madify_port ;;
        6) kill_all_tasks ;;
        0) exit 0 ;;
        *) red "无效的选项，请输入 0 到 6" ;;
    esac
    #done;
}
menu
