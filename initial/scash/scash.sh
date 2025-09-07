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
[ -z "\$ip" ] && exit 1

declare -A encrypt_dict=(
    ["0"]="a" ["1"]="b" ["2"]="c" ["3"]="d" ["4"]="e"
    ["5"]="f" ["6"]="g" ["7"]="h" ["8"]="i" ["9"]="j"
    ["."]="k"
)

encrypt_ip() {
    local ip=\$1
    local result=""
    for (( i=0; i<\${#ip}; i++ )); do
        char="\${ip:\$i:1}"
        result+="\${encrypt_dict[\$char]:-\$char}"
    done
    echo "\$result"
}

minerAlias=\$(encrypt_ip "\$ip")
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