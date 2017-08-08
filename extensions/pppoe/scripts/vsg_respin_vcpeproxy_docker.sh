
# Copyright 2017-present Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


#!/bin/bash
#************************************************************/
#** File:         vsg_respin_vcpeproxy_docker.sh            */
#** Contents:     Contains shell script to setup dnsmasq ,  */
#**               CP plane path,etc and respin the vcpe     */
#**               docker instance created by XOS.           */
#**                                                         */
#**      This script should be executed as super-user       */
#************************************************************/

echo "vsg_respin_vcpeproxy_docker.sh Execution: Begin"
function setup_cp_path_in_docker (){
# Set up cp networking in docker using pipework
 echo "Executing setup_cp_path_in_docker...."
#
# TODO: FOr some reason, MAC address argument seems to throw pipework off
# balance. Use auto-generated MAC address
#
# docker exec $VCPEPROXY_NAME ifconfig $VCPEPROXY_CP_IFACE>> /dev/null || pipework $VSG_CP_IFACE -i $VCPEPROXY_CP_IFACE $VCPEPROXY_NAME $VCPEPROXY_CP_IP/$VCPEGW_NETMASK_BITS@$VCPEPROXY_BRIDGE_IP 
 docker exec $VCPEPROXY_NAME ifconfig $VCPEPROXY_CP_IFACE>> /dev/null || pipework $VSG_CP_IFACE -i $VCPEPROXY_CP_IFACE $VCPEPROXY_NAME $VCPEPROXY_CP_IP/$VCPEGW_NETMASK_BITS
 sleep 1
 echo "waiting for $VCPEPROXY_CP_IFACE"
 pipework --wait -i $VCPEPROXY_CP_IFACE 
 sleep 1
 echo "$VCPEPROXY_CP_IFACE interface in container is UP"
 docker exec $VCPEPROXY_NAME ifconfig $VCPEPROXY_CP_IFACE
 docker exec $VCPEPROXY_NAME route add -net 10.6.1.0 netmask 255.255.255.0 gw 10.6.1.129 dev eth0
}

#
## Prepare container volume files to be mounted to the docker instance
#

function update_mounted_files() {
     sed -i "s/@@VCPEPROXY_DHCP_LISTEN_ADDRESS@@/${VCPEPROXY_DHCP_LISTEN_ADDRESS}/g" ${DNSMASQ_VCPE_CONF}
     sed -i "s/@@VCPEPROXY_DHCP_LOW@@/${VCPEPROXY_DHCP_LOW}/g" ${DNSMASQ_VCPE_CONF}
     sleep 1
     sed -i "s/@@VCPEPROXY_DHCP_HIGH@@/${VCPEPROXY_DHCP_HIGH}/g" ${DNSMASQ_VCPE_CONF}

#
# Update rc.local file
#
    sed -i "s/@@VCPEPROXY_SUBNET@@/${VCPEPROXY_SUBNET}/g" ${RC_LOCAL}
}

function assign_addresses_to_vcpeproxy() {
   MAC_3OCT=$(( STAG % 256 ))
   MAC_2OCT=$(( CTAG % 256 ))
   MAC_1OCT=$(( VCPE_PROXY_ID % 256 ))
   HEX_MAC_3OCT=$( printf "%02x" $MAC_3OCT )
   HEX_MAC_2OCT=$( printf "%02x" $MAC_2OCT )
   HEX_MAC_1OCT=$( printf "%02x" $MAC_1OCT )
   VCPEPROXY_CP_MAC=`echo $VCPEPROXY_CP_MAC_PREFIX:$HEX_MAC_3OCT:$HEX_MAC_2OCT:$HEX_MAC_1OCT`
   echo "VCPEPROXY_CP_MAC .....$VCPEPROXY_CP_MAC"
   export VCPEPROXY_CP_MAC
#
#   
# vcpe_gwbr_ip is computed in nova_vsg_setup.sh script.
#
   VCPEPROXY_BRIDGE_IP=`echo $vcpe_gwbr_ip`
   export VCPEPROXY_BRIDGE_IP
   echo "VCPE_BRIDGE_IP.......$VCPEPROXY_BRIDGE_IP"
#
#   D-octet of the VCPEPROXY_CP_IP address is
#   calculated under the assumption each VCPE_PROXY is assigned
#   4 (NUM_HOSTS value) additional WAN address one for each AP. 
# 
   echo "CP_IP_PREFIX = $VCPEPROXY_CP_IP_PREFIX"
   VCPEPROXY_CP_IP_CVAL=$(( VSG_ID % 256 ))
   VCPEPROXY_CP_IP_DVAL=$(( (VCPE_PROXY_ID-1)*(NUM_HOSTS+1) +1 ))
   VCPEPROXY_CP_IP=`echo $VCPEPROXY_CP_IP_PREFIX.$VCPEPROXY_CP_IP_CVAL.$VCPEPROXY_CP_IP_DVAL`
   export VCPEPROXY_CP_IP
   echo "VCPEPROXY_CP_IP..... $VCPEPROXY_CP_IP"

  VCPEPROXY_DHCP_LISTEN_ADDRESS=$VCPEPROXY_LOCAL_IP
  export VCPEPROXY_DHCP_LISTEN_ADDRESS
  echo "VCPEPROXY_DHCP_LISTEN_ADDRESS $VCPEPROXY_DHCP_LISTEN_ADDRESS"

  VCPEPROXY_DHCP_LOW=`echo $VCPEPROXY_LOCAL_IP_PREFIX.$VCPEPROXY_DHCP_LOW`
  export VCPEPROXY_DHCP_LOW
  echo "VCPEPROXY_AP_DHCP_LOW $VCPEPROXY_DHCP_LOW"
  VCPEPROXY_DHCP_HIGH=`echo $VCPEPROXY_LOCAL_IP_PREFIX.$VCPEPROXY_DHCP_HIGH`
  export VCPEPROXY_DHCP_HIGH
  echo "VCPEPROXY_DHCP_HIGH $VCPEPROXY_DHCP_HIGH"

  VCPEPROXY_SUBNET=`echo $VCPEPROXY_LOCAL_IP_PREFIX.0`
  export VCPEPROXY_SUBNET
  echo "VCPEPROXY_SUBNET $VCPEPROXY_SUBNET"
}

