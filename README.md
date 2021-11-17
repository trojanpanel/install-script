# 介绍

Trojan Panel一键安装脚本

# 系统要求

系统支持: CentOS 7

内存要求: ≥1G

# 准备

1. 一个**解析到服务器的域名**
2. 一台未被墙的VPS

# 开放端口

使用Trojan Panel+数据库版节点需要开放以下端口: `80` `443` `8863` `8888` `9507`(可选)

使用单机版节点需要开放以下端口: `80` `443` `8863`

# 一键安装脚本

```shell
yum install -y wget;wget --no-check-certificate https://github.com/trojanpanel/install-script/raw/main/install_script.sh;chmod 777 install_script.sh;./install_script.sh
```

# 注意

1. 控制面板和节点都推荐部署在**国外服务器**上,否则会由于网络问题使用一键安装脚本会因为远程下载文件超时报错。

2. 以Trojan Panel+数据库版节点为例,建议的安装顺序: 卸载云盾(阿里云服务器) > 安装BBRplus > 安装Trojan Panel面板 > 安装节点(数据库版)

3. 安装结束后,访问**你的域名**如果是一个静态网页,说明已经安装成功。

4. Trojan Panel后台管理地址: **http**://你的域名:8888

# 如何使用连接？

连接参数如下：

- 地址：`你输入的域名`
- 端口：`TrojanGFW的端口`
- 密码：`用户名&密码` (需要在管理后台添加)

![Qv2ray](./images/Qv2ray.png =100x100)

# 客户端推荐

- Android: [igniter](https://github.com/trojan-gfw/igniter)
- IOS: [Shadowrocket](https://apps.apple.com/us/app/shadowrocket/id932747118)
- Windows: [Qv2ray](https://github.com/Qv2ray/Qv2ray/) & [QvPlugin-Trojan](https://github.com/Qv2ray/QvPlugin-Trojan)

# Telegram讨论组

Telegram讨论组: https://t.me/jonssonyangroup
