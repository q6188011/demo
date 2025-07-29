#!/bin/bash
# SOCKS5一键安装脚本
# Author: YouTube频道<https://www.youtube.com/@aifenxiangdexiaoqie>

RED="\033[31m"      # Error message
GREEN="\033[32m"    # Success message
YELLOW="\033[33m"   # Warning message
BLUE="\033[36m"     # Info message
PLAIN='\033[0m'

colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

checkSystem() {
    result=$(id | awk '{print $1}')
    if [[ $result != "uid=0(root)" ]]; then
        colorEcho $RED " 请以root身份执行该脚本"
        exit 1
    fi

    res=`which yum 2>/dev/null`
    if [[ "$?" != "0" ]]; then
        res=`which apt 2>/dev/null`
        if [[ "$?" != "0" ]]; then
            colorEcho $RED " 不受支持的Linux系统"
            exit 1
        fi
        PMT="apt"
        CMD_INSTALL="apt install -y "
        CMD_REMOVE="apt remove -y "
        CMD_UPGRADE="apt update; apt upgrade -y; apt autoremove -y"
    else
        PMT="yum"
        CMD_INSTALL="yum install -y "
        CMD_REMOVE="yum remove -y "
        CMD_UPGRADE="yum update -y"
    fi
    res=`which systemctl 2>/dev/null`
    if [[ "$?" != "0" ]]; then
        colorEcho $RED " 系统版本过低，请升级到最新版本"
        exit 1
    fi
}

status_singbox() {
    export PATH=/usr/local/bin:$PATH
    cmd="$(command -v /root/sing-box)"
    if [[ "$cmd" = "" ]]; then
        echo 0
        return
    fi
    if [[ ! -f /root/socks5.json ]]; then
        echo 1
        return
    fi
    
    port=`grep -o '"listen_port": [0-9]*' /root/socks5.json | awk '{print $2}'`
    if [[ -n "$port" ]]; then
        res=`ss -ntlp| grep ${port} | grep sing-box`
        if [[ -z "$res" ]]; then
            echo 2
        else
            echo 3
        fi
    else
        echo 2
    fi
}

statusText_singbox() {
    res=`status_singbox`
    case $res in
        2)
            echo -e ${GREEN}已安装singbox${PLAIN} ${RED}未运行${PLAIN}
            ;;
        3)
            echo -e ${GREEN}已安装singbox${PLAIN} ${GREEN}正在运行${PLAIN}
            ;;
        *)
            echo -e ${RED}未安装singbox${PLAIN}
            ;;
    esac
}

preinstall() {
    $PMT clean all
    [[ "$PMT" = "apt" ]] && $PMT update
    echo ""
    echo "安装必要软件，请等待..."
    if [[ "$PMT" = "apt" ]]; then
        res=`which ufw 2>/dev/null`
        [[ "$?" != "0" ]] && $CMD_INSTALL ufw
    fi  
    res=`which curl 2>/dev/null`
    [[ "$?" != "0" ]] && $CMD_INSTALL curl
    res=`which openssl 2>/dev/null`
    [[ "$?" != "0" ]] && $CMD_INSTALL openssl
    res=`which qrencode 2>/dev/null`
    [[ "$?" != "0" ]] && $CMD_INSTALL qrencode
    res=`which jq 2>/dev/null`
    [[ "$?" != "0" ]] && $CMD_INSTALL jq

    if [[ -s /etc/selinux/config ]] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
        setenforce 0
    fi
}

installSingbox() {
    echo ""
    echo "请选择安装版本:"
    colorEcho $BLUE "1. 稳定版"
    colorEcho $BLUE "2. 测试版"
    echo ""
    read -p "请输入你的选择 (1-2, default: 1): " version_choice
    echo ""
    version_choice=${version_choice:-1}

    if [ "$version_choice" -eq 2 ]; then
        echo "正在安装测试版..."
        latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | jq -r '[.[] | select(.prerelease==true)][0].tag_name')
    else
        echo "正在安装稳定版..."
        latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | jq -r '[.[] | select(.prerelease==false)][0].tag_name')
    fi

    latest_version=${latest_version_tag#v}
    
    arch=$(uname -m)
    case ${arch} in
        x86_64)
            arch="amd64"
            ;;
        aarch64)
            arch="arm64"
            ;;
        armv7l)
            arch="armv7"
            ;;
    esac
    
    package_name="sing-box-${latest_version}-linux-${arch}"
    url="https://github.com/SagerNet/sing-box/releases/download/${latest_version_tag}/${package_name}.tar.gz"

    curl -sLo "/root/${package_name}.tar.gz" "$url"
    tar -xzf "/root/${package_name}.tar.gz" -C /root
    mv "/root/${package_name}/sing-box" /root/
    rm -r "/root/${package_name}.tar.gz" "/root/${package_name}"
    chown root:root /root/sing-box
    chmod +x /root/sing-box
    mkdir -p /root/singbox
    touch /root/socks5.json
    colorEcho $BLUE "已安装最新$latest_version版本"
    sleep 5
}

