generate_socks_subscription() {
    # 获取当前配置
    config_file="/etc/xrayL/config.toml"
    
    if [ ! -f "$config_file" ]; then
        echo "错误：未找到Xray配置文件"
        return 1
    fi

    # 提取配置信息
    socks_info=$(grep -A10 "protocol = \"socks\"" "$config_file" | grep -E "port|user|pass|ip")
    
    # 检查是否配置了socks
    if [ -z "$socks_info" ]; then
        echo "错误：未找到Socks5配置"
        return 1
    fi

    # 处理多IP情况
    echo "以下是Socks5订阅链接："
    echo "----------------------------------"
    
    # 使用awk解析配置并生成链接
    awk -F'"' '
    /port =/ {port=$2}
    /user =/ {user=$2}
    /pass =/ {pass=$2}
    /ip =/ {
        ip=$2
        if (port && user && pass && ip) {
            printf "socks5://%s:%s@%s:%d\n", user, pass, ip, port
            port=user=pass=ip=""
        }
    }
    ' "$config_file"
    
    echo "----------------------------------"
    echo "注意：请妥善保管这些链接"
}
