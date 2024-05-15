#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 获取传入的参数
l1_proposer_private_key=$1
l2_suggested_fee_recipient=$2
l1_endpoint=$3

#安装Taiko节点------------------------------
# 更新系统包列表
sudo apt update
# 检查 Git 是否已安装
if ! command -v git &> /dev/null
then
    # 如果 Git 未安装，则进行安装
    echo "未检测到 Git，正在安装..."
    sudo apt install git -y
else
    # 如果 Git 已安装，则不做任何操作
    echo "Git 已安装。"
fi

# 克隆 Taiko 仓库
git clone https://github.com/taikoxyz/simple-taiko-node.git

# 进入 Taiko 目录
cd simple-taiko-node

# 如果不存在.env文件，则从示例创建一个
if [ ! -f .env ]; then
  cp .env.sample .env
fi

# 提示用户输入环境变量的值
l1_endpoint_http="http://$l1_endpoint:8545"
l1_endpoint_ws="ws://$l1_endpoint:8546"
l1_beacon_http="http://unstable.holesky.beacon-api.nimbus.team"
prover_endpoints="http://198.244.201.79:9876,https://prover-hekla.taiko.tools,https://prover2-hekla.taiko.tools,http://taiko-a7-prover.zkpool.io,http://146.59.55.26:9876,http://kenz-prover.hekla.kzvn.xyz:9876,http://hekla.stonemac65.xyz:9876,http://51.91.70.42:9876,http://taiko.web3crypt.net:9876,http://148.113.17.127:9876,http://hekla.prover.taiko.coinblitz.pro:9876,http://taiko-testnet.m51nodes.xyz:9876,http://148.113.16.26:9876,http://51.161.118.103:9876,http://162.19.98.173:9876,http://49.13.215.95:9876,http://49.13.143.184:9876,http://49.13.210.192:9876,http://159.69.242.22:9876,http://49.13.69.238:9876,http://taiko.guru:9876,http://taiko.donkamote.xyz:9876"
enable_proposer="true"


# 检测并罗列未被占用的端口
function list_recommended_ports {
    local start_port=8000 # 可以根据需要调整起始搜索端口
    local needed_ports=7
    local count=0
    local ports=()

    while [ "$count" -lt "$needed_ports" ]; do
        if ! ss -tuln | grep -q ":$start_port " ; then
            ports+=($start_port)
            ((count++))
        fi
        ((start_port++))
    done

    echo "推荐的端口如下："
    for port in "${ports[@]}"; do
        echo -e "\033[0;32m$port\033[0m"
    done
}

# 使用推荐端口函数为端口配置
list_recommended_ports
# 提示用户输入端口配置，允许使用默认值
port_l2_execution_engine_http=${port_l2_execution_engine_http:-8547}
port_l2_execution_engine_ws=${port_l2_execution_engine_ws:-8548}
port_l2_execution_engine_metrics=${port_l2_execution_engine_metrics:-6060}
port_l2_execution_engine_p2p=${port_l2_execution_engine_p2p:-30306}
port_prover_server=${port_prover_server:-9876}
port_prometheus=${port_prometheus:-9091}
port_grafana=${port_grafana:-3001}

# 将用户输入的值写入.env文件
sed -i "s|L1_ENDPOINT_HTTP=.*|L1_ENDPOINT_HTTP=${l1_endpoint_http}|" .env
sed -i "s|L1_ENDPOINT_WS=.*|L1_ENDPOINT_WS=${l1_endpoint_ws}|" .env
sed -i "s|L1_BEACON_HTTP=.*|L1_BEACON_HTTP=${l1_beacon_http}|" .env
sed -i "s|ENABLE_PROPOSER=.*|ENABLE_PROPOSER=${enable_proposer}|" .env
sed -i "s|L1_PROPOSER_PRIVATE_KEY=.*|L1_PROPOSER_PRIVATE_KEY=${l1_proposer_private_key}|" .env
sed -i "s|L2_SUGGESTED_FEE_RECIPIENT=.*|L2_SUGGESTED_FEE_RECIPIENT=${l2_suggested_fee_recipient}|" .env
sed -i "s|PROVER_ENDPOINTS=.*|PROVER_ENDPOINTS=${prover_endpoints}|" .env


