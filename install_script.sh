#!/bin/bash

initVar() {
  echoType='echo -e'

  TP_DATA='/tpdata'

  TROJANGFW_DATA='/tpdata/trojanGFW'
  TROJANGFW_CONFIG='/tpdata/trojanGFW/config.json'

  MARIA_DATA='/tpdata/mariadb'

  CADDY_DATA='/tpdata/caddy'
  CADDY_Caddyfile='/tpdata/caddy/Caddyfile'
  CADDY_SRV='/tpdata/caddy/srv'
  CADDY_ACME='/tpdata/caddy/acme'

  domain=
  caddy_remote_port=8863
  your_email=123456@qq.com
  remote_addr='trojan-panel-caddy'
  trojanGFW_port=443
  mariadb_ip='trojan-panel-mariadb'
  mariadb_port=9507
  mariadb_pas=

  static_html='https://github.com/trojanpanel/install-script/raw/main/moviehtml.zip'
  sql_url='https://github.com/trojanpanel/trojan-panel/raw/master/resource/sql/trojan.sql'
}

initVar

function mkdirTools() {
  mkdir -p ${TP_DATA}

  mkdir -p ${MARIA_DATA}

  mkdir -p ${CADDY_DATA}
  touch ${CADDY_Caddyfile}
  mkdir -p ${CADDY_SRV}
  mkdir -p ${CADDY_ACME}

  mkdir -p ${TROJANGFW_DATA}
  touch ${TROJANGFW_CONFIG}
}

echoContent() {
  case $1 in
  # 红色
  "red")
    # shellcheck disable=SC2154
    ${echoType} "\033[31m$2\033[0m"
    ;;
    # 绿色
  "green")
    ${echoType} "\033[32m$2\033[0m"
    ;;
    # 黄色
  "yellow")
    ${echoType} "\033[33m$2\033[0m"
    ;;
    # 蓝色
  "blue")
    ${echoType} "\033[34m$2\033[0m"
    ;;
    # 紫色
  "purple")
    ${echoType} "\033[35m$2\033[0m"
    ;;
    # 天蓝色
  "skyBlue")
    ${echoType} "\033[36m$2\033[0m"
    ;;
    # 白色
  "white")
    ${echoType} "\033[37m$2\033[0m"
    ;;
  esac
}

# 卸载Trojan Panel
function uninstallTrojanPanel() {
  docker rm -f trojan-panel-mariadb
  docker rm -f trojan-panel-caddy
  docker rm -f trojan-panel-trojanGFW
  rm -rf ${MARIA_DATA}
  rm -rf ${TROJANGFW_DATA}

  rm -rf ${CADDY_Caddyfile}
  rm -rf ${CADDY_SRV}

  echoContent skyBlue "---> Trojan Panel卸载完成"
}

# 卸载阿里云盾
function uninstallAliyun() {
  wget --no-check-certificate -O uninstall.sh http://update.aegis.aliyun.com/download/uninstall.sh && chmod +x uninstall.sh && ./uninstall.sh
  wget --no-check-certificate -O quartz_uninstall.sh http://update.aegis.aliyun.com/download/quartz_uninstall.sh && chmod +x quartz_uninstall.sh && ./quartz_uninstall.sh
  pkill aliyun-service
  rm -fr /etc/init.d/agentwatch /usr/sbin/aliyun-service
  rm -rf /usr/local/aegis*
  iptables -I INPUT -s 140.205.201.0/28 -j DROP
  iptables -I INPUT -s 140.205.201.16/29 -j DROP
  iptables -I INPUT -s 140.205.201.32/28 -j DROP
  iptables -I INPUT -s 140.205.225.192/29 -j DROP
  iptables -I INPUT -s 140.205.225.200/30 -j DROP
  iptables -I INPUT -s 140.205.225.184/29 -j DROP
  iptables -I INPUT -s 140.205.225.183/32 -j DROP
  iptables -I INPUT -s 140.205.225.206/32 -j DROP
  iptables -I INPUT -s 140.205.225.205/32 -j DROP
  iptables -I INPUT -s 140.205.225.195/32 -j DROP
  iptables -I INPUT -s 140.205.225.204/32 -j DROP
}

