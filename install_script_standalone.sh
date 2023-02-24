#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# System Required: CentOS 7+/Ubuntu 18+/Debian 10+
# Version: v2.0.4
# Description: One click Install Trojan Panel standalone server
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
  CADDY_Config="/tpdata/caddy/config.json"
  CADDY_SRV="/tpdata/caddy/srv/"
  CADDY_CERT="/tpdata/caddy/cert/"
  CADDY_LOG="/tpdata/caddy/logs/"
  DOMAIN_FILE="/tpdata/caddy/domain.lock"
  CADDY_CERT_DIR="/tpdata/caddy/cert/certificates/acme-v02.api.letsencrypt.org-directory/"
  domain=""
  caddy_port=80
  caddy_remote_port=8863
  your_email=""
  ssl_option=1
  ssl_module_type=1
  ssl_module="acme"
  crt_path=""
  key_path=""

  # trojanGFW
  TROJANGFW_DATA="/tpdata/trojanGFW/"
  TROJANGFW_STANDALONE_CONFIG="/tpdata/trojanGFW/standalone_config.json"
  trojanGFW_port=443
  # trojanGO
  TROJANGO_DATA="/tpdata/trojanGO/"
  TROJANGO_STANDALONE_CONFIG="/tpdata/trojanGO/standalone_config.json"
  trojanGO_port=443
  trojanGO_websocket_enable=false
  trojanGO_websocket_path="trojan-panel-websocket-path"
  trojanGO_shadowsocks_enable=false
  trojanGO_shadowsocks_method="AES-128-GCM"
  trojanGO_shadowsocks_password=""
  trojanGO_mux_enable=true
  # trojan
  trojan_pas=""
  remote_addr="127.0.0.1"

  # hysteria
  HYSTERIA_DATA="/tpdata/hysteria/"
  HYSTERIA_STANDALONE_CONFIG="/tpdata/hysteria/standalone_config.json"
  hysteria_port=443
  hysteria_password=""
  hysteria_protocol="udp"
  hysteria_up_mbps=100
  hysteria_down_mbps=100

  # naiveproxy
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
  # 项目目录
  mkdir -p ${TP_DATA}

  # Caddy
  mkdir -p ${CADDY_DATA}
  touch ${CADDY_Config}
  mkdir -p ${CADDY_SRV}
  mkdir -p ${CADDY_CERT}
  mkdir -p ${CADDY_LOG}

  # trojanGFW
  mkdir -p ${TROJANGFW_DATA}
  touch ${TROJANGFW_STANDALONE_CONFIG}

  # trojanGO
  mkdir -p ${TROJANGO_DATA}
  touch ${TROJANGO_STANDALONE_CONFIG}

  # hysteria
  mkdir -p ${HYSTERIA_DATA}
  touch ${HYSTERIA_STANDALONE_CONFIG}

  # naiveproxy
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
      systemctl restart docker

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
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-caddy$") ]]; then
    echo_content green "---> 安装Caddy TLS"

    wget --no-check-certificate -O ${CADDY_DATA}html.tar.gz ${STATIC_HTML} &&
      tar -zxvf ${CADDY_DATA}html.tar.gz -C ${CADDY_SRV}

    read -r -p "请输入Caddy的端口(默认:80): " caddy_port
    [[ -z "${caddy_port}" ]] && caddy_port=80
    read -r -p "请输入Caddy的转发端口(默认:8863): " caddy_remote_port
    [[ -z "${caddy_remote_port}" ]] && caddy_remote_port=8863

    echo_content yellow "提示：请确认域名已经解析到本机 否则可能安装失败"
    while read -r -p "请输入你的域名(必填): " domain; do
      if [[ -z "${domain}" ]]; then
        echo_content red "域名不能为空"
      else
        break
      fi
    done

    read -r -p "请输入你的邮箱(可选): " your_email

    while read -r -p "请选择设置证书的方式?(1/自动申请和续签证书 2/手动设置证书路径 默认:1/自动申请和续签证书): " ssl_option; do
      if [[ -z ${ssl_option} || ${ssl_option} == 1 ]]; then
        while read -r -p "请选择申请证书的方式(1/acme 2/zerossl 默认:1/acme): " ssl_module_type; do
          if [[ -z "${ssl_module_type}" || ${ssl_module_type} == 1 ]]; then
            ssl_module="acme"
            CADDY_CERT_DIR="/tpdata/caddy/cert/certificates/acme-v02.api.letsencrypt.org-directory/"
            break
          elif [[ ${ssl_module_type} == 2 ]]; then
            ssl_module="zerossl"
            CADDY_CERT_DIR="/tpdata/caddy/cert/certificates/acme.zerossl.com-v2-dv90/"
            break
          else
            echo_content red "不可以输入除1和2之外的其他字符"
          fi
        done

        cat >${CADDY_Config} <<EOF
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
        "root":"${CADDY_CERT}"
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
                                                    "root":"${CADDY_SRV}",
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
        break
      elif [[ ${ssl_option} == 2 ]]; then
        while read -r -p "请输入证书的.crt文件路径(必填): " crt_path; do
          if [[ -z "${crt_path}" ]]; then
            echo_content red "路径不能为空"
          else
            if [[ ! -f "${crt_path}" ]]; then
              echo_content red "证书的.crt文件路径不存在"
            else
              cp "${crt_path}" "${CADDY_CERT}${domain}.crt"
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
              cp "${key_path}" "${CADDY_CERT}${domain}.key"
              break
            fi
          fi
        done

        cat >${CADDY_Config} <<EOF
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
        "root":"${CADDY_CERT}"
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
                                                    "root":"${CADDY_SRV}",
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
                ],
                "load_files":[
                    {
                        "certificate":"${CADDY_CERT_DIR}${domain}/${domain}.crt",
                        "key":"${CADDY_CERT_DIR}${domain}/${domain}.key"
                    }
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
        break
      else
        echo_content red "不可以输入除1和2之外的其他字符"
      fi
    done

    if [[ -n $(lsof -i:${caddy_port},443 -t) ]]; then
      kill -9 "$(lsof -i:${caddy_port},443 -t)"
    fi

    docker pull caddy:2.6.2 &&
      docker run -d --name trojan-panel-caddy --restart always \
        --network=host \
        -v "${CADDY_Config}":"${CADDY_Config}" \
        -v ${CADDY_CERT}:"${CADDY_CERT_DIR}${domain}/" \
        -v ${CADDY_SRV}:${CADDY_SRV} \
        -v ${CADDY_LOG}:${CADDY_LOG} \
        caddy:2.6.2 caddy run --config ${CADDY_Config}

    if [[ -n $(docker ps -q -f "name=^trojan-panel-caddy$" -f "status=running") ]]; then
      cat >${DOMAIN_FILE} <<EOF
${domain}
EOF
      echo_content skyBlue "---> Caddy安装完成"
    else
      echo_content red "---> Caddy安装失败或运行异常,请尝试修复或卸载重装"
      exit 0
    fi
  else
    domain=$(cat "${DOMAIN_FILE}")
    echo_content skyBlue "---> 你已经安装了Caddy"
  fi
}

