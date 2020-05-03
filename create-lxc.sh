#!/usr/bin/env bash

BR_NAME="lxcbr0"
BR_IP="10.0.3.1/24"
CONTAINER_NAME="my-container"
CONTAINER_ROOT_PASS="superpass"

# Create temp apt sources for install lxc
sudo cat <<< '
deb http://deb.debian.org/debian buster main
deb-src http://deb.debian.org/debian buster main ' > /etc/apt/sources.list.d/mysource.list

sudo apt-get update
sudo apt-get -y install lxc xz-utils

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

sudo ifconfig $BR_NAME $BR_IP

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
lxc.idmap = u 0 100000 65536
lxc.idmap = g 0 100000 65536
#lxc.start.auto = 1   # Autostart
EOF
"
# Create lxc container "Alpine"
sudo lxc-create -f /etc/lxc/.config/lxc/default.conf --template download --name my-container -- --dist alpine --release 3.10 --arch amd64

# Start lxc container
sudo lxc-start -n $CONTAINER_NAME -d

# Post-install
sudo lxc-attach -n $CONTAINER_NAME -- /bin/ash -c "echo \"nameserver 1.1.1.1\" > /etc/resolv.conf"
sudo lxc-attach -n $CONTAINER_NAME -- /bin/ash -c "apk add nano openssh"
sudo lxc-attach -n $CONTAINER_NAME -- /bin/ash -c "echo \"PermitRootLogin yes\" >> /etc/ssh/sshd_config"
sudo lxc-attach -n $CONTAINER_NAME -- /bin/ash -c "echo root:$CONTAINER_ROOT_PASS | chpasswd" # Root password for ssh container
sudo lxc-attach -n $CONTAINER_NAME -- /bin/ash -c "ssh-keygen -t rsa -f /root/.ssh/id_rsa -q -P \"\"" # Generate ssh key
sudo lxc-attach -n $CONTAINER_NAME -- /bin/ash -c "service sshd start"