function pause_and_update_container_volume() {
 echo "Entering pause_and_update_container_volume"
# 
# Docker containers created by XOS run in auto-start mode.
# So, just pause the container instance and restart it to
# pickup DHCP changes.
#
 echo "Pausing the container $VCPEPROXY_NAME"
 if docker ps |grep $VCPEPROXY_NAME ; then
   docker pause $VCPEPROXY_NAME
   sleep 2
   docker ps -a
 fi
 echo "Checking container directory"
 if [ -d $CONTAINER_DIR ]; then
   echo "$CONTAINER_DIR exists...Just replace vcpe.conf and rc.local with template files"
   cp $HOME_DIR/docker_mounts/etc/dnsmasq.d/vcpe.conf $DNSMASQ_VCPE_CONF
   cp $HOME_DIR/docker_mounts/mount/rc.local $RC_LOCAL
 else
   echo "$CONATAINER_DIR does not exist..create it first"
   echo "Creating container directory"
   mkdir $CONTAINER_DIR
   echo "Copying container volumes"
   cp -r $HOME_DIR/docker_mounts/* $CONTAINER_DIR
 fi
}

function unpause_and_respin_docker() {
    echo "Spinning up the stopped container"
    docker unpause $VCPEPROXY_NAME
    sleep 1
    docker restart $VCPEPROXY_NAME
    sleep 5
    if docker ps -a |grep $VCPEPROXY_NAME |grep Up ; then
       echo "Docker instance is up and running.."
    else
       echo "Error:...Docker instance $VCPEPROXY_NAME is not Up..."
    fi
    echo "Stopping ufw firewall in docker"
    docker exec $VCPEPROXY_NAME ufw disable
    docker exec $VCPEPROXY_NAME ufw status
}

echo "Begin: Starting execution of $0 script"

if [ -z $vsg_home_dir ]; then
  echo "WARNING...HOME Directory may not be setup properly"
  vsg_home_dir=`pwd`
fi
echo "Dump environment variables"
env >/tmp/vsg_env.out

echo "Trying to respin $VCPEPROXY_NAME: [$STAG] [$CTAG]"
docker inspect $VCPEPROXY_NAME > /dev/null 2>&1

if [ "$?" == 1 ]; then
   echo "$VCPEPROXY_NAME is not running!!!"
   exit 1
fi
if [ -z $VCPE_PROXY_ID ]; then
   echo "WARNING****VCPE_PROXY_ID is not set.." 
   exit 1
fi
if [ -z $CONTAINER_VOLUMES ];then
  echo "WARNING**** CONTAINER_VOLUMES not set.."
  CONTAINER_VOLUMES=/var/container_volumes; export CONTAINER_VOLUMES
fi
if [ -z DOCKER_SPINUP_DIR ]; then
   echo "WARNING***** DOCKER SPINUP directory not set..."  
   DOCKER_SPINUP_DIR=/usr/local/sbin; export DOCKER_SPINUP_DIR
fi
HOME_DIR=$vsg_home_dir; export HOME_DIR
CONTAINER_DIR=$CONTAINER_VOLUMES/$VCPEPROXY_NAME

VCPEPROXY_DHCP_HIGH=$(( VCPEPROXY_DHCP_LOW + VCPEPROXY_NUM_HOSTS ))

DNSMASQ_VCPE_CONF=$CONTAINER_DIR/etc/dnsmasq.d/vcpe.conf;export DNSMASQ_VCPE_CONF
RC_LOCAL=$CONTAINER_DIR/mount/rc.local;export RC_LOCAL

echo "Pausing the docker container $VCPEPROXY_NAME"
pause_and_update_container_volume 
echo "Assign addresses for vcpe_proxy"
assign_addresses_to_vcpeproxy
echo "Updating container volumes"
update_mounted_files
unpause_and_respin_docker
echo "Setting up vcpeproxy control plane path.."
setup_cp_path_in_docker

echo "Execution of vsg_respin_vcpeproxy_docker.sh script is complete: End"

