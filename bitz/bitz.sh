#!/bin/bash
# 检查是否有命令行参数，如果有则使用第一个参数作为钱包地址，否则使用默认地址
[ -n "$1" ] && WALLET_ADDR="$1" || WALLET_ADDR="91zhskKTwgKFiLuJSJ6GiwgKRo7g6XgDjjRXbsWSShue"
# 设置安装目录和服务名称
INSTALL_DIR="/opt/bitz"
SERVICE_NAME="bitz"

# 检查是否以root用户运行
if [ "$(id -u)" -ne 0 ]; then
    echo "错误：此脚本需要以root用户运行" >&2
    exit 1
fi

# 检查系统是否安装wget工具，如果没有则更新软件源并安装
if ! command -v wget &> /dev/null; then
    echo "正在安装wget..."
    apt-get update && apt-get install -y wget || {
        echo "错误：无法安装wget" >&2
        exit 1
    }
fi

# 创建安装目录（如果不存在）
mkdir -p "$INSTALL_DIR" || {
    echo "错误：无法创建目录 $INSTALL_DIR" >&2
    exit 1
}

# 删除旧的客户端程序（如果存在）
[ -f "$INSTALL_DIR/OrionClient" ] && rm -f "$INSTALL_DIR/OrionClient"

# 切换到安装目录
cd "$INSTALL_DIR" || {
    echo "错误：无法切换到目录 $INSTALL_DIR" >&2
    exit 1
}

# 从GitHub下载OrionClient挖矿程序并解压到安装目录
echo "正在下载OrionClient..."
wget -qO- https://github.com/egg5233/OrionClient_tw/releases/download/1.6.0/OrionClient.tar.gz | tar -zxf - -C "$INSTALL_DIR" --strip-components=1 || {
    echo "错误：下载或解压OrionClient失败" >&2
    exit 1
}

# 验证下载是否成功
if [ ! -f "$INSTALL_DIR/OrionClient" ]; then
    echo "错误：OrionClient未正确下载" >&2
    exit 1
fi

# 添加执行权限
chmod +x "$INSTALL_DIR/OrionClient"

# 创建启动脚本
echo "#!/bin/bash" > "$INSTALL_DIR/start.sh"
echo "set -euo pipefail" >> "$INSTALL_DIR/start.sh"  # 启用严格模式
echo "echo \"尝试获取公网IP...\"" >> "$INSTALL_DIR/start.sh"

# 修改IP获取逻辑，使用https://checkip.amazonaws.com
cat >> "$INSTALL_DIR/start.sh" <<'EOF'
# 尝试从通用服务获取公网IP
ip=$(wget -T 5 -t 3 -qO- https://checkip.amazonaws.com 2>/dev/null | tr -d '\n' || :)

if [ -z "$ip" ]; then
    echo "警告：无法获取公网IP，使用默认矿工名"
    minerAlias="unknown-worker"
else
    # 验证获取的IP格式是否正确
    if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "警告：获取的IP格式不正确 ($ip)，使用默认矿工名"
        minerAlias="unknown-worker"
    else
        # 使用FKAWS关键字进行IP地址加密
        encrypt_ip_with_fkaws() {
            local ip=$1
            local keyword="FKAWS"
            local result=""
            local key_index=0
            
            # 遍历IP地址的每个字符
            for (( i=0; i<${#ip}; i++ )); do
                char="${ip:$i:1}"
                
                if [[ "$char" =~ [0-9] ]]; then
                    # 对数字进行加密：数字 + 关键字字符的ASCII值
                    key_char="${keyword:$((key_index % ${#keyword})):1}"
                    # 将关键字字符转换为数字（A=1, B=2, ...）
                    case "$key_char" in
                        "F") key_val=6 ;;
                        "K") key_val=11 ;;
                        "A") key_val=1 ;;
                        "W") key_val=23 ;;
                        "S") key_val=19 ;;
                    esac
                    # 进行简单的数字偏移加密
                    encrypted_digit=$(( (char + key_val) % 10 ))
                    result+="$encrypted_digit"
                    key_index=$((key_index + 1))
                elif [[ "$char" == "." ]]; then
                    # 点号替换为关键字字符
                    key_char="${keyword:$((key_index % ${#keyword})):1}"
                    result+="$key_char"
                    key_index=$((key_index + 1))
                else
                    # 其他字符保持不变
                    result+="$char"
                fi
            done
            
            echo "$result"
        }

        # 生成矿工别名
        minerAlias=$(encrypt_ip_with_fkaws "$ip")
        echo "使用矿工别名: $minerAlias"
    fi
fi

EOF

# 追加启动挖矿程序的命令到启动脚本
echo "$INSTALL_DIR/OrionClient mine -a --pool twbitz --key '$WALLET_ADDR' --worker \"\$minerAlias\"" >> "$INSTALL_DIR/start.sh"

# 添加错误处理
echo "echo \"启动挖矿程序: $INSTALL_DIR/OrionClient mine -a --pool twbitz --key '$WALLET_ADDR' --worker \$minerAlias\"" >> "$INSTALL_DIR/start.sh"
echo "$INSTALL_DIR/OrionClient mine -a --pool twbitz --key '$WALLET_ADDR' --worker \"\$minerAlias\" || { echo \"错误：挖矿程序启动失败\"; exit 1; }" >> "$INSTALL_DIR/start.sh"

# 给启动脚本添加可执行权限
chmod +x "$INSTALL_DIR/start.sh"

# 创建systemd服务配置文件
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=BITZ Mining Pool Worker
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/start.sh
Restart=always
RestartSec=30
StandardOutput=syslog
StandardError=syslog
Environment="LD_LIBRARY_PATH=$INSTALL_DIR"
# 增加启动前检查
ExecStartPre=/bin/sh -c '[ -x "$INSTALL_DIR/OrionClient" ] || { echo "错误：OrionClient可执行文件不存在"; exit 1; }'

[Install]
WantedBy=multi-user.target
EOF

echo "重新加载systemd配置..."
systemctl daemon-reload || {
    echo "错误：重新加载systemd配置失败" >&2
    exit 1
}

echo "启用并启动$SERVICE_NAME服务..."
systemctl enable "$SERVICE_NAME" || echo "警告：无法设置$SERVICE_NAME服务开机自启"
systemctl restart "$SERVICE_NAME" || {
    echo "错误：启动$SERVICE_NAME服务失败" >&2
    echo "请检查服务状态：systemctl status $SERVICE_NAME" >&2
    echo "查看日志：journalctl -u $SERVICE_NAME -f" >&2
    exit 1
}

echo "安装完成！BITZ挖矿服务已启动。"
echo "检查服务状态：systemctl status $SERVICE_NAME"
echo "查看服务日志：journalctl -u $SERVICE_NAME -f"