#!/bin/bash
#************************************************************/
#** File:         init-head.sh                              */
#** Contents:     Contains shell script to install          */
#**               packages such as vnc in head node.        */
#************************************************************/
time_begin=`date`
echo "$0: Script execution begins: $time_begin"


grep ubuntu /etc/sudoers || echo "ubuntu  ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers


apt-get update
apt-get install -y --no-install-recommends lubuntu-desktop
#apt-get install -y vino dconf-editor
apt-get install -y bridge-utils vim sshpass
apt-get install -y vnc4server

sed -i -e 's/em1/eth0/' /etc/network/interfaces
sed -i -e 's/eno1/eth0/' /etc/network/interfaces
sed -i -e 's/GRUB_TIMEOUT=10/GRUB_TIMEOUT=0/' /etc/default/grub
sed -i -e 's/DEFAULT=""/DEFAULT="net.ifnames=1 biosdevname=0"/' /etc/default/grub
sed -i -e 's/DEFAULT="quiet splash"/DEFAULT="net.ifnames=0 biosdevname=0"/' /etc/default/grub

echo "auto eth1" >> /etc/network/interfaces
echo "iface eth1 inet manual" >> /etc/network/interfaces
echo "        up ip link set dev \$IFACE up" >> /etc/network/interfaces
echo "        down ip link set dev \$IFACE down" >> /etc/network/interfaces
echo "auto eth2" >> /etc/network/interfaces
echo "iface eth2 inet manual" >> /etc/network/interfaces
echo "        up ip link set dev \$IFACE up" >> /etc/network/interfaces
echo "        down ip link set dev \$IFACE down" >> /etc/network/interfaces
echo "auto eth3" >> /etc/network/interfaces
echo "iface eth3 inet manual" >> /etc/network/interfaces
echo "        up ip link set dev \$IFACE up" >> /etc/network/interfaces
echo "        down ip link set dev \$IFACE down" >> /etc/network/interfaces

echo "[SeatDefaults]" > /etc/lightdm/lightdm.conf.d/20-lubuntu.conf
echo "user-session=Lubuntu" >> /etc/lightdm/lightdm.conf.d/20-lubuntu.conf
echo "autologin-user=ubuntu" >> /etc/lightdm/lightdm.conf.d/20-lubuntu.conf
echo "autologin-user-timeout=0" >> /etc/lightdm/lightdm.conf.d/20-lubuntu.conf
echo "greeter-session=lightdm-gtk-greeter" >> /etc/lightdm/lightdm.conf.d/20-lubuntu.conf
echo "[SeatDefaults]" > /etc/lightdm/lightdm-gtk-greeter.conf.d/30-lubuntu.conf
echo "user-session=Lubuntu" >> /etc/lightdm/lightdm-gtk-greeter.conf.d/30-lubuntu.conf
echo "autologin-user=ubuntu" >> /etc/lightdm/lightdm-gtk-greeter.conf.d/30-lubuntu.conf
echo "autologin-user-timeout=0" >> /etc/lightdm/lightdm-gtk-greeter.conf.d/30-lubuntu.conf
echo "greeter-session=lightdm-gtk-greeter" >> /etc/lightdm/lightdm-gtk-greeter.conf.d/30-lubuntu.conf

update-grub
#vncserver

time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"
echo "Rebooting the server in 30 seconds...."
sleep 30
reboot

