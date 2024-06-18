#!/bin/bash
sudo apt -q update
sudo apt install git -y
sudo apt install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
apt-cache policy docker-ce
sudo apt install docker-ce

cd ~
git clone https://github.com/QuilibriumNetwork/ceremonyclient.git
cd ~/ceremonyclient
docker build --build-arg GIT_COMMIT=$(git log -1 --format=%h) -t quilibrium -t quilibrium:1.4.18-p2 .

sudo ufw enable
sudo ufw allow 22
sudo ufw allow 8336
sudo ufw allow 443
sudo ufw status

cd ~/ceremonyclient
docker compose up -d
docker ps