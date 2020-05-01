#!/usr/bin/env bash

BR_NAME="lxcbr0"
BR_IP="10.0.3.1/24"
CONTAINER_NAME="my-container"

# Create temp apt sources for install lxc
sudo cat <<< '
deb http://deb.debian.org/debian buster main
deb-src http://deb.debian.org/debian buster main ' > /etc/apt/sources.list.d/mysource.list

sudo apt-get update
sudo apt-get -y install lxc xz-utils

# Delete temp apt sources
sudo rm -f /etc/apt/sources.list.d/mysource.list

# Add bridge with ip-address to communicate with lxc container
sudo brctl addbr $BR_NAME
sudo ifconfig $BR_NAME $BR_IP

sudo mkdir -p /etc/lxc/.config/lxc

# Config for container
sudo bash -c "cat > /etc/lxc/.config/lxc/default.conf << EOF
lxc.net.0.type = veth
lxc.net.0.link = ${BR_NAME}
lxc.net.0.flags = up
lxc.apparmor.profile = generated
lxc.apparmor.allow_nesting = 1
lxc.idmap = u 0 100000 65536
lxc.idmap = g 0 100000 65536
EOF
"
# Create lxc container "Alpine"
sudo lxc-create -f /etc/lxc/.config/lxc/default.conf --template download --name my-container -- --dist alpine --release 3.10 --arch amd64

# Start lxc container
sudo lxc-start -n $CONTAINER_NAME -d


