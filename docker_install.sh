#!/bin/bash

PUBLIC_IP=$(curl http://169.254.169.254/v1/interfaces/0/ipv4/address)
PRIVATE_IP=$(curl http://169.254.169.254/v1/interfaces/1/ipv4/address)
SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAg3u04QBLFNJz6zEKJUQCk7ORHATz0K4sZI2a9fFP61yFd040PpSO+c0IyQTqankfR9ahb/TXYI/fu2ijPlH3wsZxmT9+VjivJNSz6YquTQE/jIAfOw4DrDwz6OhA3/K+V7lsxFjpZ7TiwM4FAxEu4TSDUnopryaD0i51+CvcKASnMJb8S4pplR1geT61ISLEhoo2ekSYDDjXp0X1zsJKJsF5lbfxAKoID1xgauqoSSMFNPGD2xVM3hrOUlJA2gj1EUzV3hEzgQQY/RDYZWWXy15s9FtObRF/AehE3aB/fzbni2s61xNKY9VavmN+3+w1XYp/paQTyDXnj9uitHKN4w== rsa-key-20170909"

#Run updates and upgrades
apt-get update
apt-get -y upgrade

#Create thor account and add public key
useradd -c "thor" -m thor
usermod -aG sudo thor
usermod -s /bin/bash thor
passwd -l thor
mkdir /home/thor/.ssh
touch /home/thor/.ssh/authorized_keys
chmod 644 /home/thor/.ssh/authorized_keys
chown -R thor:thor /home/thor/.ssh
echo $SSH_PUBLIC_KEY > /home/thor/.ssh/authorized_keys

#Disable root login and password authentication
echo "thor ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
passwd -l root

#Restart ssh
service ssh restart

#Configure the private interface
cat << EOF >> /etc/network/interfaces
allow-hotplug ens7
iface ens7 inet static
address $PRIVATE_IP
netmask 255.255.0.0
mtu 1450
EOF

#Start the private interface
ifup ens7

#Install and configure and nfs storage
apt-get -y install nfs-common
mkdir /docker_storage
mount 10.99.0.5:/docker_storage /docker_storage
echo 10.99.0.5:/docker_storage    /docker_storage   nfs auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0 >> /etc/fstab 


#Install Docker
apt-get -y install \
     apt-transport-https \
     ca-certificates \
     curl \
     gnupg2 \
     software-properties-common
     
curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -

add-apt-repository -y \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"
   
apt-get update

apt-get install -y docker-ce
apt-get install -y docker-compose

systemctl enable docker

#Add node as worker to swarm cluster
#docker swarm join --token SWMTKN-1-1ho5t2hwr31ajafu4v9436kms1mura0dvh6g0h60oju8niaxmk-bo3y52od1iws5yndckhiox9d3 10.99.0.10:2377