export DEBIAN_FRONTEND=noninteractive
apt-get -qq update
apt-get -qq upgrade -y
echo "Installing necessary libraries..."
echo "---------------------------"
apt-get install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y --force-yes make curl git unzip whois
apt-get install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y --force-yes unzip jq
useradd nknx
mkdir -p /home/nknx/.ssh
mkdir -p /home/nknx/.nknx
adduser nknx sudo
chsh -s /bin/bash nknx
PASSWORD=$(mkpasswd -m sha-512 FOegB5vv8mFW)
usermod --password $PASSWORD nknx > /dev/null 2>&1
cd /home/nknx
echo "Installing NKN Commercial..."
echo "---------------------------"
wget --quiet --continue --show-progress https://commercial.nkn.org/downloads/nkn-commercial/linux-amd64.zip > /dev/null 2>&1
unzip -qq linux-amd64.zip
cd linux-amd64
cat >config.json <<EOF
{
    "nkn-node": {
      "args": "--sync light",
      "noRemotePortCheck": true
    }
}
EOF
./nkn-commercial -b NKNDpjQHN6KJRnGEGiQC9qxhaqYiT9rjjYzE -c /home/nknx/linux-amd64/config.json -d /home/nknx/nkn-commercial -u nknx install > /dev/null 2>&1
chown -R nknx:nknx /home/nknx
chmod -R 755 /home/nknx
echo "Waiting for wallet generation..."
echo "---------------------------"
while [ ! -f /home/nknx/nkn-commercial/services/nkn-node/wallet.json ]; do sleep 10; done
echo "Chain download skipped."
echo "---------------------------"
echo "Applying finishing touches..."
echo "---------------------------"
chown -R nknx:nknx /home/nknx
chmod -R 755 /home/nknx
