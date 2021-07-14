# 阿里云DDNS解析脚本版

+------------------------------------  
| Author: ohnoku  
| Blog: https://blog.lintian.co  
| Email: yorutsuki@live.com  
+------------------------------------  
## 概要
一键将DNS解析到指定位置,方便非固定ip实现动态解析.  
一键DDNS用法:  
```
  export Ali_Key=xxx  
  export Ali_Secret=xxx  
  export Ali_Domain=example.com  
  aliddns.sh -m --record blog --value $(curl -s icanhazip.com)  此命令可作为cron定时任务,定时检查解析  
 ```
 
设置解析:  
```
  aliddns.sh -a --record blog --type A --value 0.0.0.0  
```

修改解析:  
```
  aliddns.sh -m --record blog --value 0.0.0.0  
```

删除解析: 
```
  aliddns.sh -r blog  
```

## 使用简介
```
参数说明：  
    -d, --domain         指定域名Ali_Domain,可以通过环境变量设置,两者都指定的时候脚本参数优先  
    -k, --key            指定Ali_Key,可以通过环境变量设置,两者都指定的时候脚本参数优先  
    -s, --secret         指定Ali_Secret,可以通过环境变量设置,两者都指定的时候脚本参数优先  
    -a, --add            增加解析记录  
        --record         记录名  
        --type           记录类型  
        --value          记录值  
    -m, --modify         修改解析记录,如果记录值不匹配则修改为指定值  
        --record         记录名  
        --value          记录值  
    -r, --remove         删除解析记录  
    -v, --version        版本信息  
    -h, --help           显示此帮助信息  
 ```
## 使用参考
[阿里云一键DDNS脚本](https://blog.lintian.co/?p=13)

## 附加说明
1.此脚本仅作为简单管理DNS解析记录的工具,如需全面管理域名请使用官方工具/API.  
2.环境变量Ali_Key、Ali_Secret和[[acme.sh](https://github.com/acmesh-official/acme.sh)]共用,方便HTTPS证书申请,如有介意可以自行修改  