# TrojanGFW+Caddy+Web+TLS+Websocket
install_trojan_gfw_standalone() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-trojanGFW-standalone$") ]]; then
    echo_content green "---> 安装TrojanGFW+Caddy+Web+TLS+Websocket"

    read -r -p "请输入TrojanGFW的端口(默认:443): " trojanGFW_port
    [[ -n ${trojanGFW_port} ]] && trojanGFW_port=443
    while read -r -p "请输入TrojanGFW的密码(必填): " trojan_pas; do
      if [[ -z "${trojan_pas}" ]]; then
        echo_content red "密码不能为空"
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
        "cert": "${CADDY_CERT}${domain}.crt",
        "key": "${CADDY_CERT}${domain}.key",
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
        "database": "",
        "username": "",
        "password": "",
        "key": "",
        "cert": "",
        "ca": ""
    }
}
EOF

    docker pull trojangfw/trojan &&
      docker run -d --name trojan-panel-trojanGFW-standalone --restart always \
        --network=host \
        -v ${TROJANGFW_STANDALONE_CONFIG}:"/config/config.json" \
        -v ${CADDY_CERT}:${CADDY_CERT} \
        trojangfw/trojan

    if [[ -n $(docker ps -q -f "name=^trojan-panel-trojanGFW-standalone$" -f "status=running") ]]; then
      echo_content skyBlue "---> TrojanGFW+Caddy+Web+TLS 安装完成"
      echo_content red "\n=============================================================="
      echo_content skyBlue "TrojanGFW+Caddy+Web+TLS 安装成功"
      echo_content yellow "域名: ${domain}"
      echo_content yellow "TrojanGFW的端口: ${trojanGFW_port}"
      echo_content yellow "TrojanGFW的密码: ${trojan_pas}"
      echo_content red "\n=============================================================="
    else
      echo_content red "---> TrojanGFW+Caddy+Web+TLS 安装失败或运行异常,请尝试修复或卸载重装"
      exit 0
    fi
  else
    echo_content skyBlue "---> 你已经安装了TrojanGFW+Caddy+Web+TLS"
  fi
}

