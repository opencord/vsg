#!/bin/bash
#**************************************************************/
#** File:         setup-compute_node-vm.sh                    */
#** Contents:     Contains shell script to config compute node*/
#**               virtual machine.                            */
#*************************************************************/
time_begin=`date`
echo "$0: Script execution begins: $time_begin"

function detach_vsg_vm()
{
   echo "Entering detach_vsg_vm...."
   mac_addr_list=`sudo virsh domiflist $vsg_name|grep ipoe-intbr|awk '{print $5}'`
   i=0
   echo "Detaching MAC address list: $mac_addr_list"
   if [ ! -z "$mac_addr_list" ]; then
      IFS=' ' read -ra mac_addr <<< $mac_addr_list
      for hwaddr in "${mac_addr[@]}"
      do
         i=$(( i+1 )) 
         echo "Detaching HW address[$i]=$hwaddr"
         sudo virsh detach-interface $vsg_name bridge --mac $hwaddr
      done
   fi
}

function cleanup_ipv6_addresses
{
   ipv6_addr_list=`sudo ifconfig ipoe-intbr|grep inet6|grep Global|awk '{print $3}'`
   i=0
   echo "Deleting IPv6 addresses: $ipv6_addr_list"
   if [ ! -z "$ipv6_addr_list" ]; then
      IFS=' ' read -ra ipv6_addr <<< $ipv6_addr_list
      for addr in "${ipv6_addr[@]}"
      do
         i=$(( i+1 ))
         echo "IPV6 address[$i]=$addr"
         sudo ip addr del $addr dev ipoe-intbr
      done
   fi
}

