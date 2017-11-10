#!/bin/bash
# Magnus Glantz, sudo@redhat.com, 2017
# Prep RHEL 7.4 VM which has been installed via Satellite 6.2 - for Azure

# Configure network
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
ONBOOT=yes
BOOTPROTO=dhcp
TYPE=Ethernet
USERCTL=no
PEERDNS=yes
IPV6INIT=no
NM_CONTROLLED=no
EOF

cat << EOF > /etc/sysconfig/network
NETWORKING=yes
HOSTNAME=localhost.localdomain
EOF

chkconfig network on

yum -t -y -e 0 update

# Enable extras repo
subscription-manager repos --enable=rhel-7-server-extras-rpms

# Install WALinuxAgent
yum install -y WALinuxAgent

# Unregister Red Hat subscription
subscription-manager unregister

# Enable waaagent at boot-up
systemctl enable waagent

# Disable the root account
passwd -l root

# Configure swap in WALinuxAgent
sed -i 's/^\(ResourceDisk\.EnableSwap\)=[Nn]$/\1=y/g' /etc/waagent.conf
sed -i 's/^\(ResourceDisk\.SwapSizeMB\)=[0-9]*$/\1=2048/g' /etc/waagent.conf

# Set the cmdline
sed -i 's/^\(GRUB_CMDLINE_LINUX\)=".*"$/\1="net.ifnames=0 biosdevname=0 console=tty1 console=ttyS0 earlyprintk=ttyS0 rootdelay=300"/g' /etc/default/grub

# Enable SSH keepalive
sed -i 's/^#\(ClientAliveInterval\).*$/\1 180/g' /etc/ssh/sshd_config

# Build the grub cfg
grub2-mkconfig -o /boot/grub2/grub.cfg

#update local time
echo "updating system time"
/usr/sbin/hwclock --systohc

hostnamectl set-hostname localhost.localdomain

# Add Hyper-V drivers
echo 'add_drivers+=”hv_vmbus hv_netvsc hv_storvsc”' >>/etc/dracut.conf
dracut –f -v

# Remove Satellite junk
yum -y remove python-gofer gofer qpid-proton-c python-qpid-proton python-gofer-proton katello-host-tools-fact-plugin katello-host-tools python-isodate python-pulp-common python-pulp-agent-lib python-pulp-rpm-common pulp-rpm-handlers katello-agent

# Remove old interfaces
rm -f /etc/sysconfig/network-script/ifcfg-en*

# Disable swap
grep -v /etc/fstab >/etc/fstab.fix
mv /etc/fstab.fix /etc/fstab
swapoff -a

# Deprovision and prepare for Azure
waagent -force -deprovision
