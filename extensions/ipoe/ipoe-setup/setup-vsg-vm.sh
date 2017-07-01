#!/bin/bash
#************************************************************/
#** File:         setup-vsg-vm.sh                           */
#** Contents:     Contains shell script to config VSG       */
#**               virtual machine.                          */
#************************************************************/
time_begin=`date`
echo "$0: Script execution begins: $time_begin"

function cleanup_ipv6_addresses
{
   ipv6_addr_list=`sudo ifconfig ipoe-intbr|grep Global|awk '{print $3}'`
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

if [ $# -ne 1 ]; then
  echo "Using default VSG instance id as 3"
  instance_id=3
else
  instance_id=$1
fi

if [ -z "$WIDE_DHCP6_VARS" ]; then
   WIDE_DHCP6_VARS="wide-dhcp6.vars"
   echo "Using $WIDE_DHCP6_VARS as IPOE_IPV6 setup vars"
fi
if [ -z "$IPOE_SETUP_DIR" ]; then 
  echo "Warning...IPOE_SETUP_DIR is not setup. Source from default location.."
  if [ -f /home/ubuntu/ipoe/ipoe-setup/$WIDE_DHCP6_VARS ]; then
    source /home/ubuntu/ipoe/ipoe-setup/$WIDE_DHCP6_VARS
  else
    source /cord/ipoe-setup/$WIDE_DHCP6_VARS
  fi
  if [ "$CORD_ENV" == "true" ]; then
      IPOE_SETUP_DIR=/home/ubuntu/ipoe/ipoe-setup
  else
      IPOE_SETUP_DIR=/cord/ipoe-setup
  fi
  echo "Using $IPOE_SETUP_DIR as ipoe-setup dir"
fi
if [ -z "$vsg_home_dir" ]; then
   vsg_home_dir=/home/ubuntu
   echo "Using $vsg_home_dir as vsg_home_dir"
fi
cd $IPOE_SETUP_DIR
source $WIDE_DHCP6_VARS
cp $IPOE_SETUP_DIR/rest-api.tar.gz /tmp
echo "Generating dhcp6 client files..."
./create-dhcp6-client-conf.sh $WIDE_DHCP6_VARS

sudo iptables -L > /dev/null
sudo ip6tables -L > /dev/null
sudo apt-get update
sudo apt-get install -y bridge-utils
sudo apt-get install -y arping 
echo "Delete ipoe-intbr if it exists"
sudo ifconfig -a |grep ipoe-intbr&&sudo ifconfig ipoe-intbr down
sudo brctl show|grep ipoe-intbr&&sudo brctl delbr ipoe-intbr
echo "Creating ipoe-intbr.."
sudo brctl show|grep ipoe-intbr || sudo brctl addbr ipoe-intbr
sudo ip link set dev ipoe-intbr dynamic off
sudo ip link set dev ipoe-intbr up
sleep 1
if [ "$CORD_ENV" == "true" ]; then
  sudo ifconfig -a |grep eth2 || echo "WARNING...eth2 interface missing"
  sudo ifconfig eth2 up
  sudo brctl show ipoe-intbr|grep eth2 || sudo brctl addif ipoe-intbr eth2
else
  sudo ifconfig eth1 up
  sudo brctl show ipoe-intbr|grep eth1 || sudo brctl addif ipoe-intbr eth1
fi

sudo ip neigh flush dev ipoe-intbr
vsg_mgmt_ipv4=$(( $instance_id-2+4 )) 
echo "Using $vsg_mgmt_ipv4 as vsg_mgmt ip prefix"
cleanup_ipv6_addresses
sudo -E ip addr add $IPOE_IPV6_PREFIX::$instance_id/64 dev ipoe-intbr
sudo -E sh -c "echo 1 >/proc/sys/net/ipv6/conf/all/forwarding"
sudo -E sh -c "echo 0 >/proc/sys/net/bridge/bridge-nf-call-arptables"
sudo -E sh -c "echo 0 >/proc/sys/net/bridge/bridge-nf-call-iptables"
echo "Setting IPOE_IPv4_MGMT_ADDRESS as $IPOE_MGMT_SUBNET_PREFIX.$vsg_mgmt_ipv4"
sudo -E ip addr add "$IPOE_MGMT_SUBNET_PREFIX.$vsg_mgmt_ipv4"/24 dev ipoe-intbr

ping6 -I ipoe-intbr -c 10  $IPOE_IPV6_PREFIX::1
if [ $? != 0 ]; then
  echo "WARNING...Unable to reach IPOE-Server..."
fi
ping6 -c 10  $IPOE_IPV6_PREFIX::2
if [ $? != 0 ]; then
  echo "WARNING...Unable to reach compute-node VM..."
fi
echo " Ping the IPOE_MGMT address in headnode"
ping -c 5  $IPOE_MGMT_SUBNET_PREFIX.3
if [ $? != 0 ]; then
  echo "WARNING...Unable to reach IPOE_MGMT address in head node..."
fi
if [ ! -f /usr/local/bin/pipework ]; then
  if [ "$CORD_ENV" == "true" ]; then
      sudo cp ./pipework /usr/local/bin
  else
      cp pipework /tmp
      sudo cp /tmp/pipework /usr/local/bin
  fi
  
fi


cd /tmp
echo "Cleaning up nodejs and reinstalling the javascripts.."
sudo killall nodejs
sudo apt-get purge nodejs -y
sudo rm -rf /usr/local/lib/node_modules
#setup rest api start #
echo "Installing nodejs and npm  in vsg-server vm"
sudo apt-get install -y nodejs  npm
echo "Installing line-reader , json-server,bluebird  in vsg-server vm"
sudo npm install -g json-server@0.8.12 bluebird line-reader
#setup rest api end #

#Copy Rest Api codes#
sudo cp /tmp/rest-api.tar.gz /usr/local/lib/node_modules/
cd /usr/local/lib/node_modules/
sudo tar -zxvf rest-api.tar.gz
#
# Temp. Fix. Nodejs module expect setup-vcpe-docker.sh to be under
#  /home/ubuntu
cp $IPOE_SETUP_DIR/reinit-dhcp6c.sh /tmp
cp $IPOE_SETUP_DIR/setup-vcpe-docker.sh /tmp
cp /tmp/setup-vcpe-docker.sh /home/ubuntu
cp $IPOE_SETUP_DIR/reinit-vcpe-docker.sh /tmp
cp /tmp/reinit-vcpe-docker.sh /home/ubuntu

echo "Starting nodejs server ..."
killall -q nodejs
nohup nodejs -i server.js $IPOE_MGMT_PORT $IPOE_SETUP_DIR/$WIDE_DHCP6_VARS> /tmp/rest.log 2>&1 & 

time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"
