#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# System Required: CentOS 7+/Ubuntu 18+/Debian 10+
# Version: v1.0.0
# Description: One click Install Trojan Panel server
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/trojanpanel/install-script

init_var() {
  ECHO_TYPE="echo -e"

  package_manager=""
  release=""
  get_arch=""
  can_google=0

  # Docker
  DOCKER_MIRROR='"https://registry.docker-cn.com","https://hub-mirror.c.163.com","https://docker.mirrors.ustc.edu.cn"'

  # 项目目录
  TP_DATA="/tpdata/"

  STATIC_HTML="https://github.com/trojanpanel/install-script/releases/download/v1.0.0/html.tar.gz"

  # Caddy
  CADDY_DATA="/tpdata/caddy/"
  CADDY_Caddyfile="/tpdata/caddy/Caddyfile"
  CADDY_SRV="/tpdata/caddy/srv/"
  CADDY_ACME="/tpdata/caddy/acme/"
  DOMAIN_FILE="/tpdata/caddy/domain.lock"
  domain=""
  caddy_remote_port=8863
  your_email="123456@qq.com"
  crt_path=""
  key_path=""
  ssl_option=1

  # MariaDB
  MARIA_DATA="/tpdata/mariadb/"
  mariadb_ip="127.0.0.1"
  mariadb_port=3306
  mariadb_user="root"
  mariadb_pas=""

  #Redis
  REDIS_DATA="/tpdata/redis/"
  redis_host="127.0.0.1"
  redis_port=6379
  redis_pass=""

  # Trojan Panel
  TROJAN_PANEL_DATA="/tpdata/trojan-panel/"
  TROJAN_PANEL_WEBFILE="/tpdata/trojan-panel/webfile/"
  TROJAN_PANEL_LOGS="/tpdata/trojan-panel/logs/"

  # Trojan Panel UI
  TROJAN_PANEL_UI_DATA="/tpdata/trojan-panel-ui/"
  # Nginx
  NGINX_DATA="/tpdata/nginx/"
  NGINX_CONFIG="/tpdata/nginx/default.conf"

  # Trojan Panel Core
  TROJAN_PANEL_CORE_DATA="/tpdata/trojan-panel-core/"
  TROJAN_PANEL_CORE_LOGS="/tpdata/trojan-panel-core/logs/"
  database="trojan_panel_db"
  account_table="account"
}

echo_content() {
  case $1 in
  "red")
    ${ECHO_TYPE} "\033[31m$2\033[0m"
    ;;
  "green")
    ${ECHO_TYPE} "\033[32m$2\033[0m"
    ;;
  "yellow")
    ${ECHO_TYPE} "\033[33m$2\033[0m"
    ;;
  "blue")
    ${ECHO_TYPE} "\033[34m$2\033[0m"
    ;;
  "purple")
    ${ECHO_TYPE} "\033[35m$2\033[0m"
    ;;
  "skyBlue")
    ${ECHO_TYPE} "\033[36m$2\033[0m"
    ;;
  "white")
    ${ECHO_TYPE} "\033[37m$2\033[0m"
    ;;
  esac
}

mkdir_tools() {
  # 项目目录
  mkdir -p ${TP_DATA}

  # Caddy
  mkdir -p ${CADDY_DATA}
  touch ${CADDY_Caddyfile}
  mkdir -p ${CADDY_SRV}
  mkdir -p ${CADDY_ACME}

  # MariaDB
  mkdir -p ${MARIA_DATA}

  # Redis
  mkdir -p ${REDIS_DATA}

  # Trojan Panel
  mkdir -p ${TROJAN_PANEL_DATA}
  mkdir -p ${TROJAN_PANEL_LOGS}

  # Trojan Panel UI
  mkdir -p ${TROJAN_PANEL_UI_DATA}
  # # Nginx
  mkdir -p ${NGINX_DATA}
  touch ${NGINX_CONFIG}

  # Trojan Panel Core
  mkdir -p ${TROJAN_PANEL_CORE_DATA}
  mkdir -p ${TROJAN_PANEL_CORE_LOGS}
}

can_connect() {
  ping -c2 -i0.3 -W1 "$1" &>/dev/null
  if [[ "$?" == "0" ]]; then
    return 0
  else
    return 1
  fi
}

check_sys() {
  if [[ $(command -v yum) ]]; then
    package_manager='yum'
  elif [[ $(command -v dnf) ]]; then
    package_manager='dnf'
  elif [[ $(command -v apt) ]]; then
    package_manager='apt'
  elif [[ $(command -v apt-get) ]]; then
    package_manager='apt-get'
  fi

  if [[ -z "${package_manager}" ]]; then
    echo_content red "暂不支持该系统"
    exit 0
  fi

  if [[ -n $(find /etc -name "redhat-release") ]] || grep </proc/version -q -i "centos"; then
    release="centos"
  elif grep </etc/issue -q -i "debian" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "debian" && [[ -f "/proc/version" ]]; then
    release="debian"
  elif grep </etc/issue -q -i "ubuntu" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "ubuntu" && [[ -f "/proc/version" ]]; then
    release="ubuntu"
  fi

  if [[ -z "${release}" ]]; then
    echo_content red "仅支持CentOS 7+/Ubuntu 18+/Debian 10+系统"
    exit 0
  fi

  if [[ $(arch) =~ ("x86_64"|"amd64"|"arm64"|"aarch64"|"arm"|"s390x") ]]; then
    get_arch=$(arch)
  fi

  if [[ -z "${get_arch}" ]]; then
    echo_content red "仅支持amd64/arm64/arm/s390x处理器架构"
    exit 0
  fi
}