function setup_compute_node_vm_env
{
   sudo apt-get install sshpass -y
   sudo brctl show|grep ipoe-intbr || sudo brctl addbr ipoe-intbr
   sudo ip link set dev ipoe-intbr dynamic off
   sudo ip link set dev ipoe-intbr up
   sudo brctl show ipoe-intbr|grep eth3 || sudo brctl addif ipoe-intbr eth3
   sudo ifconfig eth3 up
   cleanup_ipv6_addresses
   sudo -E ip addr add $IPOE_IPV6_PREFIX::2/64 dev ipoe-intbr 
   sleep 1
   sudo -E sh -c "echo 1 >/proc/sys/net/ipv6/conf/all/forwarding"
   sudo -E sh -c "echo 0 >/proc/sys/net/bridge/bridge-nf-call-arptables"
   sudo -E sh -c "echo 0 >/proc/sys/net/bridge/bridge-nf-call-iptables"
   ping6 -I ipoe-intbr -c 10  $IPOE_IPV6_PREFIX::1
   if [ $? != 0 ]; then
      echo "WARNING...Unable to reach IPOE-Server..."
   fi
   echo "Assigning the IP address $IPOE_MGMT_SUBNET_PREFIX.4 to ipoe-intbr"
   sudo -E ip addr add "$IPOE_MGMT_SUBNET_PREFIX.4"/24 dev ipoe-intbr
   echo "Testing the reachability of $IPOE_MGMT_SUBNET_PREFIX.3 in head node"
   ping -I ipoe-intbr -c 5 $IPOE_MGMT_SUBNET_PREFIX.3 
   if [ $? != 0 ]; then
      echo "WARNING...Unable to reach $IPOE_MGMT_SUBNET_PREFIX.3 in headnode..."
   else
      echo "Copying cord_rsa files to head node ..."
      sshpass -p ubuntu scp -o StrictHostKeyChecking=no /home/ubuntu/.ssh/cord_rsa* ubuntu@$IPOE_MGMT_SUBNET_PREFIX.3:/home/ubuntu/.ssh 
      sshpass -p ubuntu ssh -o StrictHostKeyChecking=no ubuntu@$IPOE_MGMT_SUBNET_PREFIX:3 ls -l /home/ubuntu/.ssh
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
if [ -z "$WIDE_DHCP6_VARS" ]; then
   WIDE_DHCP6_VARS="wide-dhcp6.vars"
   echo "Using $WIDE_DHCP6_VARS as IPOE_IPV6 setup vars"
fi
source $IPOE_SETUP_DIR/$WIDE_DHCP6_VARS

if [ -z "$IPOE_IPV6_PREFIX" ]; then
   IPOE_IPV6_PREFIX="FD64:8D64:AF0C:1"
   echo "Using $IPOE_IPV6_PREFIX as IPOE_IPv6_PREFIX"
fi

if [ -z "$VSG_IPV4_PREFIX" ]; then
    VSG_IPV4_PREFIX="172.27.0"
    echo "Using $VSG_IPV4_PREFIX as VSG interface IPv4 address prefix"
fi
if [ -z "$IPOE_MGMT_SUBNET_PREFIX" ]; then
    IPOE_MGMT_SUBNET_PREFIX=172.30.100
    echo "Using $IPOE_MGMT_SUBNET_PREFIX as IPOE mgmt prefix"
fi
if [ $# -eq 0 ]; then
  echo "Just setting up the compute-node VM environment.."
  setup_compute_node_vm_env
  time_end=`date`
  echo "$0 Execution begin tim $time_begin"
  echo "$0: Script execution completed successfully: $time_end"
  exit 1
fi


#read -p "Enter VSG instance name ? " -r REPLY
inst_name=$1

inst_prefix=`echo $inst_name|grep "instance-"`
if [ -z "$inst_prefix" ]; then
  echo "Invalid Response. Should be something like instance-0000000x"
  exit 1
fi
vsg_name=`sudo virsh list --all|grep $inst_name| awk '{ print $2 }'`
if [ -z "$vsg_name" ]; then
  echo "VSG $vsg_name has not been created"
  exit 1
fi
IFS='-' read -ra instance_parts <<< "$inst_name"
instance_ascii_num=`echo "${instance_parts[1]}"`
echo "instance_part[0]=$instance_pre instance_part[1]=$instance_ascii_num"
instance_id=`printf '%d' $instance_ascii_num`
echo " In ASCII=$instance_parts[1] in decimal $instance_id"

instance_num=$instance_id
instance_id=$(( instance_id+1 ))
VSG_IPV4_ADDRESS=`echo "$VSG_IPV4_PREFIX.$instance_id"`
echo "Using the $VSG_IPV4_ADDRESS to access the VSG Virtual machine"
#sudo apt-get install -y sshpass 
ssh -o StrictHostKeyChecking=no ubuntu@$VSG_IPV4_ADDRESS ping -c 3 8.8.8.8
if [ $? -ne 0 ]; then
   echo "Error in reaching $VSG_IPV4_ADDRESS from compute_node"
   exit 1
else
   echo "VSG VM can be reached from compute node"
fi
echo "Setting up compute_node_vm, if not setup already.."
setup_compute_node_vm_env
echo "Detaching any stale attachments to ipoe-intbr"
detach_vsg_vm
echo "Attaching ipoe-intbr to the $vsg_name"
sudo -E virsh attach-interface $vsg_name bridge ipoe-intbr

scp /home/ubuntu/.bashrc ubuntu@$VSG_IPV4_ADDRESS:/home/ubuntu
scp /home/ubuntu/.profile ubuntu@$VSG_IPV4_ADDRESS:/home/ubuntu
scp /home/ubuntu/ipoe-setup.tar ubuntu@$VSG_IPV4_ADDRESS:/home/ubuntu 
echo "Copy RSA keys cord_rsa to vSG"
ssh-copy-id -i /home/ubuntu/.ssh/cord_rsa ubuntu@$VSG_IPV4_ADDRESS
ssh -o StrictHostKeyChecking=no ubuntu@$VSG_IPV4_ADDRESS 'sudo gpasswd -a ubuntu docker'
echo "Extracting ipoe-setup file in VSG VM"
ssh -o StrictHostKeyChecking=no ubuntu@$VSG_IPV4_ADDRESS 'rm -rf /home/ubuntu/ipoe'
ssh -o StrictHostKeyChecking=no ubuntu@$VSG_IPV4_ADDRESS 'tar -xvf ipoe-setup.tar'
ssh -o StrictHostKeyChecking=no ubuntu@$VSG_IPV4_ADDRESS chmod +x $IPOE_SETUP_DIR/setup-vsg-vm.sh
echo "Generating dhcp6c conf files for vcpe docker instances"
ssh -o StrictHostKeyChecking=no ubuntu@$VSG_IPV4_ADDRESS "cd $IPOE_SETUP_DIR;$IPOE_SETUP_DIR/create-dhcp6-client-conf.sh $WIDE_DHCP6_VARS"

echo "Setting up VSG VM to support IPoE_IPv6"
ssh -o StrictHostKeyChecking=no ubuntu@$VSG_IPV4_ADDRESS "cd $IPOE_SETUP_DIR;$IPOE_SETUP_DIR/setup-vsg-vm.sh $instance_num" 
time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"
