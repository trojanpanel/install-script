#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

init_var() {
  ECHO_TYPE="echo -e"

  package_manager=""
  release=""
  get_arch=""
  can_google=0

  # Docker
  DOCKER_MIRROR='"https://registry.docker-cn.com","https://hub-mirror.c.163.com","https://docker.mirrors.ustc.edu.cn"'

  # Project directory
  TP_DATA="/tpdata/"

  STATIC_HTML="https://github.com/trojanpanel/install-script/releases/download/v1.0/html.tar.gz"

  # Web
  WEB_PATH="/tpdata/web/"

  # Cert
  CERT_PATH="/tpdata/cert/"
  DOMAIN_FILE="/tpdata/domain.lock"
  domain=""

  # Caddy2
  CADDY_DATA="/tpdata/caddy/"
  CADDY_CONFIG="${CADDY_DATA}config.json"
  CADDY_LOG="${CADDY_DATA}logs/"
  CADDY_CERT_DIR="${CERT_PATH}certificates/acme-v02.api.letsencrypt.org-directory/"
  caddy_port=80
  caddy_remote_port=8863
  your_email=""
  ssl_module_type=1
  ssl_module="acme"

  # TrojanGO
  TROJANGO_DATA="/tpdata/trojanGO/"
  TROJANGO_STANDALONE_CONFIG="/tpdata/trojanGO/standalone_config.json"
  trojanGO_port=443
  trojanGO_websocket_enable=0
  trojanGO_websocket_path="trojan-panel-websocket-path"
  trojanGO_shadowsocks_enable=0
  trojanGO_shadowsocks_method="AES-128-GCM"
  trojanGO_shadowsocks_password=""
  trojanGO_mux_enable=1
  # trojan
  trojan_pas=""
  remote_addr="127.0.0.1"

  # Hysteria
  HYSTERIA_DATA="/tpdata/hysteria/"
  HYSTERIA_STANDALONE_CONFIG="/tpdata/hysteria/standalone_config.json"
  hysteria_port=443
  hysteria_password=""
  hysteria_protocol="udp"
  hysteria_up_mbps=100
  hysteria_down_mbps=100

  # NaiveProxy
  NAIVEPROXY_DATA="/tpdata/naiveproxy/"
  NAIVEPROXY_STANDALONE_CONFIG="/tpdata/naiveproxy/standalone_config.json"
  naiveproxy_port=443
  naiveproxy_username=""
  naiveproxy_pass=""
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
  # Project directory
  mkdir -p ${TP_DATA}

  # Web
  mkdir -p ${WEB_PATH}

  # Cert
  mkdir -p ${CERT_PATH}
  touch ${DOMAIN_FILE}

  # Caddy2
  mkdir -p ${CADDY_DATA}
  touch ${CADDY_CONFIG}
  mkdir -p ${CADDY_LOG}

  # TrojanGO
  mkdir -p ${TROJANGO_DATA}
  touch ${TROJANGO_STANDALONE_CONFIG}

  # Hysteria
  mkdir -p ${HYSTERIA_DATA}
  touch ${HYSTERIA_STANDALONE_CONFIG}

  # NaiveProxy
  mkdir -p ${NAIVEPROXY_DATA}
  touch ${NAIVEPROXY_STANDALONE_CONFIG}
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
    echo_content red "The system is not currently supported"
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
    echo_content red "The operating system only supports CentOS 7+/Ubuntu 18+/Debian 10+"
    exit 0
  fi

  if [[ $(arch) =~ ("x86_64"|"amd64"|"arm64"|"aarch64"|"arm"|"s390x") ]]; then
    get_arch=$(arch)
  fi

  if [[ -z "${get_arch}" ]]; then
    echo_content red "The processor architecture only supports amd64/arm64/arm/s390x"
    exit 0
  fi

  can_connect www.google.com
  [[ "$?" == "0" ]] && can_google=1
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

# Install Docker
install_docker() {
  if [[ ! $(docker -v 2>/dev/null) ]]; then
    echo_content green "---> Install Docker"

    # turn off firewall
    if [[ "$(firewall-cmd --state 2>/dev/null)" == "running" ]]; then
      if [[ "${release}" == "centos" ]]; then
        systemctl disable firewalld
      elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
        sudo ufw disable
      fi
    fi

    # set time zone
    timedatectl set-timezone Asia/Shanghai

    if [[ ${can_google} == 0 ]]; then
      sh <(curl -sL https://get.docker.com) --mirror Aliyun
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
      mkdir -p /etc/docker &&
        cat >/etc/docker/daemon.json <<EOF
{
  "log-driver":"json-file",
  "log-opts":{
      "max-size":"50m",
      "max-file":"3"
  }
}
EOF
    fi

    systemctl enable docker &&
      systemctl restart docker

    if [[ $(docker -v 2>/dev/null) ]]; then
      echo_content skyBlue "---> Docker installation completed"
    else
      echo_content red "---> Docker installation failed"
      exit 0
    fi
  else
    echo_content skyBlue "---> You have installed Docker"
  fi
}

# Caddy2 https automatic application and renewal certificate configuration file
caddy2_https_auto_config() {
  cat >${CADDY_CONFIG} <<EOF
{
    "admin":{
        "disabled":true
    },
    "logging":{
        "logs":{
            "default":{
                "writer":{
                    "output":"file",
                    "filename":"${CADDY_LOG}error.log"
                },
                "level":"ERROR"
            }
        }
    },
    "storage":{
        "module":"file_system",
        "root":"${CERT_PATH}"
    },
    "apps":{
        "http":{
            "http_port": ${caddy_port},
            "servers":{
                "srv0":{
                    "listen":[
                        ":${caddy_port}"
                    ],
                    "routes":[
                        {
                            "match":[
                                {
                                    "host":[
                                        "${domain}"
                                    ]
                                }
                            ],
                            "handle":[
                                {
                                    "handler":"static_response",
                                    "headers":{
                                        "Location":[
                                            "https://{http.request.host}:${caddy_remote_port}{http.request.uri}"
                                        ]
                                    },
                                    "status_code":301
                                }
                            ]
                        }
                    ]
                },
                "srv1":{
                    "listen":[
                        ":${caddy_remote_port}"
                    ],
                    "routes":[
                        {
                            "handle":[
                                {
                                    "handler":"subroute",
                                    "routes":[
                                        {
                                            "match":[
                                                {
                                                    "host":[
                                                        "${domain}"
                                                    ]
                                                }
                                            ],
                                            "handle":[
                                                {
                                                    "handler":"file_server",
                                                    "root":"${WEB_PATH}",
                                                    "index_names":[
                                                        "index.html",
                                                        "index.htm"
                                                    ]
                                                }
                                            ],
                                            "terminal":true
                                        }
                                    ]
                                }
                            ]
                        }
                    ],
                    "tls_connection_policies":[
                        {
                            "match":{
                                "sni":[
                                    "${domain}"
                                ]
                            }
                        }
                    ],
                    "automatic_https":{
                        "disable":true
                    }
                }
            }
        },
        "tls":{
            "certificates":{
                "automate":[
                    "${domain}"
                ]
            },
            "automation":{
                "policies":[
                    {
                        "issuers":[
                            {
                                "module":"${ssl_module}",
                                "email":"${your_email}"
                            }
                        ]
                    }
                ]
            }
        }
    }
}
EOF
}

# Install Caddy2+https
install_caddy2() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-caddy$") ]]; then
    echo_content green "---> Install Caddy2+https"

    wget --no-check-certificate -O ${WEB_PATH}html.tar.gz -N ${STATIC_HTML} &&
      tar -zxvf ${WEB_PATH}html.tar.gz -k -C ${WEB_PATH}

    read -r -p "Please enter the port of Caddy2 (default: 80): " caddy_port
    [[ -z "${caddy_port}" ]] && caddy_port=80
    read -r -p "Please enter the forwarding port of Caddy2 (default: 8863): " caddy_remote_port
    [[ -z "${caddy_remote_port}" ]] && caddy_remote_port=8863

    echo_content yellow "Tip: Please confirm that the domain name has been resolved to this machine, otherwise the installation may fail"
    while read -r -p "Please enter your domain name (required): " domain; do
      if [[ -z "${domain}" ]]; then
        echo_content red "Domain name cannot be empty"
      else
        break
      fi
    done

    read -r -p "Please enter your email (optional): " your_email

    while read -r -p "Please choose the way to apply for the certificate (1/acme 2/zerossl default: 1: " ssl_module_type; do
      if [[ -z "${ssl_module_type}" || ${ssl_module_type} == 1 ]]; then
        ssl_module="acme"
        CADDY_CERT_DIR="${CERT_PATH}certificates/acme-v02.api.letsencrypt.org-directory/"
        break
      elif [[ ${ssl_module_type} == 2 ]]; then
        ssl_module="zerossl"
        CADDY_CERT_DIR="${CERT_PATH}certificates/acme.zerossl.com-v2-dv90/"
        break
      else
        echo_content red "Cannot enter other characters except 1 and 2"
      fi
    done
    caddy2_https_auto_config

    # Caddy2 temporary listening port for automatic certificate application
    if [[ -n $(lsof -i:${caddy_port},${caddy_remote_port} -t) ]]; then
      kill -9 "$(lsof -i:${caddy_port},${caddy_remote_port} -t)"
    fi

    docker pull caddy:2.6.2 &&
      docker run -d --name trojan-panel-caddy --restart always \
        --network=host \
        -v "${CADDY_CONFIG}":"${CADDY_CONFIG}" \
        -v ${CERT_PATH}:"${CADDY_CERT_DIR}${domain}/" \
        -v ${WEB_PATH}:${WEB_PATH} \
        -v ${CADDY_LOG}:${CADDY_LOG} \
        caddy:2.6.2 caddy run --config ${CADDY_CONFIG}

    if [[ -n $(docker ps -q -f "name=^trojan-panel-caddy$" -f "status=running") ]]; then
      cat >${DOMAIN_FILE} <<EOF
${domain}
EOF
      echo_content red "\n=============================================================="
      echo_content skyBlue "---> Caddy2+https installation completed"
      echo_content yellow "Certificate Directory: ${CERT_PATH}"
      echo_content red "\n=============================================================="
    else
      echo_content red "---> Caddy2+https installation fails or runs abnormally, please try to repair or uninstall and reinstall"
      exit 0
    fi
  else
    echo_content skyBlue "---> You have installed Caddy2+https"
  fi
}

# Install TrojanGO+Caddy2+Web+TLS+Websocket
install_trojanGO_standalone() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-trojanGO-standalone$") ]]; then
    echo_content green "---> Install TrojanGO+Caddy2+Web+TLS+Websocket"

    read -r -p "Please enter the port of TrojanGO (default: 443): " trojanGO_port
    [[ -z "${trojanGO_port}" ]] && trojanGO_port=443
    while read -r -p "Please enter TrojanGO password (required): " trojan_pas; do
      if [[ -z "${trojan_pas}" ]]; then
        echo_content red "Password can not be empty"
      else
        break
      fi
    done

    while read -r -p "Is multiplexing enabled? (0/disabled 1/enabled default: 1): " trojanGO_mux_enable; do
      if [[ -z "${trojanGO_mux_enable}" || ${trojanGO_mux_enable} == 1 ]]; then
        trojanGO_mux_enable=1
        break
      elif [[ ${trojanGO_mux_enable} == 0 ]]; then
        trojanGO_mux_enable=0
        break
      else
        echo_content red "Cannot enter other characters except 0 and 1"
      fi
    done

    while read -r -p "Is Websocket enabled? (0/disabled 1/enabled default: 0): " trojanGO_websocket_enable; do
      if [[ -z "${trojanGO_websocket_enable}" || ${trojanGO_websocket_enable} == 0 ]]; then
        trojanGO_websocket_enable=0
        break
      elif [[ ${trojanGO_websocket_enable} == 1 ]]; then
        trojanGO_websocket_enable=1
        read -r -p "Please enter the Websocket path (default: trojan-panel-websocket-path): " trojanGO_websocket_path
        [[ -z "${trojanGO_websocket_path}" ]] && trojanGO_websocket_path="trojan-panel-websocket-path"
        break
      else
        echo_content red "Cannot enter other characters except 0 and 1"
      fi
    done

    while read -r -p "Do you want to enable Shadowsocks AEAD encryption? (0/disabled 1/enabled default: 0): " trojanGO_shadowsocks_enable; do
      if [[ -z "${trojanGO_shadowsocks_enable}" || ${trojanGO_shadowsocks_enable} == 0 ]]; then
        trojanGO_shadowsocks_enable=0
        break
      elif [[ ${trojanGO_shadowsocks_enable} == 1 ]]; then
        echo_content skyBlue "Shadowsocks AEAD encryption method is as follows:"
        echo_content yellow "1. AES-128-GCM(default)"
        echo_content yellow "2. CHACHA20-IETF-POLY1305"
        echo_content yellow "3. AES-256-GCM"
        read -r -p "Please enter the Shadowsocks AEAD encryption method (default: 1): " select_method_type
        [[ -z "${select_method_type}" ]] && select_method_type=1
        case ${select_method_type} in
        1)
          trojanGO_shadowsocks_method="AES-128-GCM"
          ;;
        2)
          trojanGO_shadowsocks_method="CHACHA20-IETF-POLY1305"
          ;;
        3)
          trojanGO_shadowsocks_method="AES-256-GCM"
          ;;
        *)
          trojanGO_shadowsocks_method="AES-128-GCM"
          ;;
        esac

        while read -r -p "Please enter the Shadowsocks AEAD encryption password (required): " trojanGO_shadowsocks_password; do
          if [[ -z "${trojanGO_shadowsocks_password}" ]]; then
            echo_content red "Password can not be empty"
          else
            break
          fi
        done
        break
      else
        echo_content yellow "Cannot enter other characters except 0 and 1"
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
    "cert": "${CERT_PATH}${domain}.crt",
    "key": "${CERT_PATH}${domain}.key",
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

    docker pull p4gefau1t/trojan-go &&
      docker run -d --name trojan-panel-trojanGO-standalone --restart=always \
        --network=host \
        -v ${TROJANGO_STANDALONE_CONFIG}:"/etc/trojan-go/config.json" \
        -v ${CERT_PATH}:${CERT_PATH} \
        p4gefau1t/trojan-go

    if [[ -n $(docker ps -q -f "name=^trojan-panel-trojanGO-standalone$" -f "status=running") ]]; then
      echo_content skyBlue "---> TrojanGO+Caddy+Web+TLS+Websocket installation completed"
      echo_content red "\n=============================================================="
      echo_content skyBlue "TrojanGO+Caddy+Web+TLS+Websocket installed successfully"
      echo_content yellow "domain: ${domain}"
      echo_content yellow "Port of TrojanGO: ${trojanGO_port}"
      echo_content yellow "Password for TrojanGO: ${trojan_pas}"
      echo_content yellow "Certificate Directory: ${CERT_PATH}"
      if [[ ${trojanGO_websocket_enable} == 1 ]]; then
        echo_content yellow "Websocket Path: ${trojanGO_websocket_path}"
      fi
      if [[ ${trojanGO_shadowsocks_enable} == 1 ]]; then
        echo_content yellow "Shadowsocks AEAD encryption method: ${trojanGO_shadowsocks_method}"
        echo_content yellow "Shadowsocks AEAD encryption password: ${trojanGO_shadowsocks_password}"
      fi
      echo_content red "\n=============================================================="
    else
      echo_content red "---> TrojanGO+Caddy+Web+TLS+Websocket fails to install or runs abnormally, please try to repair or uninstall and reinstall"
      exit 0
    fi
  else
    echo_content skyBlue "---> You have installed TrojanGO+Caddy+Web+TLS+Websocket"
  fi
}

