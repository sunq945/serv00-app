# 1：vps一键命令
* 一键安装到serv00


vps一键脚本
```
bash <(curl -Ls https://raw.githubusercontent.com/sunq945/serv00-app/main/vless/serv00_vless.sh)
```



# 2：一键下载并执行检测app.js进程脚本
*可以添加到serv00的cron job上作为定时检查任务

自动检测脚本（autocheck.sh）
```
curl -fsSL  https://raw.githubusercontent.com/sunq945/serv00-app/main/vless/autocheck.sh -o autocheck.sh && chmod +x autocheck.sh && ./autocheck.sh
```

# 免责声明
* 本程序仅供学习了解, 非盈利目的，请于下载后 24 小时内删除, 不得用作任何商业用途, 文字、数据及图片均有所属版权, 如转载须注明来源。
* 使用本程序必循遵守部署免责声明，使用本程序必循遵守部署服务器所在地、所在国家和用户所在国家的法律法规, 程序作者不对使用者任何不当行为负责。
