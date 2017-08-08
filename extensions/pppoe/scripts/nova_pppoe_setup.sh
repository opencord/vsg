
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
#** File:         nova_pppoe_setup.sh                       */
#** Contents:     Contains shell script to install apps,    */
#**               start Nova Consolidator app, call         */
#**               nova_vsg_monitor.sh                       */
#************************************************************/

# IP address of prod VM that can be accessed from 
# nova-compute, vSG and vcpe-docker instances.
# Need to replace the hard coded value with 
# some script that can dynamically pickup the
# IP address that is reachable from vSG and docker instances
# running inside vSG.
#
# ONOS_VM Public IP is same as virbr4 IP address in
# the prod VM

function create_env_file() {
   echo "ONOS_VM_PUBLIC_IP=$ONOS_VM_PUBLIC_IP; export ONOS_VM_PUBLIC_IP" >$HOME_DIR/$VSG_ENV_FILE
   echo "NETCFG_CONSOLIDATOR_IP=$NETCFG_CONSOLIDATOR_IP;export NETCFG_CONSOLIDATOR_IP " >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEGW_BR_IP=$VCPEGW_BR_IP;export VCPEGW_BR_IP" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEGW_BR_NAME=$VCPEGW_BR_NAME;export VCPEGW_BR_NAME" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEGW_BR_SUBNET=$VCPEGW_BR_SUBNET;export VCPEGW_BR_SUBNET" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VSG_WAN_BR_NAME=$VSG_WAN_BR_NAME;export VSG_WAN_BR_NAME" >>$HOME_DIR/$VSG_ENV_FILE
   echo "NETCFG_UP_IFACE=$NETCFG_UP_IFACE;export NETCFG_UP_IFACE" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEGW_DOCKER_IMAGE=$VCPEGW_DOCKER_IMAGE;export VCPEGW_DOCKER_IMAGE" >>$HOME_DIR/$VSG_ENV_FILE
   echo "PPPOE_INSTALL_DIR=$PPPOE_INSTALL_DIR;export PPPOE_INSTALL_DIR" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VSG_ENV_FILE=$VSG_ENV_FILE;export VSG_ENV_FILE" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEPROXY_WAN_IFACE=$VCPEPROXY_WAN_IFACE;export VCPEPROXY_WAN_IFACE" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEPROXY_WAN_IP=$VCPEPROXY_WAN_IP;export VCPEPROXY_WAN_IP" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEPROXY_IP_PREFIX=$VCPEPROXY_IP_PREFIX;export VCPEPROXY_IP_PREFIX" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEPROXY_DHCP_BASE=$VCPEPROXY_DHCP_BASE;export VCPEPROXY_DHCP_BASE" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEPROXY_PREFIX=$VCPEPROXY_PREFIX;export VCPEPROXY_PREFIX" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VSG_CP_IFACE=$VSG_CP_IFACE;export VSG_CP_IFACE" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEPROXY_CP_IFACE=$VCPEPROXY_CP_IFACE;export VCPEPROXY_CP_IFACE" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEPROXY_CP_MAC_PREFIX=$VCPEPROXY_CP_MAC_PREFIX;export VCPEPROXY_CP_MAC_PREFIX" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEPROXY_LOCAL_IP=$VCPEPROXY_LOCAL_IP;export VCPEPROXY_LOCAL_IP" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEPROXY_LOCAL_IP_PREFIX=$VCPEPROXY_LOCAL_IP_PREFIX;export VCPEPROXY_LOCAL_IP_PREFIX" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEPROXY_CP_IP_PREFIX=$VCPEPROXY_CP_IP_PREFIX;export VCPEPROXY_CP_IP_PREFIX" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEPROXY_CP_IP_START=$VCPEPROXY_CP_IP_START;export VCPEPROXY_CP_IP_START" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEGW_WAN_IP_PREFIX=$VCPEGW_WAN_IP_PREFIX;export VCPEGW_WAN_IP_PREFIX" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEGW_NETMASK_BITS=$VCPEGW_NETMASK_BITS;export VCPEGW_NETMASK_BITS" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEPROXY_DVAL_START=$VCPEPROXY_DVAL_START;export VCPEPROXY_DVAL_START" >>$HOME_DIR/$VSG_ENV_FILE
   echo "MAX_IP_PER_VSG=$MAX_IP_PER_VSG;export MAX_IP_PER_VSG" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEPROXY_DHCP_LISTEN_ADDRESS=$VCPEPROXY_DHCP_LISTEN_ADDRESS;export VCPEPROXY_DHCP_LISTEN_ADDRESS" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEPROXY_DHCP_LOW=$VCPEPROXY_DHCP_LOW;export VCPEPROXY_DHCP_LOW" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEPROXY_NUM_HOSTS=$VCPEPROXY_NUM_HOSTS;export VCPEPROXY_NUM_HOSTS" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VSG_NUM_ONUS=$VSG_NUM_ONUS;export VSG_NUM_ONUS" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VSG_LAN_IFACE=$VSG_LAN_IFACE;export VSG_LAN_IFACE" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEPROXY_DOCKER_HOME=$VCPEPROXY_DOCKER_HOME;export VCPEPROXY_DOCKER_HOME" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VSG_DOCKER_IPV4=$VSG_DOCKER_IPV4;export VSG_DOCKER_IPV4" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEGW_WAN_IP_START=$VCPEGW_WAN_IP_START;export VCPEGW_WAN_IP_START" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEGW_WAN_MAC_PREFIX=$VCPEGW_WAN_MAC_PREFIX;export VCPEGW_WAN_MAC_PREFIX" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEGW_DOCKER_HOME=$VCPEGW_DOCKER_HOME;export VCPEGW_DOCKER_HOME" >>$HOME_DIR/$VSG_ENV_FILE
 
   echo "VCPEGW_WAN_IFACE=$VCPEGW_WAN_IFACE;export VCPEGW_WAN_IFACE" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEGW_LOCAL_IFACE=$VCPEGW_LOCAL_IFACE;export VCPEGW_LOCAL_IFACE" >>$HOME_DIR/$VSG_ENV_FILE

   echo "AP_RESTAPI_PORT=$AP_RESTAPI_PORT;export AP_RESTAPI_PORT" >>$HOME_DIR/$VSG_ENV_FILE
   echo "AP_REST_NETCFG=$AP_REST_NETCFG;export AP_REST_NETCFG" >>$HOME_DIR/$VSG_ENV_FILE
   echo "APMGMT_TAR_FILE=$APMGMT_TAR_FILE;export APMGMT_TAR_FILE" >>$HOME_DIR/$VSG_ENV_FILE
   echo "IPV6_TAR_FILE=$IPV6_TAR_FILE;export IPV6_TAR_FILE" >>$HOME_DIR/$VSG_ENV_FILE
   echo "OnosIP=$OnosIP;export OnosIP" >>$HOME_DIR/$VSG_ENV_FILE
   echo "NETCFG_RESTAPI_PORT=$NETCFG_RESTAPI_PORT;export NETCFG_RESTAPI_PORT" >>$HOME_DIR/$VSG_ENV_FILE

   echo "PPPOE_APPS_DIR=$PPPOE_APPS_DIR;export PPPOE_APPS_DIR" >>$HOME_DIR/$VSG_ENV_FILE
   echo "PPPOE_AP_MGMT_DIR=$PPPOE_AP_MGMT_DIR;export PPPOE_AP_MGMT_DIR" >>$HOME_DIR/$VSG_ENV_FILE
   echo "IPV6_AP_DIR=$IPV6_AP_DIR;export IPV6_AP_DIR" >>$HOME_DIR/$VSG_ENV_FILE
   echo "NODEJS_MODULES_DIR=$NODEJS_MODULES_DIR;export NODEJS_MODULES_DIR" >>$HOME_DIR/$VSG_ENV_FILE
   echo "VCPEPROXY_BASE_IP=$VCPEPROXY_BASE_IP;export VCPEPROXY_BASE_IP" >>$HOME_DIR/$VSG_ENV_FILE
   echo "PPPOE_VCPE_TAR_FILE=$PPPOE_VCPE_TAR_FILE;export PPPOE_VCPE_TAR_FILE" >>$HOME_DIR/$VSG_ENV_FILE
}