# Install Hysteria
install_hysteria_standalone() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-hysteria-standalone$") ]]; then
    echo_content green "---> Install Hysteria"

    echo_content skyBlue "Hysteria's schema is as follows:"
    echo_content yellow "1. udp(default)"
    echo_content yellow "2. faketcp"
    read -r -p "Please enter the mode of Hysteria (default: 1): " selectProtocolType
    [[ -z "${selectProtocolType}" ]] && selectProtocolType=1
    case ${selectProtocolType} in
    1)
      hysteria_protocol="udp"
      ;;
    2)
      hysteria_protocol="faketcp"
      ;;
    *)
      hysteria_protocol="udp"
      ;;
    esac
    read -r -p "Please enter the port of Hysteria (default: 443): " hysteria_port
    [[ -z ${hysteria_port} ]] && hysteria_port=443
    read -r -p "Please enter the maximum upload speed of a single client/Mbps (default: 100): " hysteria_up_mbps
    [[ -z "${hysteria_up_mbps}" ]] && hysteria_up_mbps=100
    read -r -p "Please enter the maximum download speed of a single client/Mbps (default: 100): " hysteria_down_mbps
    [[ -z "${hysteria_down_mbps}" ]] && hysteria_down_mbps=100
    while read -r -p "Please enter the password of Hysteria (required): " hysteria_password; do
      if [[ -z ${hysteria_password} ]]; then
        echo_content red "Password can not be empty"
      else
        break
      fi
    done

    cat >${HYSTERIA_STANDALONE_CONFIG} <<EOF
{
  "listen": ":${hysteria_port}",
  "protocol": "${hysteria_protocol}",
  "cert": "${CERT_PATH}${domain}.crt",
  "key": "${CERT_PATH}${domain}.key",
  "up_mbps": ${hysteria_up_mbps},
  "down_mbps": ${hysteria_down_mbps},
  "auth_str": "${hysteria_password}"
}
EOF

    docker pull tobyxdd/hysteria &&
      docker run -d --name trojan-panel-hysteria-standalone --restart=always \
        --network=host \
        -v ${HYSTERIA_STANDALONE_CONFIG}:/etc/hysteria.json \
        -v ${CERT_PATH}:${CERT_PATH} \
        tobyxdd/hysteria -c /etc/hysteria.json server

    if [[ -n $(docker ps -q -f "name=^trojan-panel-hysteria-standalone$" -f "status=running") ]]; then
      echo_content skyBlue "---> Hysteria installation completed"
      echo_content red "\n=============================================================="
      echo_content skyBlue "Hysteria installed successfully"
      echo_content yellow "domain: ${domain}"
      echo_content yellow "Port of Hysteria: ${hysteria_port}"
      echo_content yellow "Password for Hysteria: ${hysteria_password}"
      echo_content yellow "Certificate Directory: ${CERT_PATH}"
      echo_content red "\n=============================================================="
    else
      echo_content red "---> Hysteria installation fails or runs abnormally, please try to repair or uninstall and reinstall"
      exit 0
    fi
  else
    echo_content skyBlue "---> You have installed Hysteria"
  fi
}

