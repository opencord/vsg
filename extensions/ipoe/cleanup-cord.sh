#!/bin/bash
#************************************************************/
#** File:         cleanup-cord.sh                          */
#** Contents:     Contains shell script to cleanup a CORD  */
#**               installation.                             */
#************************************************************/
time_begin=`date`
echo "$0: Script execution begins: $time_begin"

if [ -z "$IPOE_SETUP_DIR" ]; then
  IPOE_SETUP_DIR=/home/ubuntu/ipoe/ipoe-setup
  echo "Using $IPOE_SETUP_DIR as ipoe-setup dir"
fi

echo "Execution of this script will completely destroy cord environment"
read -p "Do you want to continue? Enter Yes or No : " resp
resp_nocase=`echo $resp|tr "[:upper:]" "[:lower:]"`
echo "Translated input $resp_nocase"
if [ "$resp_nocase" != "yes" ]; then
    echo "Cord environment not cleanedup...."
    exit 0
fi

if [ -d /home/ubuntu/cord/build ]; then
   export VAGRANT_CWD=/home/ubuntu/cord/build/scenarios/cord
   cd /home/ubuntu/cord/build
   echo "Vagrant status...."
   vagrant status
   echo "Destroying vagrant machines..."
   vagrant destroy
   vagrant status
else
   echo "WARNING:...Cord directory not found"
fi

ipoe_server=`sudo virsh list --all|grep ipoe-server`
if [ ! -z "$ipoe_server" ]; then
   echo "Cleaning up ipoe-server VM"
   sudo virsh destroy ipoe-server
   sleep 1
   sudo virsh undefine ipoe-server
fi  
sleep 1
echo "Check whether any VM is still present"

numx=`sudo virsh list --all|wc |awk '{ print $1 }'`
if [ "$numx" -gt 3 ]; then
  echo "Some VMs are still active.."
  echo "Error: VM clean up not successful..."
  exit 1
fi

echo "Check whether any network other default is still present"
nwks=`sudo virsh net-list --all |grep -v default |wc |awk '{ print $1 }'`
if [ "$numx" -gt 3 ]; then
  echo "Some virsh network is still active.."
  echo "Error: Virsh network clean up not successful..."
  exit 1
fi

echo "Removing Vagrant executable"
vag=`which vagrant`
if [ ! -z "$vag" ]; then
   sudo rm -f $vag
fi
repo_exec=`which repo_exec` 
if [ ! -z "$repo_exec" ]; then
   sudo rm -f $repo_exec
fi
echo "Purging and cleaning up libvirtd and other packages used by cord"
sudo apt-get remove qemu-kvm libvirt-bin libvirt-dev nfs-kernel-server -y
sleep 1
sudo apt-get purge qemu-kvm libvirt-bin libvirt-dev nfs-kernel-server -y
sudo rm -rf /var/lib/libvirt
sudo rm -rf /var/run/libvirt
echo "Cleaning up relevant subdirectories stored under /home/ubuntu"
sudo rm -rf /home/ubuntu/.vagrant.d
sudo rm -rf /home/ubuntu/.repoconfig
sudo rm -f /home/ubuntu/.repo_.gitconfig.json
sudo rm -rf /home/ubuntu/.virtinst
echo "Cleaning up the bridges"
sudo ifconfig ipoe-headbr down && sudo brctl delbr ipoe-headbr
sudo ifconfig nni-uplinkbr down && sudo brctl delbr nni-uplinkbr
sudo ifconfig virbr0 down && sudo brctl delbr virbr0
sudo ifconfig virbr1 down && sudo brctl delbr virbr1
sudo ifconfig virbr2 down && sudo brctl delbr virbr2
sudo ifconfig virbr3 down && sudo brctl delbr virbr3
echo "Cleaning up iptables entries"
sudo iptables -F INPUT
sudo iptables -F FORWARD
sudo iptables -F OUTPUT
date_suf=`date '+%Y-%m-%d-%H:%M:%S'`
cord_bkp="cord-$date_suf"
echo "Moving cord directory to /home/ubuntu/$cord_bkp"
mv -f /home/ubuntu/cord /home/ubuntu/$cord_bkp
rm -rf /home/ubuntu/cord_profile
sshconfig_bkp="config-$date_suf"
mv -f /home/ubuntu/.ssh/config /home/ubuntu/config/.ssh/$sshconfig_bkp
echo "Cord cleanup is complete..."

time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"

