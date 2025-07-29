Xray() {
    clear
    echo "##################################################################"
    echo -e "#                   ${RED}Socks5一键安装脚本${PLAIN}                                    #"
    echo "##################################################################"

    echo -e "  ${GREEN}  <Xray内核版本>  ${YELLOW}"    
    echo -e "  ${GREEN}1.${PLAIN}  安装xray"    
    echo -e "  ${GREEN}2.${PLAIN}  更新xray"
    echo -e "  ${GREEN}3.${RED}  卸载xray${PLAIN}"
    echo " -------------"    
    echo -e "  ${GREEN}4.${PLAIN}  搭建Socks5代理"
    echo -e "  ${GREEN}5.${PLAIN}  查看Socks5连接信息"
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
            config_socks5
            ;;
        5)
            cat /root/socks5_info.txt 
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

config_socks5() {
    read -p "请输入Socks5端口 (默认1080): " SOCKS_PORT
    SOCKS_PORT=${SOCKS_PORT:-1080}
    
    read -p "请输入Socks5用户名 (默认user): " SOCKS_USER
    SOCKS_USER=${SOCKS_USER:-user}
    
    read -p "请输入Socks5密码 (默认随机生成): " SOCKS_PASS
    if [ -z "$SOCKS_PASS" ]; then
        SOCKS_PASS=$(openssl rand -hex 8)
    fi

    # 开启端口
    echo "正在开启${SOCKS_PORT}端口..."
    if [ -x "$(command -v firewall-cmd)" ]; then                              
        firewall-cmd --permanent --add-port=${SOCKS_PORT}/tcp > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
        colorEcho $YELLOW "$SOCKS_PORT端口已成功开启"
    elif [ -x "$(command -v ufw)" ]; then                                  
        ufw allow ${SOCKS_PORT}/tcp > /dev/null 2>&1
        ufw reload > /dev/null 2>&1
        colorEcho $YELLOW "${SOCKS_PORT}端口已成功开启"
    else
        echo "无法配置防火墙规则。请手动配置以确保端口可用!"
    fi

    # 生成Socks5配置文件
    cat > /usr/local/etc/xray/config.json <<EOF
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": ${SOCKS_PORT},
            "protocol": "socks",
            "settings": {
                "auth": "password",
                "accounts": [
                    {
                        "user": "${SOCKS_USER}",
                        "pass": "${SOCKS_PASS}"
                    }
                ],
                "udp": true,
                "ip": "127.0.0.1"
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

    # 保存连接信息
    echo "Socks5连接信息:" > /root/socks5_info.txt
    echo "服务器: $(curl -s ifconfig.me)" >> /root/socks5_info.txt
    echo "端口: ${SOCKS_PORT}" >> /root/socks5_info.txt
    echo "用户名: ${SOCKS_USER}" >> /root/socks5_info.txt
    echo "密码: ${SOCKS_PASS}" >> /root/socks5_info.txt
    echo "支持UDP: 是" >> /root/socks5_info.txt

    restart
    
    echo ""
    echo "Socks5代理已配置完成!"
    echo "========================"
    cat /root/socks5_info.txt
    echo "========================"
    echo "请妥善保存以上连接信息"
}
