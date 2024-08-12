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



[[ "$HOSTNAME" == "s1.ct8.pl" ]] && WORKDIR="/usr/home/$USER/domains/${USERNAME}.ct8.pl/trojan" || WORKDIR="/usr/home/$USER/domains/$MYDOMAIN/trojan"
[ -d "$WORKDIR" ] || (mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR")


read_trojan_port() {
    while true; do
        reading "请输入服务器端口 (面板开放的tcp端口): " trojan_port
        if [[ "$trojan_port" =~ ^[0-9]+$ ]] && [ "$trojan_port" -ge 1 ] && [ "$trojan_port" -le 65535 ]; then
            green "你的trojan端口为: $trojan_port"
            export PORT=$trojan_port
            break
        else
            yellow "输入错误，请重新输入面板开放的TCP端口"
        fi
    done
}


install_trojan() {
echo -e "${yellow}本脚本只安装trojan代理服务器和启动脚本${re}"
echo -e "${yellow}开始运行前，请确保在面板${purple}已开放1个tcp端口${re}"
echo -e "${yellow}面板${purple}Additional services${yellow}中的${purple}Run your own applications${yellow}已开启为${purplw}Enabled${yellow}状态${re}"
reading "\n确定继续安装吗？【y/n】: " choice
  case "$choice" in
    [Yy])
        cd $WORKDIR
        read_trojan_port     
        generate_infos
        download_xray_core && wait
        generate_crypito_info
        generate_config        
        run_trojan && sleep 3   
      ;;
    [Nn]) exit 0 ;;
    *) red "无效的选择，请输入y或n" && menu ;;
  esac
}

uninstall_trojan() {
  reading "\n确定要卸载吗？【y/n】: " choice
    case "$choice" in
       [Yy])
          pgrep -f "trojan_config.json" | grep -v grep | xargs kill -9   
          rm -rf $WORKDIR /usr/home/$USER/logs/checktrojan.log

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
  local app_name="Xray-freebsd-64.zip"
  echo -e "${yellow} 下载xray-core( $app_name ): ${re}"
  curl -sL -o $app_name https://github.com/XTLS/Xray-core/releases/latest/download/Xray-freebsd-64.zip
  
  if [ -f "./$app_name" ];then
    echo -e "${green} 下载 $app_name 成功，正在解压...${re}"
    unzip -o $app_name | awk 'BEGIN {ORS=" "} {print "."}'  
    echo -e "${green} 解压完毕,正在赋予执行权限...${re}"
    chmod +x xray
    rm -rf $app_name
    echo -e "${yellow} $app_name 已删除.${re}"
  else
    echo -e "${red} 下载 $app_name 失败 ${re}"
    exit 1
 fi
}

generate_infos(){
  # 生成随机密码和电子邮件
  local pws=$(openssl rand -base64 12)
  local email="user$(openssl rand -hex 4)@example.com"
  
  #去掉字符串中的‘/’
  export PASSWORD=$(echo ${pws//\//})
  export EMAIL=$(echo ${email//\//})

  # 随机选择 alpn 值
  export ALPN_VALUES=("http/1.1" "h2" "h3")
  export ALPN=${ALPN_VALUES[$RANDOM % ${#ALPN_VALUES[@]}]}
}

generate_crypito_info(){
  # 生成证书文件
  echo -e "${green} 正在生成证书文件...${re}"
  openssl ecparam -genkey -name prime256v1 -out private.key
  openssl req -new -x509 -days 3650 -key private.key -out cert.pem -subj "/CN=apple.com"
  if [ -f "./private.key" ] && [ -f "./cert.pem" ];then
    echo -e "${green} 正在生成证书文件成功${re}"
    echo -e "${yellow}private.key 文件位置:$(pwd)/private.key ${re}"
    echo -e "${yellow}cert.pem 文件位置:$(pwd)/cert.pem${re}"
   else
    echo -e "${red} 生成证书文件失败：private.key 或 cert.pem 不存在 ！${re}"
    exit 1
  fi 
}

download_check_script(){
  local path=$(pwd)
  cd $WORKDIR
  curl -fsSL  https://raw.githubusercontent.com/sunq945/serv00-app/main/trojan/checktrojan.sh -o checktrojan.sh && chmod +x checktrojan.sh
  if [ -f "./checktrojan.sh" ];then
    echo -e "${green} 下载 checktrojan.sh 成功， 文件位置： ${purple}"$WORKDIR/checktrojan.sh" ${re}"
    echo -e "${yellow} 你可以在vps的面板上找到cron job,进去之后 点击 “ Add cron job” 添加定时任务，建议定时为3分钟（Minuts填Every 和 3 ，其他时间选项填Each Time）， 命令行填写:
    ${green}/bin/sh $WORKDIR/checktrojan.sh
    ${re}"
  else
    echo -e "${red} 下载checktrojan.sh失败,请重新下载 ${re}"
    exit 1
  fi
  cd $path
} 


# Generating Configuration Files
generate_config() {
# 创建配置文件
echo -e "${yellow} 正在创建配置文件...${re}"
cat <<EOF > trojan_config.json
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": $PORT,
            "protocol": "trojan",
            "settings": {
                "clients": [
                    {
                        "password": "$PASSWORD",
                        "email": "$EMAIL"
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "alpn": [
                        "$ALPN"
                    ],
                    "certificates": [
                        {
                            "certificateFile": "cert.pem",
                            "keyFile": "private.key"
                        }
                    ]
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF
echo -e "${green} 已保存配置文件到:$(pwd)/trojan_config.json ${re}"

echo -e "${green} 生成 Trojan 链接:${re}"
TROJAN_LINK="trojan://$PASSWORD@$MYDOMAIN:$PORT?security=tls&alpn=$ALPN&allowInsecure=1&type=tcp#serv00_trojan"
cat > trojan_link.txt <<EOF
$TROJAN_LINK
EOF
echo -e "${purple}$TROJAN_LINK${re}"
}

# running files
run_trojan() {     

  if [ -f "./xray" ] && [ -f "./trojan_config.json" ]; then
        pgrep -f "trojan_config.json" | grep -v grep | xargs kill -9         
        # 在 tmux 中运行 Xray
        echo -e "${green} 正在启动 Xray...${re}"
        nohup ./xray -c trojan_config.json >/dev/null 2>&1 &
        sleep 3
        pgrep -f "trojan_config.json" > /dev/null && green "trojanis running" || { red "trojan is not running, failed!" ;}
  else
        purple "xray or trojan_config.json is not exist,skiping runing"
  fi
}

madify_port(){
  local path=$(pwd)
  cd $WORKDIR
  read_trojan_port
  rm -f trojan_config.json
  generate_config
  run_trojan && sleep 3   
}


#主菜单
menu() {
   clear
   #while true;do
   echo ""
   purple "============ trojan 一键安装脚本 =======\n"
   echo -e "${green}脚本地址：${re}${yellow}https://github.com/sunq945/serv00-app/tree/main/trojan${re}\n"
   purple "转载请注明出处，请勿滥用\n"
   green "1. 安装trojan"
   echo  "=============================="
   red "2. 卸载trojan"
   echo  "=============================="
   green "3. 查看节点信息"
   echo  "=============================="
   green "4. 下载检测脚本checktrojan.sh"
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
        1) install_trojan ;;
        2) uninstall_trojan;; 
        3) cat  $WORKDIR/trojan_link.txt ;; 
        4) download_check_script ;;
        5) madify_port ;;
        6) kill_all_tasks ;;
        0) exit 0 ;;
        *) red "无效的选项，请输入 0 到 6" ;;
    esac
    #done;
}
menu
