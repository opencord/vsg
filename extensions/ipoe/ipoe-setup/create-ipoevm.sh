#!/bin/bash
#************************************************************/
#** File:         create-ipoevm.sh                          */
#** Contents:     Contains shell script to create ipoe-server*/
#**               virtual machine.                          */
#************************************************************/
time_begin=`date`
echo "$0: Script execution begins: $time_begin"

function detach_computenode_vm() 
{
   echo "Entering detach_computenode_vm...."
   mac_addr_list=`sudo virsh domiflist $COMPUTENODE_VM_NAME|grep ipoe-headbr|awk '{print $5}'`
   i=0
   echo "Detaching MAC address list: $mac_addr_list"
   if [ ! -z "$mac_addr_list" ]; then
      IFS=' ' read -ra mac_addr <<< $mac_addr_list
      for hwaddr in "${mac_addr[@]}"
      do
         i=$(( i+1 ))
         echo "Detaching HW address[$i]=$hwaddr"
         sudo virsh detach-interface $COMPUTENODE_VM_NAME bridge --mac $hwaddr
      done
   fi
}

if [ -z "$IPOE_SETUP_DIR" ]; then
  IPOE_SETUP_DIR=/home/ubuntu/ipoe/ipoe-setup
  echo "Using $IPOE_SETUP_DIR as ipoe-setup dir"
fi
if [ -z "$vsg_home_dir" ]; then
   vsg_home_dir=/home/ubuntu
   echo "Using $vsg_home_dir as vsg_home_dir"
fi
source $IPOE_SETUP_DIR/wide-dhcp6.vars

## **Updates to this file are now at https://github.com/giovtorres/virt-install-centos **
if [[ $EUID -ne 0 ]]; then
  echo "Please run this script with sudo command"
  exit 0
else 
  echo "Executing the script with EUID Value=$EUID "
fi