function create_pppoe_server_script() {
    echo "#!/bin/bash" > $HOME_DIR/$PPPOE_SERVER_ADD_SCRIPT
    echo "PPPOE_SERVER_IP=\$1" >> $HOME_DIR/$PPPOE_SERVER_ADD_SCRIPT
    echo "curl -X POST http://$NETCFG_CONSOLIDATOR_IP:$NETCFG_RESTAPI_PORT/rest:\$PPPOE_SERVER_IP:$AP_RESTAPI_PORT" >> $HOME_DIR/$PPPOE_SERVER_ADD_SCRIPT
    chmod +x $HOME_DIR/$PPPOE_SERVER_ADD_SCRIPT

    echo "#!/bin/bash" > $HOME_DIR/$PPPOE_SERVER_DELETE_SCRIPT
    echo "PPPOE_SERVER_IP=\$1" >> $HOME_DIR/$PPPOE_SERVER_DELETE_SCRIPT
    echo "curl -X DELETE http://$NETCFG_CONSOLIDATOR_IP:$NETCFG_RESTAPI_PORT/rest:\$PPPOE_SERVER_IP:$AP_RESTAPI_PORT" >> $HOME_DIR/$PPPOE_SERVER_DELETE_SCRIPT
    chmod +x $HOME_DIR/$PPPOE_SERVER_DELETE_SCRIPT
}

