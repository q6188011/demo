#!/bin/bash
# SOCKS5一键安装脚本
# Author: YouTube频道<https://www.youtube.com/@aifenxiangdexiaoqie>

RED="\033[31m"      # Error message
GREEN="\033[32m"    # Success message
YELLOW="\033[33m"   # Warning message
BLUE="\033[36m"     # Info message
PLAIN='\033[0m'

NAME="xray"
CONFIG_FILE="/usr/local/etc/${NAME}/config.json"
SERVICE_FILE="/etc/systemd/system/${NAME}.service"

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

status() {
    export PATH=/usr/local/bin:$PATH
    cmd="$(command -v xray)"
    if [[ "$cmd" = "" ]]; then
        echo 0
        return
    fi
    if [[ ! -f $CONFIG_FILE ]]; then
        echo 1
        return
    fi
    port=`grep -o '"port": [0-9]*' $CONFIG_FILE | awk '{print $2}'`
    if [[ -n "$port" ]]; then
        res=`ss -ntlp| grep ${port} | grep xray`
        if [[ -z "$res" ]]; then
            echo 2
        else
            echo 3
        fi
    else
        echo 2
    fi
}

statusText() {
    res=`status`
    case $res in
        2)
            echo -e ${GREEN}已安装xray${PLAIN} ${RED}未运行${PLAIN}
            ;;
        3)
            echo -e ${GREEN}已安装xray${PLAIN} ${GREEN}正在运行${PLAIN}
            ;;
        *)
            echo -e ${RED}未安装xray${PLAIN}
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

installXray() {
    echo ""
    echo "正在安装Xray..."
    bash -c "$(curl -s -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" > /dev/null 2>&1
    colorEcho $BLUE "xray内核已安装完成"
    sleep 5
}

updateXray() {
    echo ""
    echo "正在更新Xray..."
    bash -c "$(curl -s -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" > /dev/null 2>&1
    colorEcho $BLUE "xray内核已更新完成"
    sleep 5
}

removeXray() {
    echo ""
    echo "正在卸载Xray..."
    bash -c "$(curl -s -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge > /dev/null 2>&1
    rm -rf /etc/systemd/system/xray.service > /dev/null 2>&1
    rm -rf /etc/systemd/system/xray@.service > /dev/null 2>&1
    rm -rf /usr/local/bin/xray > /dev/null 2>&1
    rm -rf /usr/local/etc/xray > /dev/null 2>&1
    rm -rf /usr/local/share/xray > /dev/null 2>&1
    rm -rf /var/log/xray > /dev/null 2>&1
    colorEcho $RED "已完成xray卸载"
    sleep 5
}