# Install NaiveProxy (Caddy+ForwardProxy)
install_navieproxy_standalone() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-navieproxy-standalone$") ]]; then
    echo_content green "---> Install NaiveProxy (Caddy+ForwardProxy)"

    read -r -p "Please enter the port of NaiveProxy (default: 443): " naiveproxy_port
    [[ -z "${naiveproxy_port}" ]] && naiveproxy_port=443
    while read -r -p "Please enter the username of NaiveProxy (required): " naiveproxy_username; do
      if [[ -z "${naiveproxy_username}" ]]; then
        echo_content red "Username can not be empty"
      else
        break
      fi
    done
    while read -r -p "Please enter the password of NaiveProxy (required): " naiveproxy_pass; do
      if [[ -z "${naiveproxy_pass}" ]]; then
        echo_content red "Password can not be empty"
      else
        break
      fi
    done
    domain=$(cat "${DOMAIN_FILE}")
    cat >${NAIVEPROXY_STANDALONE_CONFIG} <<EOF
{
    "admin": {
        "disabled": true
    },
    "logging": {
        "sink": {
            "writer": {
                "output": "discard"
            }
        },
        "logs": {
            "default": {
                "writer": {
                    "output": "discard"
                }
            }
        }
    },
    "apps": {
        "http": {
            "servers": {
                "srv0": {
                    "listen": [
                        ":${naiveproxy_port}"
                    ],
                    "routes": [
                        {
                            "handle": [
                                {
                                    "handler": "subroute",
                                    "routes": [
                                        {
                                            "handle": [
                                                {
                                                    "auth_pass_deprecated": "${naiveproxy_pass}",
                                                    "auth_user_deprecated": "${naiveproxy_username}",
                                                    "handler": "forward_proxy",
                                                    "hide_ip": true,
                                                    "hide_via": true,
                                                    "probe_resistance": {}
                                                }
                                            ]
                                        },
                                        {
                                            "match": [
                                                {
                                                    "host": [
                                                        "${domain}"
                                                    ]
                                                }
                                            ],
                                            "handle": [
                                                {
                                                    "handler": "file_server",
                                                    "root": "/caddy-forwardproxy/dist/",
                                                    "index_names": [
                                                        "index.html",
                                                        "index.htm"
                                                    ]
                                                }
                                            ],
                                            "terminal": true
                                        }
                                    ]
                                }
                            ]
                        }
                    ],
                    "tls_connection_policies": [
                        {
                            "match": {
                                "sni": [
                                    "${domain}"
                                ]
                            }
                        }
                    ],
                    "automatic_https": {
                        "disable": true
                    }
                }
            }
        },
        "tls": {
            "certificates": {
                "load_files": [
                    {
                        "certificate": "${CERT_PATH}${domain}.crt",
                        "key": "${CERT_PATH}${domain}.crt"
                    }
                ]
            }
        }
    }
}
EOF
    docker pull jonssonyan/caddy-forwardproxy &&
      docker run -d --name trojan-panel-navieproxy-standalone --restart=always \
        --network=host \
        -v ${NAIVEPROXY_STANDALONE_CONFIG}:"/caddy-forwardproxy/config/config.json" \
        -v ${CERT_PATH}:${CERT_PATH} \
        jonssonyan/caddy-forwardproxy

    if [[ -n $(docker ps -q -f "name=^trojan-panel-navieproxy-standalone$" -f "status=running") ]]; then
      echo_content skyBlue "---> NaiveProxy(Caddy+ForwardProxy) installation completed"
      echo_content red "\n=============================================================="
      echo_content skyBlue "NaiveProxy(Caddy+ForwardProxy) installed successfully"
      echo_content yellow "domain: ${domain}"
      echo_content yellow "Port of NaiveProxy: ${naiveproxy_port}"
      echo_content yellow "Username for NaiveProxy: ${naiveproxy_username}"
      echo_content yellow "Password for NaiveProxy: ${naiveproxy_pass}"
      echo_content yellow "Certificate Directory: ${CERT_PATH}"
      echo_content red "\n=============================================================="
    else
      echo_content red "---> NaiveProxy(Caddy+ForwardProxy) failed to install or run abnormally, please try to repair or uninstall and reinstall"
      exit 0
    fi
  else
    echo_content skyBlue "---> You have installed NaiveProxy(Caddy+ForwardProxy)"
  fi
}