# 安装BBRplus
function installBBRplus() {
  kernel_version="4.14.129-bbrplus"
  if [[ ! -f /etc/redhat-release ]]; then
    echo -e "仅支持centos"
    exit 0
  fi

  if [[ "$(uname -r)" == "${kernel_version}" ]]; then
    echo -e "内核已经安装，无需重复执行。"
    exit 0
  fi

  #卸载原加速
  echo -e "卸载加速..."
  sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
  if [[ -e /appex/bin/serverSpeeder.sh ]]; then
    wget --no-check-certificate -O appex.sh https://raw.githubusercontent.com/0oVicero0/serverSpeeder_Install/master/appex.sh && chmod +x appex.sh && bash appex.sh uninstall
    rm -f appex.sh
  fi
  echo -e "下载内核..."
  wget https://github.com/cx9208/bbrplus/raw/master/centos7/x86_64/kernel-${kernel_version}.rpm
  echo -e "安装内核..."
  yum install -y kernel-${kernel_version}.rpm

  #检查内核是否安装成功
  list="$(awk -F\' '$1=="menuentry " {print i++ " : " $2}' /etc/grub2.cfg)"
  target="CentOS Linux (${kernel_version})"
  result=$(echo $list | grep "${target}")
  if [[ "$result" == "" ]]; then
    echo -e "内核安装失败"
    exit 1
  fi

  echo -e "切换内核..."
  grub2-set-default 'CentOS Linux (${kernel_version}) 7 (Core)'
  echo -e "启用模块..."
  echo "net.core.default_qdisc=fq" >>/etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbrplus" >>/etc/sysctl.conf
  rm -f kernel-${kernel_version}.rpm

  read -p "bbrplus安装完成，现在重启 ? [Y/n] :" yn
  [ -z "${yn}" ] && yn="y"
  if [[ $yn == [Yy] ]]; then
    echo -e "重启中..."
    reboot
  fi
}

# 导入数据库
function import_sql() {
  echoContent green "---> 导入数据库"

  while true; do
    read -r -p '请输入数据库的密码(必填): ' mariadb_pas
    if [[ ! -n ${mariadb_pas} ]]; then
      echoContent yellow "数据库密码不能为空"
    else
      break
    fi
  done

  docker exec trojan-panel-mariadb mysql -uroot -p${mariadb_pas} -e 'drop database trojan;'

  yum install -y wget && wget --no-check-certificate -O trojan.sql ${sql_url} \
  && docker cp trojan.sql trojan-panel-mariadb:/trojan.sql \
  && docker exec -it trojan-panel-mariadb /bin/bash -c "mysql -uroot -p${mariadb_pas} -e 'create database trojan;'" \
  && docker exec -it trojan-panel-mariadb /bin/bash -c "mysql -uroot -p${mariadb_pas} trojan </trojan.sql"
  
  if [ $? -eq 0 ]; then
    echoContent skyBlue "---> 导入数据库完成"
  else
    echoContent red "---> 导入数据库失败"
    exit 0
  fi
}

# 安装Docker
function installDocker() {
  systemctl stop firewalld.service && systemctl disable firewalld.service
  docker -v
  if [ $? -ne 0 ]; then
    echoContent green "---> 安装Docker"

    yum install -y yum-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum makecache fast
    yum install -y docker-ce docker-ce-cli containerd.io
    
    systemctl enable docker
    systemctl start docker && docker -v && docker network create trojan-panel-network

    if [ $? -eq 0 ]; then
      echoContent skyBlue "---> Docker安装完成"
    else
      echoContent red "---> Docker安装失败"
      exit 0
    fi
  fi
}

# 安装MariaDB
function installMariadb() {
  echoContent green "---> 安装MariaDB"

  read -r -p '请输入数据库的端口(默认:9507): ' mariadb_port
  [ -z "${mariadb_port}" ] && mariadb_port="9507"

  while true; do
    read -r -p '请输入数据库的密码(必填): ' mariadb_pas
    if [[ ! -n ${mariadb_pas} ]]; then
      echoContent yellow "数据库密码不能为空"
    else
      break
    fi
  done

  docker pull mariadb \
  && docker run -d --name trojan-panel-mariadb --restart always \
  -p ${mariadb_port}:3306 \
  -v ${MARIA_DATA}:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=${mariadb_pas} -e TZ=Asia/Shanghai mariadb \
  && docker network connect trojan-panel-network trojan-panel-mariadb

  if [[ $? -eq 0 ]]; then
    echoContent skyBlue "---> MariaDB安装完成"
    echoContent skyBlue "---> MariaDB的数据库密码(请妥善保存): ${mariadb_pas}"
    import_sql
  else
    echoContent red "---> MariaDB安装失败"
    exit 0
  fi
}

