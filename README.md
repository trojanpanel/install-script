# 介绍

Trojan Panel一键安装脚本

# 准备

## 系统要求

系统支持: CentOS 7

内存要求: ≥1G

## 开放端口

使用Trojan Panel需要开放以下端口: 80 443 8863 8888 9507(可选)

使用单机版需要开放以下端口: 80 443 8863

## 域名

请提前准备好一个**解析到服务器的域名**

# 一键安装脚本

```shell
yum install -y wget;wget --no-check-certificate https://github.com/trojanpanel/install-script/raw/main/install_script.sh;chmod 777 install_script.sh;./install_script.sh
```

# 注意

1. 控制面板和节点都推荐部署在**国外服务器**上,否则会由于网络问题使用一键安装脚本会因为远程下载文件超时报错。

2. 以数据库版为例,建议的安装顺序: 卸载云盾(阿里云服务器) > 安装加速 > 安装面板 > 安装节点

3. 安装结束后,访问**域名**如果是一个静态网页,说明已经安装成功。

4. Trojan Panel前端地址在8888端口，即：{你的域名/IP}:8888

# 客户端推荐

- Android: [igniter](https://github.com/trojan-gfw/igniter)
- IOS: [Shadowrocket](https://apps.apple.com/us/app/shadowrocket/id932747118)
- Windows: [Qv2ray](https://github.com/Qv2ray/Qv2ray/) & [QvPlugin-Trojan](https://github.com/Qv2ray/QvPlugin-Trojan)

# 交流

Telegram: https://t.me/jonssonyangroup
