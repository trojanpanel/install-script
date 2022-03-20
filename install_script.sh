#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================================#
#   System Required: CentOS 6+, Debian8+, Ubuntu16+               #
#   Version: v2.0.0                                               #
#   Description: One click Install Trojan Panel server            #
#   Author: jonssonyan <https://jonssonyan.com>                   #
#   Github: https://github.com/trojanpanel                        #
#=================================================================#

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

initVar() {
  echoType='echo -e'
  cur_dir=`pwd`

  # 系统
  release=
  # CentOS版本
  centosVersion=
  # Debian版本
  debianVersion=

  # 项目目录
  TP_DATA='/tpdata'

  # MariaDB
  MARIA_DATA='/tpdata/mariadb'
  mariadb_ip='trojan-panel-mariadb'
  mariadb_port=9507
  mariadb_pas=''

  # Trojan Panel
  TROJAN_PANEL_DATA='/tpdata/trojan-panel'
  TROJAN_PANEL_CONFIG='/tpdata/trojan-panel/config.ini'
  TROJAN_PANEL_URL='https://github.com/trojanpanel/trojan-panel/releases/latest/download/trojan-panel.zip'

  # Trojan Panel UI
  TROJAN_PANEL_UI_DATA='/tpdata/trojan-panel-ui'
  TROJAN_PANEL_UI_URL='https://github.com/trojanpanel/trojan-panel-ui/releases/latest/download/trojan-panel-ui.zip'
  # Nginx
  NGINX_DATA='/tpdata/nginx'
  NGINX_CONFIG='/tpdata/nginx/default.conf'

  # Caddy
  CADDY_DATA='/tpdata/caddy'
  CADDY_Caddyfile='/tpdata/caddy/Caddyfile'
  CADDY_SRV='/tpdata/caddy/srv'
  CADDY_ACME='/tpdata/caddy/acme'
  domain=
  caddy_remote_port=8863
  your_email=123456@qq.com

  trojan_pas=''
  remote_addr='trojan-panel-caddy'
  # trojanGFW
  TROJANGFW_DATA='/tpdata/trojanGFW'
  TROJANGFW_CONFIG='/tpdata/trojanGFW/config.json'
  TROJANGFW_STANDALONE_CONFIG='/tpdata/trojanGFW/standalone_config.json'
  trojanGFW_port=443
  # trojanGO
  TROJANGO_DATA='/tpdata/trojanGO/'
  TROJANGO_CONFIG='/tpdata/trojanGO/config.json'
  TROJANGO_STANDALONE_CONFIG='/tpdata/trojanGO/standalone_config.json'
  trojanGO_port=443
  trojanGO_websocket_enable=false
  trojanGO_websocket_path='trojan-panel-websocket-path'
  trojanGO_shadowsocks_enable=false
  trojanGO_shadowsocks_method='AES-128-GCM'
  trojanGO_shadowsocks_password=''
  trojanGO_mux_enable=true

  static_html='https://github.com/trojanpanel/install-script/raw/main/static/html.zip'
  sql_url_trojan_panel='https://github.com/trojanpanel/trojan-panel/raw/master/resource/sql/trojan.sql'
}

initVar

function mkdirTools() {
  # 项目目录
  mkdir -p ${TP_DATA}

  # MariaDB
  mkdir -p ${MARIA_DATA}

  # Trojan Panel
  mkdir -p ${TROJAN_PANEL_DATA}
  touch ${TROJAN_PANEL_CONFIG}

  # Trojan Panel UI
  mkdir -p ${TROJAN_PANEL_UI_DATA}
  # # Nginx
  mkdir -p ${NGINX_DATA}
  touch ${NGINX_CONFIG}

  # Caddy
  mkdir -p ${CADDY_DATA}
  touch ${CADDY_Caddyfile}
  mkdir -p ${CADDY_SRV}
  mkdir -p ${CADDY_ACME}

  # trojanGFW
  mkdir -p ${TROJANGFW_DATA}
  touch ${TROJANGFW_CONFIG}
  touch ${TROJANGFW_STANDALONE_CONFIG}

  # trojanGO
  mkdir -p ${TROJANGO_DATA}
  touch ${TROJANGO_CONFIG}
  touch ${TROJANGO_STANDALONE_CONFIG}
}

function checkSystem() {
  if [[ -n $(find /etc -name "redhat-release") ]] || grep </proc/version -q -i "centos"; then
    # 检测系统版本号
    centosVersion=$(rpm -q centos-release | awk -F "[-]" '{print $3}' | awk -F "[.]" '{print $1}')
    if [[ -z "${centosVersion}" ]] && grep </etc/centos-release "release 8"; then
      centosVersion=8
    fi
    release="centos"

  elif grep </etc/issue -q -i "debian" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "debian" && [[ -f "/proc/version" ]]; then
    if grep </etc/issue -i "8"; then
      debianVersion=8
    fi
    release="debian"

  elif grep </etc/issue -q -i "ubuntu" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "ubuntu" && [[ -f "/proc/version" ]]; then
    release="ubuntu"
  fi

  if [[ -z ${release} ]]; then
    echoContent red "暂不支持该系统"
    exit 0
  fi
}