# 安装TrojanPanel
function installTrojanPanel() {
  echoContent green "---> 安装TrojanPanel"
}

# 安装Caddy TLS
function installCaddyTLS() {
  echoContent green "---> 安装Caddy TLS"

  echoContent yellow "注意: 请确保域名已经解析到本机IP,否则申请证书会失败"
  while true; do
    read -r -p '请输入你的域名(必填): ' domain
    if [[ ! -n ${domain} ]]; then
      echoContent yellow "域名不能为空"
    else
      break
    fi
  done

  ping -c 2 -w 5 ${domain}
  if [[ $? -ne 0 ]]; then
    echoContent yellow "你的域名没有解析到本机IP"
    echoContent red "---> Caddy安装失败"
    exit 0
  fi

  read -r -p '请输入你的邮箱(用于申请证书,默认:123456@qq.com)：' your_email
  [ -z "${your_email}" ] && your_email="123456@qq.com"

  read -r -p '请输入Caddy的转发端口(用于申请证书,默认:8863)：' caddy_remote_port
  [ -z "${caddy_remote_port}" ] && caddy_remote_port=8863

  yum install -y wget && wget --no-check-certificate -O html.zip ${static_html}
  yum install -y unzip && unzip -d ${CADDY_SRV} ./html.zip

  cat >${CADDY_Caddyfile} <<EOF
http://${domain}:80 {
    redir https://${domain}:${caddy_remote_port}{url}
}
https://${domain}:${caddy_remote_port} {
    gzip
    tls ${your_email}
    root /srv
}
EOF

  docker pull abiosoft/caddy \
  && docker run -d --name trojan-panel-caddy --restart always -e ACME_AGREE=true \
  -p 80:80 -p ${caddy_remote_port}:${caddy_remote_port} \
  -v ${CADDY_Caddyfile}:"/etc/Caddyfile" -v ${CADDY_ACME}:"/root/.caddy/acme/acme-v02.api.letsencrypt.org/sites" -v ${CADDY_SRV}:"/srv" abiosoft/caddy \
  && docker network connect trojan-panel-network trojan-panel-caddy

  if [[ $? -eq 0 ]]; then
    echoContent skyBlue "---> Caddy安装完成"
  else
    echoContent red "---> Caddy安装失败"
    exit 0
  fi
}

# 安装TrojanGFW 数据库版
function installTrojanGFW() {
  echoContent green "---> 安装TrojanGFW"

  read -r -p '请输入TrojanGFW的端口(默认:443)：' trojanGFW_port
  [ -z "${trojanGFW_port}" ] && trojanGFW_port=443
  read -r -p '请输入数据库的IP地址(默认:本地数据库)：' mariadb_ip
  [ -z "${mariadb_ip}" ] && mariadb_ip="trojan-panel-mariadb"
  read -r -p '请输入数据库的端口(默认:本地数据库端口)：' mariadb_port
  [ -z "${mariadb_port}" ] && mariadb_port=3306
  while true; do
    read -r -p '请输入数据库的密码(必填)：' mariadb_pas
    if [[ ! -n ${mariadb_pas} ]]; then
      echoContent yellow "数据库密码不能为空"
    else
      break
    fi
  done

  cat >${TROJANGFW_CONFIG} <<EOF
    {
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": ${trojanGFW_port},
    "remote_addr": "${remote_addr}",
    "remote_port": 80,
    "password": [],
    "log_level": 1,
    "ssl": {
        "cert": "${CADDY_ACME}/${domain}/${domain}.crt",
        "key": "${CADDY_ACME}/${domain}/${domain}.key",
        "key_password": "",
        "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384",
        "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "alpn_port_override": {
            "h2": 81
        },
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "prefer_ipv4": false,
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": false,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": true,
        "server_addr": "${mariadb_ip}",
        "server_port": ${mariadb_port},
        "database": "trojan",
        "username": "root",
        "password": "${mariadb_pas}",
        "key": "",
        "cert": "",
        "ca": ""
    }
}
EOF

  docker pull trojangfw/trojan \
  && docker run -d --name trojan-panel-trojanGFW --restart always \
  -p ${trojanGFW_port}:${trojanGFW_port} \
  -v ${TROJANGFW_CONFIG}:"/config/config.json" -v ${CADDY_ACME}:${CADDY_ACME} trojangfw/trojan \
  && docker network connect trojan-panel-network trojan-panel-trojanGFW

  if [[ -n $(docker ps | grep trojan-panel-trojanGFW) ]]; then
    echoContent skyBlue "---> TrojanGFW安装完成"
  else
    echoContent red "---> TrojanGFW安装失败"
    exit 0
  fi
}

