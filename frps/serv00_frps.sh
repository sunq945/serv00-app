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

[[ "$HOSTNAME" == "s1.ct8.pl" ]] && WORKDIR="/usr/home/$USER/domains/${USERNAME}.ct8.pl/proxy" || WORKDIR="/usr/home/$USER/domains/$MYDOMAIN/frps"
[ -d "$WORKDIR" ] || (mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR")


read_host_port() {
    while true; do
        reading "请输入服务器端口 (面板开放的tcp端口): " host_port
        if [[ "$host_port" =~ ^[0-9]+$ ]] && [ "$host_port" -ge 1 ] && [ "$host_port" -le 65535 ]; then
            green "你的frps端口为: $host_port"
            export HOST_PORT=$host_port
            break
        else
            yellow "输入错误，请重新输入面板开放的TCP端口"
        fi
    done
}

read_forward_port() {
    while true; do
        reading "请输入转发端口 (面板开放的TCP端口): " forward_port
        if [[ "$forward_port" =~ ^[0-9]+$ ]] && [ "$forward_port" -ge 1 ] && [ "$forward_port" -le 65535 ]; then
            green "你的转发端口为: $forward_port"
            export FORWARD_PORT=$forward_port
            break
        else
            yellow "输入错误，请重新输入面板开放的TCP端口"
        fi
    done
}

read_token() {
    while true; do
        reading "请输入您要设置的连接密码: " token
        if [[ -n "$token" ]] ; then
            green "请输入的token为: $token"
            export TOKEN=$token
            break
        else
            yellow "输入为空，请重新输入"
        fi
    done
}


install_frps() {
echo -e "${yellow}本脚本只安装frps穿透代理服务器和启动脚本${re}"
echo -e "${yellow}开始运行前，请确保在面板${purple}已开放2个tcp端口${re}"
echo -e "${yellow}面板${purple}Additional services${yellow}中的${purple}Run your own applications${yellow}已开启为${purplw}Enabled${yellow}状态${re}"
reading "\n确定继续安装吗？【y/n】: " choice
  case "$choice" in
    [Yy])
        cd $WORKDIR
        read_host_port
        read_forward_port
        read_token        
        download_frps && wait
        generate_config        
        run_frps && sleep 3        
      ;;
    [Nn]) exit 0 ;;
    *) red "无效的选择，请输入y或n" && menu ;;
  esac
}

uninstall_frps() {
  reading "\n确定要卸载吗？【y/n】: " choice
    case "$choice" in
       [Yy])
          ps aux | grep "frps" | grep -v grep | awk '{print $2}' | xargs kill -9
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
download_frps() {
  echo -e "${yellow} 下载frps安装包(frp_freebsd_amd64.tar.gz ): ${re}"

  release_info=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest)
  download_url=$(echo "$release_info" | jq -r '.assets[] | select(.name | contains("freebsd_amd64.tar.gz")) | .browser_download_url')

  curl -L "$download_url" -o frp_freebsd_amd64.tar.gz 

  if [ -f "./frp_freebsd_amd64.tar.gz" ];then
    echo -e "${green} 下载frp_freebsd_amd64.tar.gz 成功，正在解压...${re}"
    tar -xzvf frp_freebsd_amd64.tar.gz --strip-components=1
    echo -e "${green} 解压完毕${re}"
    rm -rf frp_freebsd_amd64.tar.gz
    echo -e "${yellow} frp_freebsd_amd64.tar.gz 已删除.${re}"
  else
    echo -e "${red} 下载 frp_freebsd_amd64.tar.gz 失败 ${re}"
 fi
}

download_check_script(){
  local path=$(pwd)
  cd $WORKDIR
  curl -fsSL  https://raw.githubusercontent.com/sunq945/serv00-app/main/frps/checkfrps.sh -o checkfrps.sh && chmod +x checkfrps.sh 
  if [ -f "./checkfrps.sh" ];then
    echo -e "${green} 下载 checkfrps.sh 成功， 文件位置： ${purple}"$WORKDIR/checkfrps.sh" ${re}"
    echo -e "${yellow} 你可以在vps的面板上找到cron job,进去之后 点击 “ Add cron job” 添加定时任务，建议定时为3分钟（Minuts填Every 和 3 ，其他时间选项填Each Time）， 命令行填写:
    ${green}/bin/sh $WORKDIR/checkfrps.sh
    ${re}"
  else
    echo -e "${red} 下载checkfrps.sh失败,请重新下载 ${re}"
  fi
  cd $path
} 


# Generating Configuration Files
generate_config() {
  echo -e "${yellow} 正在生成配置文件${re}"
  cat > frps.toml << EOF 
bindPort = $HOST_PORT 
vhostHTTPPort = $FORWARD_PORT 
auth.token = "$TOKEN" 
EOF
echo -e "${green} 成功生成配置文件，文件位置：$(pwd)/frps.toml ${re}"
}

# running files
run_frps() { 
  if [ -f "./frps" ] && [ -f "./frps.toml" ]; then
        ps aux | grep "frps" | grep -v grep | awk '{print $2}' | xargs kill -9        
        nohup ./frps -c ./frps.toml >/dev/null 2>&1 &
        sleep 3
        pgrep -f "frps" > /dev/null && green "frps is running" || { red "frps is not running, failed!" ;}
  else
        purple "frps or frps.toml is not exist,skiping runing"
  fi
}


#主菜单
menu() {
   clear
   #while true;do
   echo ""
   purple "============ frps 一键安装脚本 =======\n"
   echo -e "${green}脚本地址：${re}${yellow}https://github.com/sunq945/serv00-app/tree/main/frps${re}\n"
   purple "转载请注明出处，请勿滥用\n"
   green "1. 安装frp"
   echo  "==============="
   red "2. 卸载frp"
   echo  "==============="
   green "3. 查看配置文件"
   echo  "==============="
   yellow "4. 下载检测脚本checkfrps.sh"
   echo  "==============="
   yellow "5. 清理所有进程"
   echo  "==============="
   red "0. 退出脚本"
   echo "==========="
   reading "请输入选择(0-3): " choice
   echo ""
    case "${choice}" in
        1) install_frps ;;
        2) uninstall_frps ;; 
        3) cat $WORKDIR/frps.toml ;; 
        4) download_check_script ;;
        5) kill_all_tasks ;;
        0) exit 0 ;;
        *) red "无效的选项，请输入 0 到 5" ;;
    esac
    #done;
}
menu
