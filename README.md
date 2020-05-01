# containers-in-vyos

Copy create-lxc.sh to Vyos1.3 tmp dir and execute

chmod +x /tmp/create-lxc.sh

/tmp/create-lxc.sh

### Show containers
lxc-ls -f

### Get shell inside container
lxc-attach -n my-container

### Stop container
lxc-stop -n my-container

### Remove container
lxc-destroy -n my-container

### in Alpne

setup-interfaces

rc-service networkg restart

echo "nameserver 1.1.1.1" > /etc/resolv.conf

apk add git