# 安装TrojanGFW 单机版
function installTrojanGFWStandalone() {
  echoContent green "---> 安装TrojanGFW"

  read -r -p '请输入TrojanGFW的端口(默认:443)：' trojanGFW_port
  [ -z "${trojanGFW_port}" ] && trojanGFW_port=443
  while true; do
    read -r -p '请输入TrojanGFW的密码(必填)：' trojan_pas
    if [[ ! -n ${trojan_pas} ]]; then
      echoContent yellow "密码不能为空"
    else
      break
    fi
  done

  cat >${TROJANGFW_CONFIG} <<EOF
    {
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": ${trojanGFW_port},
    "remote_addr": "${remote_addr}",
    "remote_port": 80,
    "password": [
        "${trojan_pas}"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "${CADDY_ACME}/${domain}/${domain}.crt",
        "key": "${CADDY_ACME}/${domain}/${domain}.key",
        "key_password": "",
        "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384",
        "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "alpn_port_override": {
            "h2": 81
        },
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "prefer_ipv4": false,
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": false,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": "",
        "key": "",
        "cert": "",
        "ca": ""
    }
}
EOF

  docker pull trojangfw/trojan \
  && docker run -d --name trojan-panel-trojanGFW --restart always \
  -p ${trojanGFW_port}:${trojanGFW_port} \
  -v ${TROJANGFW_CONFIG}:"/config/config.json" -v ${CADDY_ACME}:${CADDY_ACME} trojangfw/trojan \
  && docker network connect trojan-panel-network trojan-panel-trojanGFW

  if [[ $? -eq 0 ]]; then
    echoContent skyBlue "---> TrojanGFW安装完成"
    echoContent red "\n=============================================================="
    echoContent skyBlue "TrojanGFW+Caddy+TLS节点 单机版 安装成功"
    echoContent yellow "域名: ${domain}"
    echoContent yellow "TrojanGFW的端口: ${trojanGFW_port}"
    echoContent yellow "TrojanGFW的密码: ${trojan_pas}"
    echoContent red "\n=============================================================="
  else
    echoContent red "---> TrojanGFW安装失败"
    exit 0
  fi
}

function main() {
  cd "$HOME" || exit
  mkdirTools
  echoContent red "\n=============================================================="
  echoContent skyBlue "当前版本: v1.2.4"
  echoContent skyBlue "Github: https://github.com/trojanpanel"
  echoContent skyBlue "描述: Trojan Panel一键安装脚本"
  echoContent red "\n=============================================================="
  echoContent yellow "1.卸载阿里云盾(仅限阿里云服务使用)"
  echoContent yellow "2.安装BBRplus"
  echoContent yellow "3.安装Trojan Panel"
  echoContent yellow "4.安装TrojanGFW+Caddy+TLS节点 数据库版"
  echoContent yellow "5.安装TrojanGFW+Caddy+TLS节点 单机版"
  echoContent yellow "6.卸载Trojan Panel"
  read -r -p "请选择:" selectInstallType
  case ${selectInstallType} in
  1)
    uninstallAliyun
    ;;
  2)
    installBBRplus
    ;;
  3)
    installDocker
    installMariadb
    installTrojanPanel
    ;;
  4)
    installDocker
    installCaddyTLS
    installTrojanGFW
    ;;
  5)
    installDocker
    installCaddyTLS
    installTrojanGFWStandalone
    ;;
  6)
    uninstallTrojanPanel
    ;;
  esac
}

main
