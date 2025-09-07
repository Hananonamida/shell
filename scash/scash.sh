#!/bin/bash


set -e

echo "========== scash 自动安装并注册为服务 =========="

# 移除已存在的服务和文件
echo "检查并移除已存在的 scash 服务..."
if systemctl is-active --quiet scash 2>/dev/null; then
    echo "停止 scash 服务..."
    systemctl stop scash
fi

if systemctl is-enabled --quiet scash 2>/dev/null; then
    echo "禁用 scash 服务..."
    systemctl disable scash
fi

if [ -f "/etc/systemd/system/scash.service" ]; then
    echo "删除 scash 服务文件..."
    rm -f /etc/systemd/system/scash.service
    systemctl daemon-reload
fi

if [ -d "/opt/scash" ]; then
    echo "删除旧的安装目录..."
    rm -rf /opt/scash
fi

echo "清理完成，开始重新安装..."

ADDRESS="scash1q697fg7ep6pywua3s3a7e9ze2qmpwfh98d5jmgj"
INSTALL_DIR="/opt/scash"
SERVICE_FILE="/etc/systemd/system/scash.service"
POOL="na.rplant.xyz:17019"

if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"/*
else
    mkdir -p "$INSTALL_DIR"
fi

# 安装依赖
echo "安装必要组件..."
apt update
apt install -y wget tar jq

# 下载
echo "下载 scash..."
DOWNLOAD_URL="https://github.com/doktor83/SRBMiner-Multi/releases/download/2.9.7/SRBMiner-Multi-2-9-7-Linux.tar.gz"
wget -qO- "$DOWNLOAD_URL" | tar -zxf - -C "$INSTALL_DIR" --strip-components=1


# 写入 run.sh
cat > "$INSTALL_DIR/run.sh" <<EOF
#!/bin/bash

ip=\$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4)

if [ -z "\$ip" ]; then
    echo "警告：无法获取公网IP，使用默认矿工名"
    minerAlias="unknown-worker"
else
    # 验证获取的IP格式是否正确
    if [[ ! "\$ip" =~ ^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+\$ ]]; then
        echo "警告：获取的IP格式不正确 (\$ip)，使用默认矿工名"
        minerAlias="unknown-worker"
    else
        # 使用FKAWS关键字进行IP地址加密
        encrypt_ip_with_fkaws() {
            local ip=\$1
            local keyword="FKAWS"
            local result=""
            local key_index=0
            
            # 遍历IP地址的每个字符
            for (( i=0; i<\${#ip}; i++ )); do
                char="\${ip:\$i:1}"
                
                if [[ "\$char" =~ [0-9] ]]; then
                    # 对数字进行加密：数字 + 关键字字符的ASCII值
                    key_char="\${keyword:\$((key_index % \${#keyword})):1}"
                    # 将关键字字符转换为数字（A=1, B=2, ...）
                    case "\$key_char" in
                        "F") key_val=6 ;;
                        "K") key_val=11 ;;
                        "A") key_val=1 ;;
                        "W") key_val=23 ;;
                        "S") key_val=19 ;;
                    esac
                    # 进行简单的数字偏移加密
                    encrypted_digit=\$(( (char + key_val) % 10 ))
                    result+="\$encrypted_digit"
                    key_index=\$((key_index + 1))
                elif [[ "\$char" == "." ]]; then
                    # 点号替换为关键字字符
                    key_char="\${keyword:\$((key_index % \${#keyword})):1}"
                    result+="\$key_char"
                    key_index=\$((key_index + 1))
                else
                    # 其他字符保持不变
                    result+="\$char"
                fi
            done
            
            echo "\$result"
        }

        # 生成矿工别名
        minerAlias=\$(encrypt_ip_with_fkaws "\$ip")
        echo "使用矿工别名: \$minerAlias"
    fi
fi
exec ${INSTALL_DIR}/SRBMiner-MULTI --algorithm randomscash --pool $POOL --tls true --wallet $ADDRESS.\$minerAlias --enable-large-pages

EOF

chmod +x "$INSTALL_DIR/run.sh"

# 写入 systemd 服务
tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Scash Miner
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/run.sh
Restart=always
RestartSec=30
Environment="LD_LIBRARY_PATH=$INSTALL_DIR"

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
echo "启用并启动 scash 服务..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable scash
systemctl restart scash