install_socks5() {
    # 获取IP地址
    get_ip() {
        LOCAL_IPv4=$(curl -s -4 https://api.ipify.org)
        LOCAL_IPv6=$(curl -s -6 https://api64.ipify.org)

        if [[ -n "$LOCAL_IPv4" && "$LOCAL_IPv4" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            if [[ -n "$LOCAL_IPv6" && "$LOCAL_IPv6" =~ ^([0-9a-fA-F:]+)$ ]]; then
                colorEcho $YELLOW "本机 IPv4 地址："$LOCAL_IPv4""            
                colorEcho $YELLOW "本机 IPv6 地址："$LOCAL_IPv6""
                read -p "请确定你的节点ip，默认ipv4（0：ipv4；1：ipv6）:" USER_IP
                if [[ $USER_IP == 1 ]]; then
                    server_ip=$LOCAL_IPv6
                    colorEcho $BLUE "节点ip："$server_ip""                
                else
                    server_ip=$LOCAL_IPv4
                    colorEcho $BLUE "节点ip："$server_ip""                        
                fi                                
            else
                colorEcho $YELLOW "本机仅有 IPv4 地址："$LOCAL_IPv4""        
                server_ip=$LOCAL_IPv4
                colorEcho $BLUE "节点ip："$server_ip""
            fi
        else
            if [[ -n "$LOCAL_IPv6" && "$LOCAL_IPv6" =~ ^([0-9a-fA-F:]+)$ ]]; then
                colorEcho $YELLOW "本机仅有 IPv6 地址："$LOCAL_IPv6""        
                server_ip=$LOCAL_IPv6
                colorEcho $BLUE "节点ip："$server_ip""
            else
                colorEcho $RED "未能获取到有效的公网 IP 地址。"        
            fi
        fi
        echo "$server_ip" > /root/singbox/ip
    }

    # 设置端口
    get_port() {
        echo ""
        while true
        do
            read -p "请设置SOCKS5代理端口[1025-65535]，不输入则随机生成:" listen_port
            [[ -z "$listen_port" ]] && listen_port=`shuf -i1025-65000 -n1`
            if [[ "${listen_port:0:1}" = "0" ]]; then
                echo -e "${RED}端口不能以0开头${PLAIN}"
                exit 1
            fi
            expr $listen_port + 0 &>/dev/null
            if [[ $? -eq 0 ]]; then
                if [[ $listen_port -ge 1025 ]] && [[ $listen_port -le 65535 ]]; then
                    echo "$listen_port" > /root/singbox/port                
                    colorEcho $BLUE "端口号：$listen_port"
                    break
                else
                    colorEcho $RED "输入错误，端口号为1025-65535的数字"
                fi
            else
                colorEcho $RED "输入错误，端口号为1025-65535的数字"
            fi
        done
    }

    # 开启防火墙端口
    set_firewall() {
        echo ""
        echo "正在开启$listen_port端口..."    
        if [ -x "$(command -v firewall-cmd)" ]; then                              
            firewall-cmd --permanent --add-port=${listen_port}/tcp > /dev/null 2>&1
            firewall-cmd --permanent --add-port=${listen_port}/udp > /dev/null 2>&1
            firewall-cmd --reload > /dev/null 2>&1
            colorEcho $YELLOW "$listen_port端口已成功开启"
        elif [ -x "$(command -v ufw)" ]; then                                  
            ufw allow ${listen_port}/tcp > /dev/null 2>&1
            ufw allow ${listen_port}/udp > /dev/null 2>&1
            ufw reload > /dev/null 2>&1
            colorEcho $YELLOW "$listen_port端口已成功开启"
        else
            colorEcho $RED "无法配置防火墙规则。请手动配置以确保新端口可用!"
        fi
    }

    # 生成认证凭据
    generate_credentials() {
        echo ""
        echo "正在生成SOCKS5认证凭据..."
        USERNAME=$(openssl rand -hex 6)
        PASSWORD=$(openssl rand -hex 12)
        echo "$USERNAME" > /root/singbox/username
        echo "$PASSWORD" > /root/singbox/password
        colorEcho $BLUE "用户名: $USERNAME"
        colorEcho $BLUE "密码: $PASSWORD"
    }

    # 生成配置文件
    generate_config() {
        cat << EOF > /root/socks5.json
{
    "log": {
        "level": "info",
        "timestamp": true
    },
    "inbounds": [
        {
            "type": "socks",
            "tag": "socks-in",
            "listen": "::",
            "listen_port": $(cat /root/singbox/port),
            "sniff": true,
            "sniff_override_destination": true,
            "users": [
                {
                    "username": "$(cat /root/singbox/username)",
                    "password": "$(cat /root/singbox/password)"
                }
            ]
        }
    ],
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct"
        },
        {
            "type": "block",
            "tag": "block"
        }
    ]
}
EOF
    }

    # 创建服务文件
    create_service() {
        cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/root/sing-box run -c /root/socks5.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
    }

    # 显示连接信息
    show_info() {
        server_ip=$(cat /root/singbox/ip)
        listen_port=$(cat /root/singbox/port)
        username=$(cat /root/singbox/username)
        password=$(cat /root/singbox/password)

        echo ""
        colorEcho $BLUE "SOCKS5代理配置信息如下："
        colorEcho $YELLOW "服务器IP: ${PLAIN}$server_ip"
        colorEcho $YELLOW "端口: ${PLAIN}$listen_port"
        colorEcho $YELLOW "用户名: ${PLAIN}$username"
        colorEcho $YELLOW "密码: ${PLAIN}$password"
        echo ""

        if [[ "$server_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            server_link="socks5://${username}:${password}@${server_ip}:${listen_port}"
        elif [[ "$server_ip" =~ ^([0-9a-fA-F:]+)$ ]]; then 
            server_link="socks5://${username}:${password}@[${server_ip}]:${listen_port}"
        else
            colorEcho $RED "没有获取到有效ip！"
            exit 1
        fi
        
        colorEcho $BLUE "SOCKS5代理链接：${server_link}"    
        echo ""
        colorEcho $YELLOW "SOCKS5代理二维码（可直接扫码导入到客户端）："
        qrencode -o - -t utf8 -s 1 ${server_link}
        echo ""
    }

    # 主安装流程
    get_ip
    get_port
    set_firewall
    generate_credentials
    generate_config
    create_service

    # 检查配置并启动服务
    if /root/sing-box check -c /root/socks5.json; then
        echo "所有配置完成，正在启动singbox程序..."
        systemctl daemon-reload
        systemctl enable sing-box > /dev/null 2>&1
        systemctl start sing-box
        systemctl restart sing-box
        show_info
    else
        colorEcho $RED "配置错误."
    fi
}

reinstallSingbox() {
    colorEcho $BLUE "正在重新安装..."
    systemctl stop sing-box
    systemctl disable sing-box > /dev/null 2>&1
    rm /etc/systemd/system/sing-box.service
    rm /root/socks5.json
    rm /root/sing-box
    rm -rf /root/singbox
}

Switch_singboxcore() {
    echo ""
    echo "更新singbox内核..."
    current_version_tag=$(/root/sing-box version | grep 'sing-box version' | awk '{print $3}')
    latest_stable_version=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | jq -r '[.[] | select(.prerelease==false)][0].tag_name')
    latest_alpha_version=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | jq -r '[.[] | select(.prerelease==true)][0].tag_name')

    if [[ $current_version_tag == *"-alpha"* ]]; then
        singbox_version="测试版"
    else
        singbox_version="稳定版"
    fi
    colorEcho $YELLOW "当前已安装$singbox_version：$current_version_tag"
    colorEcho $BLUE "当前最新稳定版：$latest_stable_version"    
    colorEcho $BLUE "当前最新测试版：$latest_alpha_version"
    
    echo ""
    echo 0. 保持不变    
    echo 1. 升级最新稳定版
    echo 2. 升级最新测试版
    read -p "请输入你的选择（0-2）:" USER_CHOICE
    case $USER_CHOICE in 
        1)
            new_version_tag=$latest_stable_version
            singbox_version="稳定版"
            ;;
        2)
            new_version_tag=$latest_alpha_version    
            singbox_version="测试版"            
            ;;
        0)
            colorEcho $BLUE "保持不变"
            exit 0
            ;;                
        *)
            colorEcho $RED "无效选择"
            exit 1
            ;;
    esac
    
    res=`status_singbox`
    case $res in
        3)
            systemctl stop sing-box 
            ;;
    esac
    
    arch=$(uname -m)
    case $arch in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l) arch="armv7" ;;
    esac

    package_name="sing-box-${new_version_tag#v}-linux-${arch}"
    url="https://github.com/SagerNet/sing-box/releases/download/${new_version_tag}/${package_name}.tar.gz"

    curl -sLo "/root/${package_name}.tar.gz" "$url"
    tar -xzf "/root/${package_name}.tar.gz" -C /root
    mv "/root/${package_name}/sing-box" /root/sing-box
    rm -r "/root/${package_name}.tar.gz" "/root/${package_name}"
    chown root:root /root/sing-box
    chmod +x /root/sing-box
    systemctl daemon-reload
    case $res in
        2)
            systemctl start sing-box 
            ;;
    esac

    colorEcho $YELLOW "已更新到$singbox_version：$new_version_tag"
    echo ""
    sleep 5
}

