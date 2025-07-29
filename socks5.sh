#!/bin/bash
# SOCKS5代理一键安装脚本
# Author: YouTube频道<https://www.youtube.com/@aifenxiangdexiaoqie>

RED="\033[31m"      # Error message
GREEN="\033[32m"    # Success message
YELLOW="\033[33m"   # Warning message
BLUE="\033[36m"     # Info message
PLAIN='\033[0m'


colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

XraySocks5() {
    clear
    echo "正在安装Xray SOCKS5代理..."
    # 这里可以添加Xray SOCKS5的安装脚本
    bash -c "$(curl -s -L https://raw.githubusercontent.com/q6188011/demo/main/socks5_xray.sh)"
}

SingboxSocks5() {
    clear
    echo "正在安装Singbox SOCKS5代理..."
    # 这里可以添加Singbox SOCKS5的安装脚本
    bash -c "$(curl -s -L https://raw.githubusercontent.com/q6188011/demo/main/socks5_singbox.sh)"
}


menu() {
    clear
    echo "##################################################################"
    echo -e "#                   ${RED}SOCKS5代理一键安装脚本${PLAIN}                                #"
    echo "##################################################################"

    echo -e "  ${GREEN}  <请选择SOCKS5代理实现方式>  ${YELLOW}"	
    echo -e "  ${GREEN}1.${PLAIN}  Xray版SOCKS5代理"
    echo -e "  ${GREEN}2.${PLAIN}  Singbox版SOCKS5代理"
    echo " -------------"
    echo -e "  ${GREEN}0.${PLAIN}   退出"
    echo 

    read -p " 请选择操作[0-2]：" answer
    case $answer in
        0)
            exit 0
            ;;
        1)
            XraySocks5
            ;;
        2)
	        SingboxSocks5
            ;;
        *)
            echo " 请选择正确的操作！"
            exit 1
            ;;
    esac
}

menu