# TrojanGO+Caddy+Web+TLS+Websocket
install_trojanGO_standalone() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-trojanGO-standalone$") ]]; then
    echo_content green "---> 安装TrojanGO+Caddy+Web+TLS+Websocket"

    read -r -p "请输入TrojanGO的端口(默认:443): " trojanGO_port
    [[ -z "${trojanGO_port}" ]] && trojanGO_port=443
    while read -r -p "请输入TrojanGO的密码(必填): " trojan_pas; do
      if [[ -z "${trojan_pas}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    while read -r -p "是否开启多路复用?(false/关闭 true/开启 默认:true/开启): " trojanGO_mux_enable; do
      if [[ -z "${trojanGO_mux_enable}" || ${trojanGO_mux_enable} == true ]]; then
        trojanGO_mux_enable=true
        break
      else
        if [[ ${trojanGO_mux_enable} != false ]]; then
          echo_content red "不可以输入除false和true之外的其他字符"
        else
          break
        fi
      fi
    done

    while read -r -p "是否开启Websocket?(false/关闭 true/开启 默认:false/关闭): " trojanGO_websocket_enable; do
      if [[ -z "${trojanGO_websocket_enable}" || ${trojanGO_websocket_enable} == false ]]; then
        trojanGO_websocket_enable=false
        break
      else
        if [[ ${trojanGO_websocket_enable} != true ]]; then
          echo_content red "不可以输入除false和true之外的其他字符"
        else
          read -r -p "请输入Websocket路径(默认:trojan-panel-websocket-path): " trojanGO_websocket_path
          [[ -z "${trojanGO_websocket_path}" ]] && trojanGO_websocket_path="trojan-panel-websocket-path"
          break
        fi
      fi
    done

    while read -r -p "是否启用Shadowsocks AEAD加密?(false/关闭 true/开启 默认:false/关闭): " trojanGO_shadowsocks_enable; do
      if [[ -z "${trojanGO_shadowsocks_enable}" || ${trojanGO_shadowsocks_enable} == false ]]; then
        trojanGO_shadowsocks_enable=false
        break
      else
        if [[ ${trojanGO_shadowsocks_enable} != true ]]; then
          echo_content yellow "不可以输入除false和true之外的其他字符"
        else
          echo_content skyBlue "Shadowsocks AEAD加密方式如下:"
          echo_content yellow "1. AES-128-GCM(默认)"
          echo_content yellow "2. CHACHA20-IETF-POLY1305"
          echo_content yellow "3. AES-256-GCM"
          read -r -p "请输入Shadowsocks AEAD加密方式(默认:1): " select_method_type
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

          while read -r -p "请输入Shadowsocks AEAD加密密码(必填): " trojanGO_shadowsocks_password; do
            if [[ -z "${trojanGO_shadowsocks_password}" ]]; then
              echo_content red "密码不能为空"
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
    "cert": "${CADDY_CERT}${domain}.crt",
    "key": "${CADDY_CERT}${domain}.key",
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
        -v ${CADDY_CERT}:${CADDY_CERT} \
        p4gefau1t/trojan-go

    if [[ -n $(docker ps -q -f "name=^trojan-panel-trojanGO-standalone$" -f "status=running") ]]; then
      echo_content skyBlue "---> TrojanGO+Caddy+Web+TLS+Websocket 安装完成"
      echo_content red "\n=============================================================="
      echo_content skyBlue "TrojanGO+Caddy+Web+TLS+Websocket 安装成功"
      echo_content yellow "域名: ${domain}"
      echo_content yellow "TrojanGO的端口: ${trojanGO_port}"
      echo_content yellow "TrojanGO的密码: ${trojan_pas}"
      echo_content yellow "TrojanGO私钥和证书目录: ${CADDY_CERT}"
      if [[ ${trojanGO_websocket_enable} == true ]]; then
        echo_content yellow "Websocket路径: ${trojanGO_websocket_path}"
      fi
      if [[ ${trojanGO_shadowsocks_enable} == true ]]; then
        echo_content yellow "Shadowsocks AEAD加密方式: ${trojanGO_shadowsocks_method}"
        echo_content yellow "Shadowsocks AEAD加密密码: ${trojanGO_shadowsocks_password}"
      fi
      echo_content red "\n=============================================================="
    else
      echo_content red "---> TrojanGO+Caddy+Web+TLS+Websocket 安装失败或运行异常,请尝试修复或卸载重装"
      exit 0
    fi
  else
    echo_content skyBlue "---> 你已经了安装了TrojanGO+Caddy+Web+TLS+Websocket"
  fi
}

# 安装Hysteria
install_hysteria_standalone() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-hysteria-standalone$") ]]; then
    echo_content green "---> 安装Hysteria"

    echo_content skyBlue "Hysteria的模式如下:"
    echo_content yellow "1. udp(默认)"
    echo_content yellow "2. faketcp"
    read -r -p "请输入Hysteria的模式(默认:1): " selectProtocolType
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
    read -r -p "请输入Hysteria的端口(默认:443): " hysteria_port
    [[ -z ${hysteria_port} ]] && hysteria_port=443
    read -r -p "请输入单客户端最大上传速度/Mbps(默认:100): " hysteria_up_mbps
    [[ -z "${hysteria_up_mbps}" ]] && hysteria_up_mbps=100
    read -r -p "请输入单客户端最大下载速度/Mbps(默认:100): " hysteria_down_mbps
    [[ -z "${hysteria_down_mbps}" ]] && hysteria_down_mbps=100
    while read -r -p "请输入Hysteria的密码(必填): " hysteria_password; do
      if [[ -z ${hysteria_password} ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    cat >${HYSTERIA_STANDALONE_CONFIG} <<EOF
{
  "listen": ":${hysteria_port}",
  "protocol": "${hysteria_protocol}",
  "cert": "${CADDY_CERT}${domain}.crt",
  "key": "${CADDY_CERT}${domain}.key",
  "up_mbps": ${hysteria_up_mbps},
  "down_mbps": ${hysteria_down_mbps},
  "auth_str": "${hysteria_password}"
}
EOF

    docker pull tobyxdd/hysteria &&
      docker run -d --name trojan-panel-hysteria-standalone --restart=always \
        --network=host \
        -v ${HYSTERIA_STANDALONE_CONFIG}:/etc/hysteria.json \
        -v ${CADDY_CERT}:${CADDY_CERT} \
        tobyxdd/hysteria -c /etc/hysteria.json server

    if [[ -n $(docker ps -q -f "name=^trojan-panel-hysteria-standalone$" -f "status=running") ]]; then
      echo_content skyBlue "---> Hysteria 安装完成"
      echo_content red "\n=============================================================="
      echo_content skyBlue "Hysteria 安装成功"
      echo_content yellow "域名: ${domain}"
      echo_content yellow "Hysteria的端口: ${hysteria_port}"
      echo_content yellow "Hysteria的密码: ${hysteria_password}"
      echo_content yellow "Hysteria私钥和证书目录: ${CADDY_CERT}"
      echo_content red "\n=============================================================="
    else
      echo_content red "---> Hysteria 安装失败或运行异常,请尝试修复或卸载重装"
      exit 0
    fi
  else
    echo_content skyBlue "---> 你已经安装了Hysteria"
  fi
}

# 安装NaiveProxy(Caddy+ForwardProxy)
install_navieproxy_standalone() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-navieproxy-standalone$") ]]; then
    echo_content green "---> 安装NaiveProxy(Caddy+ForwardProxy)"

    read -r -p "请输入NaiveProxy的端口(默认:443): " naiveproxy_port
    [[ -z "${naiveproxy_port}" ]] && naiveproxy_port=443
    while read -r -p "请输入NaiveProxy的用户名(必填): " naiveproxy_username; do
      if [[ -z "${naiveproxy_username}" ]]; then
        echo_content red "用户名不能为空"
      else
        break
      fi
    done
    while read -r -p "请输入NaiveProxy的密码(必填): " naiveproxy_pass; do
      if [[ -z "${naiveproxy_pass}" ]]; then
        echo_content red "密码不能为空"
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
                        "certificate": "${CADDY_CERT}${domain}.crt",
                        "key": "${CADDY_CERT}${domain}.crt"
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
        -v ${CADDY_CERT}:${CADDY_CERT} \
        jonssonyan/caddy-forwardproxy

    if [[ -n $(docker ps -q -f "name=^trojan-panel-navieproxy-standalone$" -f "status=running") ]]; then
      echo_content skyBlue "---> NaiveProxy(Caddy+ForwardProxy) 安装完成"
      echo_content red "\n=============================================================="
      echo_content skyBlue "NaiveProxy(Caddy+ForwardProxy) 安装成功"
      echo_content yellow "域名: ${domain}"
      echo_content yellow "NaiveProxy的端口: ${naiveproxy_port}"
      echo_content yellow "NaiveProxy的用户名: ${naiveproxy_username}"
      echo_content yellow "NaiveProxy的密码: ${naiveproxy_pass}"
      echo_content yellow "NaiveProxy私钥和证书目录: ${CADDY_CERT}"
      echo_content red "\n=============================================================="
    else
      echo_content red "---> NaiveProxy(Caddy+ForwardProxy) 安装失败或运行异常,请尝试修复或卸载重装"
      exit 0
    fi
  else
    echo_content skyBlue "---> 你已经了安装了NaiveProxy(Caddy+ForwardProxy)"
  fi
}

# 卸载Caddy TLS
uninstall_caddy_tls() {
  # 判断Caddy TLS是否安装
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-caddy$") ]]; then
    echo_content green "---> 卸载Caddy TLS"

    docker rm -f trojan-panel-caddy &&
      rm -rf ${CADDY_DATA}

    echo_content skyBlue "---> Caddy TLS卸载完成"
  else
    echo_content red "---> 请先安装Caddy TLS"
  fi
}

# TrojanGFW+Caddy+Web+TLS
uninstall_trojan_gfw_standalone() {
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-trojanGFW-standalone$") ]]; then
    echo_content green "---> 卸载TrojanGFW+Caddy+Web+TLS"

    docker rm -f trojan-panel-trojanGFW-standalone &&
      docker rmi -f trojangfw/trojan &&
      rm -f ${TROJANGFW_STANDALONE_CONFIG}

    echo_content skyBlue "---> TrojanGFW+Caddy+Web+TLS 卸载完成"
  else
    echo_content red "---> 请先安装TrojanGFW+Caddy+Web+TLS"
  fi
}

# 卸载TrojanGO 单机版
uninstall_trojanGO_standalone() {
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-trojanGO-standalone$") ]]; then
    echo_content green "---> 卸载TrojanGO+Caddy+Web+TLS+Websocket"

    docker rm -f trojan-panel-trojanGO-standalone &&
      docker rmi -f p4gefau1t/trojan-go &&
      rm -f ${TROJANGO_STANDALONE_CONFIG}

    echo_content skyBlue "---> TrojanGO+Caddy+Web+TLS+Websocket 卸载完成"
  else
    echo_content red "---> 请先安装TrojanGO+Caddy+Web+TLS+Websocket"
  fi
}

# 卸载Hysteria
uninstall_hysteria_standalone() {
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-hysteria-standalone$") ]]; then
    echo_content green "---> 卸载Hysteria"

    docker rm -f trojan-panel-hysteria-standalone &&
      docker rmi -f tobyxdd/hysteria &&
      rm -f ${HYSTERIA_STANDALONE_CONFIG}

    echo_content skyBlue "---> Hysteria 卸载完成"
  else
    echo_content red "---> 请先安装Hysteria"
  fi
}

# 卸载NaiveProxy(Caddy+ForwardProxy)
uninstall_navieproxy_standalone() {
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-navieproxy-standalone$") ]]; then
    echo_content green "---> 卸载NaiveProxy(Caddy+ForwardProxy)"

    docker rm -f trojan-panel-navieproxy-standalone &&
      docker rmi -f jonssonyan/caddy-forwardproxy &&
      rm -f ${NAIVEPROXY_STANDALONE_CONFIG}

    echo_content skyBlue "---> NaiveProxy(Caddy+ForwardProxy) 卸载完成"
  else
    echo_content red "---> 请先安装NaiveProxy(Caddy+ForwardProxy)"
  fi
}

# 卸载全部Trojan Panel相关的容器
uninstall_all() {
  echo_content green "---> 卸载全部Trojan Panel相关的容器"

  docker rm -f $(docker ps -a -q -f "name=^trojan-panel") &&
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
        echo_content red "---> Caddy TLS运行异常 错误日志如下："
        docker logs trojan-panel-caddy
      fi
      domain=$(cat "${DOMAIN_FILE}")
      if [[ -z $(cat "${DOMAIN_FILE}") || ! -d "${CADDY_CERT}" || ! -f "${CADDY_CERT}${domain}.crt" ]]; then
        echo_content red "---> 证书申请异常，请尝试 1.换个子域名重新搭建 2.重启服务器将重新申请证书 3.重新搭建选择自定义证书选项 日志如下："
        if [[ -f ${CADDY_LOG}error.log ]]; then
          tail -n 20 ${CADDY_LOG}error.log
        else
          docker logs trojan-panel-caddy
        fi
      fi
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-trojanGFW-standalone$") && -z $(docker ps -q -f "name=^trojan-panel-trojanGFW-standalone$" -f "status=running") ]]; then
      echo_content red "---> TrojanGFW运行异常"
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-trojanGO-standalone$") && -z $(docker ps -q -f "name=^trojan-panel-trojanGO-standalone$" -f "status=running") ]]; then
      echo_content red "---> TrojanGO运行异常"
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-hysteria-standalone$") && -z $(docker ps -q -f "name=^trojan-panel-hysteria-standalone$" -f "status=running") ]]; then
      echo_content red "---> Hysteria运行异常"
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-navieproxy-standalone$") && -z $(docker ps -q -f "name=^trojan-panel-navieproxy-standalone$" -f "status=running") ]]; then
      echo_content red "---> NaiveProxy(Caddy+ForwardProxy)运行异常"
    fi
  fi
  echo_content green "---> 故障检测结束"
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
  echo_content skyBlue "Version: v2.0.4"
  echo_content skyBlue "Description: One click Install Trojan Panel standalone server"
  echo_content skyBlue "Author: jonssonyan <https://jonssonyan.com>"
  echo_content skyBlue "Github: https://github.com/trojanpanel"
  echo_content skyBlue "Docs: https://trojanpanel.github.io"
  echo_content red "\n=============================================================="
  echo_content yellow "1. 安装TrojanGFW+Caddy+Web+TLS"
  echo_content yellow "2. 安装TrojanGO+Caddy+Web+TLS+Websocket"
  echo_content yellow "3. 安装Hysteria"
  echo_content yellow "4. 安装NaiveProxy(Caddy+ForwardProxy)"
  echo_content yellow "5. 安装Caddy TLS"
  echo_content green "\n=============================================================="
  echo_content yellow "6. 卸载TrojanGFW+Caddy+Web+TLS"
  echo_content yellow "7. 卸载TrojanGO+Caddy+Web+TLS+Websocket"
  echo_content yellow "8. 卸载Hysteria"
  echo_content yellow "9. 卸载NaiveProxy(Caddy+ForwardProxy)"
  echo_content yellow "10. 卸载Caddy TLS"
  echo_content yellow "11. 卸载全部Trojan Panel相关的应用"
  echo_content green "\n=============================================================="
  echo_content yellow "12. 故障检测"
  read -r -p "请选择:" selectInstall_type
  case ${selectInstall_type} in
  1)
    install_docker
    install_caddy_tls
    install_trojan_gfw_standalone
    ;;
  2)
    install_docker
    install_caddy_tls
    install_trojanGO_standalone
    ;;
  3)
    install_docker
    install_caddy_tls
    install_hysteria_standalone
    ;;
  4)
    install_docker
    install_caddy_tls
    install_navieproxy_standalone
    ;;
  5)
    install_docker
    install_caddy_tls
    ;;
  6)
    uninstall_trojan_gfw_standalone
    ;;
  7)
    uninstall_trojanGO_standalone
    ;;
  8)
    uninstall_hysteria_standalone
    ;;
  9)
    uninstall_navieproxy_standalone
    ;;
  10)
    uninstall_caddy_tls
    ;;
  11)
    uninstall_all
    ;;
  12)
    failure_testing
    ;;
  *)
    echo_content red "没有这个选项"
    ;;
  esac
}

main
