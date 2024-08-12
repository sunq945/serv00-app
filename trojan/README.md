# 1：vps一键命令
* 第一种方式：一键安装到serv00


vps一键脚本
```
bash <(curl -Ls https://raw.githubusercontent.com/sunq945/serv00-app/main/trojan/serv00_trojan.sh)
```
* 第一种方式：下载到本地后再进行自动安装
  
```
curl -fsSL  https://raw.githubusercontent.com/sunq945/serv00-app/main/trojan/serv00_trojan.sh -o serv00_trojan.sh && chmod +x serv00_trojan.sh && ./serv00_trojan.sh
```


# 2：一键下载并执行检测app.js进程脚本
* 可以添加到serv00的cron job上作为定时检查任务

下载自动检测脚本（checktrojan.sh）到本地并自动运行：
```
curl -fsSL  https://raw.githubusercontent.com/sunq945/serv00-app/main/vmess/checktrojan.sh -o checktrojan.sh && chmod +x checktrojan.sh && ./checktrojan.sh
```

该脚本会生成 /home/账号/logs/checktrojan.log 的日志文件，方便查看运行状态。

# 免责声明
* 本程序仅供学习了解, 非盈利目的，请于下载后 24 小时内删除, 不得用作任何商业用途, 文字、数据及图片均有所属版权, 如转载须注明来源。
* 使用本程序必循遵守部署免责声明，使用本程序必循遵守部署服务器所在地、所在国家和用户所在国家的法律法规, 程序作者不对使用者任何不当行为负责。