depend_install() {
  if [[ "${package_manager}" != 'yum' && "${package_manager}" != 'dnf' ]]; then
    ${package_manager} update -y
  fi
  ${package_manager} install -y \
    curl \
    wget \
    tar \
    lsof \
    systemd
}

# 安装BBRPlus 仅支持CentOS系统
install_bbr_plus() {
  kernel_version="4.14.129-bbrplus"
  if [[ ! -f /etc/redhat-release ]]; then
    echo_content yellow "仅支持CentOS系统"
    exit 0
  fi

  if [[ "$(uname -r)" == "${kernel_version}" ]]; then
    echo_content yellow "内核已经安装，无需重复执行"
    exit 0
  fi

  # 卸载原加速
  echo_content green "卸载加速..."
  sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
  if [[ -e /appex/bin/serverSpeeder.sh ]]; then
    wget --no-check-certificate -O appex.sh https://raw.githubusercontent.com/0oVicero0/serverSpeeder_Install/master/appex.sh && chmod +x appex.sh && bash appex.sh uninstall
    rm -f appex.sh
  fi
  echo_content green "下载内核..."
  wget https://github.com/cx9208/bbrplus/raw/master/centos7/x86_64/kernel-${kernel_version}.rpm
  echo_content green "安装内核..."
  yum install -y kernel-${kernel_version}.rpm

  # 检查内核是否安装成功
  list="$(awk -F\' '$1=="menuentry " {print i++ " : " $2}' /etc/grub2.cfg)"
  target="CentOS Linux (${kernel_version})"
  result=$(echo "${list}" | grep "${target}")
  if [[ -z "${result}" ]]; then
    echo_content red "内核安装失败"
    exit 1
  fi

  echo_content green "切换内核..."
  grub2-set-default "CentOS Linux (${kernel_version}) 7 (Core)"
  echo_content green "启用模块..."
  echo "net.core.default_qdisc=fq" >>/etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbrplus" >>/etc/sysctl.conf
  rm -f kernel-${kernel_version}.rpm

  read -r -p "BBRPlusPlus安装完成，现在重启 ? [Y/n] :" yn
  [[ -z "${yn}" ]] && yn="y"
  if [[ $yn == [Yy] ]]; then
    echo_content green "重启中..."
    reboot
  fi
}

# 安装Docker
install_docker() {
  if [[ ! $(docker -v 2>/dev/null) ]]; then
    echo_content green "---> 安装Docker"

    # 关闭防火墙
    if [[ "$(firewall-cmd --state 2>/dev/null)" == "running" ]]; then
      systemctl stop firewalld.service && systemctl disable firewalld.service
    fi

    # 时区
    timedatectl set-timezone Asia/Shanghai

    can_connect www.google.com
    [[ "$?" == "0" ]] && can_google=1

    if [[ ${can_google} == 0 ]]; then
      sh <(curl -sL https://get.docker.com) --mirror Aliyun
      # 设置Docker国内源
      mkdir -p /etc/docker &&
        cat >/etc/docker/daemon.json <<EOF
{
  "registry-mirrors":[${DOCKER_MIRROR}],
  "log-driver":"json-file",
  "log-opts":{
      "max-size":"50m",
      "max-file":"3"
  }
}
EOF
    else
      sh <(curl -sL https://get.docker.com)
    fi

    systemctl enable docker &&
      systemctl restart docker &&

    if [[ $(docker -v 2>/dev/null) ]]; then
      echo_content skyBlue "---> Docker安装完成"
    else
      echo_content red "---> Docker安装失败"
      exit 0
    fi
  else
    echo_content skyBlue "---> 你已经安装了Docker"
  fi
}

# 安装Caddy TLS
install_caddy_tls() {
  if [[ -z $(docker ps -q -f "name=^trojan-panel-caddy$") ]]; then
    echo_content green "---> 安装Caddy TLS"

    wget --no-check-certificate -O ${CADDY_DATA}html.tar.gz ${STATIC_HTML} &&
      tar -zxvf ${CADDY_DATA}html.tar.gz -C ${CADDY_SRV}

    read -r -p "请输入Caddy的转发端口(用于申请证书,默认:8863): " caddy_remote_port
    [[ -z "${caddy_remote_port}" ]] && caddy_remote_port=8863

    while read -r -p "请输入你的域名(必填): " domain; do
      if [[ -z "${domain}" ]]; then
        echo_content red "域名不能为空"
      else
        break
      fi
    done

    mkdir "${CADDY_ACME}${domain}"

    while read -r -p "请选择设置证书的方式?(1/自动申请和续签证书 2/手动设置证书路径 默认:1/自动申请和续签证书): " ssl_option; do
      if [[ -z ${ssl_option} || ${ssl_option} == 1 ]]; then

        echo_content yellow "正在检测域名,请稍后..."
        ping_ip=$(ping "${domain}" -s1 -c1 | grep "ttl=" | head -n1 | cut -d"(" -f2 | cut -d")" -f1)
        curl_ip=$(curl ifconfig.me)
        if [[ "${ping_ip}" != "${curl_ip}" ]]; then
          echo_content yellow "你的域名没有解析到本机IP,请稍后再试"
          echo_content red "---> Caddy安装失败"
          exit 0
        fi

        read -r -p "请输入你的邮箱(用于申请证书,默认:123456@qq.com): " your_email
        [[ -z "${your_email}" ]] && your_email="123456@qq.com"

        cat >${CADDY_Caddyfile} <<EOF
http://${domain}:80 {
    redir https://${domain}:${caddy_remote_port}{url}
}
https://${domain}:${caddy_remote_port} {
    gzip
    tls ${your_email}
    root ${CADDY_SRV}
}
EOF
        break
      else
        if [[ ${ssl_option} != 2 ]]; then
          echo_content red "不可以输入除1和2之外的其他字符"
        else

          while read -r -p "请输入证书的.crt文件路径(必填): " crt_path; do
            if [[ -z "${crt_path}" ]]; then
              echo_content red "路径不能为空"
            else
              if [[ ! -f "${crt_path}" ]]; then
                echo_content red "证书的.crt文件路径不存在"
              else
                cp "${crt_path}" "${CADDY_ACME}${domain}/${domain}.crt"
                break
              fi
            fi
          done

          while read -r -p "请输入证书的.key文件路径(必填): " key_path; do
            if [[ -z "${key_path}" ]]; then
              echo_content red "路径不能为空"
            else
              if [[ ! -f "${key_path}" ]]; then
                echo_content red "证书的.key文件路径不存在"
              else
                cp "${key_path}" "${CADDY_ACME}${domain}/${domain}.key"
                break
              fi
            fi
          done

          cat >${CADDY_Caddyfile} <<EOF
http://${domain}:80 {
    redir https://${domain}:${caddy_remote_port}{url}
}
https://${domain}:${caddy_remote_port} {
    gzip
    tls /root/.caddy/acme/acme-v02.api.letsencrypt.org/sites/${domain}/${domain}.crt /root/.caddy/acme/acme-v02.api.letsencrypt.org/sites/${domain}/${domain}.key
    root ${CADDY_SRV}
}
EOF
          break
        fi
      fi
    done

    if [[ -n $(lsof -i:80,443 -t) ]]; then
      kill -9 "$(lsof -i:80,443 -t)"
    fi

    docker pull teddysun/caddy:1.0.5 &&
      docker run -d --name trojan-panel-caddy --restart always \
        --network=host \
        -v ${CADDY_Caddyfile}:"/etc/caddy/Caddyfile" \
        -v ${CADDY_ACME}:"/root/.caddy/acme/acme-v02.api.letsencrypt.org/sites/" \
        -v ${CADDY_SRV}:${CADDY_SRV} \
        teddysun/caddy:1.0.5

    if [[ -n $(docker ps -q -f "name=^trojan-panel-caddy$") ]]; then
      cat >${DOMAIN_FILE} <<EOF
