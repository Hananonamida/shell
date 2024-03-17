#!/bin/bash

# 检查是否提供了身份码参数
if [ $# -eq 0 ]; then
    echo "请提供身份码作为参数。"
    exit 1
fi

# 获取传入的身份码参数
id=$1

apt update

# 检查 Docker 是否已安装
if ! command -v docker &> /dev/null
then
    # 如果 Docker 未安装，则进行安装
    echo "未检测到 Docker，正在安装..."
    sudo apt-get install ca-certificates curl gnupg lsb-release

    # 安装 Docker 最新版本
    sudo apt-get install docker.io -y
else
    echo "Docker 已安装。"
fi

# 拉取Docker镜像
docker pull nezha123/titan-edge:1.1

# 创建5个容器
for i in {1..5}
do
    # 为每个容器创建一个存储卷
    storage="titan_storage_$i"
    mkdir -p "$storage"

    # 运行容器，并设置重启策略为always
    container_id=$(docker run -d --restart always -v "$PWD/$storage:/root/.titanedge/storage" --name "titan$i" nezha123/titan-edge:1.1)

    echo "Container titan$i started with ID $container_id"

    sleep 15

    # 进入容器并执行绑定和其他命令
    docker exec -it $container_id bash -c "\
        titan-edge bind --hash=$id https://api-test1.container1.titannet.io/api/v2/device/binding"
done

echo "==============================所有容器均已设置并启动==================================="