UninstallSingbox() {
    echo "正在卸载singbox..."
    systemctl stop sing-box
    systemctl disable sing-box > /dev/null 2>&1
    rm /etc/systemd/system/sing-box.service
    rm /root/socks5.json
    rm /root/sing-box
    rm -rf /root/singbox
    colorEcho $RED "singbox已卸载完成!"
}

Show_Link() {
    server_ip=$(cat /root/singbox/ip)
    listen_port=$(jq -r '.inbounds[0].listen_port' /root/socks5.json)
    username=$(jq -r '.inbounds[0].users[0].username' /root/socks5.json)
    password=$(jq -r '.inbounds[0].users[0].password' /root/socks5.json)

    if [[ "$server_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        server_link="socks5://${username}:${password}@${server_ip}:${listen_port}"
    elif [[ "$server_ip" =~ ^([0-9a-fA-F:]+)$ ]]; then 
        server_link="socks5://${username}:${password}@[${server_ip}]:${listen_port}"
    else
        colorEcho $RED "没有获取到有效ip！"
        exit 1
    fi
    
    echo ""
    colorEcho $BLUE "SOCKS5代理配置信息如下："
    colorEcho $YELLOW "服务器IP: ${PLAIN}$server_ip"
    colorEcho $YELLOW "端口: ${PLAIN}$listen_port"
    colorEcho $YELLOW "用户名: ${PLAIN}$username"
    colorEcho $YELLOW "密码: ${PLAIN}$password"
    echo ""
    colorEcho $BLUE "SOCKS5代理链接：${server_link}"    
    echo ""
    colorEcho $YELLOW "SOCKS5代理二维码（可直接扫码导入到客户端）："
    qrencode -o - -t utf8 -s 1 ${server_link}
    exit 0
}

Modify_config() {
    # 获取当前配置
    listen_port=$(jq -r '.inbounds[0].listen_port' /root/socks5.json)
    username=$(jq -r '.inbounds[0].users[0].username' /root/socks5.json)
    password=$(jq -r '.inbounds[0].users[0].password' /root/socks5.json)
    server_ip=$(cat /root/singbox/ip)

    # 修改IP
    echo ""
    read -p "是否需要更换IP（0：保持不变；1：重新选择）:" CHANGE_IP
    if [[ $CHANGE_IP == 1 ]]; then        
        LOCAL_IPv4=$(curl -s -4 https://api.ipify.org)
        LOCAL_IPv6=$(curl -s -6 https://api64.ipify.org)

        if [[ -n "$LOCAL_IPv4" && "$LOCAL_IPv4" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            if [[ -n "$LOCAL_IPv6" && "$LOCAL_IPv6" =~ ^([0-9a-fA-F:]+)$ ]]; then
                colorEcho $YELLOW "本机 IPv4 地址："$LOCAL_IPv4""            
                colorEcho $YELLOW "本机 IPv6 地址："$LOCAL_IPv6""
                read -p "请确定你的节点ip，默认ipv4（0：ipv4；1：ipv6）:" USER_IP
                if [[ $USER_IP == 1 ]]; then
                    server_ip=$LOCAL_IPv6
                    colorEcho $BLUE "节点ip："$server_ip""                
                else
                    server_ip=$LOCAL_IPv4
                    colorEcho $BLUE "节点ip："$server_ip""                        
                fi                                
            else
                colorEcho $YELLOW "本机仅有 IPv4 地址："$LOCAL_IPv4""        
                server_ip=$LOCAL_IPv4
                colorEcho $BLUE "节点ip："$server_ip""
            fi
        else
            if [[ -n "$LOCAL_IPv6" && "$LOCAL_IPv6" =~ ^([0-9a-fA-F:]+)$ ]]; then
                colorEcho $YELLOW "本机仅有 IPv6 地址："$LOCAL_IPv6""        
                server_ip=$LOCAL_IPv6
                colorEcho $BLUE "节点ip："$server_ip""
            else
                colorEcho $RED "未能获取到有效的公网 IP 地址。"        
            fi
        fi
        echo "$server_ip" > /root/singbox/ip
    else
        colorEcho $BLUE "IP保持不变!"      
    fi

    # 修改端口
    echo ""
    read -p "是否需要更换端口（0：保持不变；1：更换端口）:" CHANGE_PORT
    if [[ $CHANGE_PORT == 1 ]]; then    
        while true
        do
            echo ""
            read -p "请设置SOCKS5代理端口[1025-65535]，不输入则随机生成:" listen_port
            [[ -z "$listen_port" ]] && listen_port=`shuf -i1025-65000 -n1`
            if [[ "${listen_port:0:1}" = "0" ]]; then
                echo -e "${RED}端口不能以0开头${PLAIN}"
                exit 1
            fi
            expr $listen_port + 0 &>/dev/null
            if [[ $? -eq 0 ]]; then
                if [[ $listen_port -ge 1025 ]] && [[ $listen_port -le 65535 ]]; then
                    echo "$listen_port" > /root/singbox/port                
                    colorEcho $BLUE "端口号：$listen_port"
                    # 开启端口 
                    echo ""
                    echo "正在开启$listen_port端口..."    
                    if [ -x "$(command -v firewall-cmd)" ]; then                              
                        firewall-cmd --permanent --add-port=${listen_port}/tcp > /dev/null 2>&1
                        firewall-cmd --permanent --add-port=${listen_port}/udp > /dev/null 2>&1
                        firewall-cmd --reload > /dev/null 2>&1
                        colorEcho $YELLOW "$listen_port端口已成功开启"
                    elif [ -x "$(command -v ufw)" ]; then                                  
                        ufw allow ${listen_port}/tcp > /dev/null 2>&1
                        ufw allow ${listen_port}/udp > /dev/null 2>&1
                        ufw reload > /dev/null 2>&1
                        colorEcho $YELLOW "$listen_port端口已成功开启"
                    else
                        colorEcho $RED "无法配置防火墙规则。请手动配置以确保新端口可用!"
                    fi
                    break
                else
                    colorEcho $RED "输入错误，端口号为1025-65535的数字"
                fi
            else
                colorEcho $RED "输入错误，端口号为1025-65535的数字"
            fi
        done
    else
        colorEcho $BLUE "端口保持不变!"  
    fi     

    # 修改认证凭据
    echo ""
    read -p "是否需要重新生成认证凭据（0：保持不变；1：重新生成）:" CHANGE_CRED
    if [[ $CHANGE_CRED == 1 ]]; then
        echo ""
        echo "正在生成SOCKS5认证凭据..."
        username=$(openssl rand -hex 6)
        password=$(openssl rand -hex 12)
        echo "$username" > /root/singbox/username
        echo "$password" > /root/singbox/password
        colorEcho $BLUE "用户名: $username"
        colorEcho $BLUE "密码: $password"
    else
        colorEcho $BLUE "认证凭据保持不变!"  
    fi

    # 生成新配置
    cat << EOF > /root/socks5.json
{
    "log": {
        "level": "info",
        "timestamp": true
    },
    "inbounds": [
        {
            "type": "socks",
            "tag": "socks-in",
            "listen": "::",
            "listen_port": $(cat /root/singbox/port),
            "sniff": true,
            "sniff_override_destination": true,
            "users": [
                {
                    "username": "$(cat /root/singbox/username)",
                    "password": "$(cat /root/singbox/password)"
                }
            ]
        }
    ],
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct"
        },
        {
            "type": "block",
            "tag": "block"
        }
    ]
}
EOF
  
    # 重启服务
    systemctl restart sing-box
    echo ""
    
    # 显示新配置
    server_ip=$(cat /root/singbox/ip)
    listen_port=$(cat /root/singbox/port)
    username=$(cat /root/singbox/username)
    password=$(cat /root/singbox/password)

    if [[ "$server_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        server_link="socks5://${username}:${password}@${server_ip}:${listen_port}"
    elif [[ "$server_ip" =~ ^([0-9a-fA-F:]+)$ ]]; then 
        server_link="socks5://${username}:${password}@[${server_ip}]:${listen_port}"
    else
        colorEcho $RED "没有获取到有效ip！"
        exit 1
    fi
    
    echo ""
    colorEcho $BLUE "SOCKS5代理配置信息如下："
    colorEcho $YELLOW "服务器IP: ${PLAIN}$server_ip"
    colorEcho $YELLOW "端口: ${PLAIN}$listen_port"
    colorEcho $YELLOW "用户名: ${PLAIN}$username"
    colorEcho $YELLOW "密码: ${PLAIN}$password"
    echo ""
    colorEcho $BLUE "SOCKS5代理链接：${server_link}"    
    echo ""
    colorEcho $YELLOW "SOCKS5代理二维码（可直接扫码导入到客户端）："
    qrencode -o - -t utf8 -s 1 ${server_link}
    exit 0
}

start_singbox() {
    res=`status_singbox`
    if [[ $res -lt 2 ]]; then
        echo -e "${RED}singbox未安装，请先安装！${PLAIN}"
        return
    fi
    systemctl restart sing-box
    sleep 2
    port=`grep -o '"listen_port": [0-9]*' /root/socks5.json | awk '{print $2}'`
    res=`ss -ntlp| grep ${port} | grep sing-box`
    if [[ "$res" = "" ]]; then
        colorEcho $RED "singbox启动失败，请检查端口是否被占用！"
    else
        colorEcho $BLUE "singbox启动成功！"
    fi
}

restart_singbox() {
    res=`status_singbox`
    if [[ $res -lt 2 ]]; then
        echo -e "${RED}singbox未安装，请先安装！${PLAIN}"
        return
    fi
    stop_singbox
    start_singbox
}

stop_singbox() {
    res=`status_singbox`
    if [[ $res -lt 2 ]]; then
        echo -e "${RED}singbox未安装，请先安装！${PLAIN}"
        return
    fi
    systemctl stop sing-box
    colorEcho $BLUE "singbox停止成功"
}

menu() {
    clear
    bash -c "$(curl -s -L https://raw.githubusercontent.com/q6188011/demo/main/reality.sh)"
}

Singbox() {
    clear
    echo "##################################################################"
    echo -e "#                   ${RED}SOCKS5代理一键安装脚本${PLAIN}                                #"
    echo "##################################################################"

    echo -e "  ${GREEN}  <Singbox内核版本>  ${YELLOW}"    
    echo -e "  ${GREEN}1.${PLAIN}  安装singbox"
    echo -e "  ${GREEN}2.${PLAIN}  更新singbox"
    echo -e "  ${GREEN}3.${RED}  卸载singbox${PLAIN}"
    echo " -------------"        
    echo -e "  ${GREEN}4.${PLAIN}  搭建SOCKS5代理"
    echo -e "  ${GREEN}5.${PLAIN}  查看SOCKS5连接信息"
    echo -e "  ${GREEN}6.  ${RED}修改SOCKS5配置${PLAIN}"        
    echo " -------------"
    echo -e "  ${GREEN}7.${PLAIN}  启动singbox"
    echo -e "  ${GREEN}8.${PLAIN}  重启singbox"
    echo -e "  ${GREEN}9.${PLAIN}  停止singbox"
    echo " -------------"
    echo -e "  ${GREEN}10.${PLAIN}  返回上一级菜单"    
    echo -e "  ${GREEN}0.${PLAIN}  退出"
    echo -n " 当前singbox状态："
    statusText_singbox
    echo 

    read -p " 请选择操作[0-10]：" answer
    case $answer in
        0)
            exit 0
            ;;
        1)
            checkSystem
            preinstall
            installSingbox
            Singbox
            ;;
        2)
            Switch_singboxcore
            Singbox
            ;;
        3)
            UninstallSingbox
            ;;
        4)
            install_socks5
            ;;
        5)
            Show_Link  
            ;;
        6)
            Modify_config     
            ;;            
        7)
            start_singbox
            Singbox
            ;;
        8)
            restart_singbox
            Singbox
            ;;
        9)
            stop_singbox
            Singbox
            ;;            
        10)
            menu
            ;;
        *)
            echo " 请选择正确的操作！"
            exit 1
            ;;
    esac
}

Singbox
