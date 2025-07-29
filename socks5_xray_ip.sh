#!/bin/bash
# 一键安装SOCKS5代理配置

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
declare -a USER_UUID PORT USER_NAME PRIVATE_KEY PUBLIC_KEY USER_DEST USER_SERVERNAME USER_SID LINK SOCKS_LINK
	
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

random_website() {
    domains=(
        "one-piece.com"
        "www.lovelive-anime.jp"
        "www.swift.com"
        "academy.nvidia.com"
        "www.cisco.com"
        "www.samsung.com"
        "www.amd.com"
        "www.apple.com"
        "music.apple.com"
        "www.amazon.com"		
        "www.fandom.com"
        "tidal.com"
        "zoro.to"
        "www.pixiv.co.jp"
        "mxj.myanimelist.net"
        "mora.jp"
        "www.j-wave.co.jp"
        "www.dmm.com"
        "booth.pm"
        "www.ivi.tv"
        "www.leercapitulo.com"
        "www.sky.com"
        "itunes.apple.com"
        "download-installer.cdn.mozilla.net"	
    )

    total_domains=${#domains[@]}
    random_index=$((RANDOM % total_domains))
    echo "${domains[random_index]}"
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
	
    # 开始生成 JSON 配置
    cat > /usr/local/etc/xray/config.json <<EOF
{
    "log": {
        "loglevel": "debug"
    },
    "inbounds": [
        {
            "port": 1080,
            "protocol": "socks",
            "settings": {
                "auth": "noauth",
                "udp": true,
                "ip": "127.0.0.1"
            },
            "tag": "socks-inbound"
        },
        {
            "port": 1081,
            "protocol": "http",
            "settings": {
                "allowTransparent": false
            },
            "tag": "http-inbound"
        }
EOF

	# 循环遍历 IP 和端口
	for ((i = 0; i < ${#IP_ADDRESSES[@]}; i++)); do
		/usr/local/bin/xray uuid > /usr/local/etc/xray/uuid
		USER_UUID[$i]=`cat /usr/local/etc/xray/uuid`
		USER_NAME[$i]="SOCKS5_$i"	
		/usr/local/bin/xray x25519 > /usr/local/etc/xray/key
		PRIVATE_KEY[$i]=$(cat /usr/local/etc/xray/key | head -n 1 | awk '{print $3}')
		PUBLIC_KEY[$i]=$(cat /usr/local/etc/xray/key | sed -n '2p' | awk '{print $3}')

        PORT[$i]=$((START_PORT + i))
		echo "正在开启${PORT[$i]}端口..."	
		if [ -x "$(command -v firewall-cmd)" ]; then							  
			firewall-cmd --permanent --add-port=${PORT[$i]}/tcp > /dev/null 2>&1
			firewall-cmd --permanent --add-port=${PORT[$i]}/udp > /dev/null 2>&1
			firewall-cmd --reload > /dev/null 2>&1
			colorEcho $YELLOW "$PORT[$i]端口已成功开启"
		elif [ -x "$(command -v ufw)" ]; then								  
			ufw allow ${PORT[$i]}/tcp > /dev/null 2>&1
			ufw allow ${PORT[$i]}/udp > /dev/null 2>&1
			ufw reload > /dev/null 2>&1
			colorEcho $YELLOW "${PORT[$i]}端口已成功开启"
		else
			echo "无法配置防火墙规则。请手动配置以确保新xray端口可用!"
		fi

		while true; do
			domain=$(random_website)
			check_num=$(echo QUIT | stdbuf -oL openssl s_client -connect "${domain}:443" -tls1_3 -alpn h2 2>&1 | grep -Eoi '(TLSv1.3)|(^ALPN\s+protocol:\s+h2$)|(X25519)' | sort -u | wc -l)
			if [ "$check_num" -eq 3 ]; then
				USER_SERVERNAME[$i]="$domain"
				break
			fi
		done	
		USER_DEST[$i]=${USER_SERVERNAME[i]}:443
        USER_SID[$i]=$(openssl rand -hex 8)

		echo "    ,{" >> /usr/local/etc/xray/config.json
		echo "      \"port\": ${PORT[$i]}," >> /usr/local/etc/xray/config.json
		echo "      \"protocol\": \"socks\"," >> /usr/local/etc/xray/config.json
		echo "      \"settings\": {" >> /usr/local/etc/xray/config.json
		echo "        \"auth\": \"password\"," >> /usr/local/etc/xray/config.json
		echo "        \"accounts\": [" >> /usr/local/etc/xray/config.json	
		echo "          {" >> /usr/local/etc/xray/config.json	
		echo "            \"user\": \"${USER_UUID[$i]}\"," >> /usr/local/etc/xray/config.json
		echo "            \"pass\": \"${USER_SID[$i]}\"" >> /usr/local/etc/xray/config.json
		echo "          }" >> /usr/local/etc/xray/config.json	
		echo "        ]," >> /usr/local/etc/xray/config.json	
		echo "        \"udp\": true," >> /usr/local/etc/xray/config.json
		echo "        \"ip\": \"${IP_ADDRESSES[$i]}\"" >> /usr/local/etc/xray/config.json
		echo "       }," >> /usr/local/etc/xray/config.json
		echo "      \"tag\": \"socks-proxy-$i\"" >> /usr/local/etc/xray/config.json
		echo "    }" >> /usr/local/etc/xray/config.json
    done
	    
    cat >> /usr/local/etc/xray/config.json <<EOF
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "blocked"
        }
    ],
    "routing": {
        "rules": [
            {
                "type": "field",
                "ip": [
                    "geoip:private"
                ],
                "outboundTag": "blocked"
            }
        ]
    }
}
EOF
	
    restart
	generate_links
}

generate_links() {
    > /root/link.txt
    > /root/socks_links.txt
    colorEcho $BLUE "${BLUE}SOCKS5订阅链接${PLAIN}："
    
	for ((i = 0; i < ${#IP_ADDRESSES[@]}; i++)); do
		if [[ "${IP_ADDRESSES[$i]}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
			SOCKS_LINK[$i]="socks5://${USER_UUID[$i]}:${USER_SID[$i]}@${IP_ADDRESSES[$i]}:${PORT[$i]}#${USER_NAME[$i]}"
		elif [[ "${IP_ADDRESSES[$i]}" =~ ^([0-9a-fA-F:]+)$ ]]; then 
			SOCKS_LINK[$i]="socks5://${USER_UUID[$i]}:${USER_SID[$i]}@[${IP_ADDRESSES[$i]}]:${PORT[$i]}#${USER_NAME[$i]}"
		else
			colorEcho $RED "没有获取到有效ip！"
		fi
		colorEcho $YELLOW ${SOCKS_LINK[$i]}
		echo ${SOCKS_LINK[$i]} >> /root/socks_links.txt
	done
	
	# 生成订阅链接
	SUBSCRIPTION_LINK=$(echo -n "socks5://${IP_ADDRESSES[0]}:${PORT[0]},${USER_UUID[0]},${USER_SID[0]}" | base64 -w 0)
	colorEcho $GREEN "SOCKS5订阅链接(base64编码):"
	colorEcho $BLUE "http://${IP_ADDRESSES[0]}/socks5.txt#SOCKS5订阅"
	echo "http://${IP_ADDRESSES[0]}/socks5.txt#SOCKS5订阅" >> /root/socks_links.txt
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
    echo -e "#                   ${RED}SOCKS5代理一键安装脚本${PLAIN}                                    #"
    echo "##################################################################"

    echo -e "  ${GREEN}  <Xray内核版本>  ${YELLOW}"	
    echo -e "  ${GREEN}1.${PLAIN}  安装xray"	
    echo -e "  ${GREEN}2.${PLAIN}  更新xray"
    echo -e "  ${GREEN}3.${RED}  卸载xray${PLAIN}"
    echo " -------------"	
    echo -e "  ${GREEN}4.${PLAIN}  搭建SOCKS5代理"
    echo -e "  ${GREEN}5.${PLAIN}  查看SOCKS5链接"
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
			cat /root/socks_links.txt 
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