# 卸载阿里云内置相关监控
function uninstallAliyun() {
  # 卸载云监控(Cloudmonitor) Java 版
  /usr/local/cloudmonitor/wrapper/bin/cloudmonitor.sh stop && \
  /usr/local/cloudmonitor/wrapper/bin/cloudmonitor.sh remove && \
  rm -rf /usr/local/cloudmonitor
  # 卸载云盾(安骑士)
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

# 安装BBRplus 仅支持centos
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

function installDockerCentOS(){
  yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine
  yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2 \
  unzip
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  yum install -y docker-ce docker-ce-cli containerd.io
}

function installDockerDebian(){
  apt remove docker docker-engine docker.io containerd runc
  apt -y update
  apt -y install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    unzip
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt -y update
  apt -y install docker-ce docker-ce-cli containerd.io
}

function installDockerUbuntu(){
  apt remove docker docker-engine docker.io containerd runc
  apt -y update
  apt -y install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    unzip
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt -y update
  apt -y install docker-ce docker-ce-cli containerd.io
}

# 安装Docker
function installDocker() {
  systemctl stop firewalld.service && systemctl disable firewalld.service
  docker -v
  if [ $? -ne 0 ]; then
    echoContent green "---> 安装Docker"

    if [[ ${release} == "centos" ]]; then
      installDockerCentOS
    elif [[ ${release} == "debian" ]]; then
      installDockerDebian
    elif [[ ${release} == "ubuntu" ]]; then
      installDockerUbuntu
    else
      echoContent red "---> 暂不支持该系统"
      exit 0
    fi

    systemctl enable docker
    systemctl start docker && docker -v && docker network create trojan-panel-network

    if [[ -n $(docker -v) ]]; then
      echoContent skyBlue "---> Docker安装完成"
    else
      echoContent red "---> Docker安装失败"
      exit 0
    fi
  else
    echoContent skyBlue "---> 你已经安装了Docker"
  fi
}

# 导入数据库
function import_sql() {
  if [[ -n $(docker ps -q -f "name=^trojan-panel-mariadb$") ]]; then
    echoContent green "---> 导入数据库"

    while read -r -p '请输入数据库的密码(必填): ' mariadb_pas; do
      if [[ -z ${mariadb_pas} ]]; then
        echoContent red "密码不能为空"
      else
        break
      fi
    done

    sleep 1

    docker exec trojan-panel-mariadb mysql -uroot -p"${mariadb_pas}" -e 'drop database trojan;'

    wget --no-check-certificate -O trojan.sql ${sql_url_trojan_panel} \
    && docker cp ${cur_dir}/trojan.sql trojan-panel-mariadb:/trojan.sql \
    && docker exec -it trojan-panel-mariadb /bin/bash -c "mysql -uroot -p${mariadb_pas} -e 'create database trojan;'" \
    && docker exec -it trojan-panel-mariadb /bin/bash -c "mysql -uroot -p${mariadb_pas} trojan </trojan.sql"

    if [ $? -eq 0 ]; then
      echoContent skyBlue "---> 导入数据库完成"
    else
      echoContent red "---> 导入数据库失败"
      exit 0
    fi
  else
    echoContent red "---> 你还没有安装MariaDB"
  fi
}

# 安装MariaDB
function installMariadb() {
  if [[ -z $(docker ps -q -f "name=^trojan-panel-mariadb$") ]]; then
    echoContent green "---> 安装MariaDB"

    read -r -p '请输入数据库的端口(默认:9507): ' mariadb_port
    [ -z "${mariadb_port}" ] && mariadb_port="9507"

    while read -r -p '请输入数据库的密码(必填): ' mariadb_pas; do
      if [[ -z ${mariadb_pas} ]]; then
        echoContent red "密码不能为空"
      else
        break
      fi
    done

    docker pull mariadb \
    && docker run -d --name trojan-panel-mariadb --restart always \
    -p ${mariadb_port}:3306 \
    -v ${MARIA_DATA}:/var/lib/mysql -e MYSQL_ROOT_PASSWORD="${mariadb_pas}" -e TZ=Asia/Shanghai mariadb \
    && docker network connect trojan-panel-network trojan-panel-mariadb

    if [[ -n $(docker ps -q -f "name=^trojan-panel-mariadb$") ]]; then
      echoContent skyBlue "---> MariaDB安装完成"
      echoContent skyBlue "---> MariaDB的数据库密码(请妥善保存): ${mariadb_pas}"
    else
      echoContent red "---> MariaDB安装失败"
      exit 0
    fi
  else
    echoContent skyBlue "---> 你已经安装了MariaDB"
  fi
}

# 安装TrojanPanel
function installTrojanPanel() {
  echoContent green "---> 安装TrojanPanel"

  if [[ -z $(docker ps -q -f "name=^trojan-panel$") ]]; then
    # 下载并解压Trojan Panel后端
    wget --no-check-certificate -O trojan-panel.zip ${TROJAN_PANEL_URL}
    unzip -o -d ${TROJAN_PANEL_DATA} ${cur_dir}/trojan-panel.zip

    read -r -p '请输入数据库的IP地址(默认:本地数据库): ' mariadb_ip
    [ -z "${mariadb_ip}" ] && mariadb_ip="trojan-panel-mariadb"
    read -r -p '请输入数据库的端口(默认:本地数据库端口): ' mariadb_port
    [ -z "${mariadb_port}" ] && mariadb_port=3306
    while read -r -p '请输入数据库的密码(必填): ' mariadb_pas; do
      if [[ -z ${mariadb_pas} ]]; then
        echoContent red "密码不能为空"
      else
        break
      fi
    done

  cat >${TROJAN_PANEL_CONFIG} <<EOF
[mysql]
ip=${mariadb_ip}
port=${mariadb_port}
pas=${mariadb_pas}
EOF

  cat >${TROJAN_PANEL_DATA}/Dockerfile <<EOF
FROM golang:1.16
WORKDIR ${TROJAN_PANEL_DATA}
ADD config.ini config.ini
ADD config/ config/
ADD trojan-panel trojan-panel
RUN chmod +x ./trojan-panel
ENTRYPOINT ["./trojan-panel"]
EOF

    docker build -t trojan-panel ${TROJAN_PANEL_DATA} \
    && docker run -d --name trojan-panel -p 8081:8081 --restart always trojan-panel \
    && docker network connect trojan-panel-network trojan-panel
    if [[ -n $(docker ps -q -f "name=^trojan-panel$") ]]; then
      echoContent skyBlue "---> Trojan Panel后端安装完成"
    else
      echoContent red "---> Trojan Panel后端安装失败"
      exit 0
    fi
  else
    echoContent skyBlue "---> 你已经安装了Trojan Panel"
  fi

  if [[ -z $(docker ps -q -f "name=^trojan-panel-ui$") ]]; then
    # 下载并解压Trojan Panel前端
    wget --no-check-certificate -O trojan-panel-ui.zip ${TROJAN_PANEL_UI_URL}
    unzip -o -d ${TROJAN_PANEL_UI_DATA} ${cur_dir}/trojan-panel-ui.zip

  cat >${TROJAN_PANEL_UI_DATA}/Dockerfile <<EOF
FROM nginx:latest
COPY / /usr/share/nginx/html/
EXPOSE 80
EOF

# 配置Nginx
  cat >${NGINX_CONFIG} << \EOF
server {
    listen       80;
    listen  [::]:80;
    server_name  localhost;

    #access_log  /var/log/nginx/host.access.log  main;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    location /api {
        proxy_pass http://trojan-panel:8081;
    }

    #error_page  404              /404.html;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

    # proxy the PHP scripts to Apache listening on 127.0.0.1:80
    #
    #location ~ \.php$ {
    #    proxy_pass   http://127.0.0.1;
    #}

    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #
    #location ~ \.php$ {
    #    root           html;
    #    fastcgi_pass   127.0.0.1:9000;
    #    fastcgi_index  index.php;
    #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
    #    include        fastcgi_params;
    #}

    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    #
    #location ~ /\.ht {
    #    deny  all;
    #}
}
EOF

  docker build -t trojan-panel-ui ${TROJAN_PANEL_UI_DATA} \
  && docker run -d --name trojan-panel-ui -p 8888:80 --restart always \
  -v ${NGINX_CONFIG}:/etc/nginx/conf.d/default.conf trojan-panel-ui \
  && docker network connect trojan-panel-network trojan-panel-ui
  if [[ -n $(docker ps -q -f "name=^trojan-panel-ui$") ]]; then
    echoContent skyBlue "---> Trojan Panel前端安装完成"
  else
    echoContent red "---> Trojan Panel前端安装失败"
    exit 0
  fi
  else
    echoContent skyBlue "---> 你已经安装了Trojan Panel UI"
  fi

  echoContent red "\n=============================================================="
  echoContent skyBlue "Trojan Panel 安装成功"
  echoContent yellow "MariaDB的数据库密码(请妥善保存): ${mariadb_pas}"
  echoContent yellow "后台管理地址: http://你的IP地址/域名:8888"
  echoContent yellow "系统管理员 默认用户名: sysadmin 默认密码: 123456 请及时登陆控制面板修改密码"
  echoContent red "\n=============================================================="
}

