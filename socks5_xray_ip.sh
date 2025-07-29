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
DEFAULT_START_PORT=10000                      
IP_ADDRESSES=($(hostname -I))
declare -a USER_UUID PORT USER_NAME PRIVATE_KEY PUBLIC_KEY USER_DEST USER_SERVERNAME USER_SID LINK
	
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
    port=`grep -o '"port": [0-9]*' $CONFIG_FILE | awk '{print $2}' | head -n 1`
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

config_nodes() {
    read -p "起始端口 (默认 $DEFAULT_START_PORT): " START_PORT
	START_PORT=${START_PORT:-$DEFAULT_START_PORT}
	
    # 生成随机用户名和密码
    USERNAME=$(openssl rand -hex 6)
    PASSWORD=$(openssl rand -hex 12)
	
    # 开始生成 JSON 配置
    cat > /usr/local/etc/xray/config.json <<EOF
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": ${START_PORT},
            "protocol": "socks",
            "settings": {
                "auth": "password",
                "accounts": [
                    {
                        "user": "${USERNAME}",
                        "pass": "${PASSWORD}"
                    }
                ],
                "udp": true,
                "ip": "127.0.0.1"
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
    
    # 开启端口
    echo "正在开启${START_PORT}端口..."	
    if [ -x "$(command -v firewall-cmd)" ]; then							  
        firewall-cmd --permanent --add-port=${START_PORT}/tcp > /dev/null 2>&1
        firewall-cmd --permanent --add-port=${START_PORT}/udp > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
        colorEcho $YELLOW "${START_PORT}端口已成功开启"
    elif [ -x "$(command -v ufw)" ]; then								  
        ufw allow ${START_PORT}/tcp > /dev/null 2>&1
        ufw allow ${START_PORT}/udp > /dev/null 2>&1
        ufw reload > /dev/null 2>&1
        colorEcho $YELLOW "${START_PORT}端口已成功开启"
    else
        echo "无法配置防火墙规则。请手动配置以确保新xray端口可用!"
    fi

    restart
    generate_link
}

# 输出 SOCKS5 链接
generate_socks5_link() {
    > /root/socks5_links.txt
    colorEcho $BLUE "${BLUE}SOCKS5 代理链接${PLAIN}："
    
    # 循环遍历 IP 和端口
    for ((i = 0; i < ${#IP_ADDRESSES[@]}; i++)); do
        # SOCKS5 链接格式: socks5://username:password@hostname:port
        if [[ "${IP_ADDRESSES[$i]}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            # IPv4 格式
            LINK[$i]="socks5://${USER_NAME[$i]}:${USER_UUID[$i]}@${IP_ADDRESSES[$i]}:${PORT[$i]}#SOCKS5_${USER_NAME[$i]}"
        elif [[ "${IP_ADDRESSES[$i]}" =~ ^([0-9a-fA-F:]+)$ ]]; then 
            # IPv6 格式
            LINK[$i]="socks5://${USER_NAME[$i]}:${USER_UUID[$i]}@[${IP_ADDRESSES[$i]}]:${PORT[$i]}#SOCKS5_${USER_NAME[$i]}"
        else
            colorEcho $RED "没有获取到有效ip！"
        fi
        
        colorEcho $YELLOW ${LINK[$i]}
        echo ${LINK[$i]} >> /root/socks5_links.txt
    done
}	

start() {
    res=`status`
    if [[ $res -lt 2 ]]; then
        echo -e "${RED}xray未安装，请先安装！${PLAIN}"
        return
    fi
    systemctl restart ${NAME}
    sleep 2
    port=`grep -o '"port": [0-9]*' $CONFIG_FILE | awk '{print $2}' | head -n 1`
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
    bash -c "$(curl -s -L https://raw.githubusercontent.com/q6188011/demo/main/socks5.sh)"
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
    echo " -------------"
    echo -e "  ${GREEN}6.${PLAIN}  启动xray"
    echo -e "  ${GREEN}7.${PLAIN}  重启xray"
    echo -e "  ${GREEN}8.${PLAIN}  停止xray"
    echo " -------------"
    echo -e "  ${GREEN}9.${PLAIN}  返回上一级菜单"	
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
            config_nodes
            ;;
        5)
			cat /root/link.txt 
            ;;
        6)
            start
			Xray
            ;;
        7)
            restart
			Xray
            ;;
        8)
            stop
			Xray
            ;;
		9)
			menu
            ;;
        *)
            echo " 请选择正确的操作！"
            exit 1
            ;;
    esac
}

Xray
