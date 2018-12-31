#!/bin/bash

PUBLIC_IP=$(curl http://169.254.169.254/v1/interfaces/0/ipv4/address)
PRIVATE_IP=10.99.0.5
SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAg3u04QBLFNJz6zEKJUQCk7ORHATz0K4sZI2a9fFP61yFd040PpSO+c0IyQTqankfR9ahb/TXYI/fu2ijPlH3wsZxmT9+VjivJNSz6YquTQE/jIAfOw4DrDwz6OhA3/K+V7lsxFjpZ7TiwM4FAxEu4TSDUnopryaD0i51+CvcKASnMJb8S4pplR1geT61ISLEhoo2ekSYDDjXp0X1zsJKJsF5lbfxAKoID1xgauqoSSMFNPGD2xVM3hrOUlJA2gj1EUzV3hEzgQQY/RDYZWWXy15s9FtObRF/AehE3aB/fzbni2s61xNKY9VavmN+3+w1XYp/paQTyDXnj9uitHKN4w== rsa-key-20170909"

#Run updates and upgrades
apt-get update
apt-get -y upgrade

#Create thor account and add public key
useradd -c "thor" -m thor
echo "thor:TEMPPASS123" | chpasswd
usermod -aG sudo thor
usermod -s /bin/bash thor
mkdir /home/thor/.ssh
touch /home/thor/.ssh/authorized_keys
chmod 644 /home/thor/.ssh/authorized_keys
echo $SSH_PUBLIC_KEY > /home/thor/.ssh/authorized_keys

#Disable root login and password authentication
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

#Restart ssh
service ssh restart

#Configure the private interface
cat << EOF >> /etc/network/interfaces
iface ens7 inet static
address $PRIVATE_IP
netmask 255.255.0.0
mtu 1450
EOF

#Start the private interface
ifup ens7

#Install and configure nfs server
apt-get -y install nfs-kernel-server
mkdir /docker_storage
chown -R nobody:nogroup /docker_storage
echo "/docker_storage 10.99.0.0/24(rw,sync,no_subtree_check)" >> /etc/exports
systemctl start nfs-server.service