echo "nova_pppoe_setup.sh: Execution Begin"
#
# NOVA-COMPUTE Node/VSG Globals.
#
# NOVA PPPoE Params
NOVA_PPPOE_IFACE=eth3
NOVA_PPPOE_IFACE_IP=10.200.200.200
NOVA_PPPOE_PEER_IP=10.200.200.100
NOVA_PPPOE_VXLAN_NAME=vxlanp
NOVA_PPPOE_VXLAN_ID=42
# NOVA PPPoE Params End
ONOS_VM_PUBLIC_IP=10.100.198.201; export ONOS_VM_PUBLIC_IP
OnosIP=$ONOS_VM_PUBLIC_IP; export OnosIP
NETCFG_CONSOLIDATOR_IP=10.3.0.1; export NETCFG_CONSOLIDATOR_IP
VCPEGW_BR_IP=10.3.0.2; export VCPEGW_BR_IP
VCPEGW_BR_NAME=vcpe_gwbr; export VCPEGW_BR_NAME
VCPEGW_BR_SUBNET=10.3.0.0; export VCPEGW_BR_SUBNET
VSG_WAN_BR_NAME=br-wan; export VSG_WAN_BR_NAME
VCPEGW_DOCKER_IMAGE=vcpe_gwdocker.tar; export VCPEGW_DOCKER_IMAGE 
VSG_LAN_IFACE=eth0; export VSG_LAN_IFACE
VCPEGW_DOCKER_HOME=/home/ubuntu; export VCPEGW_DOCKER_HOME
VSGGW_BR_NAME=vsg_gwbr; export VSGGW_BR_NAME
VCPEGW_WAN_IFACE=eth0; export VCPEGW_WAN_IFACE
VCPEGW_LOCAL_IFACE=eth1; export VCPEGW_LOCAL_IFACE
VCPEGW_WAN_MAC_PREFIX=00:17:38; export VCPEGW_WAN_MAC_PREFIX
VCPEGW_NETMASK_BITS=16; export VCPEGW_NETMASK_BITS
#
# The VCPEGW_WAN_IP_PREFIX should be in the same subnet as
# as the VCPEGW_BR_SUBNET
# If it is moved to Class-C subnet then the prefix should be
# adjusted.
VCPEGW_WAN_IP_PREFIX=10.3; export VCPEGW_WAN_IP_PREFIX

