generate_proxy_links() {
    local config_type=$1
    local config_file="/etc/xrayL/config.toml"
    
    if [ ! -f "$config_file" ]; then
        echo "错误：配置文件 $config_file 不存在"
        return 1
    fi

    echo -e "\n${GREEN}====== 代理链接信息 ======${PLAIN}"
    
    if [ "$config_type" == "socks" ]; then
        # 提取SOCKS配置信息
        local socks_user=$(grep -A1 "user = " $config_file | head -n1 | cut -d'"' -f2)
        local socks_pass=$(grep -A1 "pass = " $config_file | head -n1 | cut -d'"' -f2)
        local ports=($(grep "port = " $config_file | awk '{print $3}'))
        
        for port in "${ports[@]}"; do
            for ip in "${IP_ADDRESSES[@]}"; do
                if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    echo "socks5://${socks_user}:${socks_pass}@${ip}:${port}"
                else
                    echo "socks5://${socks_user}:${socks_pass}@[${ip}]:${port}"
                fi
            done
        done
        
    elif [ "$config_type" == "vmess" ]; then
        # 提取VMess配置信息
        local uuid=$(grep -A1 "id = " $config_file | head -n1 | cut -d'"' -f2)
        local ws_path=$(grep "path = " $config_file | cut -d'"' -f2)
        local ports=($(grep "port = " $config_file | awk '{print $3}'))
        
        for port in "${ports[@]}"; do
            for ip in "${IP_ADDRESSES[@]}"; do
                local vmess_json=$(cat <<EOF
{
    "v": "2",
    "ps": "XrayL_${ip}_${port}",
    "add": "${ip}",
    "port": "${port}",
    "id": "${uuid}",
    "aid": "0",
    "scy": "auto",
    "net": "ws",
    "type": "none",
    "host": "",
    "path": "${ws_path}",
    "tls": "",
    "sni": "",
    "alpn": ""
}
EOF
                )
                echo "vmess://$(echo "$vmess_json" | base64 -w 0)"
            done
        done
    fi
    
    echo -e "${GREEN}========================${PLAIN}\n"
}
