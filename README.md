# containers-in-vyos

# Get shell inside container
lxc-attach -n my-container

# Show containers
lxc-ls -f

# stop container
lxc-stop -n my-container

# Remove container
lxc-destroy -n my-container

### in Alpne

setup-interfaces

rc-service networkg start

echo "nameserver 1.1.1.1" > /etc/resolv.conf

apk add git