#
# No specific reason to start at 128. Just to keep addresses
# in non-overlapping range.
VCPEGW_WAN_IP_START=128; export VCPEGW_WAN_IP_START
#
# Interface that would be connecting the VSG instance to
# the vcpegw_br in the nova-compute node.
# 
NETCFG_UP_IFACE=eth2; export NETCFG_UP_IFACE
HOME_DIR=`pwd`; export HOME_DIR

PPPOE_INSTALL_DIR=/usr/local/pppoe; export PPPOE_INSTALL_DIR
PPPOE_VSG_ID_FILE_NAME=vsg_id.txt; export PPPOE_VSG_ID_FILE_NAME
VSG_ENV_FILE=vsg_env.txt; export VSG_ENV_FILE

### Env. variables used in setting up VCPEPROXY.
##
##
VCPEPROXY_WAN_IFACE=eth0; export VCPEPROXY_WAN_IFACE
VCPEPROXY_WAN_IP=0.0.0.0;export VCPEPROXY_WAN_IP
VCPEPROXY_IP_PREFIX=192.168.0;export VCPEPROXY_IP_PREFIX
VCPEPROXY_DHCP_BASE=50;export VCPEPROXY_DHCP_BASE
VCPEPROXY_BASE_IP=`echo $VCPEPROXY_IP_PREFIX.$VCPEPROXY_DHCP_BASE`; export VCPEPROXY_BASE_IP
VCPEPROXY_PREFIX=vcpe; export VCPEPROXY_PREFIX
VSG_CP_IFACE=$VCPEGW_BR_NAME; export VSG_CP_IFACE
VCPEPROXY_CP_IFACE=eth2; export VCPEPROXY_CP_IFACE
VCPEPROXY_CP_MAC_PREFIX=00:16:3E;export VCPEPROXY_CP_MAC
#
# LOCAL IP is hardcoded since it has to sink up with the XOS assigned
# IP address. May be later we can relax this restriction.
VCPEPROXY_LOCAL_IP="192.168.0.1"; export VCPEPROXY_LOCAL_IP
VCPEPROXY_LOCAL_IP_PREFIX="192.168.0"; export VCPEPROXY_LOCAL_IP_PREFIX
VCPEPROXY_CP_IP_PREFIX=$VCPEGW_WAN_IP_PREFIX; export VCPEPROXY_CP_IP_PREFIX
VCPEPROXY_CP_IP_START=2; export VCPEPROXY_CP_IP_START
VCPEPROXY_DHCP_LISTEN_ADDRESS=$VCPEPROXY_LOCAL_IP;export VCPEPROXY_DHCP_LISTEN_ADDRESS
VCPEPROXY_DHCP_LOW=$(( VCPEPROXY_DHCP_BASE + 1 ));export VCPEPROXY_DHCP_LOW
VCPEPROXY_NUM_HOSTS=100; export VCPEPROXY_NUM_HOSTS
VCPEPROXY_DHCP_HIGH=$(( VCPEPROXY_DHCP_LOW + VCPEPROXY_NUM_HOSTS ));export VCPEPROXY_DHCP_HIGH
VCPEPROXY_DOCKER_HOME=/home/ubuntu; export VCPEPROXY_DOCKER_HOME
VSG_NUM_ONUS=64; export VSG_NUM_ONUS

# The number of hosts is restricted to 4 for the project(4 APs per ONU). 
# For other projects, the number of hosts may be increased to a value upto 62
#
MAX_NUM_VSG=4; export MAX_NUM_VSG
VCPEPROXY_DVAL_START=$(( MAX_NUM_VSG+2 )); export VCPEPROXY_DVAL_START
MAX_IP_PER_VSG=$(( VSG_NUM_ONUS *(VCPEPROXY_NUM_HOSTS+1) )); export MAX_IP_PER_VSG

