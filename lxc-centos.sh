#!/usr/bin/env bash

BR_NAME="br999"
BR_IP="10.0.3.1/24"
CONTAINER_NAME="c2"

# Create temp apt sources for install lxc
sudo cat <<< '
deb http://deb.debian.org/debian buster main
deb-src http://deb.debian.org/debian buster main ' > /etc/apt/sources.list.d/mysource.list

sudo apt-get update
sudo apt-get -y install lxc xz-utils
# If you want to create containers other than alpine
sudo apt-get -y install lxc-templates debootstrap

# For CentOS
sudo apt-get -y install yum

# Delete temp apt sources
sudo rm -f /etc/apt/sources.list.d/mysource.list

# Check if bridge is exists
sudo brctl show $BR_NAME > /dev/null

if [ $? -eq 1 ]; then
    # Add bridge
    sudo brctl addbr $BR_NAME
else
    echo "bridge [$BR_NAME] is exists."
fi

sudo ip link set dev $BR_NAME up
sudo ip addr add dev $BR_NAME $BR_IP

sudo mkdir -p /etc/lxc/.config/lxc

# Config for container
sudo bash -c "cat > /etc/lxc/.config/lxc/default.conf << EOF
lxc.net.0.type = veth
lxc.net.0.link = ${BR_NAME}
lxc.net.0.flags = up
lxc.net.0.name = eth1
lxc.net.0.ipv4.address = 10.0.3.2/24
lxc.net.0.ipv4.gateway = 10.0.3.1
lxc.apparmor.profile = generated
lxc.apparmor.allow_nesting = 1
#lxc.idmap = u 0 100000 65536
#lxc.idmap = g 0 100000 65536
#lxc.start.auto = 1   # Autostart
EOF
"

# Create lxc Centos 7 container
sudo lxc-create -f /etc/lxc/.config/lxc/default.conf -t /usr/share/lxc/templates/lxc-centos -n ${CONTAINER_NAME} -- -R 7 -a x86_64
#sudo lxc-create -f /etc/lxc/.config/lxc/default.conf -t /usr/share/lxc/templates/lxc-centos -n ${CONTAINER_NAME}

# Start lxc container
sudo lxc-start -n ${CONTAINER_NAME} -d

# Additionat SNAT rules for VyOS. Replace interface and network for your installation.

echo "
# SNAT rules for VyOS
set nat source rule 100 description 'Internet for containers'
set nat source rule 100 outbound-interface 'eth0'
set nat source rule 100 source address '10.0.3.0/24'
set nat source rule 100 translation address 'masquerade'
"
