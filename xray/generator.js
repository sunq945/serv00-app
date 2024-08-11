var fs = require('fs'); //文件模块
var path = require('path'); //系统路径模块
const logcb = (...args) => console.log.bind(this, ...args);
const errcb = (...args) => console.error.bind(this, ...args);

function red(msg) { return "\x1B[31m"+msg+"\033[0m"; }
function green(msg) { return "\x1B[32m"+msg+"\033[0m"; }
function yellow(msg) { return "\x1B[33m"+msg+"\033[0m"; }
function purple(msg) { return "\x1B[35m"+msg+"\033[0m"; }



// 读取配置文件
let config;
try {
    const data = fs.readFileSync('generator.json', 'utf8');
    config = JSON.parse(data);
} catch (err) {
    console.error('Error reading generator.json:', err);
    process.exit(1);
}

const uuid = config.server.uuid.replace(/-/g, '');
const port = config.server.port;

console.log(yellow("读取到uuid:"+uuid))
console.log(yellow("读取到port:"+port))
console.log(yellow("正在生成xray配置文件config.json"))

let config_data={
    "log": {
        "loglevel": "warning"
    },
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "ip": [
                    "geoip:cn",
                    "geoip:private"
                ],
                "outboundTag": "block"
            }
        ]
    },
    "inbounds": [
        {
            "listen": "0.0.0.0",
            "port": port, 
            "protocol": "vmess",
            "settings": {
                "clients": [
                  {
                    "id": uuid,
                    "alterId": 0
                  }
                ],
                "disableInsecureEncryption": false
              },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                  "acceptProxyProtocol": false,
                  "path": "/IVApi/NL/7",
                  "headers": {}
                }
              },
              "sniffing":{
                "enabled": false,
                "destOverride": [
                  "http",
                  "tls"
                ]
              }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
}

//把data对象转换为json格式字符串
var content = JSON.stringify(config_data); 

//指定创建目录及文件名称，__dirname为执行当前js文件的目录
var file = path.join(__dirname, 'config.json'); 

//写入文件
fs.writeFile(file, content, function(err) {
    if (err) {
        return console.log(err);
    }
    console.log(green('文件创建成功，地址：' + file) )
    process.env.CFG_FILE = file
});