NETCFG_RESTAPI_PORT=24000; export NETCFG_RESTAPI_PORT
AP_RESTAPI_PORT=3000; export AP_RESTAPI_PORT
AP_REST_NETCFG=netcfg.sh; export AP_REST_NETCFG
APMGMT_TAR_DIR="/tmp"; export APMGMT_TAR_DIR
IPV6_TAR_DIR="/tmp"; export APMGMT_TAR_DIR
APMGMT_TAR_FILE_NAME=apmgmt_js.tar;export APMGMT_TAR_FILE_NAME
IPV6_TAR_FILE_NAME=ipv6.tar;export IPV6_TAR_FILE_NAME
APMGMT_TAR_FILE=`echo $APMGMT_TAR_DIR/$APMGMT_TAR_FILE_NAME`; export APMGMT_TAR_FILE
IPV6_TAR_FILE=`echo $IPV6_TAR_DIR/$IPV6_TAR_FILE_NAME`; export IPV6_TAR_FILE
PPPOE_VCPE_TAR_FILE=pppoe_vcpe_docker.tar;export PPPOE_VCPE_TAR_FILE
PPPOE_VCPE_TAR_GZ_FILE=pppoe_vcpe_docker.tar.gz
PPPOE_SERVER_ADD_SCRIPT=pppoe_server_add.sh
PPPOE_SERVER_DELETE_SCRIPT=pppoe_server_delete.sh
VSG_DOCKER_IPV4=""

if [[ "$1" == "ipv4" ]]; then
  echo "vsg vcpe supports $1"
  VSG_DOCKER_IPV4="ipv4"
else
  echo "vsg vcpe supports ipv6"
fi

if ping -c 3 $ONOS_VM_PUBLIC_IP >/dev/null; then
  reachable=1
else
  echo "ONOS VM ($ONOS_VM_PUBLIC_IP) is not reachable!!!"
  echo "$0 : Script execution failed!!!!!Bailing out..."
  exit 0
fi

if brctl show |grep $VSGGW_BR_NAME ; then
   echo "$VSGGW_BR_NAME exists,...Cleaning up $VSGGW_BR_NAME"
   sudo ip link set dev $VSGGW_BR_NAME down
   sudo brctl delbr $VSGGW_BR_NAME
   sleep 1
fi
sudo brctl addbr $VSGGW_BR_NAME
sudo ip link set dev $VSGGW_BR_NAME up
sudo ip link set dev $VSGGW_BR_NAME dynamic off
sudo ip addr add $NETCFG_CONSOLIDATOR_IP/$VCPEGW_NETMASK_BITS dev $VSGGW_BR_NAME
#PPPoE
if ifconfig -a |grep $NOVA_PPPOE_VXLAN_NAME; then
   sudo ip link set dev $NOVA_PPPOE_VXLAN_NAME down
   sudo ip link delete $NOVA_PPPOE_VXLAN_NAME
   sleep 1
fi
sudo ifconfig $NOVA_PPPOE_IFACE up
sudo ifconfig $NOVA_PPPOE_IFACE $NOVA_PPPOE_IFACE_IP/24
sudo ip link add $NOVA_PPPOE_VXLAN_NAME type vxlan id $NOVA_PPPOE_VXLAN_ID remote $NOVA_PPPOE_PEER_IP local $NOVA_PPPOE_IFACE_IP dev $NOVA_PPPOE_IFACE
sudo ip link set up dev $NOVA_PPPOE_VXLAN_NAME
sudo brctl addif $VSGGW_BR_NAME $NOVA_PPPOE_VXLAN_NAME
#PPPoE End
ifconfig $VSGGW_BR_NAME 
echo "Clearing VSG ID file.."
rm -f ${HOME_DIR}/$PPPOE_VSG_ID_FILE_NAME
touch ${HOME_DIR}/$PPPOE_VSG_ID_FILE_NAME
echo "ONOS VM Reachable=$reachable"
echo "VCPEGW_BR setup..."