${domain}
EOF
      echo_content skyBlue "---> Caddy安装完成"
    else
      echo_content red "---> Caddy安装失败"
      exit 0
    fi
  else
    domain=$(cat "${DOMAIN_FILE}")
    echo_content skyBlue "---> 你已经安装了Caddy"
  fi
}

# 安装MariaDB
install_mariadb() {
  if [[ -z $(docker ps -q -f "name=^trojan-panel-mariadb$") ]]; then
    echo_content green "---> 安装MariaDB"

    read -r -p "请输入数据库的端口(默认:3306): " mariadb_port
    [[ -z "${mariadb_port}" ]] && mariadb_port=3306
    read -r -p "请输入数据库的用户名(默认:root): " mariadb_user
    [[ -z "${mariadb_user}" ]] && mariadb_user="root"
    while read -r -p "请输入数据库的密码(必填): " mariadb_pas; do
      if [[ -z "${mariadb_pas}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    if [[ "${mariadb_user}" == "root" ]]; then
      docker pull mariadb:10.7.3 &&
        docker run -d --name trojan-panel-mariadb --restart always \
          --network=host \
          -v ${MARIA_DATA}:/var/lib/mysql \
          -e MYSQL_DATABASE="trojan_panel_db" \
          -e MYSQL_ROOT_PASSWORD="${mariadb_pas}" \
          -e TZ=Asia/Shanghai \
          mariadb:10.7.3
    else
      docker pull mariadb:10.7.3 &&
        docker run -d --name trojan-panel-mariadb --restart always \
          --network=host \
          -v ${MARIA_DATA}:/var/lib/mysql \
          -e MYSQL_DATABASE="trojan_panel_db" \
          -e MYSQL_ROOT_PASSWORD="${mariadb_pas}" \
          -e MYSQL_USER="${mariadb_user}" \
          -e MYSQL_PASSWORD="${mariadb_pas}" \
          -e TZ=Asia/Shanghai \
          mariadb:10.7.3
    fi

    if [[ -n $(docker ps -q -f "name=^trojan-panel-mariadb$") ]]; then
      echo_content skyBlue "---> MariaDB安装完成"
      echo_content yellow "---> MariaDB root的数据库密码(请妥善保存): ${mariadb_pas}"
      if [[ "${mariadb_user}" != "root" ]]; then
        echo_content yellow "---> MariaDB ${mariadb_user}的数据库密码(请妥善保存): ${mariadb_pas}"
      fi
    else
      echo_content red "---> MariaDB安装失败"
      exit 0
    fi
  else
    echo_content skyBlue "---> 你已经安装了MariaDB"
  fi
}

# 安装Redis
install_redis() {
  if [[ -z $(docker ps -q -f "name=^trojan-panel-redis$") ]]; then
    echo_content green "---> 安装Redis"

    read -r -p "请输入Redis的端口(默认:6379): " redis_port
    [[ -z "${redis_port}" ]] && redis_port=6379
    while read -r -p "请输入Redis的密码(必填): " redis_pass; do
      if [[ -z "${redis_pass}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    docker pull redis:6.2.7 &&
      docker run -d --name trojan-panel-redis --restart always \
        --network=host \
        -v ${REDIS_DATA}:/data redis:6.2.7 \
        redis-server --requirepass "${redis_pass}"

    if [[ -n $(docker ps -q -f "name=^trojan-panel-redis$") ]]; then
      echo_content skyBlue "---> Redis安装完成"
      echo_content yellow "---> Redis的数据库密码(请妥善保存): ${redis_pass}"
    else
      echo_content red "---> Redis安装失败"
      exit 0
    fi
  else
    echo_content skyBlue "---> 你已经安装了Redis"
  fi
}

# 安装TrojanPanel
install_trojan_panel() {
  if [[ -z $(docker ps -q -f "name=^trojan-panel$") ]]; then
    echo_content green "---> 安装Trojan Panel"

    read -r -p "请输入数据库的IP地址(默认:本机数据库): " mariadb_ip
    [[ -z "${mariadb_ip}" ]] && mariadb_ip="127.0.0.1"
    read -r -p "请输入数据库的端口(默认:本机数据库端口): " mariadb_port
    [[ -z "${mariadb_port}" ]] && mariadb_port=3306
    read -r -p "请输入数据库的用户名(默认:root): " mariadb_user
    [[ -z "${mariadb_user}" ]] && mariadb_user="root"
    while read -r -p "请输入数据库的密码(必填): " mariadb_pas; do
      if [[ -z "${mariadb_pas}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    if [[ "${mariadb_ip}" == "127.0.0.1" ]]; then
      docker exec trojan-panel-mariadb mysql -p"${mariadb_pas}" -e "drop database trojan_panel_db;" &&
        docker exec trojan-panel-mariadb mysql -p"${mariadb_pas}" -e "create database trojan_panel_db;"
    else
      docker exec trojan-panel-mariadb mysql -h"${mariadb_ip}" -P"${mariadb_port}" -u"${mariadb_user}" -p"${mariadb_pas}" -e "drop database trojan_panel_db;" &>/dev/null &&
        docker exec trojan-panel-mariadb mysql -h"${mariadb_ip}" -P"${mariadb_port}" -u"${mariadb_user}" -p"${mariadb_pas}" -e "create database trojan_panel_db;" &>/dev/null
    fi

    read -r -p "请输入Redis的IP地址(默认:本机Redis): " redis_host
    [[ -z "${redis_host}" ]] && redis_host="127.0.0.1"
    read -r -p "请输入Redis的端口(默认:本机Redis端口): " redis_port
    [[ -z "${redis_port}" ]] && redis_port=6379
    while read -r -p "请输入Redis的密码(必填): " redis_pass; do
      if [[ -z "${redis_pass}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    if [[ "${mariadb_ip}" == "127.0.0.1" ]]; then
      docker exec trojan-panel-redis redis-cli -a "${redis_pass}" -e "flushall" &>/dev/null
    else
      docker exec trojan-panel-redis redis-cli -h "${redis_host}" -p ${redis_port} -a "${redis_pass}" -e "flushall" &>/dev/null
    fi

    docker pull jonssonyan/trojan-panel &&
      docker run -d --name trojan-panel --restart always \
        --network=host \
        -v ${CADDY_SRV}:${TROJAN_PANEL_WEBFILE} \
        -v ${TROJAN_PANEL_LOGS}:${TROJAN_PANEL_LOGS} \
        -v /etc/localtime:/etc/localtime \
        -e "mariadb_ip=${mariadb_ip}" \
        -e "mariadb_port=${mariadb_port}" \
        -e "mariadb_user=${mariadb_user}" \
        -e "mariadb_pas=${mariadb_pas}" \
        -e "redis_host=${redis_host}" \
        -e "redis_port=${redis_port}" \
        -e "redis_pass=${redis_pass}" \
        jonssonyan/trojan-panel

    if [[ -n $(docker ps -q -f "name=^trojan-panel$") ]]; then
      echo_content skyBlue "---> Trojan Panel后端安装完成"
    else
      echo_content red "---> Trojan Panel后端安装失败"
      exit 0
    fi
  else
    echo_content skyBlue "---> 你已经安装了Trojan Panel"
  fi

  if [[ -z $(docker ps -q -f "name=^trojan-panel-ui$") ]]; then
    # 配置Nginx
    cat >${NGINX_CONFIG} <<-EOF
server {
    listen       8888;
    listen       443 ssl;
    server_name  localhost;

    #强制ssl
    ssl on;
    ssl_certificate      ${CADDY_ACME}${domain}/${domain}.crt;
    ssl_certificate_key  ${CADDY_ACME}${domain}/${domain}.key;
    #缓存有效期
    ssl_session_timeout  5m;
    #安全链接可选的加密协议
    ssl_protocols  TLSv1 TLSv1.1 TLSv1.2;
    #加密算法
    ssl_ciphers  ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
    #使用服务器端的首选算法
    ssl_prefer_server_ciphers  on;

    #access_log  /var/log/nginx/host.access.log  main;

    location / {
        root   ${TROJAN_PANEL_UI_DATA};
        index  index.html index.htm;
    }

    location /api {
        proxy_pass http://127.0.0.1:8081;
    }

    #error_page  404              /404.html;
    #497 http->https
    error_page  497              https://\$host:8888\$uri?\$args;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF

    docker pull jonssonyan/trojan-panel-ui &&
      docker run -d --name trojan-panel-ui --restart always \
        --network=host \
        -v ${NGINX_CONFIG}:/etc/nginx/conf.d/default.conf \
        -v ${CADDY_ACME}"${domain}":${CADDY_ACME}"${domain}" \
        jonssonyan/trojan-panel-ui

    if [[ -n $(docker ps -q -f "name=^trojan-panel-ui$") ]]; then
      echo_content skyBlue "---> Trojan Panel前端安装完成"
    else
      echo_content red "---> Trojan Panel前端安装失败"
      exit 0
    fi
  else
    echo_content skyBlue "---> 你已经安装了Trojan Panel UI"
  fi

  echo_content red "\n=============================================================="
  echo_content skyBlue "Trojan Panel 安装成功"
  echo_content yellow "MariaDB ${mariadb_user}的密码(请妥善保存): ${mariadb_pas}"
  echo_content yellow "Redis的密码(请妥善保存): ${redis_pass}"
  echo_content yellow "管理面板地址: https://${domain}:8888"
  echo_content yellow "系统管理员 默认用户名: sysadmin 默认密码: 123456 请及时登陆管理面板修改密码"
  echo_content yellow "Trojan Panel私钥和证书目录: ${CADDY_ACME}${domain}/"
  echo_content red "\n=============================================================="
}

# 安装Trojan Panel Core
install_trojan_panel_core() {
  if [[ -z $(docker ps -q -f "name=^trojan-panel-core$") ]]; then
    echo_content green "---> 安装Trojan Panel Core"
    read -r -p "请输入数据库的IP地址(默认:本机数据库): " mariadb_ip
    [[ -z "${mariadb_ip}" ]] && mariadb_ip="127.0.0.1"
    read -r -p "请输入数据库的端口(默认:本机数据库端口): " mariadb_port
    [[ -z "${mariadb_port}" ]] && mariadb_port=3306
    read -r -p "请输入数据库的用户名(默认:root): " mariadb_user
    [[ -z "${mariadb_user}" ]] && mariadb_user="root"
    while read -r -p "请输入数据库的密码(必填): " mariadb_pas; do
      if [[ -z "${mariadb_pas}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done
    read -r -p "请输入数据库名称(默认:trojan_panel_db): " database
    [[ -z "${database}" ]] && database="trojan_panel_db"
    read -r -p "请输入数据库的用户表名称(默认:account): " account_table
    [[ -z "${account_table}" ]] && account_table="account"

    read -r -p "请输入Redis的IP地址(默认:本机Redis): " redis_host
    [[ -z "${redis_host}" ]] && redis_host="127.0.0.1"
    read -r -p "请输入Redis的端口(默认:本机Redis端口): " redis_port
    [[ -z "${redis_port}" ]] && redis_port=6379
    while read -r -p "请输入Redis的密码(必填): " redis_pass; do
      if [[ -z "${redis_pass}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    domain=$(cat "${DOMAIN_FILE}")

    docker pull jonssonyan/trojan-panel-core &&
      docker run -d --name trojan-panel-core --restart always \
        --network=host \
        -v ${TROJAN_PANEL_CORE_LOGS}:${TROJAN_PANEL_CORE_LOGS} \
        -v /etc/localtime:/etc/localtime \
        -v ${CADDY_ACME}:${CADDY_ACME} \
        -e "mariadb_ip=${mariadb_ip}" \
        -e "mariadb_port=${mariadb_port}" \
        -e "mariadb_user=${mariadb_user}" \
        -e "mariadb_pas=${mariadb_pas}" \
        -e "database=${database}" \
        -e "account-table=${account_table}" \
        -e "redis_host=${redis_host}" \
        -e "redis_port=${redis_port}" \
        -e "redis_pass=${redis_pass}" \
        -e "crt_path=${CADDY_ACME}${domain}/${domain}.crt" \
        -e "key_path=${CADDY_ACME}${domain}/${domain}.key" \
        jonssonyan/trojan-panel-core
    if [[ -n $(docker ps -q -f "name=^trojan-panel-core$") ]]; then
      echo_content skyBlue "---> Trojan Panel Core安装完成"
    else
      echo_content red "---> Trojan Panel Core后端安装失败"
      exit 0
    fi
  else
    echo_content skyBlue "---> 你已经安装了Trojan Panel Core"
  fi
}

# 更新Trojan Panel
update_trojan_panel() {
  # 判断Trojan Panel是否安装
  if [[ -z $(docker ps -q -f "name=^trojan-panel$") ]]; then
    echo_content red "---> 请先安装Trojan Panel"
    exit 0
  fi

  echo_content green "---> 更新Trojan Panel"

  read -r -p "请输入数据库的IP地址(默认:本机数据库): " mariadb_ip
  [[ -z "${mariadb_ip}" ]] && mariadb_ip="127.0.0.1"
  read -r -p "请输入数据库的端口(默认:本机数据库端口): " mariadb_port
  [[ -z "${mariadb_port}" ]] && mariadb_port=3306
  read -r -p "请输入数据库的用户名(默认:root): " mariadb_user
  [[ -z "${mariadb_user}" ]] && mariadb_user="root"
  while read -r -p "请输入数据库的密码(必填): " mariadb_pas; do
    if [[ -z "${mariadb_pas}" ]]; then
      echo_content red "密码不能为空"
    else
      break
    fi
  done

  if [[ "${mariadb_ip}" == "127.0.0.1" ]]; then
    docker exec trojan-panel-mariadb mysql -p"${mariadb_pas}" -e "drop database trojan_panel_db;"
    docker exec trojan-panel-mariadb mysql -p"${mariadb_pas}" -e "create database trojan_panel_db;"
  else
    docker exec trojan-panel-mariadb mysql -h"${mariadb_ip}" -P"${mariadb_port}" -u"${mariadb_user}" -p"${mariadb_pas}" -e "drop database trojan_panel_db;" &>/dev/null
    docker exec trojan-panel-mariadb mysql -h"${mariadb_ip}" -P"${mariadb_port}" -u"${mariadb_user}" -p"${mariadb_pas}" -e "create database trojan_panel_db;" &>/dev/null
  fi

  read -r -p "请输入Redis的IP地址(默认:本机Redis): " redis_host
  [[ -z "${redis_host}" ]] && redis_host="127.0.0.1"
  read -r -p "请输入Redis的端口(默认:本机Redis端口): " redis_port
  [[ -z "${redis_port}" ]] && redis_port=6379
  while read -r -p "请输入Redis的密码(必填): " redis_pass; do
    if [[ -z "${redis_pass}" ]]; then
      echo_content red "密码不能为空"
    else
      break
    fi
  done

  if [[ "${mariadb_ip}" == "127.0.0.1" ]]; then
    docker exec trojan-panel-redis redis-cli -a "${redis_pass}" -e "flushall" &>/dev/null
  else
    docker exec trojan-panel-redis redis-cli -h "${redis_host}" -p ${redis_port} -a "${redis_pass}" -e "flushall" &>/dev/null
  fi

  docker rm -f trojan-panel &&
    docker rmi -f jonssonyan/trojan-panel &&
    rm -rf ${TROJAN_PANEL_DATA}

  docker rm -f trojan-panel-ui &&
    docker rmi -f jonssonyan/trojan-panel-ui &&
    rm -rf ${TROJAN_PANEL_UI_DATA}

  docker pull jonssonyan/trojan-panel &&
    docker run -d --name trojan-panel --restart always \
      --network=host \
      -v ${CADDY_SRV}:${TROJAN_PANEL_WEBFILE} \
      -v ${TROJAN_PANEL_LOGS}:${TROJAN_PANEL_LOGS} \
      -v /etc/localtime:/etc/localtime \
      -e "mariadb_ip=${mariadb_ip}" \
      -e "mariadb_port=${mariadb_port}" \
      -e "mariadb_user=${mariadb_user}" \
      -e "mariadb_pas=${mariadb_pas}" \
      -e "redis_host=${redis_host}" \
      -e "redis_port=${redis_port}" \
      -e "redis_pass=${redis_pass}" \
      jonssonyan/trojan-panel

  if [[ "$?" == "0" ]]; then
    echo_content skyBlue "---> Trojan Panel更新完成"
  else
    echo_content red "---> Trojan Panel更新失败"
  fi

  docker pull jonssonyan/trojan-panel-ui &&
    docker run -d --name trojan-panel-ui --restart always \
      --network=host \
      -v ${NGINX_CONFIG}:/etc/nginx/conf.d/default.conf \
      -v ${CADDY_ACME}"${domain}":${CADDY_ACME}"${domain}" \
      jonssonyan/trojan-panel-ui

  if [[ "$?" == "0" ]]; then
    echo_content skyBlue "---> Trojan Panel UI更新完成"
  else
    echo_content red "---> Trojan Panel UI更新失败"
  fi
}

# 更新Trojan Panel Core
update_trojan_panel_core() {
  # 判断Trojan Panel Core是否安装
  if [[ -z $(docker ps -q -f "name=^trojan-panel-core$") ]]; then
    echo_content red "---> 请先安装Trojan Panel Core"
    exit 0
  fi

  echo_content green "---> 更新Trojan Panel Core"

  read -r -p "请输入数据库的IP地址(默认:本机数据库): " mariadb_ip
  [[ -z "${mariadb_ip}" ]] && mariadb_ip="127.0.0.1"
  read -r -p "请输入数据库的端口(默认:本机数据库端口): " mariadb_port
  [[ -z "${mariadb_port}" ]] && mariadb_port=3306
  read -r -p "请输入数据库的用户名(默认:root): " mariadb_user
  [[ -z "${mariadb_user}" ]] && mariadb_user="root"
  while read -r -p "请输入数据库的密码(必填): " mariadb_pas; do
    if [[ -z "${mariadb_pas}" ]]; then
      echo_content red "密码不能为空"
    else
      break
    fi
  done
  read -r -p "请输入数据库名称(默认:trojan_panel_db): " database
  [[ -z "${database}" ]] && database="trojan_panel_db"
  read -r -p "请输入数据库的用户表名称(默认:account): " account_table
  [[ -z "${account_table}" ]] && account_table="account"

  if [[ "${mariadb_ip}" == "127.0.0.1" ]]; then
    docker exec trojan-panel-mariadb mysql -p"${mariadb_pas}" -e "drop database trojan_panel_db;"
    docker exec trojan-panel-mariadb mysql -p"${mariadb_pas}" -e "create database trojan_panel_db;"
  else
    docker exec trojan-panel-mariadb mysql -h"${mariadb_ip}" -P"${mariadb_port}" -u"${mariadb_user}" -p"${mariadb_pas}" -e "drop database trojan_panel_db;" &>/dev/null
    docker exec trojan-panel-mariadb mysql -h"${mariadb_ip}" -P"${mariadb_port}" -u"${mariadb_user}" -p"${mariadb_pas}" -e "create database trojan_panel_db;" &>/dev/null
  fi

  read -r -p "请输入Redis的IP地址(默认:本机Redis): " redis_host
  [[ -z "${redis_host}" ]] && redis_host="127.0.0.1"
  read -r -p "请输入Redis的端口(默认:本机Redis端口): " redis_port
  [[ -z "${redis_port}" ]] && redis_port=6379
  while read -r -p "请输入Redis的密码(必填): " redis_pass; do
    if [[ -z "${redis_pass}" ]]; then
      echo_content red "密码不能为空"
    else
      break
    fi
  done

  if [[ "${mariadb_ip}" == "127.0.0.1" ]]; then
    docker exec trojan-panel-redis redis-cli -a "${redis_pass}" -e "flushall" &>/dev/null
  else
    docker exec trojan-panel-redis redis-cli -h "${redis_host}" -p ${redis_port} -a "${redis_pass}" -e "flushall" &>/dev/null
  fi

  docker rm -f trojan-panel-core &&
    docker rmi -f jonssonyan/trojan-panel-core &&
    rm -rf ${TROJAN_PANEL_CORE_DATA}

  docker pull jonssonyan/trojan-panel-core &&
    docker run -d --name trojan-panel-core --restart always \
      --network=host \
      -v ${TROJAN_PANEL_CORE_LOGS}:${TROJAN_PANEL_CORE_LOGS} \
      -v /etc/localtime:/etc/localtime \
      -e "mariadb_ip=${mariadb_ip}" \
      -e "mariadb_port=${mariadb_port}" \
      -e "mariadb_user=${mariadb_user}" \
      -e "mariadb_pas=${mariadb_pas}" \
      -e "database=${database}" \
      -e "account-table=${account_table}" \
      -e "redis_host=${redis_host}" \
      -e "redis_port=${redis_port}" \
      -e "redis_pass=${redis_pass}" \
      jonssonyan/trojan-panel-core

  if [[ "$?" == "0" ]]; then
    echo_content skyBlue "---> Trojan Panel Core更新完成"
  else
    echo_content red "---> Trojan Panel Core更新失败"
  fi
}

# 卸载Caddy TLS
uninstall_caddy_tls() {
  # 判断Caddy TLS是否安装
  if [[ -n $(docker ps -q -f "name=^trojan-panel-caddy$") ]]; then
    echo_content green "---> 卸载Caddy TLS"

    docker rm -f trojan-panel-caddy &&
      rm -rf ${CADDY_DATA}

    echo_content skyBlue "---> Caddy TLS卸载完成"
  else
    echo_content red "---> 请先安装Caddy TLS"
  fi
}

# 卸载MariaDB
uninstall_mariadb() {
  # 判断MariaDB是否安装
  if [[ -n $(docker ps -q -f "name=^trojan-panel-mariadb$") ]]; then
    echo_content green "---> 卸载MariaDB"

    docker rm -f trojan-panel-mariadb &&
      rm -rf ${MARIA_DATA}

    echo_content skyBlue "---> MariaDB卸载完成"
  else
    echo_content red "---> 请先安装MariaDB"
  fi
}

# 卸载Redis
uninstall_redis() {
  # 判断Redis是否安装
  if [[ -n $(docker ps -q -f "name=^trojan-panel-redis$") ]]; then
    echo_content green "---> 卸载Redis"

    docker rm -f trojan-panel-redis &&
      rm -rf ${REDIS_DATA}

    echo_content skyBlue "---> Redis卸载完成"
  else
    echo_content red "---> 请先安装Redis"
  fi
}

# 卸载Trojan Panel
uninstall_trojan_panel() {
  # 判断Trojan Panel是否安装
  if [[ -n $(docker ps -q -f "name=^trojan-panel$") ]]; then
    echo_content green "---> 卸载Trojan Panel"

    docker rm -f trojan-panel &&
      docker rmi -f jonssonyan/trojan-panel &&
      rm -rf ${TROJAN_PANEL_DATA}

    docker rm -f trojan-panel-ui &&
      docker rmi -f jonssonyan/trojan-panel-ui &&
      rm -rf ${TROJAN_PANEL_UI_DATA} &&
      rm -rf ${NGINX_DATA}

    echo_content skyBlue "---> Trojan Panel卸载完成"
  else
    echo_content red "---> 请先安装Trojan Panel"
  fi
}

# 卸载Trojan Panel Core
uninstall_trojan_panel_core() {
  # 判断Trojan Panel Core是否安装
  if [[ -n $(docker ps -q -f "name=^trojan-panel-core$") ]]; then
    echo_content green "---> 卸载Trojan Panel Core"

    docker rm -f trojan-panel-core &&
      docker rmi -f jonssonyan/trojan-panel-core &&
      rm -rf ${TROJAN_PANEL_CORE_DATA}

    echo_content skyBlue "---> Trojan Panel Core卸载完成"
  else
    echo_content red "---> 请先安装Trojan Panel Core"
  fi
}

# 卸载全部Trojan Panel相关的容器
uninstall_all() {
  echo_content green "---> 卸载全部Trojan Panel相关的容器"

  docker rm -f "$(docker ps -q -f "name=^trojan-panel")" &&
    docker rmi -f "$(docker images | grep "^trojan-panel" | awk '{print $3}')" &&
    rm -rf ${TP_DATA}

  echo_content skyBlue "---> 卸载全部Trojan Panel相关的容器完成"
}

# 故障检测
failure_testing() {
  echo_content green "---> 故障检测开始"
  if [[ ! $(docker -v 2>/dev/null) ]]; then
    echo_content red "---> Docker运行异常"
  else
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-caddy$") ]]; then
      if [[ -z $(docker ps -q -f "name=^trojan-panel-caddy$" -f "status=running") ]]; then
        echo_content red "---> Caddy TLS运行异常"
      else
        domain=$(cat "${DOMAIN_FILE}")
        if [[ -z $(cat "${DOMAIN_FILE}") || ! -d "${CADDY_ACME}${domain}" || ! -f "${CADDY_ACME}${domain}/${domain}.crt" ]]; then
          echo_content red "---> 证书申请异常，请尝试重启服务器将重新申请证书或者重新搭建选择自定义证书选项"
        fi
      fi
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-mariadb$") && -z $(docker ps -q -f "name=^trojan-panel-mariadb$" -f "status=running") ]]; then
      echo_content red "---> MariaDB运行异常"
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-redis$") && -z $(docker ps -q -f "name=^trojan-panel-redis$" -f "status=running") ]]; then
      echo_content red "---> Redis运行异常"
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel$") && -z $(docker ps -q -f "name=^trojan-panel$" -f "status=running") ]]; then
      echo_content red "---> Trojan Panel后端运行异常"
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-ui$") && -z $(docker ps -q -f "name=^trojan-panel-ui$" -f "status=running") ]]; then
      echo_content red "---> Trojan Panel前端运行异常"
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-core$") && -z $(docker ps -q -f "name=^trojan-panel-core$" -f "status=running") ]]; then
      echo_content red "---> Trojan Panel Core运行异常"
    fi
  fi
  echo_content green "---> 故障检测结束"
}

# 卸载阿里云内置相关监控
uninstall_aliyun() {
  # 卸载云监控(Cloudmonitor) Java 版
  /usr/local/cloudmonitor/wrapper/bin/cloudmonitor.sh stop &&
    /usr/local/cloudmonitor/wrapper/bin/cloudmonitor.sh remove &&
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

main() {
  cd "$HOME" || exit 0
  init_var
  mkdir_tools
  check_sys
  depend_install
  clear
  echo_content red "\n=============================================================="
  echo_content skyBlue "System Required: CentOS 7+/Ubuntu 18+/Debian 10+"
  echo_content skyBlue "Version: v1.0.0"
  echo_content skyBlue "Description: One click Install Trojan Panel server"
  echo_content skyBlue "Author: jonssonyan <https://jonssonyan.com>"
  echo_content skyBlue "Github: https://github.com/trojanpanel/install-script"
  echo_content red "\n=============================================================="
  echo_content yellow "1. 卸载阿里云盾(仅支持阿里云服务器)"
  echo_content yellow "2. 安装BBRPlus(仅支持CentOS系统)"
  echo_content green "\n=============================================================="
  echo_content yellow "3. 安装Trojan Panel"
  echo_content yellow "4. 更新Trojan Panel(注意: 会清除数据)"
  echo_content yellow "5. 卸载Trojan Panel"
  echo_content green "\n=============================================================="
  echo_content yellow "6. 安装Trojan Panel Core"
  echo_content yellow "7. 更新Trojan Panel Core"
  echo_content yellow "8. 卸载Trojan Panel Core"
  echo_content green "\n=============================================================="
  echo_content yellow "9. 卸载Caddy TLS"
  echo_content yellow "10. 卸载MariaDB"
  echo_content yellow "11. 卸载Redis"
  echo_content yellow "12. 卸载全部Trojan Panel相关的容器"
  echo_content green "\n=============================================================="
  echo_content yellow "13. 故障检测"
  read -r -p "请选择:" selectInstall_type
  case ${selectInstall_type} in
  1)
    uninstall_aliyun
    ;;
  2)
    install_bbr_plus
    ;;
  3)
    install_docker
    install_caddy_tls
    install_mariadb
    install_redis
    install_trojan_panel
    ;;
  4)
    update_trojan_panel
    ;;
  5)
    uninstall_trojan_panel
    ;;
  6)
    install_docker
    install_caddy_tls
    install_trojan_panel_core
    ;;
  7)
    update_trojan_panel_core
    ;;
  8)
    uninstall_trojan_panel_core
    ;;
  9)
    uninstall_caddy_tls
    ;;
  10)
    uninstall_mariadb
    ;;
  11)
    uninstall_redis
    ;;
  12)
    uninstall_all
    ;;
  13)
    failure_testing
    ;;
  *)
    echo_content red "没有这个选项"
    ;;
  esac
}

main