# Uninstall Caddy2
uninstall_caddy2() {
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-caddy$") ]]; then
    echo_content green "---> Uninstall Caddy2"

    docker rm -f trojan-panel-caddy &&
      rm -rf ${CADDY_DATA}

    echo_content skyBlue "---> Caddy2 uninstallation completed"
  else
    echo_content red "---> Please install Caddy2 first"
  fi
}

# Uninstall TrojanGO+Caddy+Web+TLS+Websocket
uninstall_trojanGO_standalone() {
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-trojanGO-standalone$") ]]; then
    echo_content green "---> Uninstall TrojanGO+Caddy+Web+TLS+Websocket"

    docker rm -f trojan-panel-trojanGO-standalone &&
      docker rmi -f p4gefau1t/trojan-go &&
      rm -f ${TROJANGO_STANDALONE_CONFIG}

    echo_content skyBlue "---> TrojanGO+Caddy+Web+TLS+Websocket uninstallation completed"
  else
    echo_content red "---> Please install TrojanGO+Caddy+Web+TLS+Websocket first"
  fi
}

# Uninstall Hysteria
uninstall_hysteria_standalone() {
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-hysteria-standalone$") ]]; then
    echo_content green "---> Uninstall Hysteria"

    docker rm -f trojan-panel-hysteria-standalone &&
      docker rmi -f tobyxdd/hysteria &&
      rm -f ${HYSTERIA_STANDALONE_CONFIG}

    echo_content skyBlue "---> Hysteria uninstallation completed"
  else
    echo_content red "---> Please install Hysteria"
  fi
}