getip() {
    # 尝试获取 IP 地址
    LOCAL_IPv4=$(curl -s -4 https://api.ipify.org)
    LOCAL_IPv6=$(curl -s -6 https://api64.ipify.org)

    # 检查 IPv是否存在且合法
    if [[ -n "$LOCAL_IPv4" && "$LOCAL_IPv4" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # 检查 IPv6 是否存在且合法
        if [[ -n "$LOCAL_IPv6" && "$LOCAL_IPv6" =~ ^([0-9a-fA-F:]+)$ ]]; then
            colorEcho $YELLOW "本机 IPv4 地址："$LOCAL_IPv4""            
            colorEcho $YELLOW "本机 IPv6 地址："$LOCAL_IPv6""
            read -p "请确定你的节点ip，默认ipv4（0：ipv4；1：ipv6）:" USER_IP
            if [[ $USER_IP == 1 ]]; then
                LOCAL_IP=$LOCAL_IPv6
                colorEcho $BLUE "节点ip："$LOCAL_IP""                
            else
                LOCAL_IP=$LOCAL_IPv4
                colorEcho $BLUE "节点ip："$LOCAL_IP""                        
            fi                                
        else
            colorEcho $YELLOW "本机仅有 IPv4 地址："$LOCAL_IPv4""        
            LOCAL_IP=$LOCAL_IPv4
            colorEcho $BLUE "节点ip："$LOCAL_IP""
        fi
    else
        if [[ -n "$LOCAL_IPv6" && "$LOCAL_IPv6" =~ ^([0-9a-fA-F:]+)$ ]]; then
            colorEcho $YELLOW "本机仅有 IPv6 地址："$LOCAL_IPv6""        
            LOCAL_IP=$LOCAL_IPv6
            colorEcho $BLUE "节点ip："$LOCAL_IP""
        else
            colorEcho $RED "未能获取到有效的公网 IP 地址。"        
        fi
    fi
    # 将 IP 地址写入文件
    echo "$LOCAL_IP" > /usr/local/etc/xray/ip
}

getport() {
    echo ""
    while true
    do
        read -p "请设置SOCKS5代理端口[1025-65535]，不输入则随机生成:" PORT
        [[ -z "$PORT" ]] && PORT=`shuf -i1025-65000 -n1`
        if [[ "${PORT:0:1}" = "0" ]]; then
            echo -e " ${RED}端口不能以0开头${PLAIN}"
            exit 1
        fi
        expr $PORT + 0 &>/dev/null
        if [[ $? -eq 0 ]]; then
            if [[ $PORT -ge 1025 ]] && [[ $PORT -le 65535 ]]; then
                echo "$PORT" > /usr/local/etc/xray/port                
                colorEcho $BLUE "端口号：$PORT"
                break
            else
                colorEcho $RED "输入错误，端口号为1025-65535的数字"
            fi
        else
            colorEcho $RED "输入错误，端口号为1025-65535的数字"
        fi
    done
}

setFirewall() {
    echo ""
    echo "正在开启$PORT端口..."    
    if [ -x "$(command -v firewall-cmd)" ]; then                              
        firewall-cmd --permanent --add-port=${PORT}/tcp > /dev/null 2>&1
        firewall-cmd --permanent --add-port=${PORT}/udp > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
        colorEcho $YELLOW "$PORT端口已成功开启"
    elif [ -x "$(command -v ufw)" ]; then                                  
        ufw allow ${PORT}/tcp > /dev/null 2>&1
        ufw allow ${PORT}/udp > /dev/null 2>&1
        ufw reload > /dev/null 2>&1
        colorEcho $YELLOW "$PORT端口已成功开启"
    else
        echo "无法配置防火墙规则。请手动配置以确保新xray端口可用!"
    fi
}

generate_credentials() {
    echo ""
    echo "正在生成SOCKS5认证凭据..."
    USERNAME=$(openssl rand -hex 6)
    PASSWORD=$(openssl rand -hex 12)
    echo "$USERNAME" > /usr/local/etc/xray/username
    echo "$PASSWORD" > /usr/local/etc/xray/password
    colorEcho $BLUE "用户名: $USERNAME"
    colorEcho $BLUE "密码: $PASSWORD"
}

generate_config() {
    cat << EOF > /usr/local/etc/xray/config.json
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": $(cat /usr/local/etc/xray/port),
            "protocol": "socks",
            "settings": {
                "auth": "password",
                "accounts": [
                    {
                        "user": "$(cat /usr/local/etc/xray/username)",
                        "pass": "$(cat /usr/local/etc/xray/password)"
                    }
                ],
                "udp": true,
                "ip": "0.0.0.0"
            },
            "streamSettings": {
                "network": "tcp"
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        }
    ]
}
EOF
    echo "创建SOCKS5配置文件完成..."
    echo ""
}

print_config() {
    echo ""
    colorEcho $BLUE "SOCKS5代理配置信息如下："
    colorEcho $YELLOW "服务器IP: ${PLAIN}$(cat /usr/local/etc/xray/ip)"
    colorEcho $YELLOW "端口: ${PLAIN}$(cat /usr/local/etc/xray/port)"
    colorEcho $YELLOW "用户名: ${PLAIN}$(cat /usr/local/etc/xray/username)"
    colorEcho $YELLOW "密码: ${PLAIN}$(cat /usr/local/etc/xray/password)"
    echo ""
}

generate_link() {
    LOCAL_IP=`cat /usr/local/etc/xray/ip`
    USERNAME=`cat /usr/local/etc/xray/username`
    PASSWORD=`cat /usr/local/etc/xray/password`
    PORT=`cat /usr/local/etc/xray/port`
    
    if [[ "$LOCAL_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        LINK="socks5://${USERNAME}:${PASSWORD}@${LOCAL_IP}:${PORT}"
    elif [[ "$LOCAL_IP" =~ ^([0-9a-fA-F:]+)$ ]]; then 
        LINK="socks5://${USERNAME}:${PASSWORD}@[${LOCAL_IP}]:${PORT}"
    else
        colorEcho $RED "没有获取到有效ip！"
    fi
    
    colorEcho $BLUE "${BLUE}SOCKS5代理链接${PLAIN}：${LINK}"
    echo ""
    
    colorEcho $YELLOW "SOCKS5代理二维码（可直接扫码导入到客户端...）："
    qrencode -o - -t utf8 -s 1 ${LINK}
    echo ""
}

Modify_config() {
    echo ""
    read -p "是否需要更换IP（0：保持不变；1：重新选择）:" CHANGE_IP
    if [[ $CHANGE_IP == 1 ]]; then        
        getip
    else
        colorEcho $BLUE "IP保持不变!"      
    fi

    echo ""
    read -p "是否需要更换端口（0：保持不变；1：更换端口）:" CHANGE_PORT
    if [[ $CHANGE_PORT == 1 ]]; then    
        getport
        setFirewall
    else
        colorEcho $BLUE "端口保持不变!"  
    fi     

    echo ""
    read -p "是否需要重新生成认证凭据（0：保持不变；1：重新生成）:" CHANGE_CRED
    if [[ $CHANGE_CRED == 1 ]]; then
        generate_credentials
    else
        colorEcho $BLUE "认证凭据保持不变!"  
    fi

    generate_config
    restart
    print_config
    generate_link
}

start() {
    res=`status`
    if [[ $res -lt 2 ]]; then
        echo -e "${RED}xray未安装，请先安装！${PLAIN}"
        return
    fi
    systemctl restart ${NAME}
    sleep 2
    port=`grep -o '"port": [0-9]*' $CONFIG_FILE | awk '{print $2}'`
    res=`ss -ntlp| grep ${port} | grep xray`
    if [[ "$res" = "" ]]; then
        colorEcho $RED "xray启动失败，请检查端口是否被占用！"
    else
        colorEcho $BLUE "xray启动成功！"
    fi
}

restart() {
    res=`status`
    if [[ $res -lt 2 ]]; then
        echo -e "${RED}xray未安装，请先安装！${PLAIN}"
        return
    fi
    stop
    start
}

stop() {
    res=`status`
    if [[ $res -lt 2 ]]; then
        echo -e "${RED}xray未安装，请先安装！${PLAIN}"
        return
    fi
    systemctl stop ${NAME}
    colorEcho $BLUE "xray停止成功"
}

menu() {
    clear
    bash -c "$(curl -s -L https://raw.githubusercontent.com/yirenchengfeng1/linux/main/reality.sh)"
}

Xray() {
    clear
    echo "##################################################################"
    echo -e "#                   ${RED}SOCKS5代理一键安装脚本${PLAIN}                                #"
    echo "##################################################################"

    echo -e "  ${GREEN}  <Xray内核版本>  ${YELLOW}"    
    echo -e "  ${GREEN}1.${PLAIN}  安装xray"    
    echo -e "  ${GREEN}2.${PLAIN}  更新xray"
    echo -e "  ${GREEN}3.${RED}  卸载xray${PLAIN}"
    echo " -------------"    
    echo -e "  ${GREEN}4.${PLAIN}  搭建SOCKS5代理"
    echo -e "  ${GREEN}5.${PLAIN}  查看SOCKS5连接信息"
    echo -e "  ${GREEN}6.  ${RED}修改SOCKS5配置${PLAIN}"        
    echo " -------------"
    echo -e "  ${GREEN}7.${PLAIN}  启动xray"
    echo -e "  ${GREEN}8.${PLAIN}  重启xray"
    echo -e "  ${GREEN}9.${PLAIN}  停止xray"
    echo " -------------"
    echo -e "  ${GREEN}10.${PLAIN}  返回上一级菜单"    
    echo -e "  ${GREEN}0.${PLAIN}  退出"
    echo -n " 当前xray状态："
    statusText
    echo 

    read -p " 请选择操作[0-10]：" answer
    case $answer in
        0)
            exit 0
            ;;
        1)
            checkSystem
            preinstall
            installXray
            Xray
            ;;
        2)
            updateXray
            Xray
            ;;    
        3)
            removeXray
            ;;            
        4)
            getip
            getport
            setFirewall
            generate_credentials
            generate_config
            restart
            print_config
            generate_link
            ;;
        5)
            print_config
            generate_link  
            ;;
        6)
            Modify_config     
            ;;
        7)
            start
            Xray
            ;;
        8)
            restart
            Xray
            ;;
        9)
            stop
            Xray
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

Xray