if [ ! -f ~/admin-openrc.sh ]; then
   echo "admin-openrc.sh is not found under /home/ubuntu directory"
   scp vagrant@prod:admin-openrc.sh ~/
   sudo chmod +x ~/admin-openrc.sh
fi 
cp ~/admin-openrc.sh ${HOME_DIR}

sudo apt list --installed | grep sshpass > /dev/null 2>&1
if [ "$?" == 1 ]; then
   sudo apt-get install sshpass -y
fi

if [ -d ${HOME_DIR}/apps ]; then
   echo "Using ${HOME_DIR}/apps to install REST server applications"
else
   echo "apps directory is missing..."
   echo "$0: Script execution failed!!!.Bailing out.."
   exit 0
fi

#
# Update NetcfgConfig.json with ONOS_VM_PUBLIC_IP
#
echo "{\"OnosIP\":\"$ONOS_VM_PUBLIC_IP\"}" > $HOME_DIR/apps/netcfgConsolidator/NetcfgConfig.json


PPPOE_APPS_DIR="$PPPOE_INSTALL_DIR/utils/"; export PPPOE_APPS_DIR
PPPOE_AP_MGMT_DIR=pppoeMgmt; export PPPOE_AP_MGMT_DIR
IPV6_AP_DIR=ipv6Apps; export IPV6_AP_DIR
NODEJS_MODULES_DIR=/usr/local/lib/node_modules/; export NODEJS_MODULES_DIR
if [ -d "$PPPOE_APPS_DIR" ]; then
  echo "$PPPOE_APPS_DIR exists, removing..."
  sudo rm -rf $PPPOE_APPS_DIR
  sudo rm -rf $PPPOE_INSTALL_DIR
fi

if [ ! -f $HOME_DIR/apps/$PPPOE_AP_MGMT_DIR/authwebapp/js/jquery.js ]; then
  wget https://code.jquery.com/jquery-1.11.1.js
  mv jquery-1.11.1.js $HOME_DIR/apps/$PPPOE_AP_MGMT_DIR/authwebapp/js/jquery.js
fi

if [ ! -f $HOME_DIR/apps/$IPV6_AP_DIR/tayga ]; then
  wget http://www.litech.org/tayga/tayga-0.9.2.tar.bz2
  tar xvf tayga-0.9.2.tar.bz2
  cd tayga-0.9.2
  ./configure
  make
  cp tayga $HOME_DIR/apps/$IPV6_AP_DIR
fi

if [ ! -f $HOME_DIR/apps/$IPV6_AP_DIR/totd ]; then
  wget https://launchpad.net/ubuntu/+archive/primary/+files/totd_1.5.1.orig.tar.gz
  tar xvf totd_1.5.1.orig.tar.gz
  cd totd-1.5.1
  ./configure OPTFLAGS="-Wno-error"
  make
  cp totd $HOME_DIR/apps/$IPV6_AP_DIR
fi

if [ ! -f $PPPOE_VCPE_TAR_FILE ]; then
    if [ -f $PPPOE_VCPE_TAR_GZ_FILE ]; then
        gzip -d $PPPOE_VCPE_TAR_GZ_FILE
    fi
fi
sudo mkdir $PPPOE_INSTALL_DIR
sudo mkdir $PPPOE_APPS_DIR

sudo cp -r $HOME_DIR/apps/* $PPPOE_APPS_DIR
echo $ONOS_VM_PUBLIC_IP >$PPPOE_INSTALL_DIR/onos_vm_public_ip
#
# Create environment file.
#
echo "Creating environment file"
create_env_file
create_pppoe_server_script

sudo $HOME_DIR/nova_consolidator_setup.sh
sudo $HOME_DIR/nova_consolidator_stop.sh
sleep 2
sudo $HOME_DIR/nova_consolidator_start.sh
$HOME_DIR/nova_vsg_monitor.sh > $HOME_DIR/nova_vsg_monitor.log 2>&1 &
echo "nova_pppoe_setup.sh: Execution End"