# 更新.env文件中的端口配置
sed -i "s|PORT_L2_EXECUTION_ENGINE_HTTP=.*|PORT_L2_EXECUTION_ENGINE_HTTP=${port_l2_execution_engine_http}|" .env
sed -i "s|PORT_L2_EXECUTION_ENGINE_WS=.*|PORT_L2_EXECUTION_ENGINE_WS=${port_l2_execution_engine_ws}|" .env
sed -i "s|PORT_L2_EXECUTION_ENGINE_METRICS=.*|PORT_L2_EXECUTION_ENGINE_METRICS=${port_l2_execution_engine_metrics}|" .env
sed -i "s|PORT_L2_EXECUTION_ENGINE_P2P=.*|PORT_L2_EXECUTION_ENGINE_P2P=${port_l2_execution_engine_p2p}|" .env
sed -i "s|PORT_PROVER_SERVER=.*|PORT_PROVER_SERVER=${port_prover_server}|" .env
sed -i "s|PORT_PROMETHEUS=.*|PORT_PROMETHEUS=${port_prometheus}|" .env
sed -i "s|PORT_GRAFANA=.*|PORT_GRAFANA=${port_grafana}|" .env
sed -i "s|BLOCK_PROPOSAL_FEE=.*|BLOCK_PROPOSAL_FEE=30|" .env
sed -i "s|BOOT_NODES=.*|BOOT_NODES=enode://0b310c7dcfcf45ef32dde60fec274af88d52c7f0fb6a7e038b14f5f7bb7d72f3ab96a59328270532a871db988a0bcf57aa9258fa8a80e8e553a7bb5abd77c40d@167.235.249.45:30303,enode://500a10f3a8cfe00689eb9d41331605bf5e746625ac356c24235ff66145c2de454d869563a71efb3d2fb4bc1c1053b84d0ab6deb0a4155e7227188e1a8457b152@85.10.202.253:30303,enode://0b310c7dcfcf45ef32dde60fec274af88d52c7f0fb6a7e038b14f5f7bb7d72f3ab96a59328270532a871db988a0bcf57aa9258fa8a80e8e553a7bb5abd77c40d@167.235.249.45:30303,enode://500a10f3a8cfe00689eb9d41331605bf5e746625ac356c24235ff66145c2de454d869563a71efb3d2fb4bc1c1053b84d0ab6deb0a4155e7227188e1a8457b152@85.10.202.253:30303|" .env

# 用户信息已配置完毕
echo "用户信息已配置完毕。"

# 升级所有已安装的包
sudo apt upgrade -y

# 安装基本组件
sudo apt install pkg-config curl build-essential libssl-dev libclang-dev ufw docker-compose-plugin -y

# 检查 Docker 是否已安装
if ! command -v docker &> /dev/null
then
    # 如果 Docker 未安装，则进行安装
    echo "未检测到 Docker，正在安装..."
    sudo apt-get install ca-certificates curl gnupg lsb-release

    # 添加 Docker 官方 GPG 密钥
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # 设置 Docker 仓库
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 授权 Docker 文件
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    sudo apt-get update

    # 安装 Docker 最新版本
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
else
    echo "Docker 已安装。"
fi

    # 安装 Docker compose 最新版本
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.5.0/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
docker compose version

# 验证 Docker Engine 安装是否成功

# 运行 Taiko 节点
docker compose --profile l2_execution_engine down
docker stop simple-taiko-node-taiko_client_proposer-1 && docker rm simple-taiko-node-taiko_client_proposer-1
docker compose --profile proposer up -d

# 获取公网 IP 地址
public_ip=$(curl -s ifconfig.me)

# 准备原始链接
original_url="LocalHost:${port_grafana}/d/L2ExecutionEngine/l2-execution-engine-overview?orgId=1&refresh=10s"

# 替换 LocalHost 为公网 IP 地址
updated_url=$(echo $original_url | sed "s/LocalHost/$public_ip/")

# 显示更新后的链接
echo "请通过以下链接查询设备运行情况，如果无法访问，请等待2-3分钟后重试：$updated_url"