# Take one argument from the commandline: VM name
if ! [ $# -eq 1 ]; 
then
   echo "Missing Argument error..."
   echo "Usage: sudo $0 <head-node|vsg-server|ipoe-server|onusim-server[-num]|radius-server>"
   echo " head-node option is valid only if CORD_TEST_SETUP is two-node"
   exit 0
else
   VM_NAME=$1
fi
VM_NAME=`echo $VM_NAME| tr '[:upper:]' '[:lower:]'`

if [ "$VM_NAME" == "vsg-server" ] || [ "$VM_NAME" == "ipoe-server" ] \
      || [[ $VM_NAME == "onusim-server"* ]] \
      || [[ $VM_NAME == "head-node" ]] || [ "$VM_NAME" == "radius-server" ] 
then
   echo "Started creating $VM_NAME VM...."
else
   echo "Missing argument or incorrect argument error..."
   echo "Usage: sudo $0 <head-node|vsg-server|ipoe-server|onusim-server[-num]|radius-server>"
   echo " head-node option is valid only if CORD_TEST_SETUP is two-node"
   exit 0
fi

if [[ $CORD_TEST_SETUP == "single" ]] && [[ $VM_NAME == "head-node" ]]; then
   echo "Incorrect argument error..."
   echo " head-node option is valid only if CORD_TEST_SETUP is two-node"
   exit 0
fi

headnode_server=`sudo virsh list --all|grep cord_compute1`
if [ "$CORD_ENV" == "false" ]; then
   echo "Only single node configuration is supported, if CORD_ENV is false"
   headnode_server = ""
fi

if [[ $CORD_TEST_SETUP != "single" ]] && [ ! -z $headnode_server ] && \
    [[ $VM_NAME == "ipoe-server" ]]; then
   echo "Incorrect argument error..."
   echo " In two-node setting, ipoe-server VM cannot be created in headnod "
   exit 0
fi
if [[ $CORD_TEST_SETUP != "single" ]] && [  -z $headnode_server ] && \
    [[ $VM_NAME == "onusim-server"* ]]; then
   echo "Incorrect argument error..."
   echo " In two-node setting, onusim-server can be created only in headnod "
   exit 0
fi

sudo apt-get update
    
if [ -f voltha.qcow2.gz ]; then
  echo "Decompressing voltha.qcow2.gz.....Please wait..."
  sudo apt-get install gzip -y
  gunzip voltha.qcow2.gz
  ln -s voltha.qcow2 $VM_NAME.qcow2
fi
if [ ! -f /usr/bin/virt-install ]; then
   echo "Installing libvirt...etc.."
   sudo apt-get -y --force-yes install qemu-kvm libvirt-bin libvirt-dev nfs-kernel-server
   echo "Using virt-install to create KVM virtual machine"
   echo "Installing virt-manager utilities"
   sudo apt-get install virt-manager -y
   echo "Installed virt-manager utilities. "
   echo "Using virt-install to create KVM virtual machine"
fi

echo "Creating the VM ...[$VM_NAME]"
# Check if domain already exists
virsh dominfo $VM_NAME > /dev/null 2>&1
if [ "$?" -eq 0 ]; then
    echo -n "[WARNING] $VM_NAME already exists.  "
    read -p "Do you want to overwrite $VM_NAME (y/[N])? " -r REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        virsh destroy $VM_NAME > /dev/null
        virsh undefine $VM_NAME > /dev/null
    else
        echo -e "\nNot overwriting $VM_NAME. Exiting..."
        exit 0
    fi
fi
# Directory to store images
DIR=`pwd`
#Ubuntu version. Make sure that cloud-image for the selected version is the 
# latest. For example, check by visting the page 
# https://cloud-images.ubuntu.com/releases/14.04.04/14.04.04 to 
# make sure that the image ubuntu-14.04-cloudimg-amd64-disk-1.img 
# is available on this page. For Ubuntu 16.04, use the version and release
# number as indicated below (see commented out part).


UBUNTU_VERSION=14.04
RELEASE_VERSION=14.04.4
#UBUNTU_VERSION=16.04
#RELEASE_VERSION=release-20171011
if [ ! -f $DIR/voltha.qcow2 ]
then
   echo "voltha.qcow2 image file not found in local directory"
   if [ ! -f $DIR/ubuntu_$UBUNTU_VERSION-server-cloudimg-amd64-disk1.img ]; then
      echo "Raw cloud image is also not found...."
#      read -p "Do you want to download from net? Enter Yes or No : " resp
#      resp_nocase=`echo $resp|tr "[:upper:]" "[:lower:]"`
      resp_nocase="yes"
      echo "Translated input $resp_nocase"
      if [ "$resp_nocase" == "yes" ]; then
         echo "Proceeding to download voltha.qcow2 from the net. It may take a while to complete"
      else
          echo "Cannot continue with the VM creation...Bailing out.."
          exit 0
      fi
      wget https://cloud-images.ubuntu.com/releases/$UBUNTU_VERSION/$RELEASE_VERSION/ubuntu-$UBUNTU_VERSION-server-cloudimg-amd64-disk1.img
   fi
   sleep 5
   echo "Converting ubuntu-$UBUNTU_VERSIONS-server-cloudimg-amd64-disk1.img" 
   qemu-img convert -O qcow2 ubuntu-$UBUNTU_VERSION-server-cloudimg-amd64-disk1.img voltha.qcow2
fi

# Location of cloud image
IMAGE=$DIR/voltha.qcow2

# Amount of RAM in MB
MEM=10000
DISK_SIZE=32G

# Number of virtual CPUs
CPUS=2

# Cloud init files
USER_DATA=user-data
META_DATA=meta-data
CI_ISO=$VM_NAME-cidata.iso
DISK=$VM_NAME.qcow2

# Bridge for VMs (default on Ubuntu/Vagrant is virbr0)
BRIDGE=virbr0
echo "Cord TEST setup = $CORD_TEST_SETUP"
if [ "$CORD_ENV" == "true" ]; then
   if [[ $CORD_TEST_SETUP == "single" ]]; then
       echo "Using vagrant-libvirt as NETWORK_NAME"
       NETWORK_NAME=vagrant-libvirt
   else
       echo "Using default as NETWORK_NAME"
       NETWORK_NAME=default
   fi
   COMPUTENODE_VM_NAME=cord_compute1 
else
   NETWORK_NAME=default
   COMPUTENODE_VM_NAME=vsg-server
fi

LEASE_FILE=/var/lib/libvirt/dnsmasq/$NETWORK_NAME.leases
if [ -f "$LEASE_FILE" ]; then
  cat $LEASE_FILE
else
  echo "Something wrong... $LEASE_FILE is missing"
  echo "Make sure that virbr0 is associated with vagrant-libvirt network"
  exit 1
fi

# Start clean
if [[ $VM_NAME != "head-node" ]]; then
  rm -rf $DIR/$VM_NAME
  mkdir -p $DIR/$VM_NAME
  echo "Preparing to create the VM $VM_NAME"
  pushd $DIR/$VM_NAME > /dev/null

    # Create log file
    touch $VM_NAME.log
    echo "Generating user_data metafile"
    $DIR/create-udata.sh $USER_DATA $VM_NAME
    if [ ! -f $USER_DATA ];then
      echo "Error...$USER_DATA is not found in $DIR/$VM_NAME.."
      exit 1
    fi 
    echo "$(date -R) Destroying the $VM_NAME domain (if it exists)..."

    # Remove domain with the same name
    virsh destroy $VM_NAME >> $VM_NAME.log 2>&1
    virsh undefine $VM_NAME >> $VM_NAME.log 2>&1

    # cloud-init config: set hostname, remove cloud-init package,
    # and add ssh-key 
    echo "instance-id: $VM_NAME; local-hostname: $VM_NAME" > $META_DATA

    echo "$(date -R) Copying template image..."
    cp $IMAGE $DISK
    sudo qemu-img resize $DISK + $DISK_SIZE
    sudo qemu-img info $DISK 
    sudo qemu-img info $DISK >>$VM_NAME.log 2>&1 

    # Create CD-ROM ISO with cloud-init config
    echo "$(date -R) Generating ISO for cloud-init..."
    echo "$(date -R) Generating ISO for cloud-init..." >>$VM_NAME.log 2>&1

    genisoimage -output $CI_ISO -volid cidata -joliet -r $USER_DATA $META_DATA &>> $VM_NAME.log
    echo "$(date -R) Generated ISO for cloud-init..." >>$VM_NAME.log 2>&1

    echo "$(date -R) Installing the domain and adjusting the configuration..."
    echo "[INFO] Installing with the following parameters:"
    echo "virt-install --import --name $VM_NAME --ram $MEM --vcpus $CPUS --disk
    path=$DISK,format=qcow2,bus=virtio --disk $CI_ISO,device=cdrom --network network=$NETWORK_NAME,model=virtio --os-type=linux --os-variant=none --noautoconsole"

    virt-install --virt-type=kvm --import --name $VM_NAME --ram $MEM --vcpus $CPUS --disk \
    path=$DISK,format=qcow2,bus=virtio --disk $CI_ISO,device=cdrom \
    --network network=$NETWORK_NAME,model=virtio --os-type=linux \
    --os-variant=none --noautoconsole

    MAC=$(virsh dumpxml $VM_NAME | awk -F\' '/mac address/ {print $2}')
    echo "Mac address of the Guest VM is $MAC"
    while true
    do
#        IP=$(grep -B1 $MAC /var/lib/libvirt/dnsmasq/$NETWORK_NAME.leases | head \
        IP=$(grep -B1 $MAC $LEASE_FILE | head \
             -n 1 | awk '{print $3}' | sed -e s/\"//g -e s/,//)
        if [ "$IP" = "" ]
        then
            sleep 1
        else
            break
        fi
    done

    # Eject cdrom
    echo "$(date -R) Cleaning up cloud-init..."
#TODO: hda is not the correct device name for the cdrom in Xenial. FIX IT
    virsh change-media $VM_NAME hda --eject --config >> $VM_NAME.log

    # Remove the unnecessary cloud init files
#    rm $USER_DATA $CI_ISO

    echo "$(date -R) DONE. SSH to $VM_NAME using $IP with  username 'ubuntu'."
    echo "Updating /etc/hosts file"
    sudo cp /etc/hosts /tmp
    sudo chmod 666 /tmp/hosts
#    sudo -E sed -i '/oai-server/c\' /tmp/hosts
    sudo -E sed -i /$VM_NAME/d /tmp/hosts
    sudo -E echo "$IP $VM_NAME" >>/tmp/hosts
    sudo cp /tmp/hosts /etc

 popd > /dev/null
fi

sudo apt-get update
apt-get install -y sshpass -y
sudo apt-get install bridge-utils -y
ipoebr=`sudo virsh net-info ipoe-network|grep ipoe-headbr`
nnibr=`sudo virsh net-info nni-network|grep nni-uplinkbr`
if [[ -z $ipoebr || -z $nnibr ]]; then
  echo "Creating ipoe-network and nni-network" 
  $DIR/setup-ipoe-networks.sh
fi
ipoebr=`sudo virsh net-info ipoe-network|grep ipoe-headbr`
nnibr=`sudo virsh net-info nni-network|grep nni-uplinkbr`
if [[ -z $ipoebr || -z $nnibr ]]; then
   echo "Error in creating ipoe-network or nni-network"
   exit 1
fi
if [ "$VM_NAME" == "head-node" ]; then
#   Add the IPOE_MGMT subnet address (e.g., 172.30.100.3) to ipoe-headbr
#
   echo "Disable bridge-arp and bridge-iptables"
   sudo -E sh -c "echo 1 >/proc/sys/net/ipv6/conf/all/forwarding"
   sudo -E /bin/bash -c 'echo 0 >/proc/sys/net/bridge/bridge-nf-call-arptables'
   sudo -E /bin/bash -c 'echo 0 >/proc/sys/net/bridge/bridge-nf-call-iptables'
   echo "Adding $IPOE_MGMT_SUBNET_PREFIX.3 to ipoe-headbr"
   sudo -E ip addr add $IPOE_MGMT_SUBNET_PREFIX.3/24 dev ipoe-headbr
   detach_computenode_vm
   sudo virsh domiflist cord_compute1|grep ipoe-headbr || sudo virsh attach-interface $COMPUTENODE_VM_NAME bridge ipoe-headbr
fi

if [ "$VM_NAME" == "vsg-server" ] || [[ $VM_NAME == "onusim-server"* ]];
then
   echo "Connecting the $VM_NAME VM to nni_uplinkbr"
   sudo brctl show|grep nni-uplinkbr || sudo brctl addbr nni-uplinkbr 
   sudo ip link set dev nni-uplinkbr dynamic off
   sudo ip link set dev nni-uplinkbr up
   sudo virsh attach-interface $VM_NAME bridge nni-uplinkbr
fi

if [[ $VM_NAME == "onusim-server"* ]]; 
then
   echo "Copying setup scripts to $VM_NAME"
   sudo -u ubuntu ssh-keygen -f "/home/ubuntu/.ssh/known_hosts" -R $VM_NAME 
   sudo -u ubuntu scp -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa /home/ubuntu/ipoe-setup.tar ubuntu@$VM_NAME:/home/ubuntu 
   echo "Login to $VM_NAME and run setup-dibbler-client.sh script"
   echo "$VM_NAME setup is complete..Nothing more to be done"
   exit 0
fi

#sudo ssh-keygen -f '/home/ubuntu/.ssh/known_hosts' -R ipoe-server

if [ "$VM_NAME" == "ipoe-server" ];
then
   echo "Connecting the VM $VM_NAME to ipoe-headbr"
   sudo brctl show|grep ipoe-headbr || sudo brctl addbr ipoe-headbr 
   sudo ip link set dev ipoe-headbr dynamic off
   sudo ip link set dev ipoe-headbr up
#   sudo virsh attach-interface $VM_NAME bridge ipoe-headbr 
   echo "Attaching $VM_NAME to ipoe-headbr"
   sudo virsh attach-interface $VM_NAME bridge ipoe-headbr 
   echo "Attaching ipoe-headbr to compute1 node, if not attached"
   if [ ! -z "$headnode_server" ]; then 
      detach_computenode_vm 
      sudo virsh domiflist cord_compute1|grep ipoe-headbr || sudo virsh attach-interface $COMPUTENODE_VM_NAME bridge ipoe-headbr 
   fi
# sudo /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
#
#   Add the IPOE_MGMT subnet address (e.g., 172.30.100.3) to ipoe-headbr
#
   echo "Disable bridge-arp and bridge-iptables"
   sudo -E sh -c "echo 1 >/proc/sys/net/ipv6/conf/all/forwarding"
   sudo -E /bin/bash -c 'echo 0 >/proc/sys/net/bridge/bridge-nf-call-arptables'
   sudo -E /bin/bash -c 'echo 0 >/proc/sys/net/bridge/bridge-nf-call-iptables'
   if [ ! -z "$headnode_server" ];then
      echo "Adding $IPOE_MGMT_SUBNET_PREFIX.3 to ipoe-headbr"
      sudo -E ip addr add $IPOE_MGMT_SUBNET_PREFIX.3/24 dev ipoe-headbr
   else
      echo "Adding $IPOE_MGMT_SUBNET_PREFIX.2 to ipoe-headbr"
      sudo -E ip addr add $IPOE_MGMT_SUBNET_PREFIX.2/24 dev ipoe-headbr
   fi
#   sudo ssh-keygen -f '/home/ubuntu/.ssh/known_hosts' -R ipoe-server
# sudo /sbin/iptables -A FORWARD -i eth0 -o ipoe-headbr -m state --state RELATED,ESTABLISHED -j ACCEPT
# sudo /sbin/iptables -A FORWARD -i ipoe-headbr -o eth0 -j ACCEPT
#
   sudo rm -f /home/ubuntu/.ssh/known_hosts
   sudo rm -f /root/.ssh/known_hosts
   known_host=`cat ~/.ssh/config|grep $VM_NAME`
   if [ -z  "$known_host" ]; then
       echo "$VM_NAME is not included in the ssh_config file"
       cat >> /home/ubuntu/.ssh/config << __EOF__

Host ipoe-server 
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel QUIET

__EOF__
cat >> /root/.ssh/config << __EOF__

Host ipoe-server 
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel QUIET

__EOF__

   sleep 1
   cat /home/ubuntu/.ssh/config
   sudo chown ubuntu:ubuntu /home/ubuntu/.ssh/config
   else
         echo "$VM_NAME is a known host in ssh_config file"
   fi 
   echo "Finishing up the final steps of ipoe-server VM installation"
   if [ ! -f /home/ubuntu/.ssh/id_rsa.pub ]; then
       echo "id_rsa.pub file does not exist. Use ssh-keygen to generate the RSA keys"
       exit 1
   fi
#   sshpass -p ubuntu ssh-copy-id -i /home/ubuntu/.ssh/id_rsa.pub ubuntu@ipoe-server
   sshpass -p ubuntu ssh -o StrictHostKeyChecking=no ubuntu@ipoe-server ls -ld /tmp
   if [ $? -eq 0 ]; then
      echo "ipoe-server can be reached successfully"
   else
      echo "ipoe-server cannot be reached..."
      echo "ipoe-server VM creation failed!!!!"
      exit 1
   fi
   sshpass -p ubuntu ssh -o StrictHostKeyChecking=no ubuntu@ipoe-server "sudo ip -f inet6 addr add $IPOE_IPV6_PREFIX::1/64 scope global dev $DHCP6S_IPOE_INTF" 
   sshpass -p ubuntu ssh -o StrictHostKeyChecking=no ubuntu@ipoe-server "sudo ip addr add $IPOE_MGMT_SUBNET_PREFIX.1/24 dev $DHCP6S_IPOE_INTF" 
   sshpass -p ubuntu ssh -o StrictHostKeyChecking=no ubuntu@ipoe-server "sudo ifconfig $DHCP6S_IPOE_INTF up" 
   sshpass -p ubuntu ssh -o StrictHostKeyChecking=no ubuntu@ipoe-server ssh-keygen -f /home/ubuntu/.ssh/known_hosts -R 192.168.122.1
   sshpass -p ubuntu ssh -o StrictHostKeyChecking=no ubuntu@ipoe-server sudo mkdir /cord 
   sshpass -p ubuntu ssh -o StrictHostKeyChecking=no ubuntu@ipoe-server sudo chown ubuntu /cord 
   sshpass -p ubuntu ssh -o StrictHostKeyChecking=no ubuntu@ipoe-server sudo chgrp ubuntu /cord 
   sshpass -p ubuntu ssh -o StrictHostKeyChecking=no ubuntu@ipoe-server sudo apt-get install sshfs -y 
   sshpass -p ubuntu ssh -o StrictHostKeyChecking=no ubuntu@ipoe-server 'sudo chown ubuntu /etc/fuse.conf' 
   sshpass -p ubuntu ssh -o StrictHostKeyChecking=no ubuntu@ipoe-server 'echo user_allow_other >>/etc/fuse.conf' 
   echo "Preparing local/remote environment to allow ipoe-server VM to mount host directory /home/ubuntu/ipoe-xxx to /cord directory"
   scp -i /home/ubuntu/.ssh/id_rsa /home/ubuntu/.ssh/id_rsa ubuntu@ipoe-server:/home/ubuntu/.ssh/id_rsa
   scp -i /home/ubuntu/.ssh/id_rsa /home/ubuntu/ipoe-setup.tar ubuntu@ipoe-server:/home/ubuntu/
   local_hostname=`hostname -s`
   authorized_host=`cat /home/ubuntu/.ssh/authorized_keys|grep $local_hostname`
   if [ -z  "$authorized_host" ]; then
      echo "Adding $local_hostname keys to the authorized_keys file"
      cat /home/ubuntu/.ssh/id_rsa.pub >>/home/ubuntu/.ssh/authorized_keys
   else
      echo "$local_hostname is a known host in authorized_keys file"
   fi 
#
# NOTE: Do not use sudo command to execute sshfs in ipoe-server
#
   sshpass -p ubuntu ssh -o StrictHostKeyChecking=no ubuntu@ipoe-server "sshfs -o allow_root,ssh_command='ssh -i /home/ubuntu/.ssh/id_rsa -o StrictHostKeyChecking=no' ubuntu@$local_hostname:/home/ubuntu/ipoe /cord"
   
   num_files=`sudo sshpass -p ubuntu ssh -o StrictHostKeyChecking=no ubuntu@ipoe-server 'ls /cord |wc -l'`

   echo "$num_files files are located under /cord"
   if [ $num_files -ne 0 ]; then
      echo "/home/ubuntu/ipoe host directory is successfully mounted in ipoe-server"
#      sudo sshpass -p ubuntu ssh -o StrictHostKeyChecking=no ubuntu@ipoe-server ls /cord 
   else
      echo "Error in mounting the /home/ubuntu/ipoe directory..."
      exit 1
   fi
fi 
echo "$0 execution completed successfully..."
 
time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"