# 卸载Trojan Panel
function uninstallTrojanPanel() {
  echoContent green "---> 卸载Trojan Panel"

  # 强制删除容器
  docker rm -f trojan-panel-ui
  docker rm -f trojan-panel
  # 删除image
  docker rmi trojan-panel-ui
  docker rmi trojan-panel

  # 删除文件
  rm -rf ${TROJAN_PANEL_DATA}/*
  rm -rf ${TROJAN_PANEL_UI_DATA}/*
  rm -rf ${NGINX_DATA}/*

  echoContent skyBlue "---> Trojan Panel卸载完成"
}

# 更新Trojan Panel
function updateTrojanPanel() {
  echoContent green "---> 更新Trojan Panel"

  # 判断Trojan Panel是否安装
  if [[ -z $(docker ps -q -f "name=^trojan-panel$") ]];then
    echoContent red "---> 请先安装Trojan Panel"
    exit 0
  fi

  import_sql trojan-panel
  # 下载并解压Trojan Panel后端
  wget --no-check-certificate -O trojan-panel.zip ${TROJAN_PANEL_URL} \
  && unzip -o -d ${TROJAN_PANEL_DATA} ${cur_dir}/trojan-panel.zip \
  && chmod +x ${TROJAN_PANEL_DATA}/trojan-panel

  # 下载并解压Trojan Panel前端
  wget --no-check-certificate -O trojan-panel-ui.zip ${TROJAN_PANEL_UI_URL} \
  && unzip -o -d ${TROJAN_PANEL_UI_DATA} ${cur_dir}/trojan-panel-ui.zip

  docker cp ${TROJAN_PANEL_DATA}/trojan-panel trojan-panel:${TROJAN_PANEL_DATA}/ \
  && docker cp ${TROJAN_PANEL_DATA}/config trojan-panel:${TROJAN_PANEL_DATA}/ \
  && docker restart trojan-panel \
  && docker cp ${TROJAN_PANEL_UI_DATA}/. trojan-panel-ui:/usr/share/nginx/html/ \
  && docker restart trojan-panel-ui

  if [ $? -ne 0 ]; then
    echoContent red "---> Trojan Panel更新失败"
  else
    echoContent skyBlue "---> Trojan Panel更新完成"
  fi
}

# 安装Caddy TLS
function installCaddyTLS() {
  if [[ -z $(docker ps -q -f "name=^trojan-panel-caddy$") ]]; then
    echoContent green "---> 安装Caddy TLS"

    echoContent yellow "注意: 请确保域名已经解析到本机IP,否则申请证书会失败"
    while read -r -p '请输入你的域名(必填): ' domain; do
      if [[ -z ${domain} ]]; then
        echoContent red "域名不能为空"
      else
        break
      fi
    done

    ping -c 2 -w 5 "${domain}"
    if [[ $? -ne 0 ]]; then
      echoContent yellow "你的域名没有解析到本机IP"
      echoContent red "---> Caddy安装失败"
      exit 0
    fi

    read -r -p '请输入你的邮箱(用于申请证书,默认:123456@qq.com): ' your_email
    [ -z "${your_email}" ] && your_email="123456@qq.com"

    read -r -p '请输入Caddy的转发端口(用于申请证书,默认:8863): ' caddy_remote_port
    [ -z "${caddy_remote_port}" ] && caddy_remote_port=8863

    wget --no-check-certificate -O html.zip ${static_html}
    unzip -d ${CADDY_SRV} ${cur_dir}/html.zip

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

    if [[ -n $(docker ps -q -f "name=^trojan-panel-caddy$") ]]; then
      echoContent skyBlue "---> Caddy安装完成"
    else
      echoContent red "---> Caddy安装失败"
      exit 0
    fi
  else
    echoContent skyBlue "---> 你已经安装了Caddy"
  fi
}

# 安装TrojanGFW 数据库版
function installTrojanGFW() {
  if [[ -z $(docker ps -q -f "name=^trojan-panel-trojanGFW$") ]]; then
    echoContent green "---> 安装TrojanGFW"

    read -r -p '请输入TrojanGFW的端口(默认:443): ' trojanGFW_port
    [ -z "${trojanGFW_port}" ] && trojanGFW_port=443
    read -r -p '请输入数据库的IP地址(默认:本地数据库): ' mariadb_ip
    [ -z "${mariadb_ip}" ] && mariadb_ip="trojan-panel-mariadb"
    read -r -p '请输入数据库的端口(默认:本地数据库端口): ' mariadb_port
    [ -z "${mariadb_port}" ] && mariadb_port=3306
    while read -r -p '请输入数据库的密码(必填): ' mariadb_pas; do
      if [[ -z ${mariadb_pas} ]]; then
        echoContent red "密码不能为空"
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

    if [[ -n $(docker ps -q -f "name=^trojan-panel-trojanGFW$") ]]; then
      echoContent skyBlue "---> TrojanGFW 数据库版 安装完成"
      echoContent red "\n=============================================================="
      echoContent skyBlue "TrojanGFW+Caddy+Web+TLS节点 数据库版 安装成功"
      echoContent yellow "域名: ${domain}"
      echoContent yellow "TrojanGFW的端口: ${trojanGFW_port}"
      echoContent yellow "TrojanGFW的密码: 用户名&密码"
      echoContent red "\n=============================================================="
    else
      echoContent red "---> TrojanGFW 数据库版 安装失败"
      exit 0
    fi
  else
    echoContent skyBlue "---> 你已经安装了TrojanGFW 数据库版"
  fi
}

# 安装TrojanGFW 单机版
function installTrojanGFWStandalone() {
  if [[ -z $(docker ps -q -f "name=^trojan-panel-trojanGFW-standalone$") ]]; then
    echoContent green "---> 安装TrojanGFW"

    read -r -p '请输入TrojanGFW的端口(默认:443): ' trojanGFW_port
    [ -z "${trojanGFW_port}" ] && trojanGFW_port=443
    while read -r -p '请输入TrojanGFW的密码(必填): ' trojan_pas; do
      if [[ -z ${trojan_pas} ]]; then
        echoContent red "密码不能为空"
      else
        break
      fi
    done

  cat >${TROJANGFW_STANDALONE_CONFIG} <<EOF
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
    && docker run -d --name trojan-panel-trojanGFW-standalone --restart always \
    -p ${trojanGFW_port}:${trojanGFW_port} \
    -v ${TROJANGFW_STANDALONE_CONFIG}:"/config/config.json" -v ${CADDY_ACME}:${CADDY_ACME} trojangfw/trojan \
    && docker network connect trojan-panel-network trojan-panel-trojanGFW

    if [[ -n $(docker ps -q -f "name=^trojan-panel-trojanGFW-standalone$") ]]; then
      echoContent skyBlue "---> TrojanGFW 单机版 安装完成"
      echoContent red "\n=============================================================="
      echoContent skyBlue "TrojanGFW+Caddy+Web+TLS节点 单机版 安装成功"
      echoContent yellow "域名: ${domain}"
      echoContent yellow "TrojanGFW的端口: ${trojanGFW_port}"
      echoContent yellow "TrojanGFW的密码: ${trojan_pas}"
      echoContent red "\n=============================================================="
    else
      echoContent red "---> TrojanGFW 单机版 安装失败"
      exit 0
    fi
  else
    echoContent skyBlue "---> 你已经安装了TrojanGFW 单机版"
  fi
}

# 卸载TrojanGFW+Caddy+Web+TLS节点 数据库版
function uninstallTrojanGFW() {
  # 判断TrojanGFW+Caddy+Web+TLS节点 数据库版是否安装
  if [[ -n $(docker ps -q -f "name=^trojan-panel-trojanGFW$") ]];then
    echoContent green "---> 卸载TrojanGFW+Caddy+Web+TLS节点 数据库版"

    # 强制删除容器
    docker rm -f trojan-panel-trojanGFW
    # 删除image
    docker rmi trojangfw/trojan

    # 删除文件
    rm -f ${TROJANGFW_CONFIG}

    echoContent skyBlue "---> TrojanGFW+Caddy+Web+TLS节点 数据库版卸载完成"
  else
    echoContent red "---> 请先安装TrojanGFW+Caddy+Web+TLS节点 数据库版"
  fi
}

# 卸载TrojanGFW+Caddy+Web+TLS节点 单机版
function uninstallTrojanGFWStandalone() {
  # 判断TrojanGFW+Caddy+Web+TLS节点 单机版是否安装
  if [[ -n $(docker ps -q -f "name=^trojan-panel-trojanGFW-standalone$") ]];then
    echoContent green "---> 卸载TrojanGFW+Caddy+Web+TLS节点 单机版"

    # 强制删除容器
    docker rm -f trojan-panel-trojanGFW-standalone
    # 删除image
    docker rmi trojangfw/trojan

    # 删除文件
    rm -f ${TROJANGFW_STANDALONE_CONFIG}

    echoContent skyBlue "---> TrojanGFW+Caddy+Web+TLS节点 单机版卸载完成"
  else
    echoContent red "---> 请先安装TrojanGFW+Caddy+Web+TLS节点 单机版"
  fi
}

# 安装TrojanGO 数据库版
function installTrojanGO() {
  if [[ -z $(docker ps -q -f "name=^trojan-panel-trojanGO$") ]]; then
    echoContent green "---> 安装TrojanGO 数据库版"

    read -r -p '请输入TrojanGO的端口(默认:443): ' trojanGO_port
    [ -z "${trojanGO_port}" ] && trojanGO_port=443
    read -r -p '请输入数据库的IP地址(默认:本地数据库): ' mariadb_ip
    [ -z "${mariadb_ip}" ] && mariadb_ip="trojan-panel-mariadb"
    read -r -p '请输入数据库的端口(默认:本地数据库端口): ' mariadb_port
    [ -z "${mariadb_port}" ] && mariadb_port=3306
    while read -r -p '请输入数据库的密码(必填): ' mariadb_pas; do
      if [[ -z ${mariadb_pas} ]]; then
        echoContent red "密码不能为空"
      else
        break
      fi
    done

    while read -r -p '是否开启多路复用?(false/关闭 true/开启 默认:true/开启): ' trojanGO_mux_enable; do
      if [ -z "${trojanGO_mux_enable}" ] || [ "${trojanGO_mux_enable}" = true ]; then
          trojanGO_mux_enable=true
          break
      else
        if [[ ! ${trojanGO_mux_enable} = false ]]; then
          echoContent red "不可以输入除false和true之外的其他字符"
        else
          break
        fi
      fi
    done

    while read -r -p '是否开启Websocket?(false/关闭 true/开启 默认:false/关闭): ' trojanGO_websocket_enable; do
      if [[ -z ${trojanGO_websocket_enable} || ${trojanGO_websocket_enable} = false ]]; then
          trojanGO_websocket_enable=false
          break
      else
        if [[ ! ${trojanGO_websocket_enable} = true ]]; then
          echoContent red "不可以输入除false和true之外的其他字符"
        else
          read -r -p '请输入Websocket路径(默认:trojan-panel-websocket-path): ' trojanGO_websocket_path
          [ -z "${trojanGO_websocket_path}" ] && trojanGO_websocket_path="trojan-panel-websocket-path"
          break
        fi
      fi
    done

    while read -r -p '是否启用Shadowsocks AEAD加密?(false/关闭 true/开启 默认:false/关闭): ' trojanGO_shadowsocks_enable; do
      if [[ -z ${trojanGO_shadowsocks_enable} || ${trojanGO_shadowsocks_enable} = false ]]; then
          trojanGO_shadowsocks_enable=false
          break
      else
        if [[ ! ${trojanGO_shadowsocks_enable} = true ]]; then
          echoContent yellow "不可以输入除false和true之外的其他字符"
        else
          echoContent skyBlue "Shadowsocks AEAD加密方式如下:"
          echoContent yellow "1. AES-128-GCM(默认)"
          echoContent yellow "2. CHACHA20-IETF-POLY1305"
          echoContent yellow "3. AES-256-GCM"
          read -r -p '请输入Shadowsocks AEAD加密方式(默认:1): ' selectMethodType
          [ -z "${selectMethodType}" ] && selectMethodType=1
          case ${selectMethodType} in
          1)
            trojanGO_shadowsocks_method='AES-128-GCM'
            ;;
          2)
            trojanGO_shadowsocks_method='CHACHA20-IETF-POLY1305'
            ;;
          3)
            trojanGO_shadowsocks_method='AES-256-GCM'
            ;;
          *)
            trojanGO_shadowsocks_method='AES-128-GCM'
          esac

          while read -r -p '请输入Shadowsocks AEAD加密密码(必填): ' trojanGO_shadowsocks_password; do
            if [[ -z ${trojanGO_shadowsocks_password} ]]; then
              echoContent red "密码不能为空"
            else
              break
            fi
          done
          break
        fi
      fi
    done

    cat >${TROJANGO_CONFIG} <<EOF
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": ${trojanGO_port},
  "remote_addr": "${remote_addr}",
  "remote_port": 80,
  "log_level": 1,
  "log_file": "",
  "password": [],
  "disable_http_check": false,
  "udp_timeout": 60,
  "ssl": {
    "verify": true,
    "verify_hostname": true,
    "cert": "${CADDY_ACME}/${domain}/${domain}.crt",
    "key": "${CADDY_ACME}/${domain}/${domain}.key",
    "key_password": "",
    "cipher": "",
    "curves": "",
    "prefer_server_cipher": false,
    "sni": "",
    "alpn": [
      "http/1.1"
    ],
    "session_ticket": true,
    "reuse_session": true,
    "plain_http_response": "",
    "fallback_addr": "",
    "fallback_port": 80,
    "fingerprint": ""
  },
  "tcp": {
    "no_delay": true,
    "keep_alive": true,
    "prefer_ipv4": false
  },
  "mux": {
    "enabled": ${trojanGO_mux_enable},
    "concurrency": 8,
    "idle_timeout": 60
  },
  "websocket": {
    "enabled": ${trojanGO_websocket_enable},
    "path": "/${trojanGO_websocket_path}",
    "host": "${domain}"
  },
  "shadowsocks": {
    "enabled": ${trojanGO_shadowsocks_enable},
    "method": "${trojanGO_shadowsocks_method}",
    "password": "${trojanGO_shadowsocks_password}"
  },
  "mysql": {
    "enabled": true,
    "server_addr": "${mariadb_ip}",
    "server_port": ${mariadb_port},
    "database": "trojan",
    "username": "root",
    "password": "${mariadb_pas}",
    "check_rate": 60
  }
}
EOF
    docker pull teddysun/trojan-go && \
    docker run -d --name trojan-panel-trojanGO --restart=always \
    -p ${trojanGO_port}:${trojanGO_port} \
    -v ${TROJANGO_CONFIG}:"/etc/trojan-go/config.json" -v ${CADDY_ACME}:${CADDY_ACME} teddysun/trojan-go \
    && docker network connect trojan-panel-network trojan-panel-trojanGO

    if [[ -n $(docker ps -q -f "name=^trojan-panel-trojanGO$") ]]; then
      echoContent skyBlue "---> TrojanGO 数据库版 安装完成"
      echoContent red "\n=============================================================="
      echoContent skyBlue "TrojanGO+Caddy+Web+TLS+Websocket节点 数据库版 安装成功"
      echoContent yellow "域名: ${domain}"
      echoContent yellow "TrojanGO的端口: ${trojanGO_port}"
      echoContent yellow "TrojanGFW的密码: 用户名&密码"
      if [[ ${trojanGO_websocket_enable} = true ]]; then
          echoContent yellow "Websocket路径: ${trojanGO_websocket_path}"
      fi
      if [[ ${trojanGO_shadowsocks_enable} = true ]]; then
          echoContent yellow "Shadowsocks AEAD加密方式: ${trojanGO_shadowsocks_method}"
          echoContent yellow "Shadowsocks AEAD加密密码: ${trojanGO_shadowsocks_password}"
      fi
      echoContent red "\n=============================================================="
    else
      echoContent red "---> TrojanGO 数据库版 安装失败"
      exit 0
    fi
  else
    echoContent skyBlue "---> 你已经安装了TrojanGO 数据库版"
  fi
}

# 安装TrojanGO 单机版
function installTrojanGOStandalone() {
  if [[ -z $(docker ps -q -f "name=^trojan-panel-trojanGO-standalone$") ]]; then
    echoContent green "---> 安装TrojanGO 单机版"

    read -r -p '请输入TrojanGO的端口(默认:443): ' trojanGO_port
    [ -z "${trojanGO_port}" ] && trojanGO_port=443
    while read -r -p '请输入TrojanGO的密码(必填): ' trojan_pas; do
      if [[ -z ${trojan_pas} ]]; then
        echoContent red "密码不能为空"
      else
        break
      fi
    done

    while read -r -p '是否开启多路复用?(false/关闭 true/开启 默认:true/开启): ' trojanGO_mux_enable; do
      if [ -z "${trojanGO_mux_enable}" ] || [ "${trojanGO_mux_enable}" = true ]; then
          trojanGO_mux_enable=true
          break
      else
        if [[ ! ${trojanGO_mux_enable} = false ]]; then
          echoContent red "不可以输入除false和true之外的其他字符"
        else
          break
        fi
      fi
    done

    while read -r -p '是否开启Websocket?(false/关闭 true/开启 默认:false/关闭): ' trojanGO_websocket_enable; do
      if [ -z "${trojanGO_websocket_enable}" ] || [ "${trojanGO_websocket_enable}" = false ]; then
          trojanGO_websocket_enable=false
          break
      else
        if [[ ! ${trojanGO_websocket_enable} = true ]]; then
          echoContent red "不可以输入除false和true之外的其他字符"
        else
          read -r -p '请输入Websocket路径(默认:trojan-panel-websocket-path): ' trojanGO_websocket_path
          [ -z "${trojanGO_websocket_path}" ] && trojanGO_websocket_path="trojan-panel-websocket-path"
          break
        fi
      fi
    done

    while read -r -p '是否启用Shadowsocks AEAD加密?(false/关闭 true/开启 默认:false/关闭): ' trojanGO_shadowsocks_enable; do
      if [ -z "${trojanGO_shadowsocks_enable}" ] || [ "${trojanGO_shadowsocks_enable}" = false ]; then
          trojanGO_shadowsocks_enable=false
          break
      else
        if [[ ! ${trojanGO_shadowsocks_enable} = true ]]; then
          echoContent yellow "不可以输入除false和true之外的其他字符"
        else
          echoContent skyBlue "Shadowsocks AEAD加密方式如下:"
          echoContent yellow "1. AES-128-GCM(默认)"
          echoContent yellow "2. CHACHA20-IETF-POLY1305"
          echoContent yellow "3. AES-256-GCM"
          read -r -p '请输入Shadowsocks AEAD加密方式(默认:1): ' selectMethodType
          [ -z "${selectMethodType}" ] && selectMethodType=1
          case ${selectMethodType} in
          1)
            trojanGO_shadowsocks_method='AES-128-GCM'
            ;;
          2)
            trojanGO_shadowsocks_method='CHACHA20-IETF-POLY1305'
            ;;
          3)
            trojanGO_shadowsocks_method='AES-256-GCM'
            ;;
          *)
            trojanGO_shadowsocks_method='AES-128-GCM'
          esac

          while read -r -p '请输入Shadowsocks AEAD加密密码(必填): ' trojanGO_shadowsocks_password; do
            if [[ -z ${trojanGO_shadowsocks_password} ]]; then
              echoContent red "密码不能为空"
            else
              break
            fi
          done
          break
        fi
      fi
    done

    cat >${TROJANGO_STANDALONE_CONFIG} <<EOF
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": ${trojanGO_port},
  "remote_addr": "${remote_addr}",
  "remote_port": 80,
  "log_level": 1,
  "log_file": "",
  "password": [
      "${trojan_pas}"
  ],
  "disable_http_check": false,
  "udp_timeout": 60,
  "ssl": {
    "verify": true,
    "verify_hostname": true,
    "cert": "${CADDY_ACME}/${domain}/${domain}.crt",
    "key": "${CADDY_ACME}/${domain}/${domain}.key",
    "key_password": "",
    "cipher": "",
    "curves": "",
    "prefer_server_cipher": false,
    "sni": "",
    "alpn": [
      "http/1.1"
    ],
    "session_ticket": true,
    "reuse_session": true,
    "plain_http_response": "",
    "fallback_addr": "",
    "fallback_port": 80,
    "fingerprint": ""
  },
  "tcp": {
    "no_delay": true,
    "keep_alive": true,
    "prefer_ipv4": false
  },
    "mux": {
    "enabled": ${trojanGO_mux_enable},
    "concurrency": 8,
    "idle_timeout": 60
  },
  "websocket": {
    "enabled": ${trojanGO_websocket_enable},
    "path": "/${trojanGO_websocket_path}",
    "host": "${domain}"
  },
  "shadowsocks": {
    "enabled": ${trojanGO_shadowsocks_enable},
    "method": "${trojanGO_shadowsocks_method}",
    "password": "${trojanGO_shadowsocks_password}"
  },
  "mysql": {
    "enabled": false,
    "server_addr": "localhost",
    "server_port": 3306,
    "database": "",
    "username": "",
    "password": "",
    "check_rate": 60
  }
}
EOF
    docker pull teddysun/trojan-go && \
    docker run -d --name trojan-panel-trojanGO-standalone --restart=always \
    -p ${trojanGO_port}:${trojanGO_port} \
    -v ${TROJANGO_STANDALONE_CONFIG}:"/etc/trojan-go/config.json" -v ${CADDY_ACME}:${CADDY_ACME} teddysun/trojan-go \
    && docker network connect trojan-panel-network trojan-panel-trojanGO-standalone

    if [[ -n $(docker ps -q -f "name=^trojan-panel-trojanGO-standalone$") ]]; then
      echoContent skyBlue "---> TrojanGO 单机版 安装完成"
      echoContent red "\n=============================================================="
      echoContent skyBlue "TrojanGO+Caddy+Web+TLS+Websocket节点 单机版 安装成功"
      echoContent yellow "域名: ${domain}"
      echoContent yellow "TrojanGO的端口: ${trojanGO_port}"
      echoContent yellow "TrojanGO的密码: ${trojan_pas}"
      if [[ ${trojanGO_websocket_enable} = true ]]; then
          echoContent yellow "Websocket路径: ${trojanGO_websocket_path}"
      fi
      if [[ ${trojanGO_shadowsocks_enable} = true ]]; then
          echoContent yellow "Shadowsocks AEAD加密方式: ${trojanGO_shadowsocks_method}"
          echoContent yellow "Shadowsocks AEAD加密密码: ${trojanGO_shadowsocks_password}"
      fi
      echoContent red "\n=============================================================="
    else
      echoContent red "---> TrojanGO 单机版 安装失败"
      exit 0
    fi
  else
    echoContent skyBlue "---> 你已经了安装了TrojanGO 单机版"
  fi
}

# 卸载TrojanGo+Caddy+Web+TLS+Websocket节点 数据库版
function uninstallTrojanGO() {
  # 判断TrojanGo+Caddy+Web+TLS+Websocket节点 数据库版是否安装
  if [[ -n $(docker ps -q -f "name=^trojan-panel-trojanGO$") ]]; then
    echoContent green "---> 卸载TrojanGo+Caddy+Web+TLS+Websocket节点 数据库版"

    # 强制删除容器
    docker rm -f trojan-panel-trojanGO
    # 删除image
    docker rmi teddysun/trojan-go

    # 删除文件
    rm -f ${TROJANGO_CONFIG}

    echoContent skyBlue "---> TrojanGo+Caddy+Web+TLS+Websocket节点 数据库版卸载完成"
  else
    echoContent red "---> 请先安装TrojanGo+Caddy+Web+TLS+Websocket节点 数据库版"
  fi
}

# 卸载TrojanGo+Caddy+Web+TLS+Websocket节点 单机版
function uninstallTrojanGOStandalone() {
  # 判断TrojanGo+Caddy+Web+TLS+Websocket节点 单机版是否安装
  if [[ -n $(docker ps -q -f "name=^trojan-panel-trojanGO-standalone$") ]]; then
    echoContent green "---> 卸载TrojanGo+Caddy+Web+TLS+Websocket节点 单机版"

    # 强制删除容器
    docker rm -f trojan-panel-trojanGO-standalone
    # 删除image
    docker rmi teddysun/trojan-go

    # 删除文件
    rm -f ${TROJANGO_STANDALONE_CONFIG}

    echoContent skyBlue "---> TrojanGo+Caddy+Web+TLS+Websocket节点 单机版卸载完成"
  else
    echoContent red "---> 请先安装TrojanGo+Caddy+Web+TLS+Websocket节点 单机版"
  fi
}

function main() {
  cd "$HOME" || exit
  mkdirTools
  checkSystem
  clear
  echoContent red "\n=============================================================="
  echoContent skyBlue "System Required: CentOS 6+, Debian8+, Ubuntu16+"
  echoContent skyBlue "Version: v2.0.0"
  echoContent skyBlue "Description: One click Install Trojan Panel server"
  echoContent skyBlue "Author: jonssonyan <https://jonssonyan.com>"
  echoContent skyBlue "Github: https://github.com/trojanpanel"
  echoContent red "\n=============================================================="
  echoContent yellow "1. 卸载阿里云盾(仅阿里云服务)"
  echoContent yellow "2. 安装BBRplus(仅CentOS)"
  echoContent green "\n=============================================================="
  echoContent yellow "3. 安装Trojan Panel"
  echoContent yellow "4. 更新Trojan Panel"
  echoContent yellow "5. 卸载Trojan Panel"
  echoContent green "\n=============================================================="
  echoContent yellow "6. 安装TrojanGFW+Caddy+Web+TLS节点 数据库版"
  echoContent yellow "7. 安装TrojanGFW+Caddy+Web+TLS节点 单机版"
  echoContent yellow "8. 卸载TrojanGFW+Caddy+Web+TLS节点 数据库版"
  echoContent yellow "9. 卸载TrojanGFW+Caddy+Web+TLS节点 单机版"
  echoContent green "\n=============================================================="
  echoContent yellow "10. 安装TrojanGo+Caddy+Web+TLS+Websocket节点 数据库版"
  echoContent yellow "11. 安装TrojanGo+Caddy+Web+TLS+Websocket节点 单机版"
  echoContent yellow "12. 卸载TrojanGo+Caddy+Web+TLS+Websocket节点 数据库版"
  echoContent yellow "13. 卸载TrojanGo+Caddy+Web+TLS+Websocket节点 单机版"
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
    import_sql trojan-panel
    installTrojanPanel
    ;;
  4)
    updateTrojanPanel
    ;;
  5)
    uninstallTrojanPanel
    ;;
  6)
    installDocker
    installCaddyTLS
    installTrojanGFW
    ;;
  7)
    installDocker
    installCaddyTLS
    installTrojanGFWStandalone
    ;;
  8)
    uninstallTrojanGFW
    ;;
  9)
    uninstallTrojanGFWStandalone
    ;;
  10)
    installDocker
    installCaddyTLS
    installTrojanGO
    ;;
  11)
    installDocker
    installCaddyTLS
    installTrojanGOStandalone
    ;;
  12)
    uninstallTrojanGO
    ;;
  13)
    uninstallTrojanGOStandalone
    ;;
  *)
    echoContent red "没有这个选项"
  esac
}

main
