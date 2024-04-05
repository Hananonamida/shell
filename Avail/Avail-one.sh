#!/bin/bash

# 函数：检查命令是否存在
exists() {
  command -v "$1" >/dev/null 2>&1
}

# 函数：安装依赖项（如果不存在）
install_dependency() {
  exists "$1" || sudo apt update && sudo apt install "$1" -y < "/dev/null"
}

# 检查参数数量
if [ "$#" -ne 12 ]; then
  echo "需要传入12个参数作为钱包助记词。"
  exit 1
fi

# 安装必要的依赖项
install_dependency curl
install_dependency make
install_dependency clang
install_dependency pkg-config
install_dependency libssl-dev
install_dependency build-essential

# 设置安装目录和发布 URL
INSTALL_DIR="${HOME}/avail-light"
RELEASE_URL="https://github.com/availproject/avail-light/releases/download/v1.7.10/avail-light-linux-amd64.tar.gz"

# 创建安装目录并进入
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit

# 下载并解压发布包
wget "$RELEASE_URL" -O avail-light.tar.gz
tar -xvzf avail-light.tar.gz
cp avail-light-linux-amd64 avail-light

# 创建identity.toml文件
SECRET_SEED_PHRASE="$*"
cat > identity.toml <<EOF
avail_secret_seed_phrase = "$SECRET_SEED_PHRASE"
EOF

# 配置 systemd 服务文件
tee /etc/systemd/system/availd.service > /dev/null << EOF
[Unit]
Description=Avail Light Client
After=network.target
StartLimitIntervalSec=0
[Service]
User=root
ExecStart=/root/avail-light/avail-light --network goldberg --identity /root/avail-light/identity.toml
Restart=always
RestartSec=120
[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 并启用并启动服务
sudo systemctl daemon-reload
sudo systemctl enable availd
sudo systemctl start availd.service

# 增加5s延迟
sleep 5

# 输出Avail运行钱包地址
journalctl -u availd | grep address