# Uninstall NaiveProxy (Caddy+ForwardProxy)
uninstall_navieproxy_standalone() {
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-navieproxy-standalone$") ]]; then
    echo_content green "---> Uninstall NaiveProxy (Caddy+ForwardProxy)"

    docker rm -f trojan-panel-navieproxy-standalone &&
      docker rmi -f jonssonyan/caddy-forwardproxy &&
      rm -f ${NAIVEPROXY_STANDALONE_CONFIG}

    echo_content skyBlue "---> NaiveProxy(Caddy+ForwardProxy) uninstallation completed"
  else
    echo_content red "---> Please install NaiveProxy(Caddy+ForwardProxy)"
  fi
}

# Uninstall all Trojan Panel related containers
uninstall_all() {
  echo_content green "---> Uninstall all Trojan Panel related containers"

  docker rm -f $(docker ps -a -q -f "name=^trojan-panel")
  docker rmi -f $(docker images | grep "^jonssonyan/trojan-panel" | awk '{print $3}')
  rm -rf ${TP_DATA}

  echo_content skyBlue "---> Uninstall all Trojan Panel related containers completed"
}

# Fault detection
failure_testing() {
  echo_content green "---> Start troubleshooting"
  if [[ ! $(docker -v 2>/dev/null) ]]; then
    echo_content red "---> Docker is running abnormally"
  else
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-caddy$") ]]; then
      if [[ -z $(docker ps -q -f "name=^trojan-panel-caddy$" -f "status=running") ]]; then
        echo_content red "---> Caddy2 is running abnormally and the running log is as follows:"
        docker logs trojan-panel-caddy
      fi
      domain=$(cat "${DOMAIN_FILE}")
      if [[ -n ${domain} && ! -f "${CERT_PATH}${domain}.crt" ]]; then
        echo_content red "---> The certificate application is abnormal, please try 1. Change the sub-domain name to re-build 2. Restart the server to re-apply for the certificate 3. Re-build and select the custom certificate option"
        if [[ -f ${CADDY_LOG}error.log ]]; then
          echo_content red "Caddy2 error log is as follows:"
          tail -n 20 ${CADDY_LOG}error.log | grep error
        fi
      fi
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-trojanGO-standalone$") && -z $(docker ps -q -f "name=^trojan-panel-trojanGO-standalone$" -f "status=running") ]]; then
      echo_content red "---> TrojanGO is running abnormally"
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-hysteria-standalone$") && -z $(docker ps -q -f "name=^trojan-panel-hysteria-standalone$" -f "status=running") ]]; then
      echo_content red "---> Hysteria is running abnormally"
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-navieproxy-standalone$") && -z $(docker ps -q -f "name=^trojan-panel-navieproxy-standalone$" -f "status=running") ]]; then
      echo_content red "---> NaiveProxy(Caddy+ForwardProxy) is running abnormally"
    fi
  fi
  echo_content green "---> Troubleshooting ended"
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
  echo_content skyBlue "Description: One click Install Trojan Panel standalone server"
  echo_content skyBlue "Author: jonssonyan <https://jonssonyan.com>"
  echo_content skyBlue "Github: https://github.com/trojanpanel"
  echo_content skyBlue "Docs: https://trojanpanel.github.io"
  echo_content red "\n=============================================================="
  echo_content yellow "2. Install TrojanGO+Caddy2+Web+TLS+Websocket"
  echo_content yellow "3. Install Hysteria"
  echo_content yellow "4. Install NaiveProxy(Caddy2+ForwardProxy)"
  echo_content yellow "5. Install Caddy2+https"
  echo_content green "\n=============================================================="
  echo_content yellow "7. Uninstall TrojanGO+Caddy2+Web+TLS+Websocket"
  echo_content yellow "8. Uninstall Hysteria"
  echo_content yellow "9. Uninstall NaiveProxy(Caddy2+ForwardProxy)"
  echo_content yellow "10. Uninstall Caddy2+https"
  echo_content yellow "11. Uninstall all Trojan Panel related containers"
  echo_content green "\n=============================================================="
  echo_content yellow "12. Fault detection"
  read -r -p "Please choose: " selectInstall_type
  case ${selectInstall_type} in
  1)
    install_docker
    install_caddy2
    install_trojanGO_standalone
    ;;
  2)
    install_docker
    install_caddy2
    install_hysteria_standalone
    ;;
  3)
    install_docker
    install_caddy2
    install_navieproxy_standalone
    ;;
  4)
    install_docker
    install_caddy2
    ;;
  5)
    uninstall_trojanGO_standalone
    ;;
  6)
    uninstall_hysteria_standalone
    ;;
  7)
    uninstall_navieproxy_standalone
    ;;
  8)
    uninstall_caddy2
    ;;
  9)
    uninstall_all
    ;;
  10)
    failure_testing
    ;;
  *)
    echo_content red "No such option"
    ;;
  esac
}

main
